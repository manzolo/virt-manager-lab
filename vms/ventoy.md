# ventoy

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | ventoy                                   |
| UUID    | 2e0b02b6-cc91-4eab-89be-83a5e9a19304    |
| OS      | Windows (avvio da USB Ventoy esterna)   |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                         |
|-----------|------------------------------------------------|
| RAM       | 8 GB (8388608 KiB)                             |
| vCPU      | 4                                              |
| Arch      | x86_64                                         |
| Machine   | pc-q35-8.2                                     |
| Firmware  | EFI + Secure Boot (enrolled keys)              |
| NVRAM     | `/var/lib/libvirt/qemu/nvram/ventoy_VARS.fd`   |
| CPU mode  | host-passthrough                               |
| Clock     | localtime (Windows)                            |
| TPM       | tpm-crb emulato v2.0                           |
| HyperV    | relaxed, vapic, spinlocks                      |

## Storage

| Dispositivo | File                                              | Bus  | Formato | Note              |
|-------------|---------------------------------------------------|------|---------|-------------------|
| sda (disco) | `/media/manzolo/Ventoy/BOOTIMG/WindowsNow.vhd`    | sata | raw     | USB esterna!      |
| sdb (cdrom) | —                                                 | sata | raw     | —                 |

> Il disco principale e' un VHD su chiavetta USB Ventoy montata sul host.
> La VM non funziona se la chiavetta non e' montata.

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:be:7f:88 | e1000e  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Note

- Boot menu abilitato
- Watchdog: itco
- Memballoon: virtio
- Dipende dalla presenza della chiavetta USB `/media/manzolo/Ventoy/`
