#!/usr/bin/env bash
# Crea la VM Windows 7 Ultimate con installazione non presidiata.
#
# Strategia ISO:
#   - estrae la ISO originale Windows7U;
#   - integra autounattend.xml, driver viostor, certificato Red Hat, Firefox ESR 115 e Notepad++;
#   - installa AutoIt e SciTE4AutoIt;
#   - prepara una seconda fase manuale per installare SPICE/VirtIO guest tools;
#   - mette sul desktop i comandi per montare la cartella shared via SMB;
#   - importa il certificato Red Hat prima di installare i driver VirtIO;
#   - ricrea una ISO avviabile BIOS-only/UDF (etfsboot.com, bootfix.bin rimosso);
#   - usa ordine boot hd,cdrom per evitare di rientrare nel setup ai riavvii.
#
# Uso: bash scripts/win7u/create_win7u_vm.sh
#      bash scripts/win7u/create_win7u_vm.sh --iso-only
#      echo S | bash scripts/win7u/create_win7u_vm.sh

set -euo pipefail

VM_NAME="Windows7U"
STORAGE="/home/manzolo/Workspaces/qemu/storage"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ISO_ORIG="$STORAGE/Iso/Windows/Windows7U.iso"
ISO_AUTO="$STORAGE/Iso/Windows/Windows7U-autounattend-noprompt.iso"
ISO_VIRTIO="$STORAGE/Iso/addons/virtio-win-0.1.285.iso"
ISO_SPICE="$STORAGE/Iso/addons/spice.iso"
DISK="$STORAGE/hd/Windows7U.qcow2"
DISK_SIZE="40G"
AUTOUNATTEND="$SCRIPT_DIR/autounattend.xml"
SHARED_DIR="$STORAGE/shared"
BUILD_DIR="/tmp/win7u-iso-build"
ISO_ONLY=0

shopt -s nullglob
FIREFOX_CANDIDATES=("$SHARED_DIR"/Firefox\ Setup\ 115*.exe)
shopt -u nullglob
FIREFOX_INSTALLER="${FIREFOX_CANDIDATES[0]:-}"
AUTOIT_ZIP="$SHARED_DIR/autoit-v3-setup.zip"
SCITE_INSTALLER="$SHARED_DIR/SciTE4AutoIt3.exe"

if [[ "${1:-}" == "--iso-only" ]]; then
    ISO_ONLY=1
elif [[ $# -gt 0 ]]; then
    echo "Uso: $0 [--iso-only]"
    exit 1
fi

for cmd in 7z genisoimage qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

if [[ -z "$FIREFOX_INSTALLER" ]]; then
    echo "Mancante: Firefox ESR 115 per Windows 7 in $SHARED_DIR (es. 'Firefox Setup 115.*/115.*esr*.exe')"
    exit 1
fi

for f in "$ISO_ORIG" "$ISO_VIRTIO" "$ISO_SPICE" "$AUTOUNATTEND" \
         "$FIREFOX_INSTALLER" \
         "$AUTOIT_ZIP" \
         "$SCITE_INSTALLER" \
         "$SHARED_DIR/virtio-win-guest-tools.exe" \
         "$SHARED_DIR/npp.8.6.4.Installer.x64.exe"; do
    [[ -f "$f" ]] || { echo "Mancante: $f"; exit 1; }
done

echo "[*] Preparo ISO Windows 7 Ultimate unattended senza prompt di boot..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
7z x -y "-o$BUILD_DIR" "$ISO_ORIG" >/dev/null
cp "$AUTOUNATTEND" "$BUILD_DIR/autounattend.xml"

mkdir -p "$BUILD_DIR/tools"
cp "$FIREFOX_INSTALLER" "$BUILD_DIR/tools/firefox-setup.exe"
cp "$SCITE_INSTALLER" "$BUILD_DIR/tools/scite4autoit3.exe"
cp "$SHARED_DIR/virtio-win-guest-tools.exe" "$BUILD_DIR/tools/virtio-win-guest-tools.exe"
cp "$SHARED_DIR/npp.8.6.4.Installer.x64.exe" "$BUILD_DIR/tools/notepadpp-setup.exe"
7z e -y "-o$BUILD_DIR/tools" "$AUTOIT_ZIP" autoit-v3-setup.exe >/dev/null
mkdir -p "$BUILD_DIR/tools/cert"
7z e -y "-o$BUILD_DIR/tools/cert" "$ISO_VIRTIO" cert/Virtio_Win_Red_Hat_CA.cer >/dev/null
mkdir -p "$BUILD_DIR/drivers/viostor/w7/amd64"
7z e -y "-o$BUILD_DIR/drivers/viostor/w7/amd64" "$ISO_VIRTIO" viostor/w7/amd64/* >/dev/null
7z e -y "-o$BUILD_DIR/tools" "$ISO_SPICE" spice-guest-tools-latest.exe >/dev/null
mv "$BUILD_DIR/tools/spice-guest-tools-latest.exe" "$BUILD_DIR/tools/spice-guest-tools.exe"

SETUPCOMPLETE_DIR="$BUILD_DIR/sources/\$OEM\$/\$\$/Setup/Scripts"
mkdir -p "$SETUPCOMPLETE_DIR"
cat > "$SETUPCOMPLETE_DIR/ImportRedHatCert.cmd" <<'IMPORTCERT'
@echo off
setlocal EnableExtensions
set "LOG=C:\import-redhat-cert.log"
echo ==== ImportRedHatCert %DATE% %TIME% ==== > "%LOG%"

set "TOOLROOT="
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\tools\cert\Virtio_Win_Red_Hat_CA.cer" set "TOOLROOT=%%D:\tools"
)

if not defined TOOLROOT (
    echo Red Hat VirtIO certificate not found on mounted media. >> "%LOG%"
    exit /b 0
)

echo Toolroot: %TOOLROOT% >> "%LOG%"
certutil -addstore -f Root "%TOOLROOT%\cert\Virtio_Win_Red_Hat_CA.cer" >> "%LOG%" 2>&1
certutil -addstore -f TrustedPublisher "%TOOLROOT%\cert\Virtio_Win_Red_Hat_CA.cer" >> "%LOG%" 2>&1
reg add HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff /f >> "%LOG%" 2>&1
exit /b 0
IMPORTCERT

cat > "$SETUPCOMPLETE_DIR/InstallGuestTools.cmd" <<'GUESTTOOLS'
@echo off
setlocal EnableExtensions
set "LOG=C:\install-guest-tools.log"
echo ==== InstallGuestTools %DATE% %TIME% ==== > "%LOG%"

set "TOOLROOT="
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\tools\virtio-win-guest-tools.exe" set "TOOLROOT=%%D:\tools"
)

if not defined TOOLROOT (
    echo Tools directory not found on mounted media. >> "%LOG%"
    exit /b 1
)

call "%WINDIR%\Setup\Scripts\ImportRedHatCert.cmd" >> "%LOG%" 2>&1
call :run "VirtIO guest tools" "%TOOLROOT%\virtio-win-guest-tools.exe" /install /quiet /norestart
call :run "SPICE guest tools" "%TOOLROOT%\spice-guest-tools.exe" /S
echo Done. Reboot is recommended. >> "%LOG%"
exit /b 0

:run
echo Installing %~1... >> "%LOG%"
start /wait "" "%~2" %3 %4 %5 %6 >> "%LOG%" 2>&1
echo %~1 exit code: %ERRORLEVEL% >> "%LOG%"
exit /b 0
GUESTTOOLS

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

call "%WINDIR%\Setup\Scripts\ImportRedHatCert.cmd" >> "%LOG%" 2>&1

call :run "AutoIt" "%TOOLROOT%\autoit-v3-setup.exe" /S
call :run "SciTE4AutoIt" "%TOOLROOT%\scite4autoit3.exe" /S
call :run "Firefox ESR" "%TOOLROOT%\firefox-setup.exe" /S
call :run "Notepad++" "%TOOLROOT%\notepadpp-setup.exe" /S
call :desktop_shortcut >> "%LOG%" 2>&1

exit /b 0

:run
echo Installing %~1... >> "%LOG%"
start /wait "" "%~2" %3 %4 %5 %6 >> "%LOG%" 2>&1
echo %~1 exit code: %ERRORLEVEL% >> "%LOG%"
exit /b 0

:desktop_shortcut
set "DESKTOP=C:\Users\Public\Desktop"
if not exist "%DESKTOP%" set "DESKTOP=%USERPROFILE%\Desktop"

>"%DESKTOP%\Installa guest tools.bat" echo @echo off
>>"%DESKTOP%\Installa guest tools.bat" echo powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%WINDIR%\Setup\Scripts\InstallGuestTools.cmd' -Verb RunAs"

>"%DESKTOP%\Monta shared Z.bat" echo @echo off
>>"%DESKTOP%\Monta shared Z.bat" echo net use Z: /delete /y ^>nul 2^>^&1
>>"%DESKTOP%\Monta shared Z.bat" echo net use Z: \\192.168.122.1\qemu-shared /persistent:yes
>>"%DESKTOP%\Monta shared Z.bat" echo if errorlevel 1 pause
>>"%DESKTOP%\Monta shared Z.bat" echo if not errorlevel 1 explorer Z:\

>"%DESKTOP%\LEGGIMI guest tools.txt" echo Dopo il primo login puoi installare SPICE/VirtIO guest tools.
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo.
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo 1. Lascia montata la ISO Windows7U-autounattend-noprompt.iso.
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo 2. Esegui come amministratore "Installa guest tools.bat".
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo 3. Dal host esegui: bash scripts/win7u/enable_win7u_smb_shared.sh
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo 4. Nel guest esegui "Monta shared Z.bat" per aprire Z:.
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo.
>>"%DESKTOP%\LEGGIMI guest tools.txt" echo Log: C:\install-guest-tools.log
exit /b 0
SETUPCOMPLETE

if [[ -f "$BUILD_DIR/boot/bootfix.bin" ]]; then
    rm -f "$BUILD_DIR/boot/bootfix.bin"
fi

rm -f "$ISO_AUTO"
genisoimage \
    -iso-level 3 \
    -udf \
    -J \
    -joliet-long \
    -relaxed-filenames \
    -D \
    -N \
    -V "WIN7U_ISO" \
    -o "$ISO_AUTO" \
    -b boot/etfsboot.com \
    -c boot.catalog \
    -no-emul-boot \
    -boot-load-size 8 \
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
    --os-variant win7 \
    --machine q35 \
    --cpu host-passthrough \
    --boot hd,cdrom \
    --disk path="$DISK",bus=virtio,format=qcow2,discard=unmap \
    --disk path="$ISO_AUTO",device=cdrom,bus=sata \
    --network network=default,model=e1000e \
    --graphics spice,listen=none \
    --channel none \
    --video qxl \
    --memballoon model=none \
    --noautoconsole

echo ""
echo "[+] VM $VM_NAME avviata, installazione in corso."
echo "    Connettiti con: virt-viewer $VM_NAME"
echo ""
echo "    La ISO generata non chiede di premere un tasto."
echo "    Ai riavvii successivi il boot passa al disco Windows."
