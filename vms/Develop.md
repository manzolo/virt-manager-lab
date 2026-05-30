# Develop

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Develop                                  |
| UUID    | e5fd22b7-1985-4a92-9712-2afa1e849217    |
| OS      | Ubuntu 22.04 (uso come macchina di sviluppo) |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                          |
|-----------|-------------------------------------------------|
| RAM       | 4 GB (4194304 KiB)                              |
| vCPU      | 2                                               |
| Arch      | x86_64                                          |
| Machine   | pc-q35-8.2                                      |
| Firmware  | EFI + Secure Boot (enrolled keys)               |
| NVRAM     | `/var/lib/libvirt/qemu/nvram/Develop_VARS.fd`   |
| CPU mode  | host-passthrough                                |
| Clock     | UTC                                             |

## Storage

| Dispositivo | File                                                        | Bus    | Formato | Dimensione |
|-------------|-------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/develop.qcow2`   | virtio | qcow2   | 14 GB      |

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:a1:6e:f1 | virtio  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

| Parametro   | Valore                                              |
|-------------|-----------------------------------------------------|
| Tipo        | filesystem mount (9p, accessmode=**mapped**)        |
| Sorgente    | `/home/manzolo/Workspaces/qemu/storage/shared`      |
| Target guest| `shared`                                            |

> Usa **9p mapped** (non virtiofs). Non richiede memfd backing.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Ubuntu 22.04.5 LTS              |
| Hostname    | develop                         |
| Pacchetti   | 2019 (apt)                      |

### Pacchetti notevoli

- `build-essential 12.9ubuntu3` — toolchain compilazione
- `arc-theme 20220405` — tema UI personalizzato (KDE/Qt)
- `bluedevil`, `breeze-cursor-theme` — ambiente KDE
- `bindfs 1.14.7` — mount bind utente
- `btrfs-progs` — supporto BTRFS
- `chafa 1.8.0` — visualizzatore immagini terminale
- `2048-qt` — gioco 2048 (desktop attivo)
- Stack Python, build tools, bind9-utils presenti

> Hostname **develop** → VM attivamente usata come macchina di sviluppo.  
> Desktop KDE con ambiente personalizzato (arc-theme, breeze).

## Note

- Guest Agent abilitato
- Watchdog: itco
- RNG: virtio
- Memballoon: virtio
- **VM di sviluppo attiva** con hostname configurato e desktop KDE
