# Windows98

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows98                                |
| UUID    | 8bde56fb-b91b-4651-a18f-55c49e634e90    |
| OS      | Windows 98 SE                            |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                               |
|-----------|--------------------------------------|
| RAM       | 32 MB (32768 KiB)                    |
| vCPU      | 1                                    |
| Arch      | **i686** (32-bit)                    |
| Machine   | pc-i440fx-kinetic                    |
| Firmware  | BIOS (boot menu disabilitato)        |
| CPU mode  | host-passthrough (migratable=off)    |
| Clock     | UTC                                  |

## Storage

| Dispositivo  | File                                                      | Bus | Formato | Note                          | Dimensione |
|--------------|-----------------------------------------------------------|-----|---------|-------------------------------|------------|
| hda (disco)  | `/home/manzolo/Workspaces/qemu/storage/hd/win98.qcow2`   | ide | **raw** | File .qcow2 aperto come raw!  | 1 GB       |
| hdb (cdrom)  | —                                                         | ide | raw     | —                             | —          |
| fda (floppy) | —                                                         | fdc | raw     | Controller floppy presente    | —          |

> Il file e' `.qcow2` ma il driver QEMU e' configurato come `raw` — potrebbe causare problemi.

## Rete

| NIC | MAC               | Modello  | Rete    |
|-----|-------------------|----------|---------|
| 1   | 52:54:00:a9:42:d7 | rtl8139  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | VGA     |
| Audio      | SB16    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato a runtime — screenshot)

| Campo       | Valore                                                     |
|-------------|-------------------------------------------------------------|
| OS rilevato | **Non bootabile** — SeaBIOS "No bootable device"           |
| Hostname    | —                                                           |
| App rilevate| 0                                                           |

**Boot screen osservata:** splash Windows 98 — avvio regolare dopo il fix.

> **Fix applicato il 2026-05-29**: cambiato `driver type='raw'` → `type='qcow2'` nel XML.  
> La VM boota correttamente.

## Note

- Architettura **i686** (32-bit), chipset i440fx
- Controller floppy (fdc) configurato
- Bus disco: IDE
- Scheda di rete: RTL8139 (compatibile Win98)
- ~~**BUG CRITICO**: driver `raw` su file qcow2~~ → **CORRETTO il 2026-05-29**
- Memballoon: virtio
- virt-inspector non supporta Win98 (FAT16/32)
