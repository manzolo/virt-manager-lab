# Debian13

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Debian13                                 |
| UUID    | d75fbdbb-de62-45c8-9d10-b1316d524ca2    |
| OS      | Debian 13 (Trixie)                       |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                           |
|-----------|--------------------------------------------------|
| RAM       | 2 GB (2097152 KiB)                               |
| vCPU      | 2                                                |
| Arch      | x86_64                                           |
| Machine   | pc-q35-8.2                                       |
| Firmware  | EFI (OVMF, senza Secure Boot enrollato dallo script) |
| NVRAM     | `/var/lib/libvirt/qemu/nvram/Debian13_VARS.fd`   |
| CPU mode  | host-passthrough                                 |
| Clock     | UTC                                              |

## Storage

| Dispositivo | File                                                        | Bus    | Formato | Dimensione |
|-------------|-------------------------------------------------------------|--------|---------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/Debian13.qcow2`  | virtio | qcow2   | 50 GB      |
| sda (cdrom) | —                                                           | sata   | raw     | —          |

## Rete

| NIC | Modello | Rete    |
|-----|---------|---------|
| 1   | virtio  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema

| Campo       | Valore                             |
|-------------|------------------------------------|
| OS rilevato | Debian 13 (Trixie)                 |
| Hostname    | ManzoloDebian                      |
| Pacchetti   | 1697 (apt)                         |

### Pacchetti notevoli

- `apache2` — server web Apache
- `containerd.io` + `docker-ce` + `docker-ce-cli` — Docker CE (repo ufficiale)
- `docker-buildx-plugin` + `docker-compose-plugin`
- `build-essential`, `gcc`, `binutils`, `cpp` — toolchain dev
- `bind9-dnsutils` — tool DNS
- `aspell-it` — dizionario italiano
- `spice-vdagent` — integrazione SPICE
- `qemu-guest-agent` — guest agent
- Desktop GNOME completo (gnome-shell)

## Installazione automatica

La VM è replicabile da zero tramite:

```bash
bash /home/manzolo/Workspaces/qemu/virt-manager/scripts/install-debian13.sh
```

File coinvolti:
| File | Scopo |
|------|-------|
| `virt-manager/scripts/install-debian13.sh` | Script principale (scarica ISO se mancante, cancella VM esistente chiedendo conferma, ricostruisce ISO con preseed, lancia virt-install) |
| `virt-manager/Debian13-preseed.cfg` | Template preseed Debian: locale IT, utente da `scripts/lab.env`, standard task dal DVD, GNOME + Apache + Docker + dev tools via late_command dalla rete |
| `storage/Iso/Distro/debian-13-preseed.iso` | ISO con preseed integrato (generata dallo script) |

### Strategia preseed

Il passo `tasksel` installa solo `standard` dal DVD (stabile, nessuna dipendenza di rete).
GNOME, Apache2, Docker e tutti i pacchetti aggiuntivi vengono installati nel `late_command`
via apt da `deb.debian.org` dopo che la rete è già attiva.

## Note

- Controller SCSI: virtio-scsi
- Guest Agent abilitato
- Watchdog: i6300esb
- RNG: virtio
- Memballoon: virtio
- Boot menu abilitato
- Utente e password da `scripts/lab.env` (default: `manzolo` / `manzolo`)
- **Apache2 e Docker CE installati e abilitati**
