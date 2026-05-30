# Windows10_Cisco

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows10_Cisco                          |
| UUID    | de51cd68-fc65-4c41-b095-e7dcdb616db0    |
| OS      | Windows 10 con Cisco Packet Tracer       |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                 |
|-----------|----------------------------------------|
| RAM max   | 8 GB (8388608 KiB)                     |
| RAM curr  | 4 GB (4194304 KiB) — balloon memory   |
| vCPU      | 4                                      |
| Arch      | x86_64                                 |
| Machine   | pc-q35-7.0                             |
| Firmware  | BIOS                                   |
| CPU mode  | host-passthrough                       |
| Clock     | localtime (Windows)                    |
| Memory    | memfd + shared (richiesto da virtiofs) |
| HyperV    | relaxed, vapic, spinlocks              |

## Storage

| Dispositivo | File                                                                | Bus    | Formato | Dimensione |
|-------------|---------------------------------------------------------------------|--------|---------|------------|
| sda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/windows10_cisco.qcow2`   | virtio | qcow2   | 6.5 GB     |
| sdb (cdrom) | —                                                                   | sata   | raw     | —          |

## Rete

**Nessuna interfaccia di rete configurata** — VM isolata dalla rete.

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

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Windows 10 Pro                  |
| Hostname    | DESKTOP-1MK94ND                 |
| App rilevate| 12                              |

### Applicazioni installate

| Applicazione                    | Versione      |
|---------------------------------|---------------|
| **Cisco Packet Tracer 8.2.0**   | 8.2.0 (64-bit)|
| 7-Zip                           | 24.01         |
| Microsoft Edge                  | 122.0.2365.92 |
| Microsoft Edge Update           | 1.3.185.21    |
| Notepad++                       | 8.6.4         |
| WinFSP (`{E4C768C9...}`)        | 2.0.23075     |

> Hostname **DESKTOP-1MK94ND** (identico a Windows10 — clonate dalla stessa base).  
> Firefox **non** presente (a differenza di Windows10).

## Note

- **Nessuna NIC**: VM completamente isolata dalla rete (ideale per Packet Tracer)
- Balloon memory: max 8 GB, corrente 4 GB
- File `.pkt` di Cisco Packet Tracer presenti nella cartella shared
- Watchdog: itco
- Memballoon: virtio
- **Clonata dalla stessa base di Windows10**, poi differenziata con Cisco PT
