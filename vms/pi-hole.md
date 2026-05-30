# pi-hole

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | pi-hole                                  |
| UUID    | 7671b5b1-479a-4932-8d6e-80d39c3aeaba    |
| OS      | Ubuntu 22.04 (server DNS con Pi-hole)   |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore           |
|-----------|------------------|
| RAM       | 1 GB (1048576 KiB) |
| vCPU      | 2                |
| Arch      | x86_64           |
| Machine   | pc-q35-7.0       |
| Firmware  | BIOS             |
| CPU mode  | host-passthrough |
| Clock     | UTC              |

## Storage

| Dispositivo | File                                                         | Bus    | Formato | Dimensione |
|-------------|--------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/pi-hole.qcow2`    | virtio | qcow2   | 3.4 GB     |
| sda (cdrom) | —                                                            | sata   | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    | Stato |
|-----|-------------------|---------|---------|-------|
| 1   | 52:54:00:4d:90:65 | virtio  | default | up    |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Ubuntu 22.04.5 LTS              |
| Hostname    | qpi-hole                        |
| Pacchetti   | 552 (apt) — installazione minima|

### Pacchetti notevoli

- `dns-root-data 2024071801` — dati root DNS (Pi-hole)
- `dnsutils`, `bind9-*` — tool DNS
- `cloud-init 24.4.1` — provisioning cloud
- `curl 7.81.0`, `dialog 1.3` — tool usati dall'installer Pi-hole
- `eatmydata 130` — accelerazione I/O installazioni
- `cron 3.0pl1` — schedulazione aggiornamenti Pi-hole
- nessun desktop grafico installato (server headless)

> Hostname **qpi-hole** → VM configurata come server DNS.  
> Solo 552 pacchetti: installazione server minimale.  
> Pi-hole probabilmente installato ma non rilevato direttamente dal package manager
> (Pi-hole si installa via script, non via apt).

## Note

- Interfaccia di rete configurata esplicitamente come `link state='up'`
- Guest Agent abilitato
- Watchdog: itco
- RNG: virtio
- Memballoon: virtio
- **Server Pi-hole configurato** — hostname specifico, installazione server minimale
