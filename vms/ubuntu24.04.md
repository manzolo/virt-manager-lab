# ubuntu24.04

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | ubuntu24.04                              |
| UUID    | assegnato dinamicamente alla creazione   |
| OS      | Ubuntu 24.04 LTS (Noble Numbat)          |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                              |
|-----------|-----------------------------------------------------|
| RAM       | 4 GB (4194304 KiB)                                  |
| vCPU      | 2                                                   |
| Arch      | x86_64                                              |
| Machine   | pc-q35-8.2                                          |
| Firmware  | EFI (OVMF, senza Secure Boot enrollato dallo script)|
| NVRAM     | `/var/lib/libvirt/qemu/nvram/ubuntu24.04_VARS.fd`   |
| CPU mode  | host-passthrough                                    |
| Clock     | UTC                                                 |
| Memory    | memfd + shared (richiesto da virtiofs)               |

## Storage

| Dispositivo | File                                                            | Bus    | Formato | Opzioni       | Dimensione |
|-------------|-----------------------------------------------------------------|--------|---------|---------------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/ubuntu24.04.qcow2`   | virtio | qcow2   | discard=unmap | 40 GB      |
| sda (cdrom) | —                                                               | sata   | raw     | —             | —          |

## Rete

| NIC | MAC                          | Modello | Rete    |
|-----|------------------------------|---------|---------|
| 1   | assegnato dinamicamente      | virtio  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | virtio  |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa (virtiofs)

| Parametro    | Valore                                              |
|--------------|-----------------------------------------------------|
| Tipo         | virtiofs (passthrough)                              |
| Sorgente     | `/home/manzolo/Workspaces/qemu/storage/shared`      |
| Target guest | `host_shared`                                       |

La VM richiede `memfd` come backing della memoria:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

E il filesystem montato con virtiofsd:

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <binary path='/usr/libexec/virtiofsd'/>
  <source dir='/home/manzolo/Workspaces/qemu/storage/shared'/>
  <target dir='host_shared'/>
</filesystem>
```

Sul guest, il mount si esegue con:

```bash
mount -t virtiofs host_shared /mnt/shared
```

## Stato sistema

| Campo       | Valore                                  |
|-------------|-----------------------------------------|
| OS rilevato | Ubuntu 24.04 LTS                        |
| Hostname    | ubuntu24                                |
| Kernel      | 6.14.0-33-generic (HWE)                 |
| Pacchetti   | 1585 (apt)                              |

### Pacchetti notevoli

- `bpfcc-tools`, `bpftrace`, `python3-bpfcc` — strumenti eBPF per analisi kernel
- `openvpn`, `network-manager-openvpn`, `network-manager-openvpn-gnome` — VPN
- `cloud-init` — provisioning cloud
- `cpp`, `cpp-13` — compilatore C
- `bind9-dnsutils` — tool DNS
- `aspell`, `aspell-en` — dizionario inglese
- `spice-vdagent` — integrazione SPICE
- `qemu-guest-agent` — guest agent
- `snapd` — pacchetti snap
- Desktop GNOME 46 con estensioni Ubuntu:
  - `gnome-shell-extension-ubuntu-dock`
  - `gnome-shell-extension-ubuntu-tiling-assistant`
  - `gnome-shell-extension-appindicator`
  - `gnome-shell-extension-desktop-icons-ng`
- `linux-generic-hwe-24.04` — kernel HWE (metapackage)

## Note

- USB controller: qemu-xhci (15 porte)
- Controller SCSI: virtio-scsi (aggiunto dallo script, non usato dal disco principale)
- Guest Agent abilitato
- Watchdog: i6300esb
- RNG: virtio
- Memballoon: virtio
- `discard=unmap` sul disco (TRIM abilitato)
- **bpftrace e bpfcc** → uso per debugging/analisi kernel
- **openvpn** installato e integrato in NetworkManager
- Target virtiofs: `host_shared` (diverso da Windows10 che usa `shared`)
