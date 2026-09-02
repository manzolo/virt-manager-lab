# Windows7U

## Identificazione

| Campo   | Valore |
|---------|--------|
| Nome    | Windows7U |
| UUID    | assegnato dinamicamente alla creazione |
| OS      | Windows 7 Ultimate |
| Hostname| Windows7U-Lab |
| Stato   | generata da script unattended |

## Hardware

| Risorsa   | Valore |
|-----------|--------|
| RAM       | 4 GB (4194304 KiB) |
| vCPU      | 2 |
| Arch      | x86_64 |
| Machine   | q35 |
| Firmware  | BIOS (SeaBIOS) — ISO ricostruita BIOS-only/UDF con `etfsboot.com` |
| CPU mode  | host-passthrough |
| os-variant| win7 |

## Storage

| Dispositivo | File | Bus | Formato | Dimensione |
|-------------|------|-----|---------|------------|
| vda (disco) | `$VM_BASE_DIR/storage/hd/Windows7U.qcow2` | virtio (driver viostor integrato nella ISO) | qcow2, discard=unmap | 40G |
| cdrom       | `storage/Iso/Windows/Windows7U-autounattend-noprompt.iso` (generata da `Windows7U.iso`) | sata | raw | — |

Ordine di boot `hd,cdrom`: ai riavvii non si rientra nel setup.

## Rete

| NIC | Modello | Rete |
|-----|---------|------|
| 1   | e1000e  | default |

## Video & Audio

| Componente | Valore |
|------------|--------|
| Video      | QXL |
| Display    | SPICE (listen=none) |

## Cartella condivisa

**Nessun virtiofs** (Windows 7 non ha WinFSP/virtiofs). Due alternative, entrambe da attivare a mano dopo l'installazione:

- **SMB**: `scripts/win7u/enable_win7u_smb_shared.sh` esporta `storage/shared` via Samba dall'host; nel guest `net use Z: \\192.168.122.1\qemu-shared /persistent:yes`. I comandi sono messi sul desktop dallo script di install.
- **SPICE WebDAV**: `scripts/win7u/enable_win7u_shared.sh` aggiunge il canale WebDAV alla VM, dopo aver lanciato nel guest "Installa guest tools.bat".

## Metodo di installazione

`scripts/win7u/create_win7u_vm.sh` estrae la ISO originale, integra `autounattend.xml` (autologon dell'utente di `scripts/lab.env`), il driver viostor con il certificato Red Hat, Firefox ESR 115 (ultimo per Windows 7), Notepad++, AutoIt + SciTE, e ricrea una ISO avviabile. `SetupComplete.cmd` importa il certificato e installa i driver VirtIO; **SPICE/VirtIO guest tools restano una seconda fase manuale** (`InstallGuestTools.cmd`, log in `C:\install-guest-tools.log`).

Prerequisiti in `storage/shared`: `Firefox Setup 115*.exe` (ESR), `virtio-win-guest-tools.exe`, `npp.8.6.4.Installer.x64.exe`; ISO addon `virtio-win` e `spice.iso`.

## Note

- **Nessun canale QEMU guest agent** (`--channel none`): la VM non e' interrogabile dall'host. Nei test e2e (`make test-win`) l'esito e' sempre **WARN** per costruzione: attesa fissa (`TEST_WIN_NOAGENT_WAIT`, ~40 min) poi solo screenshot.
- Gestione via Makefile: `make win7u`, `make iso-win7u` (solo ISO), `make start-win7u`, `make clean-win7u` (ID `win7u` in `vms.tsv`)
- Test e2e: WARN (no-agent) il 2026-09-02, run `20260902-105037`, VM avviata e fotografata a fine attesa
