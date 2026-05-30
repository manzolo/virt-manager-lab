# centos8

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | centos8                                  |
| UUID    | 33cca09b-03d3-4350-b597-a69d7e70ce8e    |
| OS      | CentOS 8                                 |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                  |
|-----------|-------------------------|
| RAM       | 1.5 GB (1572864 KiB)    |
| vCPU      | 2                       |
| Arch      | x86_64                  |
| Machine   | pc-q35-7.0              |
| Firmware  | BIOS                    |
| CPU mode  | host-passthrough        |
| Clock     | UTC                     |

## Storage

| Dispositivo | File                                                        | Bus    | Formato | Dimensione |
|-------------|-------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/centos8.qcow2`   | virtio | qcow2   | 3.3 GB     |
| sda (cdrom) | —                                                           | sata   | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:ee:ce:66 | virtio  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | virtio  |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo         | Valore                          |
|---------------|---------------------------------|
| OS rilevato   | CentOS Stream 8                 |
| Kernel        | 4.18.0-544.el8.x86_64           |
| Hostname      | localhost.localdomain (default) |
| Timezone      | EDT (UTC-4)                     |
| IP enp1s0     | 192.168.0.206 (DHCP)            |
| IP virbr0     | 192.168.122.1 (bridge libvirt)  |
| Disco usato   | ~6 GB su xfs+LVM (cs-root/cs-swap)  |
| Pacchetti     | 1368 (rilevati da virt-inspector)   |

> **Hostname non configurato** (localhost.localdomain): installazione non personalizzata.  
> La presenza di pacchetti anaconda (GUI installer) indica installazione con interfaccia grafica.  
> Contiene GNOME completo (adwaita, baobab, bluez, ecc.): non è installazione minimale.

### Pacchetti notevoli

- GNOME desktop completo (baobab, adwaita, bluez, avahi)
- `anaconda-*` — installer GUI (residuo post-installazione)
- `libvirt*`, `qemu-*` — **libvirt/KVM installato** (nested virtualization)
- `bind-utils`, `avahi` — tool di rete

## Note

- Guest Agent abilitato (`org.qemu.guest_agent.0`)
- **guest-exec disabilitato** dalla policy CentOS (sicurezza default)
- **libvirt/KVM installato** nella VM → possibile uso per nested virt
- Hostname non configurato → installazione di base non riutilizzata
- Watchdog: itco
- RNG: virtio
- Memballoon: virtio
