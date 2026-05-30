# ubuntu26.04

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | ubuntu26.04                              |
| UUID    | assegnato dinamicamente alla creazione   |
| OS      | Ubuntu 26.04 LTS                         |
| Stato   | installata e funzionante ✓                   |

## Hardware

| Risorsa   | Valore                                              |
|-----------|-----------------------------------------------------|
| RAM       | 4 GB (4194304 KiB)                                  |
| vCPU      | 2                                                   |
| Arch      | x86_64                                              |
| Machine   | pc-q35-9.2                                          |
| Firmware  | EFI (OVMF, senza Secure Boot enrollato dallo script)|
| NVRAM     | `/var/lib/libvirt/qemu/nvram/ubuntu26.04_VARS.fd`   |
| CPU mode  | host-passthrough                                    |
| Clock     | UTC                                                 |
| Memory    | memfd + shared (richiesto da virtiofs)               |

## Storage

| Dispositivo | File                                                            | Bus    | Formato | Opzioni       | Dimensione |
|-------------|-----------------------------------------------------------------|--------|---------|---------------|------------|
| vda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/ubuntu26.04.qcow2`   | virtio | qcow2   | discard=unmap | 40 GB      |
| cdrom       | ISO durante installazione, poi rimosso                          | —      | —       | —             | —          |

Storage layout: LVM sul disco più grande.

## Rete

| NIC | MAC                     | Modello | Rete    |
|-----|-------------------------|---------|---------|
| 1   | assegnato dinamicamente | virtio  | default |

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
| Mount guest  | `/mnt/shared`                                       |

Configurazione XML richiesta:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/home/manzolo/Workspaces/qemu/storage/shared'/>
  <target dir='host_shared'/>
</filesystem>
```

Voce `/etc/fstab` aggiunta dall'autoinstall:

```
host_shared  /mnt/shared  virtiofs  nofail,x-systemd.automount,x-systemd.idle-timeout=60  0  0
```

## Autoinstall

| Parametro  | Valore                          |
|------------|---------------------------------|
| Hostname   | ubuntu26                        |
| Utente     | manzolo / manzolo               |
| Locale     | it_IT.UTF-8                     |
| Tastiera   | it                              |
| Script     | `scripts/install-ubuntu26.04.sh`|
| YAML       | `ubuntu26.04-autoinstall.yaml`  |

### ISO

| File                                                             | Ruolo          |
|------------------------------------------------------------------|----------------|
| `storage/Iso/Distro/ubuntu-26.04-desktop-amd64.iso`             | originale      |
| `storage/Iso/Distro/ubuntu-26.04-autoinstall.iso`               | con autoinstall|

> **Attenzione:** il nome dell'ISO potrebbe variare col punto di release
> (es. `ubuntu-26.04.1-desktop-amd64.iso`). In tal caso aggiornare
> `ISO_ORIG`, `ISO_AUTO` e `ISO_URL` nello script prima di eseguirlo.

### Late-commands: setup cartella condivisa

A differenza di Ubuntu 24.04, il YAML 26.04 ha un comando aggiuntivo che imposta
la cartella condivisa **direttamente nella home di manzolo**, oltre che in `/etc/skel`.
Questo gestisce il caso in cui Ubuntu 26.04 crei l'utente *prima* dei late-commands
(comportamento diverso dal 24.04 dove la creazione avviene dopo via ubuntu-desktop-bootstrap).

Sequenza completa:

| Passo | Azione |
|-------|--------|
| 1 | `systemctl enable qemu-guest-agent` e `spice-vdagent` |
| 2 | `mkdir -p /mnt/shared` + voce `/etc/fstab` per automount virtiofs |
| 3 | Popola `/etc/skel`: dirs, symlink, bookmark GTK3, `gnome-initial-setup-done` |
| 4 | Se `manzolo` esiste già: replica symlink e bookmark anche in `$HOME`, corregge ownership |

Il passo 4 (fallback diretto sulla home) è assente nel YAML 24.04.

### Pacchetti installati dall'autoinstall

- `bpfcc-tools`, `bpftrace`, `python3-bpfcc` — strumenti eBPF
- `openvpn`, `network-manager-openvpn`, `network-manager-openvpn-gnome` — VPN
- `spice-vdagent` — integrazione SPICE
- `qemu-guest-agent` — guest agent
- `bind9-dnsutils` — tool DNS
- `aspell`, `aspell-en` — dizionario inglese
- `linux-generic-hwe-26.04` — kernel HWE (metapackage)
- GNOME Desktop (incluso nell'ISO desktop)

### os-variant

Lo script rileva automaticamente: prova `ubuntu26.04`, fallback a `ubuntu25.10`.
Al test del 2026-05-30 ha usato il fallback `ubuntu25.10` (non ancora nel db osinfo).

## Stato sistema

| Campo       | Valore                                      |
|-------------|---------------------------------------------|
| OS rilevato | Ubuntu 26.04 LTS (Resolute Raccoon)         |
| Hostname    | ubuntu26                                    |
| Kernel      | 7.0.0-22-generic (HWE 7.0.0-22.22)         |
| IP (DHCP)   | 192.168.122.76 (libvirt default)            |
| GNOME       | Shell 50.1                                  |
| Disco usato | 9.4 GB / 19 GB LVM (55%)                   |
| Testato il  | 2026-05-30 ✓                                |

### virtiofs verificato

| Check                          | Esito |
|--------------------------------|-------|
| `/mnt/shared` accessibile      | ✓     |
| `~/shared` → `/mnt/shared`     | ✓     |
| `~/Desktop/shared`             | ✓     |
| `~/Scrivania/shared`           | ✓     |
| GTK bookmark `/mnt/shared`     | ✓     |

## Note

- Controller SCSI: virtio-scsi (aggiunto dallo script, non usato dal disco principale)
- Watchdog: i6300esb
- RNG: virtio
- Memballoon: virtio
- `discard=unmap` sul disco (TRIM abilitato)
- Target virtiofs: `host_shared` (uguale a ubuntu24.04, diverso da Windows10 che usa `shared`)
- Symlink in `/etc/skel` e in `$HOME/manzolo`: `shared`, `Scrivania/shared`, `Desktop/shared` → `/mnt/shared`
- Bookmark GTK3 aggiunto in skel e in `$HOME` (con `chown` ownership corretta)
- Fix rispetto a ubuntu24.04: late-command aggiuntivo che imposta la home direttamente
  se l'utente viene creato dall'installer prima dei late-commands
