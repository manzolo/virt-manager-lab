# lubuntu20.04

## Identificazione

| Campo | Valore |
|-------|--------|
| Nome  | lubuntu20.04 |
| UUID  | assegnato dinamicamente alla creazione |
| OS    | Lubuntu 20.04 LTS |
| Stato | generata da script unattended |

## Hardware

| Risorsa   | Valore |
|-----------|--------|
| RAM       | 2 GB (2097152 KiB) |
| vCPU      | 2 |
| Arch      | x86_64 |
| Machine   | q35 |
| Firmware  | EFI (OVMF) |
| CPU mode  | host-passthrough |
| Memory    | memfd + shared (richiesto da virtiofs) |

## Storage

| Dispositivo | File | Bus | Formato | Opzioni | Dimensione |
|-------------|------|-----|---------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/lubuntu20.04.qcow2` | virtio | qcow2 | discard=unmap | 25G |

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

- Ambiente: **LXQt**
- Display manager: **sddm** con autologin utente `manzolo`
- Plymouth: splash del flavor se disponibile

## Metodo di installazione

Base Ubuntu **20.04.6** live-server + autoinstall, pacchetto **LXQt** installato nella fase principale di curtin (lista `packages:`).

## Note

- Controller SCSI aggiuntivo: virtio-scsi · Guest Agent abilitato · Watchdog i6300esb · RNG/Memballoon virtio
- Gestione via Makefile: ID del flavor da `make list` (target `install-<id>`, `start-<id>`, `clean-<id>`)
