# lubuntu22

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | lubuntu22                                |
| UUID    | 8d64ff0b-db4a-4653-a409-1ad90ab41e4f    |
| OS      | Lubuntu 22.04                            |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore           |
|-----------|------------------|
| RAM       | 2 GB (2097152 KiB) |
| vCPU      | 2                |
| Arch      | x86_64           |
| Machine   | pc-q35-7.0       |
| Firmware  | BIOS             |
| CPU mode  | host-passthrough |
| Clock     | UTC              |

## Storage

| Dispositivo | File                                                          | Bus    | Formato | Dimensione |
|-------------|---------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/lubuntu22.qcow2`   | virtio | qcow2   | 17 GB      |
| sda (cdrom) | —                                                             | sata   | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:58:89:b1 | virtio  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                        |
|-------------|-------------------------------|
| OS rilevato | Ubuntu 22.04.5 LTS (Lubuntu)  |
| Hostname    | lubuntu                       |
| Pacchetti   | 1782 (apt)                    |

### Pacchetti notevoli

- `compton 1`, `compton-conf 0.16.0` — compositor LXQt
- `2048-qt` — gioco incluso di default in Lubuntu
- `arc-theme` — tema UI installato
- `chafa 1.8.0`, `caca-utils` — tool da terminale
- Stack standard Lubuntu/LXQt (bluedevil, breeze, ecc.)
- `btrfs-progs`, `bindfs` presenti

> Hostname **lubuntu** (default Lubuntu).  
> Installazione standard Lubuntu 22.04, nessuna personalizzazione evidente oltre al tema.

## Note

- Controller SCSI aggiuntivo: virtio-scsi
- Guest Agent abilitato
- Watchdog: itco
- RNG: virtio
- Memballoon: virtio
- **Installazione base Lubuntu** — hostname di default, nessun software aggiuntivo rilevante
