# WindowsXP

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | WindowsXP                                |
| UUID    | 3e03f7b3-5b9c-4532-92c3-cae290f2bc29    |
| OS      | Windows XP (italiano)                    |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                  |
|-----------|-------------------------|
| RAM       | 2 GB (2097152 KiB)      |
| vCPU      | 1                       |
| Arch      | x86_64                  |
| Machine   | pc-i440fx-kinetic       |
| Firmware  | BIOS                    |
| CPU mode  | host-passthrough        |
| Clock     | UTC                     |

## Storage

| Dispositivo | File                                                           | Bus | Formato | Dimensione |
|-------------|----------------------------------------------------------------|-----|---------|------------|
| hda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/windowsxp.qcow2`    | ide | qcow2   | 7.3 GB     |
| hdb (cdrom) | —                                                              | ide | raw     | —          |

## Rete

| NIC | MAC               | Modello  | Rete    |
|-----|-------------------|----------|---------|
| 1   | 52:54:00:67:06:59 | rtl8139  | default |

## Video & Audio

| Componente | Valore   |
|------------|----------|
| Video      | QXL      |
| Audio      | AC97     |
| Display    | SPICE    |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                           |
|-------------|----------------------------------|
| OS rilevato | Microsoft Windows XP             |
| Hostname    | windowsxp                        |
| App rilevate| 8                                |

### Applicazioni installate

| Applicazione                        | Versione       |
|-------------------------------------|----------------|
| 7-Zip                               | 24.01          |
| Mozilla Firefox 52.9.0 ESR (it,x86) | 52.9.0         |
| SpiceGuestTools                     | 0.141          |
| **Microsoft Office** (`{90120000-0010-0409}`) | 12.0.4518 (2003/2007)|
| MozillaMaintenanceService           | 52.9.0         |
| `{350C9410...}` (Adobe?)            | 9.50.7523      |

> Hostname **windowsxp** (lowercase, configurato).  
> Firefox ESR 52 — ultima versione supportata su XP.  
> Office installato (GUID `90120000-0010` = Office 2007/2003 core).

## Note

- SPICE WebDAV configurato (`org.spice-space.webdav.0`) per trasferimento file via SPICE
- Chipset i440fx (non Q35), compatibile con XP
- Bus disco: IDE
- Scheda di rete: RTL8139 (driver nativo XP)
- Audio AC97 (compatibile XP)
- Memballoon: virtio
- **Microsoft Office e Firefox ESR** installati — VM in uso per compatibilità software legacy
