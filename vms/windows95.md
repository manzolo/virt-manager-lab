# windows95

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | windows95                                |
| UUID    | 593b1d02-6022-474d-a990-82c44da081ce    |
| OS      | Windows 95                               |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                              |
|-----------|-------------------------------------|
| RAM       | 64 MB (65536 KiB)                   |
| vCPU      | 1                                   |
| Arch      | **i686** (32-bit)                   |
| Machine   | pc-i440fx-6.2                       |
| Firmware  | BIOS                                |
| CPU mode  | custom — modello Pentium            |
| Clock     | UTC                                 |

## Storage

| Dispositivo | File                                                      | Bus | Formato | Dimensione |
|-------------|-----------------------------------------------------------|-----|---------|------------|
| hda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/win95.qcow2`   | ide | qcow2   | 637 MB     |
| hdb (cdrom) | —                                                         | ide | raw     | —          |

## Rete

| NIC | MAC               | Modello  | Rete    |
|-----|-------------------|----------|---------|
| 1   | 52:54:00:09:d2:47 | ne2k_pci | default |

## Video & Audio

| Componente | Valore              |
|------------|---------------------|
| Video      | virtio (no 3D)      |
| Audio      | SB16                |
| Display    | SPICE               |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato a runtime — screenshot desktop)

| Campo       | Valore                                          |
|-------------|-------------------------------------------------|
| OS rilevato | Windows 95 (italiano)                           |
| Hostname    | —                                               |
| App rilevate| solo icone desktop predefinite                  |

**Desktop osservato:**
- Icone standard: Risorse del computer, Risorse di rete, Cestino, Internet (IE), Posta in arrivo, Sincronia file
- Nessun software aggiuntivo sul desktop
- Tema viola standard Win95 IT
- Al boot esegue ScanDisk su `C:\WIN95CD\DEMOS\MSB\GEO\CONTROLS` (demo CD inclusa)

> **Installazione base Win95 italiano.** Nessun software aggiuntivo visibile.  
> La cartella `WIN95CD\DEMOS` indica che il CD dimostrativo di Win95 è stato copiato sul disco.

## Note

- Architettura **i686** (32-bit) con CPU Pentium emulato
- Chipset legacy i440fx (non Q35)
- Bus disco: IDE (non virtio)
- Scheda di rete: NE2000 PCI (compatibile Win95)
- Audio SB16 per compatibilita' con driver Win9x
- Memballoon: virtio
- virt-inspector non supporta Win95 (FAT16)
- Dimensione contenuta (637 MB) — da tenere come ambiente legacy
