# Windows10

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows10                                |
| UUID    | 20c1df90-5ca2-4ebb-bc40-4df232e1dae2    |
| OS      | Windows 10                               |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                |
|-----------|---------------------------------------|
| RAM       | 4 GB (4194304 KiB)                    |
| vCPU      | 2                                     |
| Arch      | x86_64                                |
| Machine   | pc-q35-7.0                            |
| Firmware  | BIOS                                  |
| CPU mode  | host-passthrough                      |
| Clock     | localtime (Windows)                   |
| Memory    | memfd + shared (richiesto da virtiofs)|
| HyperV    | relaxed, vapic, spinlocks             |

## Storage

| Dispositivo | File                                                           | Bus    | Formato | Dimensione |
|-------------|----------------------------------------------------------------|--------|---------|------------|
| sda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/windows10.qcow2`    | virtio | qcow2   | 33 GB      |
| sdb (cdrom) | —                                                              | sata   | raw     | —          |

## Rete

| NIC | MAC               | Modello | Rete    | Stato |
|-----|-------------------|---------|---------|-------|
| 1   | 52:54:00:58:64:24 | e1000e  | default | down  |

> Interfaccia di rete configurata come `link state='down'`.

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

> Richiede WinFSP installato nel guest per montare il filesystem virtiofs.  
> Richiede `<memoryBacking><source type='memfd'/><access mode='shared'/></memoryBacking>`.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Windows 10 Pro                  |
| Hostname    | DESKTOP-1MK94ND                 |
| App rilevate| 13                              |

### Applicazioni installate

| Applicazione               | Versione         |
|----------------------------|------------------|
| 7-Zip                      | 24.01            |
| Microsoft Edge             | 122.0.2365.92    |
| Mozilla Firefox (it, x64)  | 123.0.1          |
| Notepad++                  | 8.6.4            |
| WinFSP (`{E4C768C9...}`)   | 2.0.23075        |
| MozillaMaintenanceService  | 123.0.1          |
| Microsoft EdgeWebView      | 122.0.2365.92    |

> WinFSP presente → necessario per il mount virtiofs della cartella shared.  
> Hostname **DESKTOP-1MK94ND** (stesso di Windows10_Cisco — clonate dalla stessa immagine).

## Note

- Watchdog: itco
- Memballoon: virtio
- Nessun QEMU guest agent Windows configurato
- **Stessa immagine base di Windows10_Cisco** (hostname identico)
