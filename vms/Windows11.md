# Windows11

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows11                                |
| OS      | Windows 11 Pro 24H2 (italiano)           |
| Stato   | installata e funzionante ✓               |

## Hardware

| Risorsa   | Valore                                          |
|-----------|-------------------------------------------------|
| RAM       | 8 GB                                            |
| vCPU      | 4                                               |
| Arch      | x86_64                                          |
| Machine   | q35                                             |
| Firmware  | EFI (OVMF 4M)                                   |
| NVRAM     | `/var/lib/libvirt/qemu/nvram/Windows11_VARS.fd` |
| CPU mode  | host-passthrough                                |
| Clock     | localtime (Windows)                             |
| TPM       | tpm-crb emulato v2.0                            |

## Storage

| Dispositivo | File                                                         | Bus    | Formato | Opzioni       | Dimensione |
|-------------|--------------------------------------------------------------|--------|---------|---------------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/Windows11.qcow2`  | virtio | qcow2   | discard=unmap | 60 GB      |

## Rete

| NIC | Modello | Rete    |
|-----|---------|---------|
| 1   | virtio  | default |

## Video & Audio

| Componente | Valore |
|------------|--------|
| Video      | QXL    |
| Audio      | ich9   |
| Display    | SPICE  |

## Cartella condivisa (virtiofs)

| Parametro    | Valore                                         |
|--------------|------------------------------------------------|
| Tipo         | virtiofs (passthrough)                         |
| Sorgente     | `/home/manzolo/Workspaces/qemu/storage/shared` |
| Target guest | `shared`                                       |
| Unità guest  | `Z:`                                           |

## Installazione unattended

| Parametro   | Valore                                    |
|-------------|-------------------------------------------|
| Script      | `scripts/win11/create_win11_vm.sh`        |
| Unattend    | `scripts/win11/autounattend.xml`          |
| ISO Windows | `storage/Iso/Windows/Win11_24H2_Italian_x64.iso` |
| ISO virtio  | `storage/Iso/addons/virtio-win-0.1.285.iso` |
| Utente      | da `scripts/lab.env` (non versionato: vedi lab.env.example) |
| Hostname    | Windows11-Lab                             |
| Lingua      | it-IT                                     |

### Strategia driver virtio (windowsPE)

Il disco usa `bus=virtio` → senza `viostor` in WinPE il setup non trova nessun disco.
`autounattend.xml` inietta i driver tramite `Microsoft-Windows-PnpCustomizationsWinPE`
con `<DriverPaths>` che puntano a `E:\viostor\w11\amd64` e `E:\NetKVM\w11\amd64`
(con fallback D: e F:) dalla virtio ISO montata come secondo CD-ROM.

### FirstLogonCommands

| Ordine | Azione |
|--------|--------|
| 1 | `virtio-win-gt-x64.msi` — driver VirtIO hardware |
| 2 | `virtio-win-guest-tools.exe` — QEMU Guest Agent + SPICE Agent |
| 3 | `winfsp-2.0.23075.msi` — WinFSP (necessario per virtiofs) |
| 4 | `sc config VirtioFsSvc start=auto` + `net start VirtioFsSvc` |

## Stato sistema

| Campo          | Valore                     |
|----------------|----------------------------|
| Testato il     | 2026-05-30 ✓               |
| Disco usato    | ~11 GB / 60 GB             |
| Unità Z:       | virtiofs shared (1167 GB)  |

### Software installato e verificato

| App                        | Versione   |
|----------------------------|------------|
| Virtio-win-driver-installer | 0.1.285   |
| QEMU Guest Agent           | 110.0.2    |
| Spice Agent                | 0.10.5     |
| WinFsp 2023                | 2.0.23075  |

### Servizi verificati via guest-agent

| Servizio     | Stato                  |
|--------------|------------------------|
| QEMU-GA      | Running, Automatic ✓   |
| spice-agent  | Running, Automatic ✓   |
| VirtioFsSvc  | Running, Automatic ✓   |

## Note

- `discard=unmap` sul disco (TRIM abilitato)
- Boot: `efisys_noprompt.bin` + ordine `hd,cdrom` — nessun "Press any key", riavvii dal disco
- LabConfig bypass: TPM, SecureBoot, CPU, RAM, Storage check disabilitati per QEMU/KVM
- Chiave KMS generica Win11 Pro (`W269N-WFGWX-YVC9B-4J6C9-T83GX`) — non attiva, solo per saltare la schermata
