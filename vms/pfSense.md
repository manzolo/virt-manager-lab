# pfSense

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | pfSense                                  |
| UUID    | 9b73adaa-17fc-4e19-afc5-55e64b688cd0    |
| OS      | pfSense CE 2.7.x (FreeBSD 12.4)         |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore               |
|-----------|----------------------|
| RAM       | 1 GB (1048576 KiB)   |
| vCPU      | 1                    |
| Arch      | x86_64               |
| Machine   | pc-i440fx-kinetic    |
| Firmware  | BIOS                 |
| CPU mode  | host-passthrough     |
| Clock     | UTC                  |

## Storage

| Dispositivo | File                                                         | Bus    | Formato | Dimensione |
|-------------|--------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/pfsense.qcow2`    | virtio | qcow2   | 1.3 GB     |
| hda (cdrom) | —                                                            | ide    | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    | Ruolo       |
|-----|-------------------|---------|---------|-------------|
| 1   | 52:54:00:5d:ba:e3 | virtio  | default | WAN         |
| 2   | 52:54:00:ad:31:d6 | virtio  | default | LAN         |

> Doppia interfaccia di rete come da configurazione tipica pfSense.

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich6    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                                               |
|-------------|------------------------------------------------------|
| OS rilevato | Non rilevato (FreeBSD/pfSense non supportato)        |
| Hostname    | —                                                    |
| App rilevate| 0                                                    |

> virt-inspector non supporta il filesystem UFS di FreeBSD/pfSense.  
> Lo snapshot "Funzionante" del 2025-08-26 indica che era operativo.

## Note

- Chipset legacy i440fx (non Q35)
- USB controller: ich9-ehci1
- Memballoon: virtio
- Nessun guest agent
- virt-inspector non supporta FreeBSD/UFS
