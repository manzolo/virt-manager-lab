# WindowsNT

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | WindowsNT                                |
| UUID    | 67d089b0-586e-42d4-ac76-154bf466cf9b    |
| OS      | Windows NT 4.0 Workstation/Server        |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                              |
|-----------|-------------------------------------|
| RAM       | 256 MB (262144 KiB)                 |
| vCPU      | 1                                   |
| Arch      | **i686** (32-bit)                   |
| Machine   | pc-i440fx-2.9 (molto vecchio)       |
| Firmware  | BIOS                                |
| Emulatore | `/usr/bin/qemu-system-i386`         |
| CPU mode  | custom — modello Pentium            |
| Clock     | localtime                           |

## Storage

| Dispositivo | File                                                           | Bus | Formato | Opzioni     | Dimensione |
|-------------|----------------------------------------------------------------|-----|---------|-------------|------------|
| hda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/WindowsNT4.qcow2`   | ide | qcow2   | cache=none  | 409 MB     |
| hdc (cdrom) | —                                                              | ide | raw     | —           | —          |

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:2c:8c:c9 | pcnet   | default |

## Video & Audio

| Componente | Valore   |
|------------|----------|
| Video      | Cirrus   |
| Audio      | SB16     |
| Display    | SPICE    |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato a runtime — screenshot desktop)

| Campo       | Valore                                       |
|-------------|----------------------------------------------|
| OS rilevato | Windows NT 4.0 Workstation (italiano)        |
| Hostname    | manzolont                                    |
| App rilevate| solo icone di sistema predefinite            |

**Desktop osservato:**
- Icone standard: Risorse del computer, Risorse di rete, Cestino, Internet Explorer, Posta in arrivo, Sincronia file
- Tema teal/verde classico NT4
- Nessun software aggiuntivo sul desktop

**Problema machine type:**
- Il machine type originale `pc-i440fx-2.9` non è più supportato da QEMU
- Aggiornato a `pc-i440fx-noble` per il boot (modifica applicata al XML libvirt)
- La scheda di rete PCnet richiedeva la rimozione del ROM bar per avviarsi

> **Installazione base NT4 italiano.** Nessun software aggiuntivo.  
> La VM è funzionante dopo la correzione del machine type.

## Note

- **Unica VM che usa `qemu-system-i386`** (non x86_64)
- **Machine type aggiornato**: `pc-i440fx-2.9` → `pc-i440fx-noble` (vecchio tipo non supportato)
- Nessuna USB, nessun APIC (solo ACPI)
- Scheda di rete: AMD PCnet (ROM bar disabilitato per compatibilità)
- Video: Cirrus Logic (driver nativo NT4)
- Clock localtime (necessario per NT4)
- Memballoon: virtio
- Dimensione contenuta (409 MB) — da tenere come ambiente legacy
