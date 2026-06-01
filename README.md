# virt-manager-lab

Script di installazione unattended e documentazione del mio lab personale di virtualizzazione KVM/QEMU su Linux.

Il repo raccoglie tutto quello che serve per ricreare da zero le VM del lab: script bash che costruiscono la ISO con autoinstall integrato, la creano e la avviano in un unico comando — senza toccare tastiera durante l'installazione.

---

## Cosa c'è nel repo

```
virt-manager-lab/
├── Makefile                       # comandi install/start/shutdown/status per tutte le VM
├── scripts/
│   ├── lab.env                    # credenziali e percorsi centralizzati (VM_USER, VM_PASS, VM_BASE_DIR…)
│   ├── install-debian13.sh        # Debian 13 unattended (preseed)
│   ├── install-ubuntu24.04.sh     # Ubuntu 24.04 LTS unattended (autoinstall)
│   ├── install-ubuntu26.04.sh     # Ubuntu 26.04 LTS unattended (autoinstall)
│   ├── install-lubuntu20.04.sh    # Lubuntu 20.04 LTS unattended (autoinstall)
│   ├── install-lubuntu22.04.sh    # Lubuntu 22.04 LTS unattended (autoinstall)
│   ├── install-lubuntu24.04.sh    # Lubuntu 24.04 LTS unattended (autoinstall)
│   ├── install-kubuntu22.04.sh    # Kubuntu 22.04 LTS unattended (wrapper flavor)
│   ├── install-xubuntu22.04.sh    # Xubuntu 22.04 LTS unattended (wrapper flavor)
│   ├── install-mate22.04.sh       # Ubuntu MATE 22.04 LTS unattended (wrapper flavor)
│   ├── install-budgie22.04.sh     # Ubuntu Budgie 22.04 LTS unattended (wrapper flavor)
│   ├── install-kubuntu24.04.sh    # Kubuntu 24.04 LTS unattended (wrapper flavor)
│   ├── install-xubuntu24.04.sh    # Xubuntu 24.04 LTS unattended (wrapper flavor)
│   ├── install-mate24.04.sh       # Ubuntu MATE 24.04 LTS unattended (wrapper flavor)
│   ├── install-budgie24.04.sh     # Ubuntu Budgie 24.04 LTS unattended (wrapper flavor)
│   ├── install-kubuntu26.04.sh    # Kubuntu 26.04 LTS unattended (wrapper flavor)
│   ├── install-xubuntu26.04.sh    # Xubuntu 26.04 LTS unattended (wrapper flavor)
│   ├── install-mate26.04.sh       # Ubuntu MATE 26.04 LTS unattended (wrapper flavor)
│   ├── install-budgie26.04.sh     # Ubuntu Budgie 26.04 LTS unattended (wrapper flavor)
│   ├── win10/
│   │   ├── create_win10_vm.sh     # Windows 10 con autounattend
│   │   └── autounattend.xml       # risposta automatica setup Win10
│   ├── win11/
│   │   ├── create_win11_vm.sh     # Windows 11 con autounattend
│   │   └── autounattend.xml       # risposta automatica setup Win11
│   └── win7u/
│       ├── create_win7u_vm.sh     # Windows 7 Ultimate con autounattend
│       ├── autounattend.xml       # risposta automatica setup Win7
│       ├── enable_win7u_smb_shared.sh  # configura Samba sul host per shared Z:
│       └── enable_win7u_shared.sh      # aggiunge canale SPICE WebDAV alla VM
├── Debian13-preseed.cfg           # configurazione preseed Debian
├── ubuntu24.04-autoinstall.yaml   # cloud-init autoinstall Ubuntu 24.04
├── ubuntu26.04-autoinstall.yaml   # cloud-init autoinstall Ubuntu 26.04
├── lubuntu20.04-autoinstall.yaml  # cloud-init autoinstall Lubuntu 20.04
├── lubuntu22.04-autoinstall.yaml  # cloud-init autoinstall Lubuntu 22.04
├── lubuntu24.04-autoinstall.yaml  # cloud-init autoinstall Lubuntu 24.04
├── lubuntu26.04-autoinstall.yaml  # cloud-init autoinstall Lubuntu 26.04
├── ubuntu-flavor22.04-autoinstall.yaml # template comune flavor 22/24/26
└── vms/                           # documentazione di ogni VM (hardware, pacchetti, note)
```

---

## Requisiti host

- Linux con KVM abilitato (`/dev/kvm` accessibile)
- `libvirt` + `libvirtd` in esecuzione
- `virt-install` (pacchetto `virtinst`)
- `qemu-img`
- `xorriso` — necessario per costruire le ISO con autoinstall integrato
- `wget` — per scaricare le ISO se mancanti
- Pool libvirt `hdd` che punta alla cartella dove vuoi salvare i dischi

### Verifica rapida

```bash
kvm-ok                        # oppure: grep -c vmx /proc/cpuinfo
virsh pool-list --all         # deve comparire il pool "hdd"
which xorriso virt-install qemu-img
```

---

## Storage pools

Gli script si aspettano un pool libvirt chiamato **`hdd`** che punta alla cartella dei dischi VM. Adatta il percorso alla tua macchina:

```bash
virsh pool-define-as hdd dir --target /percorso/ai/tuoi/dischi
virsh pool-build hdd
virsh pool-start hdd
virsh pool-autostart hdd
```

---

## Installazione VM

### Uso con Makefile

Il Makefile alla root raccoglie i comandi principali:

```bash
make help
make list
make status
make win11              # installazione interattiva
make reinstall-win11    # risponde S se la VM esiste gia'
make iso-win11          # rigenera solo la ISO unattended (Windows)
make start-win11
make shutdown-win11
```

ID disponibili: `debian13`, `ubuntu24`, `ubuntu26`, `lubuntu20`, `lubuntu22`, `lubuntu24`, `kubuntu22`, `xubuntu22`, `mate22`, `budgie22`, `kubuntu24`, `xubuntu24`, `mate24`, `budgie24`, `kubuntu26`, `xubuntu26`, `mate26`, `budgie26`, `lubuntu26`, `win10`, `win11`, `win7u`.

Questi ID sono scorciatoie del Makefile, non gli ID numerici mostrati da libvirt.
Per ricavare l'ID numerico runtime di una VM avviata:

```bash
make status
```

`make status` mostra prima l'elenco libvirt e poi una tabella delle VM gestite
dal Makefile con ID stabile, nome libvirt, ID runtime e stato. Nell'elenco
libvirt la prima colonna (`Id`) e' l'ID runtime, per esempio `2` in questa riga:

```text
 Id   Nome        Stato
-----------------------------
 2    Windows11   in esecuzione
```

Quell'ID numerico esiste solo mentre la VM e' in esecuzione e cambia tra un avvio
e l'altro. Subito sotto trovi la corrispondenza stabile usata dal Makefile:

```text
ID         VM             LibvirtId  Stato
win11      Windows11      2          running
```

Il Makefile usa gli ID stabili:

```bash
make status-win11
make start-win11
make shutdown-win11
```

Se vuoi interrogare l'ID numerico libvirt, usa direttamente `virsh`:

```bash
virsh dominfo 2
```

I profili Ubuntu e Lubuntu configurano anche il login automatico dell'utente
definito in `scripts/lab.env`: GDM per Ubuntu/GNOME, SDDM per Lubuntu/LXQt.
I flavor 22.04 aggiuntivi usano SDDM per Kubuntu e LightDM per Xubuntu, Ubuntu
MATE e Ubuntu Budgie.

I profili desktop impostano anche Plymouth per mostrare la splash del flavor al
boot quando disponibile: spinner Ubuntu, logo Lubuntu/Kubuntu/Xubuntu/MATE/Budgie.

Ogni script fa tutto in autonomia:

1. Scarica la ISO originale se mancante
2. Costruisce una nuova ISO con autoinstall/preseed incorporato (tramite `xorriso`)
3. Crea il disco qcow2
4. Avvia la VM con `virt-install` e aspetta che l'installazione finisca

La VM si spegne automaticamente al termine. Poi basta `virsh start <nome>`.

### Esempio — Ubuntu 24.04

```bash
# Interattivo (chiede conferma se la VM esiste già)
bash scripts/install-ubuntu24.04.sh

# Non interattivo (risponde S automaticamente)
echo S | bash scripts/install-ubuntu24.04.sh
```

### Esempio — Debian 13

```bash
echo S | bash scripts/install-debian13.sh
```

### Esempio — Ubuntu 26.04

```bash
echo S | bash scripts/install-ubuntu26.04.sh
```

> **Nota:** lo script Ubuntu 26.04 rileva automaticamente l'`os-variant` disponibile
> (`ubuntu26.04` se presente nel db osinfo, altrimenti fallback a `ubuntu25.10`).

### Esempio — Lubuntu 24.04

```bash
make lubuntu24
make reinstall-lubuntu24
```

Lo script usa l'ISO Ubuntu 24.04 live-server con Subiquity/autoinstall e installa
`lubuntu-desktop`. Questa scelta evita di dipendere dall'automazione
dell'installer grafico Calamares dell'ISO Lubuntu.

### Esempio — Lubuntu 20.04 leggera

```bash
make lubuntu20
make reinstall-lubuntu20
```

La VM `lubuntu20.04` usa 2 GB RAM, 2 vCPU e disco da 25 GB. Anche qui la base e'
Ubuntu 20.04 live-server con Subiquity/autoinstall e pacchetto
`lubuntu-desktop`.

### Esempio — Lubuntu 22.04

```bash
make lubuntu22
make reinstall-lubuntu22
```

La VM `lubuntu22.04` usa 2 GB RAM, 2 vCPU e disco da 30 GB. La base e' Ubuntu
22.04 live-server con Subiquity/autoinstall e pacchetto `lubuntu-desktop`.

### Esempio — flavor Ubuntu 22.04 / 24.04 / 26.04

```bash
make kubuntu22
make xubuntu22
make mate22
make budgie22

make kubuntu24
make xubuntu24
make mate24
make budgie24

make kubuntu26
make xubuntu26
make mate26
make budgie26
```

Questi profili usano lo stesso template autoinstall comune e cambiano versione
Ubuntu, pacchetto desktop, display manager, Plymouth e risorse della VM.

### Esempio — Windows 7 Ultimate

```bash
make win7u
# oppure
bash scripts/win7u/create_win7u_vm.sh
```

**Prerequisiti aggiuntivi** rispetto alle altre VM Windows:

| File richiesto in `storage/shared/` | Scopo |
|---|---|
| `Firefox Setup 115.*.exe` | Firefox ESR (ultima versione che gira su Win7) |
| `autoit-v3-setup.zip` | AutoIt v3 |
| `SciTE4AutoIt3.exe` | editor SciTE per AutoIt |
| `virtio-win-guest-tools.exe` | driver VirtIO |
| `npp.8.6.4.Installer.x64.exe` | Notepad++ |

Servono anche `storage/Iso/addons/virtio-win-0.1.285.iso` e `storage/Iso/addons/spice.iso`.

Lo script installa tutto in autonomia (certificato Red Hat, driver viostor, Firefox ESR, AutoIt, SciTE, Notepad++) tramite `SetupComplete.cmd`. SPICE guest tools e VirtIO guest tools si installano manualmente al primo avvio con il batch sul desktop.

**Cartella shared su Windows 7** — virtiofs non è supportato; si usa Samba:

```bash
# Sul host: configura e avvia Samba
bash scripts/win7u/enable_win7u_smb_shared.sh

# Nel guest: monta Z: (shortcut già sul desktop)
net use Z: \\192.168.122.1\qemu-shared /persistent:yes
```

---

## Cosa installano le VM Linux

Ogni script installa un sistema GNOME completo con questi pacchetti aggiuntivi:

| Pacchetto | Scopo |
|---|---|
| `openvpn`, `network-manager-openvpn*` | VPN integrata in GNOME |
| `qemu-guest-agent` | integrazione con l'host (snapshot, IP, ecc.) |
| `spice-vdagent` | copia/incolla e ridimensionamento schermo con SPICE |
| `bind9-dnsutils` | tool DNS (dig, nslookup) |
| `aspell` | correttore ortografico |
| `linux-generic-hwe-*` | kernel HWE più recente |

Credenziali default: utente **`manzolo`**, password **`manzolo`** — per cambiarle modifica solo `scripts/lab.env` (rigenera `VM_PASS_HASH` con `openssl passwd -6 "<nuova_password>"`). I YAML, preseed e XML sono template con placeholder e vengono materializzati a runtime dagli script.

---

## Cartella condivisa con virtiofs

Le VM Linux montano automaticamente una cartella dell'host tramite **virtiofs** — più veloce e sicuro di 9p/samba per uso locale.

**Lato host** — la cartella sorgente è configurabile nello script (`SHARED_DIR`).

**Lato guest** — montata in `/mnt/shared` via `/etc/fstab` con automount systemd:

```
host_shared  /mnt/shared  virtiofs  nofail,x-systemd.automount,x-systemd.idle-timeout=60  0  0
```

Symlink creati automaticamente nell'home dell'utente:

```
~/shared          → /mnt/shared
~/Desktop/shared  → /mnt/shared
~/Scrivania/shared → /mnt/shared
```

Bookmark GTK3 aggiunto per averla visibile nel file manager.

**Requisito XML della VM** — virtiofs richiede `memfd` come backing della memoria:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

Gli script gestiscono tutto questo via `--memorybacking` e `--filesystem` di `virt-install`.

---

## Inventario VM documentato

La cartella `vms/` contiene un file markdown per ogni VM con hardware, pacchetti installati e note operative.

| VM | OS | Note |
|---|---|---|
| ubuntu24.04 | Ubuntu 24.04.3 LTS | GNOME 46, HWE kernel, virtiofs |
| ubuntu26.04 | Ubuntu 26.04 LTS | GNOME 50, HWE kernel, virtiofs |
| lubuntu20.04 | Lubuntu 20.04 LTS | LXQt, VM leggera 2 GB RAM / 25 GB disco |
| lubuntu22.04 | Lubuntu 22.04 LTS | LXQt, 2 GB RAM / 30 GB disco |
| lubuntu24.04 | Lubuntu 24.04 LTS | LXQt, installata via autoinstall server + lubuntu-desktop |
| lubuntu26.04 | Lubuntu 26.04 LTS | LXQt, installata via autoinstall server + lubuntu-desktop |
| kubuntu22.04 | Kubuntu 22.04 LTS | KDE Plasma, 4 GB RAM / 35 GB disco |
| xubuntu22.04 | Xubuntu 22.04 LTS | Xfce, 4 GB RAM / 30 GB disco |
| ubuntu-mate22.04 | Ubuntu MATE 22.04 LTS | MATE, 4 GB RAM / 30 GB disco |
| ubuntu-budgie22.04 | Ubuntu Budgie 22.04 LTS | Budgie, 4 GB RAM / 30 GB disco |
| kubuntu24.04 | Kubuntu 24.04 LTS | KDE Plasma, 4 GB RAM / 35 GB disco |
| xubuntu24.04 | Xubuntu 24.04 LTS | Xfce, 4 GB RAM / 30 GB disco |
| ubuntu-mate24.04 | Ubuntu MATE 24.04 LTS | MATE, 4 GB RAM / 30 GB disco |
| ubuntu-budgie24.04 | Ubuntu Budgie 24.04 LTS | Budgie, 4 GB RAM / 30 GB disco |
| kubuntu26.04 | Kubuntu 26.04 LTS | KDE Plasma, 4 GB RAM / 35 GB disco |
| xubuntu26.04 | Xubuntu 26.04 LTS | Xfce, 4 GB RAM / 30 GB disco |
| ubuntu-mate26.04 | Ubuntu MATE 26.04 LTS | MATE, 4 GB RAM / 30 GB disco |
| ubuntu-budgie26.04 | Ubuntu Budgie 26.04 LTS | Budgie, 4 GB RAM / 30 GB disco |
| Debian13 | Debian 13 | GNOME, Apache2, Docker CE |
| Windows10 | Windows 10 | autounattend, virtiofs, full virtio, Firefox, Notepad++ |
| Windows11 | Windows 11 | autounattend, KMS generico |
| Windows7U | Windows 7 Ultimate | autounattend, viostor, Firefox ESR 115, AutoIt, Notepad++; shared via SMB |
| WindowsXP/98/95/NT | Windows legacy | per test compatibilità |
| pfSense | pfSense | firewall/router |
| pi-hole | Ubuntu | ad-blocking DNS |
| … | … | vedi `vms/` |

---

## Report HTML inventario VM

Lo script `scripts/vm-report.sh` interroga libvirt e `qemu-img` e genera un file HTML
self-contained con la mappa filtrabile di tutte le VM.

```bash
bash scripts/vm-report.sh              # → vm-report.html nella directory corrente
bash scripts/vm-report.sh /tmp/report.html
```

Il report include:
- Stato (in esecuzione / ferma)
- OS family (Linux / Windows / Altro)
- RAM, vCPU, lista dischi con nome file
- Disco virtuale vs disco usato con barra di utilizzo
- Totali aggregati in cima
- Filtri per stato e OS + casella di ricerca per nome
- Ordinamento per colonna (click sull'intestazione)

---

## Strategia ISO (nota tecnica)

Le ISO Ubuntu vengono modificate con `xorriso` usando `-indev/-outdev -boot_image any replay`.
Questo approccio preserva intatti El Torito, la partizione EFI appended e l'MBR dall'originale — al contrario di approcci basati su `-dev/-commit` o `isohybrid`, che rischiano di rompere il boot UEFI.

---

## Licenza

Uso personale / laboratorio. Adatta liberamente.
