#!/bin/bash
# Ispeziona offline tutti i dischi VM tramite virt-inspector (richiede sudo).
# Output: /tmp/vm_inspection_results/ con un file XML per ogni VM.
#
# Uso: sudo bash scripts/inspect_all_vms.sh

set -e

STORAGE="/home/manzolo/Workspaces/qemu/storage/hd"
OUTDIR="/tmp/vm_inspection_results"
mkdir -p "$OUTDIR"

# Rendi leggibile il kernel host (necessario per libguestfs/supermin)
echo "[*] Fix permessi kernel..."
chmod o+r /boot/vmlinuz-* 2>/dev/null || true

DISKS=(
  "centos8:$STORAGE/centos8.qcow2"
  "Debian13:$STORAGE/Debian.vhd"
  "Develop:$STORAGE/develop.qcow2"
  "lubuntu22:$STORAGE/lubuntu22.qcow2"
  "pi-hole:$STORAGE/pi-hole.qcow2"
  "ubuntu24.04:$STORAGE/ubuntu24.04.qcow2"
  "Windows7:$STORAGE/Windows7.qcow2"
  "Windows10:$STORAGE/windows10.qcow2"
  "Windows10_Cisco:$STORAGE/windows10_cisco.qcow2"
  "Windows11:$STORAGE/Windows11.qcow2"
  "WindowsXP:$STORAGE/windowsxp.qcow2"
  "Windows98:$STORAGE/win98.qcow2"
  "windows95:$STORAGE/win95.qcow2"
  "WindowsNT:$STORAGE/WindowsNT4.qcow2"
  "pfSense:$STORAGE/pfsense.qcow2"
)

for entry in "${DISKS[@]}"; do
  VM="${entry%%:*}"
  DISK="${entry##*:}"
  OUTFILE="$OUTDIR/${VM}.xml"

  if [ ! -f "$DISK" ]; then
    echo "[-] $VM: disco non trovato ($DISK)"
    continue
  fi

  echo "[*] Ispeziono $VM ($DISK)..."
  if virt-inspector -a "$DISK" > "$OUTFILE" 2>/dev/null; then
    echo "[+] $VM: OK → $OUTFILE"
  else
    echo "[-] $VM: virt-inspector fallito"
    rm -f "$OUTFILE"
  fi
done

echo ""
echo "[*] Parsing risultati..."
python3 << 'PYEOF'
import os, xml.etree.ElementTree as ET

OUTDIR = "/tmp/vm_inspection_results"
VMDIR  = "/home/manzolo/Workspaces/qemu/vms"

def fmt_size(n):
    if not n: return "?"
    n = int(n)
    for unit in ["B","KB","MB","GB","TB"]:
        if n < 1024: return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"

for fname in sorted(os.listdir(OUTDIR)):
    if not fname.endswith(".xml"): continue
    vm = fname[:-4]
    path = os.path.join(OUTDIR, fname)
    try:
        root = ET.parse(path).getroot()
    except Exception as e:
        print(f"[{vm}] parse error: {e}")
        continue

    for os_el in root.findall("operatingsystem"):
        print(f"\n{'='*55}")
        print(f"VM: {vm}")
        print(f"OS:       {os_el.findtext('name')} {os_el.findtext('version','')}")
        print(f"Distro:   {os_el.findtext('distro','N/A')}")
        print(f"Arch:     {os_el.findtext('arch','N/A')}")
        print(f"Hostname: {os_el.findtext('hostname','N/A')}")
        print(f"Format:   {os_el.findtext('format','N/A')}")
        print(f"Root:     {os_el.findtext('root','N/A')}")

        # Package manager
        pm = os_el.findtext('package_management','N/A')
        print(f"Pkg mgr:  {pm}")

        # Applicazioni
        apps_el = os_el.find("applications")
        if apps_el is not None:
            apps = [(a.findtext("name","?"), a.findtext("version","?"))
                    for a in apps_el.findall("application")]
            print(f"App installate: {len(apps)}")
            # Mostra le prime 50 ordinate
            for name, ver in sorted(apps)[:50]:
                print(f"  {name} {ver}")
            if len(apps) > 50:
                print(f"  ... e altri {len(apps)-50}")

        # Filesystem
        fss = os_el.find("filesystems")
        if fss:
            for fs in fss.findall("filesystem"):
                mp = fs.get("dev","?")
                typ = fs.findtext("type","?")
                label = fs.findtext("label","")
                print(f"  fs: {mp} ({typ}) {label}")

PYEOF
echo ""
echo "[*] Ispezione completata. File XML in $OUTDIR"
