# lubuntu22.04

## Identificazione

| Campo | Valore |
|-------|--------|
| Nome  | lubuntu22.04 |
| UUID  | assegnato dinamicamente alla creazione |
| OS    | Lubuntu 22.04 LTS (Jammy) |
| Stato | generata da script unattended |

> Da non confondere con **`lubuntu22`**, VM legacy creata a mano (disco `lubuntu22.qcow2`, 17 GB), documentata in [lubuntu22.md](lubuntu22.md) e non gestita dal registro.

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
| vda (disco) | `$VM_BASE_DIR/storage/hd/lubuntu22.04.qcow2` | virtio | qcow2 | discard=unmap | 30G |
| cdrom       | `storage/Iso/Distro/lubuntu-22.04.5-autoinstall.iso` (generata) | sata | raw | — | — |

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

`storage/shared` esposta come `host_shared` e montata su **/mnt/shared** (automount, `nofail`). Symlink `shared` in home, Scrivania e Desktop.

## Desktop

- Ambiente: **LXQt**
- Display manager: **sddm** con autologin dell'utente di `scripts/lab.env`
- Plymouth: `plymouth-theme-lubuntu-logo` se disponibile

## Metodo di installazione

Base Ubuntu **22.04.5** live-server + autoinstall (`unattended/lubuntu22.04-autoinstall.yaml`), pacchetti `lubuntu-desktop`, `plymouth-theme-lubuntu-logo`, `qemu-guest-agent`, `spice-vdagent`, OpenVPN + plugin NetworkManager, `linux-generic-hwe-22.04` installati nella fase principale di curtin (lista `packages:`). Il boot automatico usa `fsck.mode=skip`.

Script: `scripts/install-lubuntu22.04.sh` (sola configurazione, il lavoro lo fa `scripts/lib/subiquity-install.sh`).

## Note

- Controller SCSI aggiuntivo: virtio-scsi · Guest Agent abilitato · Watchdog i6300esb · RNG/Memballoon virtio
- Gestione via Makefile: `make lubuntu22`, `make start-lubuntu22`, `make clean-lubuntu22` (ID `lubuntu22` in `vms.tsv`)
- Test e2e: PASS il 2026-09-02 (run `20260902-105037`, install + desktop verificato via guest agent)
