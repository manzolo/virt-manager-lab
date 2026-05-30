#!/usr/bin/env bash
# Genera un report HTML delle VM libvirt con inventario disco.
#
# Uso: bash scripts/vm-report.sh [output.html]
#      bash scripts/vm-report.sh           → vm-report.html nella directory corrente
#      bash scripts/vm-report.sh /tmp/report.html

set -euo pipefail

OUTPUT="${1:-vm-report.html}"

python3 - "$OUTPUT" <<'PYEOF'
import subprocess, json, sys, os, re
from datetime import datetime

OUTPUT = sys.argv[1]

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout

def virsh(args):
    return run(["virsh"] + args)

def os_family(name):
    n = name.lower()
    if any(x in n for x in ["ubuntu","debian","centos","lubuntu","fedora",
                              "pi-hole","pihole","pfsense","ventoy","develop","mint","arch"]):
        return "Linux"
    if any(x in n for x in ["windows","win95","win98","winnt","win7","win10","win11","win"]):
        return "Windows"
    return "Other"

def qemu_info(path):
    if not os.path.exists(path):
        return None, None
    try:
        out = run(["qemu-img", "info", "-U", "--output=json", path])
        d = json.loads(out)
        vsize = round(d.get("virtual-size", 0) / 1073741824, 1)
        asize = round(d.get("actual-size", 0) / 1073741824, 1)
        return vsize, asize
    except Exception:
        return None, None

# --- Raccolta dati VM ---
vms = []
raw = virsh(["list", "--all"])
for line in raw.splitlines()[2:]:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 2)
    if len(parts) < 3:
        parts = line.split(None, 1) + [""]
    name = parts[1]
    state_raw = parts[2].strip() if len(parts) > 2 else "unknown"

    # dominfo
    info_raw = virsh(["dominfo", name])
    ram_mb = 0
    vcpus = 0
    for l in info_raw.splitlines():
        if "Max memory" in l or "Memoria max" in l:
            try: ram_mb = int(l.split(":")[1].strip().split()[0]) // 1024
            except: pass
        if "CPU(s)" in l or "CPU:" in l:
            try: vcpus = int(l.split(":")[1].strip())
            except: pass

    # dischi
    disks = []
    blk = virsh(["domblklist", name, "--details"])
    for dl in blk.splitlines()[2:]:
        dl = dl.strip()
        if not dl:
            continue
        cols = dl.split()
        if len(cols) < 4:
            continue
        dtype, device, _target, source = cols[0], cols[1], cols[2], cols[3]
        if dtype != "file" or device != "disk":
            continue
        if source == "-" or not source:
            continue
        vsize, asize = qemu_info(source)
        if vsize is None:
            continue
        disks.append({
            "path": source,
            "name": os.path.basename(source),
            "vsize": vsize,
            "asize": asize,
        })

    total_v = round(sum(d["vsize"] for d in disks), 1)
    total_a = round(sum(d["asize"] for d in disks), 1)
    pct = round(total_a / total_v * 100) if total_v > 0 else 0

    vms.append({
        "name": name,
        "state": state_raw,
        "running": "esecuzione" in state_raw or "running" in state_raw,
        "os": os_family(name),
        "ram": ram_mb,
        "vcpus": vcpus,
        "disks": disks,
        "total_v": total_v,
        "total_a": total_a,
        "pct": pct,
    })

vms.sort(key=lambda v: (v["os"], v["name"].lower()))

# Totali
tot_v = round(sum(v["total_v"] for v in vms), 1)
tot_a = round(sum(v["total_a"] for v in vms), 1)
n_run = sum(1 for v in vms if v["running"])
generated = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# --- HTML ---
def badge(vm):
    if vm["running"]:
        return '<span class="badge run">&#9679; in esecuzione</span>'
    return '<span class="badge stop">&#9675; ferma</span>'

def disk_bar(pct, asize, vsize):
    color = "#ef4444" if pct > 80 else "#f59e0b" if pct > 60 else "#22c55e"
    return f'''<div class="bar-wrap" title="{asize} GB usati / {vsize} GB virtuali">
      <div class="bar" style="width:{pct}%;background:{color}"></div>
    </div>
    <span class="bar-label">{asize} / {vsize} GB ({pct}%)</span>'''

def disk_list(disks):
    if not disks:
        return "<em>—</em>"
    items = "".join(f'<li title="{d["path"]}">{d["name"]}</li>' for d in disks)
    return f'<ul class="disklist">{items}</ul>'

rows = ""
for v in vms:
    rows += f'''
    <tr data-state="{'running' if v['running'] else 'stopped'}"
        data-os="{v['os']}"
        data-name="{v['name'].lower()}">
      <td class="vm-name">{v['name']}</td>
      <td>{badge(v)}</td>
      <td><span class="os-tag os-{v['os'].lower()}">{v['os']}</span></td>
      <td class="num">{v['ram']}</td>
      <td class="num">{v['vcpus']}</td>
      <td>{disk_list(v['disks'])}</td>
      <td class="num">{v['total_v']}</td>
      <td class="num">{v['total_a']}</td>
      <td>{disk_bar(v['pct'], v['total_a'], v['total_v'])}</td>
    </tr>'''

html = f"""<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VM Lab — Inventario</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; }}
  header {{ background: #1e293b; border-bottom: 1px solid #334155; padding: 1.2rem 2rem;
            display: flex; align-items: center; justify-content: space-between; }}
  header h1 {{ font-size: 1.4rem; font-weight: 700; color: #f8fafc; }}
  header .gen {{ font-size: 0.8rem; color: #64748b; }}
  .stats {{ display: flex; gap: 1rem; padding: 1.2rem 2rem; flex-wrap: wrap; }}
  .stat {{ background: #1e293b; border: 1px solid #334155; border-radius: 8px;
           padding: .6rem 1.2rem; font-size: .85rem; color: #94a3b8; }}
  .stat strong {{ color: #f1f5f9; font-size: 1.3rem; display: block; }}
  .stat.green strong {{ color: #22c55e; }}
  .filters {{ padding: .8rem 2rem; display: flex; gap: 1rem; align-items: center; flex-wrap: wrap;
              border-bottom: 1px solid #1e293b; }}
  .filters input {{ background: #1e293b; border: 1px solid #334155; color: #e2e8f0;
                    border-radius: 6px; padding: .4rem .8rem; font-size: .85rem; width: 200px; }}
  .filters input::placeholder {{ color: #475569; }}
  .filter-group {{ display: flex; gap: .3rem; }}
  .filter-group button {{ background: #1e293b; border: 1px solid #334155; color: #94a3b8;
                          border-radius: 6px; padding: .35rem .8rem; font-size: .8rem;
                          cursor: pointer; transition: all .15s; }}
  .filter-group button.active,
  .filter-group button:hover {{ background: #3b82f6; border-color: #3b82f6; color: #fff; }}
  .table-wrap {{ padding: 1rem 2rem 2rem; overflow-x: auto; }}
  table {{ width: 100%; border-collapse: collapse; font-size: .85rem; }}
  th {{ background: #1e293b; color: #64748b; font-weight: 600; text-transform: uppercase;
        font-size: .72rem; letter-spacing: .05em; padding: .7rem .8rem;
        text-align: left; position: sticky; top: 0; cursor: pointer; user-select: none; }}
  th:hover {{ color: #e2e8f0; }}
  th.sort-asc::after {{ content: " ↑"; }}
  th.sort-desc::after {{ content: " ↓"; }}
  td {{ padding: .6rem .8rem; border-bottom: 1px solid #1e293b; vertical-align: middle; }}
  tr:hover td {{ background: #1e293b; }}
  tr.hidden {{ display: none; }}
  .vm-name {{ font-weight: 600; color: #f1f5f9; font-family: monospace; font-size: .9rem; }}
  .num {{ text-align: right; font-variant-numeric: tabular-nums; color: #94a3b8; }}
  .badge {{ font-size: .78rem; padding: .2rem .6rem; border-radius: 999px; white-space: nowrap; }}
  .badge.run {{ background: #14532d; color: #4ade80; }}
  .badge.stop {{ background: #1e293b; color: #64748b; }}
  .os-tag {{ font-size: .75rem; padding: .2rem .55rem; border-radius: 4px; font-weight: 600; }}
  .os-tag.os-linux {{ background: #0c4a6e; color: #38bdf8; }}
  .os-tag.os-windows {{ background: #1e3a5f; color: #60a5fa; }}
  .os-tag.os-other {{ background: #292524; color: #a8a29e; }}
  .bar-wrap {{ background: #334155; border-radius: 999px; height: 6px; width: 120px; overflow: hidden; margin-bottom: 3px; }}
  .bar {{ height: 100%; border-radius: 999px; transition: width .3s; }}
  .bar-label {{ font-size: .75rem; color: #64748b; white-space: nowrap; }}
  ul.disklist {{ list-style: none; padding: 0; }}
  ul.disklist li {{ font-family: monospace; font-size: .78rem; color: #94a3b8;
                    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 200px; }}
  .no-results {{ text-align: center; padding: 3rem; color: #475569; display: none; }}
  @media (max-width: 900px) {{ .table-wrap {{ padding: .5rem; }} }}
</style>
</head>
<body>
<header>
  <h1>&#128421; VM Lab — Inventario</h1>
  <span class="gen">Generato il {generated}</span>
</header>

<div class="stats">
  <div class="stat"><strong>{len(vms)}</strong>VM totali</div>
  <div class="stat green"><strong>{n_run}</strong>in esecuzione</div>
  <div class="stat"><strong>{len(vms)-n_run}</strong>ferme</div>
  <div class="stat"><strong>{tot_v} GB</strong>disco virtuale tot.</div>
  <div class="stat"><strong>{tot_a} GB</strong>disco usato tot.</div>
</div>

<div class="filters">
  <input type="search" id="search" placeholder="&#128269; Cerca VM…">
  <div class="filter-group" id="state-filter">
    <button class="active" data-value="all">Tutte</button>
    <button data-value="running">In esecuzione</button>
    <button data-value="stopped">Ferme</button>
  </div>
  <div class="filter-group" id="os-filter">
    <button class="active" data-value="all">Tutte OS</button>
    <button data-value="Linux">Linux</button>
    <button data-value="Windows">Windows</button>
    <button data-value="Other">Altro</button>
  </div>
</div>

<div class="table-wrap">
  <table id="vm-table">
    <thead>
      <tr>
        <th data-col="name">Nome</th>
        <th>Stato</th>
        <th>OS</th>
        <th data-col="ram" class="num">RAM (MB)</th>
        <th data-col="vcpu" class="num">vCPU</th>
        <th>Dischi</th>
        <th data-col="vsize" class="num">Virtuale (GB)</th>
        <th data-col="asize" class="num">Usato (GB)</th>
        <th>Utilizzo</th>
      </tr>
    </thead>
    <tbody id="vm-tbody">
{rows}
    </tbody>
  </table>
  <div class="no-results" id="no-results">Nessuna VM corrisponde ai filtri.</div>
</div>

<script>
  const tbody = document.getElementById('vm-tbody');
  const noRes = document.getElementById('no-results');
  let stateF = 'all', osF = 'all', searchF = '';

  function applyFilters() {{
    let visible = 0;
    tbody.querySelectorAll('tr').forEach(tr => {{
      const s = tr.dataset.state, o = tr.dataset.os, n = tr.dataset.name;
      const show = (stateF === 'all' || s === stateF)
                && (osF === 'all' || o === osF)
                && (!searchF || n.includes(searchF));
      tr.classList.toggle('hidden', !show);
      if (show) visible++;
    }});
    noRes.style.display = visible === 0 ? 'block' : 'none';
  }}

  document.getElementById('search').addEventListener('input', e => {{
    searchF = e.target.value.toLowerCase().trim();
    applyFilters();
  }});

  document.getElementById('state-filter').addEventListener('click', e => {{
    if (!e.target.matches('button')) return;
    stateF = e.target.dataset.value;
    e.target.closest('.filter-group').querySelectorAll('button')
      .forEach(b => b.classList.remove('active'));
    e.target.classList.add('active');
    applyFilters();
  }});

  document.getElementById('os-filter').addEventListener('click', e => {{
    if (!e.target.matches('button')) return;
    osF = e.target.dataset.value;
    e.target.closest('.filter-group').querySelectorAll('button')
      .forEach(b => b.classList.remove('active'));
    e.target.classList.add('active');
    applyFilters();
  }});

  // Ordinamento colonne
  let sortCol = null, sortDir = 1;
  const colIdx = {{name:0, ram:3, vcpu:4, vsize:6, asize:7}};
  document.querySelectorAll('th[data-col]').forEach(th => {{
    th.addEventListener('click', () => {{
      const col = th.dataset.col;
      const idx = colIdx[col];
      if (sortCol === col) sortDir *= -1; else {{ sortCol = col; sortDir = 1; }}
      document.querySelectorAll('th').forEach(h => h.classList.remove('sort-asc','sort-desc'));
      th.classList.add(sortDir === 1 ? 'sort-asc' : 'sort-desc');
      const rows = [...tbody.querySelectorAll('tr')];
      rows.sort((a, b) => {{
        const av = a.cells[idx]?.textContent.trim() ?? '';
        const bv = b.cells[idx]?.textContent.trim() ?? '';
        const an = parseFloat(av), bn = parseFloat(bv);
        return (isNaN(an) ? av.localeCompare(bv) : an - bn) * sortDir;
      }});
      rows.forEach(r => tbody.appendChild(r));
    }});
  }});
</script>
</body>
</html>"""

with open(OUTPUT, "w") as f:
    f.write(html)

print(f"Report generato: {OUTPUT}")
print(f"  VM totali   : {len(vms)}")
print(f"  In esecuzione: {n_run}")
print(f"  Disco virtuale tot.: {tot_v} GB")
print(f"  Disco usato tot.  : {tot_a} GB")
PYEOF
