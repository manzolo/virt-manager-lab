# kubuntu24.04

## Identificazione

| Campo | Valore |
|-------|--------|
| Nome  | kubuntu24.04 |
| UUID  | assegnato dinamicamente alla creazione |
| OS    | Kubuntu 24.04 LTS |
| Stato | generata da script unattended |

## Hardware

| Risorsa   | Valore |
|-----------|--------|
| RAM       | 4 GB (4194304 KiB) |
| vCPU      | 2 |
| Arch      | x86_64 |
| Machine   | q35 |
| Firmware  | EFI (OVMF) |
| CPU mode  | host-passthrough |
| Memory    | memfd + shared (richiesto da virtiofs) |

## Storage

| Dispositivo | File | Bus | Formato | Opzioni | Dimensione |
|-------------|------|-----|---------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/kubuntu24.04.qcow2` | virtio | qcow2 | discard=unmap | 35G |

## Rete

| NIC | Modello | Rete |
|-----|---------|------|
| 1   | virtio  | default |

## Video & Audio

| Componente | Valore |
|------------|--------|
| Video      | virtio |
| Audio      | ich9   |
| Display    | SPICE  |

## Cartella condivisa (virtiofs)

`storage/shared` esposta come `host_shared` e montata su **/mnt/shared** (automount). Symlink `shared` in home, Scrivania e Desktop.

## Desktop

- Ambiente: **KDE Plasma**
- Display manager: **sddm** con autologin utente `manzolo`
- Plymouth: splash del flavor se disponibile

## Metodo di installazione

Base Ubuntu **24.04.4** live-server + autoinstall, metapacchetto **KDE Plasma** installato nella fase principale di curtin (lista `packages:` del template condiviso `unattended/ubuntu-flavor-autoinstall.yaml`).

## Note

- Controller SCSI aggiuntivo: virtio-scsi · Guest Agent abilitato · Watchdog i6300esb · RNG/Memballoon virtio
- Gestione via Makefile: ID del flavor da `make list` (target `install-<id>`, `start-<id>`, `clean-<id>`)
