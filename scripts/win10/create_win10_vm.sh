#!/usr/bin/env bash
# Crea la VM Windows 10 con installazione non presidiata.
#
# Strategia ISO:
#   - estrae la ISO originale di Windows 10;
#   - integra autounattend.xml, WinFSP, Firefox e Notepad++;
#   - ricrea una ISO avviabile con efisys_noprompt.bin;
#   - usa ordine boot hd,cdrom per evitare di rientrare nel setup ai riavvii.
#
# Uso: bash scripts/win10/create_win10_vm.sh
#      bash scripts/win10/create_win10_vm.sh --iso-only
#      echo S | bash scripts/win10/create_win10_vm.sh

set -euo pipefail

VM_NAME="Windows10"
STORAGE="/home/manzolo/Workspaces/qemu/storage"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ISO_ORIG="$STORAGE/Iso/Windows/Windows10.iso"
ISO_AUTO="$STORAGE/Iso/Windows/Windows10-autounattend-noprompt.iso"
ISO_VIRTIO="$STORAGE/Iso/addons/virtio-win-0.1.285.iso"
DISK="$STORAGE/hd/windows10.qcow2"
DISK_SIZE="60G"
AUTOUNATTEND="$SCRIPT_DIR/autounattend.xml"
SHARED_DIR="$STORAGE/shared"
FIREFOX_INSTALLER="$SHARED_DIR/Firefox Setup 151.0.2 x64 it.exe"
BUILD_DIR="/tmp/win10-iso-build"
ISO_ONLY=0

if [[ "${1:-}" == "--iso-only" ]]; then
    ISO_ONLY=1
elif [[ $# -gt 0 ]]; then
    echo "Uso: $0 [--iso-only]"
    exit 1
fi

for cmd in 7z xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

for f in \
    "$ISO_ORIG" \
    "$ISO_VIRTIO" \
    "$AUTOUNATTEND" \
    "$SHARED_DIR/winfsp-2.0.23075.msi" \
    "$SHARED_DIR/virtio-win-guest-tools.exe" \
    "$FIREFOX_INSTALLER" \
    "$SHARED_DIR/npp.8.6.4.Installer.x64.exe"; do
    [[ -f "$f" ]] || { echo "Mancante: $f"; exit 1; }
done

echo "[*] Preparo ISO Windows 10 unattended senza prompt di boot..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
7z x -y "-o$BUILD_DIR" "$ISO_ORIG" >/dev/null
cp "$AUTOUNATTEND" "$BUILD_DIR/autounattend.xml"
mkdir -p "$BUILD_DIR/tools"
cp "$SHARED_DIR/winfsp-2.0.23075.msi" "$BUILD_DIR/tools/winfsp-2.0.23075.msi"
cp "$SHARED_DIR/virtio-win-guest-tools.exe" "$BUILD_DIR/tools/virtio-win-guest-tools.exe"
cp "$FIREFOX_INSTALLER" "$BUILD_DIR/tools/firefox-setup.exe"
cp "$SHARED_DIR/npp.8.6.4.Installer.x64.exe" "$BUILD_DIR/tools/notepadpp-setup.exe"

SETUPCOMPLETE_DIR="$BUILD_DIR/sources/\$OEM\$/\$\$/Setup/Scripts"
mkdir -p "$SETUPCOMPLETE_DIR"
cat > "$SETUPCOMPLETE_DIR/SetupComplete.cmd" <<'SETUPCOMPLETE'
@echo off
setlocal EnableExtensions
set "LOG=C:\install-tools.log"
echo ==== SetupComplete %DATE% %TIME% ==== > "%LOG%"

set "TOOLROOT="
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\tools\firefox-setup.exe" set "TOOLROOT=%%D:\tools"
)

if not defined TOOLROOT (
    echo Tools directory not found on mounted media. >> "%LOG%"
    exit /b 0
)

echo Toolroot: %TOOLROOT% >> "%LOG%"

call :run "VirtIO guest tools" "%TOOLROOT%\virtio-win-guest-tools.exe" /install /quiet /norestart
call :msi "WinFSP" "%TOOLROOT%\winfsp-2.0.23075.msi"
call :run "Firefox" "%TOOLROOT%\firefox-setup.exe" /S
call :run "Notepad++" "%TOOLROOT%\notepadpp-setup.exe" /S

sc config VirtioFsSvc start= auto >> "%LOG%" 2>&1
net start VirtioFsSvc >> "%LOG%" 2>&1
exit /b 0

:run
echo Installing %~1... >> "%LOG%"
start /wait "" "%~2" %3 %4 %5 %6 >> "%LOG%" 2>&1
echo %~1 exit code: %ERRORLEVEL% >> "%LOG%"
exit /b 0

:msi
echo Installing %~1... >> "%LOG%"
start /wait msiexec.exe /i "%~2" /qn /norestart >> "%LOG%" 2>&1
echo %~1 exit code: %ERRORLEVEL% >> "%LOG%"
exit /b 0
SETUPCOMPLETE

if [[ -f "$BUILD_DIR/efi/microsoft/boot/efisys_noprompt.bin" ]]; then
    EFI_BOOT_IMAGE="efi/microsoft/boot/efisys_noprompt.bin"
else
    echo "Attenzione: efisys_noprompt.bin non trovato, uso efisys.bin."
    EFI_BOOT_IMAGE="efi/microsoft/boot/efisys.bin"
fi

if [[ -f "$BUILD_DIR/boot/bootfix.bin" ]]; then
    : > "$BUILD_DIR/boot/bootfix.bin"
fi

rm -f "$ISO_AUTO"
xorriso -as mkisofs \
    -iso-level 3 \
    -J \
    -joliet-long \
    -relaxed-filenames \
    -V "ESD_ISO" \
    -o "$ISO_AUTO" \
    -b boot/etfsboot.com \
    -no-emul-boot \
    -boot-load-size 8 \
    -eltorito-alt-boot \
    -e "$EFI_BOOT_IMAGE" \
    -no-emul-boot \
    "$BUILD_DIR" >/dev/null

rm -rf "$BUILD_DIR"
echo "    -> $ISO_AUTO"

if [[ "$ISO_ONLY" -eq 1 ]]; then
    echo "[+] ISO pronta. Nessuna VM creata perche' e' stato usato --iso-only."
    exit 0
fi

if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    if [[ ! "$risposta" =~ ^[sS]$ ]]; then
        echo "Installazione annullata."
        exit 0
    fi

    echo "Fermo e rimuovo la VM..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --snapshots-metadata --nvram 2>/dev/null || \
    virsh undefine "$VM_NAME" --snapshots-metadata 2>/dev/null || true
fi

echo "[*] Creo disco $DISK ($DISK_SIZE)..."
rm -f "$DISK"
qemu-img create -f qcow2 -o preallocation=off "$DISK" "$DISK_SIZE"
virsh pool-refresh hdd 2>/dev/null || true

echo "[*] Creo e avvio VM $VM_NAME..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --os-variant win10 \
    --machine q35 \
    --cpu host-passthrough \
    --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,hd,cdrom \
    --disk path="$DISK",bus=virtio,format=qcow2,discard=unmap \
    --disk path="$ISO_AUTO",device=cdrom,bus=sata \
    --disk path="$ISO_VIRTIO",device=cdrom,bus=sata \
    --filesystem source="$SHARED_DIR",target=shared,driver.type=virtiofs \
    --memorybacking source.type=memfd,access.mode=shared \
    --network network=default,model=virtio \
    --graphics spice,listen=none \
    --video qxl \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --noautoconsole

echo ""
echo "[+] VM $VM_NAME avviata, installazione in corso."
echo "    Connettiti con: virt-viewer $VM_NAME"
echo ""
echo "    La ISO generata non chiede piu' di premere un tasto."
echo "    Ai riavvii successivi il boot passa al disco Windows."
