#!/usr/bin/env bash
# Libreria condivisa per i test end-to-end del lab (Linux e Windows).
# Sorgente comune a:
#   scripts/test-linux.sh  (solo VM Linux)
#   scripts/test-win.sh    (solo VM Windows)
#   scripts/test-all.sh    (Linux + Windows, report unico)
#
# Il chiamante imposta queste variabili PRIMA di sourcare questo file e chiamare
# engine_main:
#   TITLE          titolo mostrato nel report HTML
#   PARALLEL       quante VM in parallelo
#   OUTDIR         cartella base degli output (run datati al suo interno)
#   OPEN_BROWSER   1/0 apri il report nel browser all'avvio
#   ITEMS          array "id|vm|script|type[|agent]"  (type = linux|windows)
#   EXCLUDED_ITEMS array "id|vm|motivo"  (mostrate come EXCLUDED, non testate)
#
# Schema risultato unificato ($OUT/results/<id>, chiave<TAB>valore):
#   id vm ostype status phase secs detail env desktop shared extra
#     env      Linux: display-manager id   | Windows: nome OS
#     desktop  Linux: pacchetto desktop    | Windows: tools installati (si/no)
#     shared   virtiofs montato (si/no/-)
#     extra    Linux: n. sessioni          | Windows: hostname

# ---- helper di base -------------------------------------------------------
vmstate() { LC_ALL=C virsh domstate "$1" 2>/dev/null | head -n1; }
ga_ready() { virsh qemu-agent-command "$1" '{"execute":"guest-ping"}' >/dev/null 2>&1; }

# Escape minimale per inserire una stringa dentro JSON (backslash e doppi apici).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# shutdown_after_test <vm> <timeout_s>
shutdown_after_test() {
  local vm="$1" timeout="$2" dl s
  [ "$(vmstate "$vm")" = "running" ] || return 0
  virsh shutdown "$vm" >/dev/null 2>&1 || true
  dl=$(( $(date +%s) + timeout ))
  while :; do
    s="$(vmstate "$vm")"
    [ "$s" = "shut off" ] && return 0
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 5
  done
  virsh destroy "$vm" >/dev/null 2>&1 || true
}

capture_screenshot() {
  local id="$1" vm="$2" try png_size
  for try in 1 2 3; do
    virsh send-key "$vm" KEY_SPACE >/dev/null 2>&1 || true
    sleep 2
    if virsh screenshot "$vm" "$OUT/screens/$id.ppm" >/dev/null 2>&1; then
      convert "$OUT/screens/$id.ppm" "$OUT/screens/$id.png" 2>/dev/null && rm -f "$OUT/screens/$id.ppm"
    fi
    png_size="$(stat -c %s "$OUT/screens/$id.png" 2>/dev/null || echo 0)"
    [ "$png_size" -ge 4096 ] && return 0
    virsh send-key "$vm" KEY_ESC >/dev/null 2>&1 || true
  done
  return 1
}

# Esegue cmd nel guest Linux via guest-agent. Stampa stdout; ritorna l'exit code.
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

# Esegue 'cmd.exe /c <cmdline>' nel guest Windows. Stampa stdout; ritorna l'exit code.
ga_run_win() {
  local vm="$1" cmdline="$2" arg_esc out pid st ec payload
  arg_esc="$(json_escape "$cmdline")"
  payload="{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"cmd.exe\",\"arg\":[\"/c\",\"$arg_esc\"],\"capture-output\":true}}"
  out="$(virsh qemu-agent-command "$vm" "$payload" 2>/dev/null)" || return 125
  pid="$(sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' <<<"$out")"
  [ -n "$pid" ] || return 125
  for _ in $(seq 1 30); do
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

# Nome OS dal guest agent Windows (guest-get-osinfo -> pretty-name).
ga_osname() {
  local vm="$1" js
  js="$(virsh qemu-agent-command "$vm" '{"execute":"guest-get-osinfo"}' 2>/dev/null)" || return 1
  sed -n 's/.*"pretty-name":"\([^"]*\)".*/\1/p' <<<"$js"
}

# Diagnostica dal disco (a VM spenta) per i fallimenti d'installazione Linux.
_diag_disk() {
  local id="$1" vm="$2" disk
  disk="$(virsh domblklist "$vm" 2>/dev/null | awk '$2 ~ /\.qcow2$/{print $2; exit}')"
  [ -n "$disk" ] || return 0
  virt-cat -a "$disk" /var/log/apt/history.log 2>/dev/null | grep -E '^(Commandline|Error|End-Date)' | tail -10 > "$OUT/logs/$id-apt-history.txt"
  virt-cat -a "$disk" /var/log/dpkg.log 2>/dev/null | tail -30 > "$OUT/logs/$id-dpkg-tail.txt"
  virt-cat -a "$disk" /var/log/lab-desktop.log 2>/dev/null | tail -30 > "$OUT/logs/$id-lab-desktop.txt"
}

# ---- risultati ------------------------------------------------------------
# _write_result id vm ostype status phase secs detail env desktop shared extra
_write_result() {
  local f="$OUT/results/$1"
  {
    printf 'id\t%s\n' "$1"; printf 'vm\t%s\n' "$2"; printf 'ostype\t%s\n' "$3"
    printf 'status\t%s\n' "$4"; printf 'phase\t%s\n' "$5"; printf 'secs\t%s\n' "$6"
    printf 'detail\t%s\n' "$7"; printf 'env\t%s\n' "$8"; printf 'desktop\t%s\n' "$9"
    printf 'shared\t%s\n' "${10}"; printf 'extra\t%s\n' "${11}"
  } > "$f.tmp" && mv -f "$f.tmp" "$f"
}

# _progress id vm ostype status phase secs detail
_progress() { _write_result "$1" "$2" "$3" "$4" "$5" "$6" "$7" "-" "-" "-" "-"; }

# ---- pipeline Linux -------------------------------------------------------
run_one_linux() {
  local id="$1" vm="$2" script="$3"
  local t0 status phase detail dm shared sess pkg s seen dl agent
  t0=$(date +%s); status=""; phase=""; detail=""; dm="-"; shared="-"; sess="-"; pkg="-"

  _progress "$id" "$vm" "Linux" "RUNNING" "install" "0" "autoinstall base in corso..."
  echo ">>> [$id] install $(date +%T)"
  # FIRSTBOOT_AUTOSTART=false: lo script fa SOLO l'autoinstall base e si spegne.
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
      _write_result "$id" "$vm" "Linux" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$dm" "$pkg" "$shared" "$sess"
      return
    fi
    sleep "$TEST_POLL"
  done

  # Fase 2: boot + desktop pronto
  _progress "$id" "$vm" "Linux" "RUNNING" "boot+desktop" "$(( $(date +%s)-t0 ))" "autoinstall ok, boot e desktop in corso..."
  echo ">>> [$id] boot+desktop $(date +%T)"
  virsh start "$vm" >/dev/null 2>&1
  agent=0; dl=$(( $(date +%s) + TEST_DESKTOP_TIMEOUT ))
  while :; do
    if ga_ready "$vm"; then
      agent=1
      # Check primario: systemctl (funziona su Ubuntu/Debian; bloccato da SELinux su Fedora).
      # Fallback: socket X11 o Wayland presenti (funziona anche con SELinux restrittivo).
      if ga_run "$vm" 'systemctl get-default | grep -qx graphical.target && systemctl is-active --quiet display-manager.service' >/dev/null 2>&1 \
         || ga_run "$vm" '[ -S /tmp/.X11-unix/X0 ] || ls /run/user/[0-9]*/wayland-0 2>/dev/null | grep -q .' >/dev/null 2>&1; then
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

  if [ "$agent" = 1 ]; then
    dm="$(ga_run "$vm" 'systemctl show -p Id --value display-manager.service 2>/dev/null' 2>/dev/null | tr -d "\r\n")"
    # Fallback DM detection per sistemi con SELinux restrittivo (es. Fedora Silverblue).
    [ -z "$dm" ] && dm="$(ga_run "$vm" 'ls /run/systemd/units/ 2>/dev/null | sed -n "s/^invocation:\(gdm\|sddm\|lightdm\|lxdm\)\.service$/\1.service/p" | head -1' 2>/dev/null | tr -d "\r\n")"
    ga_run "$vm" 'ls /mnt/shared >/dev/null 2>&1' >/dev/null 2>&1 && shared="si" || shared="no"
    sess="$(ga_run "$vm" 'loginctl list-sessions --no-legend 2>/dev/null | wc -l' 2>/dev/null | tr -d "\r\n ")"
    pkg="$(ga_run "$vm" 'for p in kubuntu-desktop xubuntu-desktop ubuntu-mate-desktop ubuntu-budgie-desktop lubuntu-desktop ubuntu-desktop; do v=$(dpkg-query -W -f="${Version}" $p 2>/dev/null); [ -n "$v" ] && { echo "$p $v"; break; }; done' 2>/dev/null | tr -d "\r\n")"
  fi
  [ -z "$status" ] && { status="FAIL"; phase="?"; detail="esito indeterminato"; }

  if ! capture_screenshot "$id" "$vm"; then
    if [ "$status" = "PASS" ]; then
      # Desktop verificato via systemctl/socket ma screenshot nero: tipico dei compositor
      # Wayland (es. niri) che non renderizzano sul framebuffer virtuale. Non è un errore.
      detail="${detail:+$detail; }screenshot nero (compositor Wayland?)"
    else
      detail="${detail:+$detail; }screenshot assente o probabilmente nero"
    fi
  fi
  shutdown_after_test "$vm" "$TEST_SHUTDOWN_TIMEOUT"
  _write_result "$id" "$vm" "Linux" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$dm" "$pkg" "$shared" "$sess"
  echo ">>> [$id] $status ($phase) $(date +%T)"
}

# ---- pipeline Windows -----------------------------------------------------
run_one_win() {
  local id="$1" vm="$2" script="$3" agent="$4"
  local t0 status phase detail osname host tools shared s seen dl
  t0=$(date +%s); status=""; phase=""; detail=""
  osname="-"; host="-"; tools="-"; shared="-"

  _progress "$id" "$vm" "Windows" "RUNNING" "install" "0" "reinstall Windows in corso..."
  echo ">>> [$id] install $(date +%T)"
  # Lo script create_* ritorna subito (--noautoconsole): l'install prosegue nella VM.
  printf 'S\n' | bash "$script" > "$OUT/logs/$id-install.log" 2>&1

  # Fase 1: la VM deve risultare avviata.
  seen=0; dl=$(( $(date +%s) + TEST_WIN_BOOT_TIMEOUT ))
  while :; do
    s="$(vmstate "$vm")"
    [ "$s" = "running" ] && { seen=1; break; }
    if [ "$(date +%s)" -ge "$dl" ]; then break; fi
    sleep "$TEST_WIN_POLL"
  done
  if [ "$seen" != 1 ]; then
    status="FAIL"; phase="install"; detail="VM non avviata entro ${TEST_WIN_BOOT_TIMEOUT}s (script create fallito? vedi install.log)"
    _write_result "$id" "$vm" "Windows" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$osname" "$tools" "$shared" "$host"
    echo ">>> [$id] $status ($phase) $(date +%T)"
    return
  fi

  if [ "$agent" = "yes" ]; then
    # Fase 2: install + OOBE + autologon + virtio-win-guest-tools -> guest agent up.
    _progress "$id" "$vm" "Windows" "RUNNING" "boot+tools" "$(( $(date +%s)-t0 ))" "install in corso, attendo il guest agent..."
    echo ">>> [$id] boot+tools $(date +%T)"
    dl=$(( $(date +%s) + TEST_WIN_READY_TIMEOUT ))
    while :; do
      if ga_ready "$vm"; then status="PASS"; phase="desktop"; break; fi
      if [ "$(date +%s)" -ge "$dl" ]; then
        if [ "$(vmstate "$vm")" = "running" ]; then
          status="WARN"; phase="boot"; detail="guest agent assente entro ${TEST_WIN_READY_TIMEOUT}s: verifica lo screenshot"
        else
          status="FAIL"; phase="install"; detail="VM non piu' in esecuzione e guest agent mai risposto (install fallita?)"
        fi
        break
      fi
      sleep "$TEST_WIN_POLL"
    done

    if [ "$status" = "PASS" ]; then
      osname="$(ga_osname "$vm" | tr -d '\r\n')"; [ -n "$osname" ] || osname="Windows"
      host="$(ga_run_win "$vm" 'hostname' 2>/dev/null | tr -d '\r\n ')"; [ -n "$host" ] || host="-"
      if ga_run_win "$vm" 'sc query VirtioFsSvc' 2>/dev/null | grep -q RUNNING; then shared="si"; else shared="no"; fi
      if ga_run_win "$vm" 'if exist C:\install-tools.log (echo PRESENT) else (echo MISSING)' 2>/dev/null | grep -q PRESENT; then tools="si"; else tools="no"; fi
    fi
  else
    # VM senza canale guest-agent (win7u): attesa fissa, poi screenshot.
    _progress "$id" "$vm" "Windows" "RUNNING" "install(no-agent)" "$(( $(date +%s)-t0 ))" "VM senza guest agent: attendo ~$((TEST_WIN_NOAGENT_WAIT/60))min poi screenshot..."
    echo ">>> [$id] no-agent wait $(date +%T)"
    dl=$(( $(date +%s) + TEST_WIN_NOAGENT_WAIT ))
    while [ "$(date +%s)" -lt "$dl" ]; do
      [ "$(vmstate "$vm")" = "running" ] || break
      sleep "$TEST_WIN_POLL"
    done
    if [ "$(vmstate "$vm")" = "running" ]; then
      status="WARN"; phase="no-agent"; detail="canale guest-agent assente: esito basato solo sullo screenshot"
    else
      status="FAIL"; phase="install"; detail="VM spenta prima del termine atteso (install fallita?)"
    fi
  fi
  [ -z "$status" ] && { status="FAIL"; phase="?"; detail="esito indeterminato"; }

  if ! capture_screenshot "$id" "$vm"; then
    detail="${detail:+$detail; }screenshot assente o probabilmente nero"
    [ "$status" = "PASS" ] && status="WARN"
  fi
  shutdown_after_test "$vm" "$TEST_WIN_SHUTDOWN_TIMEOUT"
  _write_result "$id" "$vm" "Windows" "$status" "$phase" "$(( $(date +%s)-t0 ))" "$detail" "$osname" "$tools" "$shared" "$host"
  echo ">>> [$id] $status ($phase) $(date +%T)"
}

# Dispatch in base al type dell'item.
run_one() {
  local id="$1" vm="$2" script="$3" type="$4" agent="$5"
  case "$type" in
    windows) run_one_win   "$id" "$vm" "$script" "${agent:-no}" ;;
    *)       run_one_linux "$id" "$vm" "$script" ;;
  esac
}

# ---- report HTML ----------------------------------------------------------
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
  total=$((total + ${#EXCLUDED_ITEMS[@]}))
  {
    cat <<HEAD
<!doctype html><html lang="it"><head><meta charset="utf-8">
$REFRESH_META
<title>$TITLE — $RUN_TS</title>
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
.b-EXCLUDED{background:#23262e;color:#9aa0a6}
.t-Linux{color:#8ec6f0} .t-Windows{color:#e8d488}
img.shot{max-width:150px;height:auto;border:1px solid #262b36;border-radius:6px;display:block;cursor:zoom-in}
details{color:#c2c7cf} summary{cursor:pointer;color:#9aa0a6}
.det{color:#f3a0b0;font-size:13px}
</style></head><body>
<h1>$TITLE</h1>
<div class="sub">Run $RUN_TS · parallelismo $PARALLEL · host $(hostname)</div>
<div class="summary">
  <div class="card tot">Totale gestite: $total</div>
  <div class="card ok">PASS: $pass</div>
  <div class="card ko">FAIL: $fail</div>
  <div class="card wa">WARN: $warn</div>
  <div class="card" style="background:#16304a;color:#8ec6f0">In corso: $running</div>
</div>
<div class="sub">$([ -f "$OUT/.done" ] && echo "Completato." || echo "Test in esecuzione — la pagina si aggiorna ogni 15s.")</div>
<table><thead><tr>
<th>ID</th><th>VM</th><th>Tipo</th><th>Esito</th><th>Fase</th><th>Durata</th>
<th>Ambiente / DM</th><th>Desktop / Tools</th><th>shared</th><th>Sessioni / Host</th>
<th>Screenshot</th><th>Dettaglio</th>
</tr></thead><tbody>
HEAD
    local item id vm
    for item in "${ITEMS[@]}"; do
      IFS='|' read -r id vm _ <<<"$item"
      local r="$OUT/results/$id"
      [ -f "$r" ] || { echo "<tr><td>$id</td><td>$vm</td><td><span class=\"badge b-FAIL\">NO-RUN</span></td><td colspan=9>nessun risultato</td></tr>"; continue; }
      local ot st ph se de ev dk sh ex dur
      ot=$(awk -F'\t' '$1=="ostype"{print $2}' "$r"); st=$(awk -F'\t' '$1=="status"{print $2}' "$r")
      ph=$(awk -F'\t' '$1=="phase"{print $2}' "$r"); se=$(awk -F'\t' '$1=="secs"{print $2}' "$r")
      de=$(awk -F'\t' '$1=="detail"{sub(/^detail\t/,"");print $2}' "$r")
      ev=$(awk -F'\t' '$1=="env"{print $2}' "$r"); dk=$(awk -F'\t' '$1=="desktop"{print $2}' "$r")
      sh=$(awk -F'\t' '$1=="shared"{print $2}' "$r"); ex=$(awk -F'\t' '$1=="extra"{print $2}' "$r")
      dur=$(printf '%dm%02ds' $((se/60)) $((se%60)))
      local img="screens/$id.png"; local imgcell="—"
      [ -f "$OUT/screens/$id.png" ] && imgcell="<a href=\"$img\" target=\"_blank\" rel=\"noopener\" title=\"apri a piena risoluzione\"><img class=\"shot\" src=\"$img\"></a>"
      local logs="<details><summary>log</summary><a href=\"logs/$id-install.log\">install.log</a>"
      [ -f "$OUT/logs/$id-apt-history.txt" ] && logs="$logs · <a href=\"logs/$id-apt-history.txt\">apt</a>"
      [ -f "$OUT/logs/$id-dpkg-tail.txt" ] && logs="$logs · <a href=\"logs/$id-dpkg-tail.txt\">dpkg</a>"
      [ -f "$OUT/logs/$id-lab-desktop.txt" ] && logs="$logs · <a href=\"logs/$id-lab-desktop.txt\">firstboot</a>"
      logs="$logs</details>"
      echo "<tr><td>$id</td><td>$vm</td><td class=\"t-${ot}\">${ot}</td><td><span class=\"badge b-${st}\">$st</span></td><td>$ph</td><td>$dur</td><td>${ev:-–}</td><td>${dk:-–}</td><td>$sh</td><td>$ex</td><td>$imgcell</td><td class=\"det\">${de}<br>$logs</td></tr>"
    done
    for item in "${EXCLUDED_ITEMS[@]}"; do
      IFS='|' read -r id vm reason <<<"$item"
      echo "<tr><td>$id</td><td>$vm</td><td>—</td><td><span class=\"badge b-EXCLUDED\">EXCLUDED</span></td><td>non testata</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td class=\"det\">$reason</td></tr>"
    done
    cat <<FOOT
</tbody></table>
<p class="sub">Output completo in $OUT</p>
</body></html>
FOOT
  } > "$REPORT"
}

# ---- motore principale ----------------------------------------------------
engine_main() {
  RUN_TS="$(date +%Y%m%d-%H%M%S)"
  OUT="$OUTDIR/$RUN_TS"
  mkdir -p "$OUT/logs" "$OUT/screens" "$OUT/results"
  REPORT="$OUT/report.html"

  echo "=== $TITLE start $(date) — parallelismo $PARALLEL — ${#ITEMS[@]} VM ==="
  echo "Output: $OUT"
  local mem_g; mem_g=$(free -g | awk '/Mem/{print $7}')
  echo "RAM disponibile: ${mem_g}G"

  local item id vm script type agent
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r id vm script type agent <<<"$item"
    _progress "$id" "$vm" "${type^}" "PENDING" "in coda" "0" "in attesa"
  done
  gen_html
  echo "REPORT HTML (gia' apribile, si auto-aggiorna ogni 15s): $REPORT"

  if [ "${OPEN_BROWSER:-1}" = "1" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$REPORT" >/dev/null 2>&1 &
    echo "Apro il report nel browser..."
  fi

  ( while [ ! -f "$OUT/.done" ]; do gen_html; sleep 15; done ) &
  local refresher=$!

  local pids=() p alive
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r id vm script type agent <<<"$item"
    run_one "$id" "$vm" "$script" "$type" "${agent:-}" &
    pids+=($!)
    sleep 8   # sfasa i lanci: evita burst di probe os-variant / 7z / xorriso
    while :; do
      alive=0
      for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && alive=$((alive+1)); done
      (( alive < PARALLEL )) && break
      sleep 3
    done
  done
  for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done

  touch "$OUT/.done"
  kill "$refresher" 2>/dev/null; wait "$refresher" 2>/dev/null
  gen_html
  echo "=== $TITLE fine $(date) ==="
  local pass notpass
  pass=$(grep -lP '^status\tPASS$' "$OUT"/results/* 2>/dev/null | wc -l)
  notpass=$(( ${#ITEMS[@]} - pass ))
  echo "Risultato: $pass PASS, $notpass non-PASS su ${#ITEMS[@]}"
  echo "REPORT HTML: $REPORT"
}
