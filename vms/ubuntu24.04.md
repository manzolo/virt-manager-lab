# ubuntu24.04

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | ubuntu24.04                              |
| UUID    | assegnato dinamicamente alla creazione   |
| OS      | Ubuntu 24.04 LTS (Noble Numbat)          |
| Stato   | installata e funzionante ✓               |

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

| Campo       | Valore                                        |
|-------------|-----------------------------------------------|
| OS rilevato | Ubuntu 24.04.3 LTS (Noble Numbat)             |
| Hostname    | ubuntu24                                      |
| Kernel      | 6.17.0-35-generic (HWE 6.17.0-35.35~24.04.1) |
| IP (DHCP)   | 192.168.122.131 (libvirt default)             |
| GNOME       | Shell 46.0                                    |
| Disco usato | 8.7 GB / 19 GB LVM (51%)                      |
| Testato il  | 2026-05-30 ✓                                  |

### virtiofs verificato

| Check                          | Esito |
|--------------------------------|-------|
| `/mnt/shared` accessibile      | ✓     |
| `~/shared` → `/mnt/shared`     | ✓     |
| `~/Desktop/shared`             | ✓     |
| `~/Scrivania/shared`           | ✓     |
| GTK bookmark `/mnt/shared`     | ✓     |

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
