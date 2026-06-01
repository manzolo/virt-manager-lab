#!/usr/bin/env bash
# Test end-to-end di tutte le installazioni del lab.
# Per ogni VM: reinstalla da zero -> attende lo spegnimento (autoinstall ok) ->
# riavvia -> verifica via guest-agent che il desktop sia pronto (graphical.target
# + display manager attivo + virtiofs) -> screenshot. Esegue N VM in parallelo
# (default 4) e a fine run scrive un report HTML con PASS/FAIL di ognuna.
#
# Uso:
#   bash scripts/test-all.sh            # usa TEST_PARALLEL da test-all.env (4)
#   bash scripts/test-all.sh 6          # 6 in parallelo
#   TEST_OUTDIR=/data/e2e bash scripts/test-all.sh
#
# ATTENZIONE: REINSTALLA (cancella e ricrea) le VM elencate in test-all.env.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"
source "$SCRIPT_DIR/test-all.env"
[ -n "${1:-}" ] && TEST_PARALLEL="$1"

RUN_TS="$(date +%Y%m%d-%H%M%S)"
OUT="$TEST_OUTDIR/$RUN_TS"
mkdir -p "$OUT/logs" "$OUT/screens" "$OUT/results"
REPORT="$OUT/report.html"

vmstate() { LC_ALL=C virsh domstate "$1" 2>/dev/null | head -n1; }
ga_ready() { virsh qemu-agent-command "$1" '{"execute":"guest-ping"}' >/dev/null 2>&1; }

# Esegue cmd nel guest via guest-agent. Stampa stdout; ritorna l'exit code del comando.
ga_run() {
  local vm="$1" cmd="$2" enc out pid st ec payload
  enc="$(printf '%s' "$cmd" | base64 | tr -d '\n')"
  payload="{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"/bin/sh\",\"arg\":[\"-c\",\"echo $enc | base64 -d | /bin/sh\"],\"capture-output\":true}}"
  out="$(virsh qemu-agent-command "$vm" "$payload" 2>/dev/null)" || return 125
  pid="$(sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' <<<"$out")"
  [ -n "$pid" ] || return 125
  for _ in $(seq 1 40); do
    st="$(virsh qemu-agent-command "$vm" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" 2>/dev/null)" || return 125
    if [[ "$st" == *'"exited":true'* ]]; then
      sed -n 's/.*"out-data":"\([^"]*\)".*/\1/p' <<<"$st" | base64 -d 2>/dev/null
      ec="$(sed -n 's/.*"exitcode":\([0-9][0-9]*\).*/\1/p' <<<"$st")"
      return "${ec:-0}"
    fi
    sleep 1
  done
  return 124
}

# Pipeline completa per una VM. Scrive $OUT/results/$id (formato chiave<TAB>valore).
run_one() {
  local id="$1" vm="$2" script="$3"
  local t0 status phase detail dm shared sess pkg s seen dl
  t0=$(date +%s); status=""; phase=""; detail=""; dm="-"; shared="-"; sess="-"; pkg="-"

  _progress "$id" "$vm" "RUNNING" "install" "0" "autoinstall base in corso..."
  echo ">>> [$id] install $(date +%T)"
  # FIRSTBOOT_AUTOSTART=false: lo script fa SOLO l'autoinstall base e si spegne;
  # boot + install desktop (firstboot) + verifica li gestisce questo test.
  printf 'S\n' | FIRSTBOOT_AUTOSTART=false bash "$script" > "$OUT/logs/$id-install.log" 2>&1

  # Fase 1: autoinstall base -> shut off
  seen=0; dl=$(( $(date +%s) + TEST_BASE_TIMEOUT ))
  while :; do
    s="$(vmstate "$vm")"
    [ "$s" = "running" ] && seen=1
    if [ "$s" = "shut off" ] && [ "$seen" = 1 ]; then break; fi
    if [ "$(date +%s)" -ge "$dl" ]; then
      status="FAIL"; phase="install"; detail="autoinstall non completato entro ${TEST_BASE_TIMEOUT}s (crash/blocco)"
      [ -n "$(vmstate "$vm")" ] && virsh destroy "$vm" >/dev/null 2>&1
      _diag_disk "$id" "$vm"
      _write_result "$id" "$vm" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$dm" "$shared" "$sess" "$pkg"
      return
    fi
    sleep "$TEST_POLL"
  done

  # Fase 2: boot + desktop pronto
  _progress "$id" "$vm" "RUNNING" "boot+desktop" "$(( $(date +%s)-t0 ))" "autoinstall ok, boot e desktop in corso..."
  echo ">>> [$id] boot+desktop $(date +%T)"
  virsh start "$vm" >/dev/null 2>&1
  local agent=0; dl=$(( $(date +%s) + TEST_DESKTOP_TIMEOUT ))
  while :; do
    if ga_ready "$vm"; then
      agent=1
      if ga_run "$vm" 'systemctl get-default | grep -qx graphical.target && systemctl is-active --quiet display-manager.service' >/dev/null 2>&1; then
        status="PASS"; phase="desktop"; break
      fi
    fi
    if [ "$(date +%s)" -ge "$dl" ]; then
      if [ "$agent" = 1 ]; then
        status="FAIL"; phase="desktop"; detail="desktop/display-manager non attivo entro ${TEST_DESKTOP_TIMEOUT}s"
      else
        status="WARN"; phase="boot"; detail="VM avviata ma guest-agent assente: verifica lo screenshot"
      fi
      break
    fi
    sleep "$TEST_POLL"
  done

  # Dettagli (best-effort via agent)
  if [ "$agent" = 1 ]; then
    dm="$(ga_run "$vm" 'systemctl show -p Id --value display-manager.service 2>/dev/null' 2>/dev/null | tr -d "\r\n")"
    ga_run "$vm" 'ls /mnt/shared >/dev/null 2>&1' >/dev/null 2>&1 && shared="si" || shared="no"
    sess="$(ga_run "$vm" 'loginctl list-sessions --no-legend 2>/dev/null | wc -l' 2>/dev/null | tr -d "\r\n ")"
    pkg="$(ga_run "$vm" 'for p in kubuntu-desktop xubuntu-desktop ubuntu-mate-desktop ubuntu-budgie-desktop lubuntu-desktop ubuntu-desktop; do v=$(dpkg-query -W -f="${Version}" $p 2>/dev/null); [ -n "$v" ] && { echo "$p $v"; break; }; done' 2>/dev/null | tr -d "\r\n")"
  fi
  [ -z "$status" ] && { status="FAIL"; phase="?"; detail="esito indeterminato"; }

  # Screenshot
  if virsh screenshot "$vm" "$OUT/screens/$id.ppm" >/dev/null 2>&1; then
    convert "$OUT/screens/$id.ppm" "$OUT/screens/$id.png" 2>/dev/null && rm -f "$OUT/screens/$id.ppm"
  fi
  _write_result "$id" "$vm" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$dm" "$shared" "$sess" "$pkg"
  echo ">>> [$id] $status ($phase) $(date +%T)"
}

# Diagnostica dal disco (a VM spenta) per i fallimenti d'installazione
_diag_disk() {
  local id="$1" vm="$2" disk
  disk="$(virsh domblklist "$vm" 2>/dev/null | awk '$2 ~ /\.qcow2$/{print $2; exit}')"
  [ -n "$disk" ] || return 0
  virt-cat -a "$disk" /var/log/apt/history.log 2>/dev/null | grep -E '^(Commandline|Error|End-Date)' | tail -10 > "$OUT/logs/$id-apt-history.txt"
  virt-cat -a "$disk" /var/log/dpkg.log 2>/dev/null | tail -30 > "$OUT/logs/$id-dpkg-tail.txt"
  virt-cat -a "$disk" /var/log/lab-desktop.log 2>/dev/null | tail -30 > "$OUT/logs/$id-lab-desktop.txt"
}

_write_result() {
  local f="$OUT/results/$1"
  {
    printf 'id\t%s\n' "$1"; printf 'vm\t%s\n' "$2"; printf 'status\t%s\n' "$3"
    printf 'phase\t%s\n' "$4"; printf 'secs\t%s\n' "$5"; printf 'detail\t%s\n' "$6"
    printf 'dm\t%s\n' "$7"; printf 'shared\t%s\n' "$8"; printf 'sessions\t%s\n' "$9"
    printf 'pkg\t%s\n' "${10}"
  } > "$f.tmp" && mv -f "$f.tmp" "$f"
}

# Aggiornamento di stato intermedio (live nell'HTML)
_progress() { _write_result "$1" "$2" "$3" "$4" "$5" "$6" "-" "-" "-" "-"; }

gen_html() {
  local total=0 pass=0 fail=0 warn=0 running=0 REFRESH_META=""
  [ -f "$OUT/.done" ] || REFRESH_META='<meta http-equiv="refresh" content="15">'
  for r in "$OUT"/results/*; do
    [ -f "$r" ] || continue
    total=$((total+1))
    case "$(awk -F'\t' '$1=="status"{print $2}' "$r")" in
      PASS) pass=$((pass+1));; WARN) warn=$((warn+1));;
      RUNNING|PENDING) running=$((running+1));; *) fail=$((fail+1));;
    esac
  done
  {
    cat <<HEAD
<!doctype html><html lang="it"><head><meta charset="utf-8">
$REFRESH_META
<title>VM Lab - Test E2E $RUN_TS</title>
<style>
body{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:24px;background:#0f1115;color:#e6e6e6}
h1{font-size:20px} .sub{color:#9aa0a6;margin-bottom:18px}
.summary{display:flex;gap:14px;margin:14px 0 22px}
.card{padding:12px 18px;border-radius:10px;font-weight:600}
.tot{background:#1f2430} .ok{background:#10391f;color:#7ee2a8} .ko{background:#3a1620;color:#f3a0b0} .wa{background:#3a3416;color:#e8d488}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{border-bottom:1px solid #262b36;padding:8px 10px;text-align:left;vertical-align:top}
th{color:#9aa0a6;font-weight:600}
.badge{padding:2px 9px;border-radius:20px;font-size:12px;font-weight:700}
.b-PASS{background:#10391f;color:#7ee2a8} .b-FAIL{background:#3a1620;color:#f3a0b0} .b-WARN{background:#3a3416;color:#e8d488}
.b-RUNNING{background:#16304a;color:#8ec6f0} .b-PENDING{background:#23262e;color:#9aa0a6} .b-NO-RUN{background:#3a1620;color:#f3a0b0}
img{max-width:320px;border:1px solid #262b36;border-radius:6px;display:block}
details{color:#c2c7cf} summary{cursor:pointer;color:#9aa0a6}
.det{color:#f3a0b0;font-size:13px}
</style></head><body>
<h1>VM Lab — Test end-to-end</h1>
<div class="sub">Run $RUN_TS · parallelismo $TEST_PARALLEL · host $(hostname)</div>
<div class="summary">
  <div class="card tot">Totale: $total</div>
  <div class="card ok">PASS: $pass</div>
  <div class="card ko">FAIL: $fail</div>
  <div class="card wa">WARN: $warn</div>
  <div class="card" style="background:#16304a;color:#8ec6f0">In corso: $running</div>
</div>
<div class="sub">$([ -f "$OUT/.done" ] && echo "Completato." || echo "Test in esecuzione — la pagina si aggiorna ogni 15s.")</div>
<table><thead><tr>
<th>ID</th><th>VM</th><th>Esito</th><th>Fase</th><th>Durata</th><th>Display mgr</th>
<th>Desktop pkg</th><th>shared</th><th>sessioni</th><th>Screenshot</th><th>Dettaglio</th>
</tr></thead><tbody>
HEAD
    local item id vm
    for item in "${TEST_ITEMS[@]}"; do
      IFS='|' read -r id vm _ <<<"$item"
      local r="$OUT/results/$id"
      [ -f "$r" ] || { echo "<tr><td>$id</td><td>$vm</td><td><span class=\"badge b-FAIL\">NO-RUN</span></td><td colspan=8>nessun risultato</td></tr>"; continue; }
      local st ph se de dmv sh ss pk dur
      st=$(awk -F'\t' '$1=="status"{print $2}' "$r"); ph=$(awk -F'\t' '$1=="phase"{print $2}' "$r")
      se=$(awk -F'\t' '$1=="secs"{print $2}' "$r"); de=$(awk -F'\t' '$1=="detail"{sub(/^detail\t/,"");print $2}' "$r")
      dmv=$(awk -F'\t' '$1=="dm"{print $2}' "$r"); sh=$(awk -F'\t' '$1=="shared"{print $2}' "$r")
      ss=$(awk -F'\t' '$1=="sessions"{print $2}' "$r"); pk=$(awk -F'\t' '$1=="pkg"{print $2}' "$r")
      dur=$(printf '%dm%02ds' $((se/60)) $((se%60)))
      local img="screens/$id.png"; local imgcell="—"
      [ -f "$OUT/screens/$id.png" ] && imgcell="<a href=\"$img\"><img src=\"$img\"></a>"
      local logs="<details><summary>log</summary><a href=\"logs/$id-install.log\">install.log</a>"
      [ -f "$OUT/logs/$id-apt-history.txt" ] && logs="$logs · <a href=\"logs/$id-apt-history.txt\">apt</a>"
      [ -f "$OUT/logs/$id-dpkg-tail.txt" ] && logs="$logs · <a href=\"logs/$id-dpkg-tail.txt\">dpkg</a>"
      [ -f "$OUT/logs/$id-lab-desktop.txt" ] && logs="$logs · <a href=\"logs/$id-lab-desktop.txt\">firstboot</a>"
      logs="$logs</details>"
      echo "<tr><td>$id</td><td>$vm</td><td><span class=\"badge b-${st}\">$st</span></td><td>$ph</td><td>$dur</td><td>${dmv:-–}</td><td>${pk:-–}</td><td>$sh</td><td>$ss</td><td>$imgcell</td><td class=\"det\">${de}<br>$logs</td></tr>"
    done
    cat <<FOOT
</tbody></table>
<p class="sub">Output completo in $OUT</p>
</body></html>
FOOT
  } > "$REPORT"
}

# Permette di caricare le funzioni (es. per test del report) senza eseguire il main:
#   TEST_NO_MAIN=1 source scripts/test-all.sh
if [ "${TEST_NO_MAIN:-}" = "1" ]; then return 0 2>/dev/null || exit 0; fi

# ---- main ----
echo "=== TEST E2E start $(date) — parallelismo $TEST_PARALLEL — ${#TEST_ITEMS[@]} VM ==="
echo "Output: $OUT"
mem_g=$(free -g | awk '/Mem/{print $7}')
echo "RAM disponibile: ${mem_g}G — richiesti ~$((TEST_PARALLEL*4))G di picco"

# Stato iniziale PENDING + HTML subito disponibile
for item in "${TEST_ITEMS[@]}"; do
  IFS='|' read -r id vm script <<<"$item"
  _progress "$id" "$vm" "PENDING" "in coda" "0" "in attesa"
done
gen_html
echo "REPORT HTML (gia' apribile, si auto-aggiorna ogni 15s): $REPORT"

# Refresher live finche' non compare il sentinel .done
( while [ ! -f "$OUT/.done" ]; do gen_html; sleep 15; done ) &
refresher=$!

# Pool: max TEST_PARALLEL pipeline run_one in parallelo
pids=()
for item in "${TEST_ITEMS[@]}"; do
  IFS='|' read -r id vm script <<<"$item"
  run_one "$id" "$vm" "$script" &
  pids+=($!)
  sleep 8   # sfasa i lanci: evita burst di probe os-variant / xorriso concorrenti
  # throttle: conta SOLO i run_one ancora vivi (non il refresher)
  while :; do
    alive=0
    for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && alive=$((alive+1)); done
    (( alive < TEST_PARALLEL )) && break
    sleep 3
  done
done
for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done

touch "$OUT/.done"
kill "$refresher" 2>/dev/null; wait "$refresher" 2>/dev/null
gen_html
echo "=== TEST E2E fine $(date) ==="
pass=$(grep -lP '^status\tPASS$' "$OUT"/results/* 2>/dev/null | wc -l)
notpass=$(( ${#TEST_ITEMS[@]} - pass ))
echo "Risultato: $pass PASS, $notpass non-PASS su ${#TEST_ITEMS[@]}"
echo "REPORT HTML: $REPORT"
