# Windows10

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows10                                |
| UUID    | d0b5d907-a011-447f-a6b3-1f29b8212da2    |
| OS      | Windows 10                               |
| Stato   | installata e funzionante ✓               |

## Hardware

| Risorsa   | Valore                                |
|-----------|---------------------------------------|
| RAM       | 4 GB (4194304 KiB)                    |
| vCPU      | 2                                     |
| Arch      | x86_64                                |
| Machine   | pc-q35-10.2                          |
| Firmware  | UEFI OVMF                             |
| CPU mode  | host-passthrough                      |
| Clock     | localtime (Windows)                   |
| Memory    | memfd + shared (richiesto da virtiofs)|
| HyperV    | relaxed, vapic, spinlocks             |

## Storage

| Dispositivo | File                                                           | Bus    | Formato | Dimensione |
|-------------|----------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/windows10.qcow2`    | virtio | qcow2   | 60 GB      |
| sda (cdrom) | `storage/Iso/Windows/Windows10-autounattend-noprompt.iso`     | sata   | raw     | —          |
| sdb (cdrom) | `storage/Iso/addons/virtio-win-0.1.285.iso`                   | sata   | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    | Stato |
|-----|-------------------|---------|---------|-------|
| 1   | 52:54:00:47:59:50 | virtio  | default | up    |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

| Parametro    | Valore                                               |
|--------------|------------------------------------------------------|
| Tipo         | virtiofs (passthrough)                               |
| Sorgente     | `/home/manzolo/Workspaces/qemu/storage/shared/`      |
| Target guest | `shared`                                             |

> Richiede WinFSP installato nel guest per montare il filesystem virtiofs.  
> Richiede `<memoryBacking><source type='memfd'/><access mode='shared'/></memoryBacking>`.

## Stato sistema

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Windows 10 Pro 10.0.19042       |
| Hostname    | Windows10-Lab                   |
| Disco usato | 11 GB / 60 GB                   |
| Unità Z:    | virtiofs shared (1158 GB)       |
| Testato il  | 2026-05-30 ✓                    |

### Servizi verificati via guest-agent

| Servizio     | Stato                  |
|--------------|------------------------|
| QEMU-GA      | Running, Automatic ✓   |
| spice-agent  | Running, Automatic ✓   |
| VirtioFsSvc  | Running, Automatic ✓   |

### Applicazioni installate

| Applicazione               | Versione         |
|----------------------------|------------------|
| Mozilla Firefox (x64 it)   | 151.0.2          |
| Notepad++ (64-bit x64)     | 8.6.4            |
| QEMU guest agent           | 106.0.1          |
| Virtio-win-driver-installer| 0.1.240          |
| Virtio-win-guest-tools     | 0.1.240          |
| Spice Agent                | 0.10.5           |
| WinFSP 2023                | 2.0.23075        |

> Verifica del 2026-05-30: Firefox e Notepad++ presenti nel registro programmi.
> `C:\install-tools.log` riporta exit code 0 per VirtIO guest tools, WinFSP, Firefox e Notepad++.

## Note

- Watchdog: itco
- Memballoon: virtio
- QEMU guest agent configurato e rispondente
- Reinstallata da zero il 2026-05-30 con ISO unattended noprompt
- Script unattended: `scripts/win10/create_win10_vm.sh`
- Risposte setup: `scripts/win10/autounattend.xml`
- ISO generata: `storage/Iso/Windows/Windows10-autounattend-noprompt.iso`
- Boot noprompt: `efisys_noprompt.bin` + `bootfix.bin` vuoto + ordine `hd,cdrom`
- Post-install: `SetupComplete.cmd` installa VirtIO guest tools, WinFSP, Firefox 151.0.2 x64 it e Notepad++ 8.6.4 prima del primo login; log in `C:\install-tools.log`
- Credenziali unattended da `scripts/lab.env` (default: `manzolo` / `manzolo`)
