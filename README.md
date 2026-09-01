# kvm-lab

Script di installazione unattended e documentazione del mio lab personale di virtualizzazione KVM/QEMU su Linux.

Il repo raccoglie tutto quello che serve per ricreare da zero le VM del lab: script bash che costruiscono la ISO con autoinstall integrato, la creano e la avviano in un unico comando — senza toccare tastiera durante l'installazione.

Strumenti usati: `virt-install`, `virsh`, `qemu-img`, `xorriso`. (Il nome precedente, *virt-manager-lab*, era fuorviante: la GUI virt-manager non serve.)

---

## Cosa c'è nel repo

```
kvm-lab/
├── vms.tsv                  # REGISTRO VM: unica fonte di verita' dell'inventario
├── Makefile                 # target generati dal registro (install/start/shutdown/clean/test)
├── unattended/              # risposte automatiche degli installer (template con placeholder)
│   ├── *-autoinstall.yaml   #   subiquity (Ubuntu, Lubuntu, flavor)
│   ├── Debian13-preseed.cfg #   preseed Debian
│   ├── enterprise-linux.ks  #   kickstart Rocky/AlmaLinux
│   ├── fedora-silverblue.ks #   kickstart Fedora Silverblue
│   └── tumbleweed-autoyast.xml  # AutoYaST openSUSE
├── scripts/
│   ├── lab.env              # credenziali e percorsi (VM_USER, VM_PASS, VM_BASE_DIR...)
│   ├── vms-registry.sh      # lettura/validazione di vms.tsv (make check-registry)
│   ├── lib/
│   │   └── subiquity-install.sh   # MOTORE comune: ISO + disco + virt-install + first boot
│   ├── install-<distro>.sh  # un file per VM: solo configurazione, poi chiama il motore
│   ├── install-ubuntu-flavor.sh   # motore dei flavor (Kubuntu/Xubuntu/MATE/Budgie 22/24/26)
│   ├── install-enterprise-linux.sh # motore Rocky/AlmaLinux (kickstart)
│   ├── test-*.sh, test-lib.sh     # test end-to-end (make test-linux / test-win / test-all)
│   ├── setup.sh, clean-vm.sh, vm-report.sh, v2p-deploy.sh, gen-cheatsheet.sh
│   ├── assets/              # bootstrap Arch/niri
│   └── win10/ win11/ win7u/ # Windows: create_*_vm.sh + autounattend.xml
├── vms/                     # scheda di ogni VM (hardware, pacchetti, note)
└── docs/                    # cheat sheet virsh, note sulle distro nuove
```

### Come sono fatti gli script di installazione

Tre livelli, dal generale al particolare:

1. **`scripts/lib/subiquity-install.sh`** — motore condiviso per tutte le VM basate
   su subiquity (Ubuntu, Lubuntu, flavor): scarica la ISO, chiede conferma se la VM
   esiste, crea il disco, inietta l'autoinstall nella ISO con `xorriso`, lancia
   `virt-install`, e opzionalmente orchestra il desktop al primo boot.
2. **Motori di famiglia** — `install-ubuntu-flavor.sh` (genera i blocchi YAML dei
   flavor) e `install-enterprise-linux.sh` (kickstart Rocky/Alma).
3. **Un file per VM** — `install-ubuntu24.04.sh`, `install-lubuntu22.04.sh`,
   `install-kubuntu26.04.sh`, ...: 15-30 righe di sola configurazione (nome VM,
   ISO, dimensione disco, RAM, template) e poi `subiquity_install` o `exec` del
   motore di famiglia. Per aggiungere una VM si copia uno di questi.

Debian, Silverblue, Tumbleweed, Arch e Windows hanno installer propri (preseed,
kickstart, AutoYaST, archiso, autounattend) e non passano dal motore subiquity.

---

## Avvio rapido

```bash
# 1. Clona il repo (in una cartella qualsiasi: gli script si orientano da soli)
git clone https://github.com/manzolo/virt-manager-lab.git kvm-lab
cd kvm-lab

# 2. Installa dipendenze e crea pool/rete libvirt (idempotente)
make setup

# 3. Verifica l'ambiente
make setup-check

# 4. Installa una VM (es. Lubuntu 24.04)
make lubuntu24
```

> **Dove stanno i dischi e le ISO**: in `$VM_BASE_DIR/storage/` con `VM_BASE_DIR`
> definito in `scripts/lab.env` (default `~/Workspaces/qemu`). Adattalo alla tua
> macchina **prima** di eseguire qualsiasi script. La posizione del repo invece
> non conta: ogni script individua la root del repo dalla propria posizione.

---

## Requisiti host

- Linux con KVM abilitato (`/dev/kvm` accessibile)
- `libvirt` + `libvirtd` in esecuzione
- `virt-install` (pacchetto `virtinst`)
- `virtiofsd` — richiesto per la cartella condivisa virtiofs nelle VM Linux
- `qemu-img`
- `xorriso` — necessario per costruire le ISO con autoinstall integrato
- `wget` — per scaricare le ISO se mancanti
- Pool libvirt `hdd` che punta alla cartella dove vuoi salvare i dischi

`make setup` installa automaticamente tutte le dipendenze sopra.

### Verifica rapida

```bash
kvm-ok                        # oppure: grep -c vmx /proc/cpuinfo
virsh pool-list --all         # deve comparire il pool "hdd"
which xorriso virt-install qemu-img virtiofsd
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

### Registro VM (`vms.tsv`)

[`vms.tsv`](vms.tsv) e' l'**unica fonte di verita'** dell'inventario del lab.
Una riga per VM, campi separati da TAB:

| Campo | Significato |
|--------|-------------|
| `id` | ID breve del Makefile (`make <id>`, `make start-<id>`, ...) |
| `vm` | nome del dominio libvirt (quello che vede `virsh`) |
| `script` | script di installazione, path relativo alla root |
| `family` | `linux` o `windows` — determina il flusso di test e2e |
| `agent` | `yes`/`no` — la VM espone il canale QEMU guest agent |
| `e2e` | `yes`/`no` — inclusa nei test end-to-end (se `no`, `note` = motivo) |
| `group` | raggruppamento mostrato da `make help` |
| `note` | descrizione libera |

Da questo file sono **generati**, senza liste duplicate da tenere allineate a mano:

- i target del Makefile (`make <id>`, `start-`, `shutdown-`, `clean-`, ...) e
  l'output di `make help`, `make list`, `make status`;
- `VMS` e `TEST_VMS`, usati da `make clean-all` e `make clean-test`;
- gli item dei test e2e in `scripts/test-linux.env` e `scripts/test-win.env`;
- la lista di script controllati dalla CI.

#### Aggiungere una distro

1. Scrivi lo script di installazione in `scripts/`.
2. Aggiungi **una riga** a `vms.tsv`.
3. `make check-registry` — valida id/nomi VM univoci, esistenza dello script,
   campi ammessi, e segnala se manca la scheda in `vms/`.

Non serve toccare il Makefile, gli `.env` dei test o la CI.

```bash
make check-registry        # valida il registro (girato anche in CI)
make list                  # ID, nome VM libvirt, famiglia, descrizione
```

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

Gli ID disponibili **non sono elencati qui**: sono definiti in
[`vms.tsv`](vms.tsv) e li stampa `make list` (oppure `make help`, che li
raggruppa per famiglia). Vedi [Registro VM](#registro-vm-vmstsv).

I profili `silverblue` (Fedora Silverblue immutabile, kickstart), `rocky9`,
`alma9`, `tumbleweed`, `arch` (Arch Linux, GNOME) e `niri` (Arch +
compositor Wayland niri + shell noctalia) sono installer piu' recenti: vedi
[vms/silverblue.md](vms/silverblue.md), [vms/rocky9.md](vms/rocky9.md),
[vms/alma9.md](vms/alma9.md), [vms/tumbleweed.md](vms/tumbleweed.md),
[vms/arch.md](vms/arch.md), [vms/niri.md](vms/niri.md)
e [docs/new-distros.md](docs/new-distros.md).

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

Questi profili usano lo stesso template (`unattended/ubuntu-flavor-autoinstall.yaml`)
e lo stesso motore (`scripts/install-ubuntu-flavor.sh`), e cambiano solo versione
Ubuntu, pacchetto desktop, display manager, Plymouth e risorse della VM.

Su 26.04 il desktop viene installato al primo boot dal servizio
`lab-desktop.service`, dopo l'installazione base. Questo evita i crash osservati
durante l'unpack dei desktop nell'ambiente live dell'installer 26.04, mantenendo
autologin, Plymouth e virtiofs come nei profili 24.04. Gli script 26.04
orchestrano automaticamente anche questo passaggio: attendono lo spegnimento
dell'installazione base, riavviano la VM e terminano solo quando il desktop e'
installato e il display manager e' attivo. Per disabilitare l'attesa:
`FIRSTBOOT_WAIT_DESKTOP=false make reinstall-kubuntu26`.

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

Credenziali default: utente **`manzolo`**, password **`manzolo`** — per cambiarle modifica solo `scripts/lab.env` (rigenera `VM_PASS_HASH` con `openssl passwd -6 "<nuova_password>"`). I file in `unattended/` sono template con placeholder e vengono materializzati a runtime dagli script.

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
| lubuntu26.04 | Lubuntu 26.04 LTS | LXQt, desktop installato al primo boot |
| kubuntu22.04 | Kubuntu 22.04 LTS | KDE Plasma, 4 GB RAM / 35 GB disco |
| xubuntu22.04 | Xubuntu 22.04 LTS | Xfce, 4 GB RAM / 30 GB disco |
| ubuntu-mate22.04 | Ubuntu MATE 22.04 LTS | MATE, 4 GB RAM / 30 GB disco |
| ubuntu-budgie22.04 | Ubuntu Budgie 22.04 LTS | Budgie, 4 GB RAM / 30 GB disco |
| kubuntu24.04 | Kubuntu 24.04 LTS | KDE Plasma, 4 GB RAM / 35 GB disco |
| xubuntu24.04 | Xubuntu 24.04 LTS | Xfce, 4 GB RAM / 30 GB disco |
| ubuntu-mate24.04 | Ubuntu MATE 24.04 LTS | MATE, 4 GB RAM / 30 GB disco |
| ubuntu-budgie24.04 | Ubuntu Budgie 24.04 LTS | Budgie, 4 GB RAM / 30 GB disco |
| kubuntu26.04 | Kubuntu 26.04 LTS | KDE Plasma, desktop installato al primo boot |
| xubuntu26.04 | Xubuntu 26.04 LTS | Xfce, desktop installato al primo boot |
| ubuntu-mate26.04 | Ubuntu MATE 26.04 LTS | MATE, desktop installato al primo boot |
| ubuntu-budgie26.04 | Ubuntu Budgie 26.04 LTS | Budgie, desktop installato al primo boot |
| silverblue | Fedora Silverblue 44 | GNOME immutabile (ostree), kickstart via OEMDRV |
| arch | Arch Linux | GNOME + GDM, install via archiso `script=` |
| niri | Arch + niri | compositor Wayland niri + shell noctalia (AUR), SDDM autologin |
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

## Test end-to-end (e2e)

Reinstalla le VM da zero, verifica che arrivino al desktop e produce un report HTML
con PASS/WARN/FAIL e screenshot di ognuna.

```bash
make test-all       # Linux + Windows, report unico (default PAR=2)
make test-linux     # solo VM Linux (default PAR=4)
make test-win       # solo VM Windows (default PAR=2)
```

- **Linux**: install → spegnimento → avvio → `qemu-guest-agent` verifica
  `graphical.target` + display-manager attivo → screenshot.
- **Windows**: install → attesa del guest-agent (OOBE/autologon + virtio-win-guest-tools)
  → verifica via `cmd.exe` → screenshot. Windows 7 (senza canale agent) è screenshot-only.
- Motore condiviso: `scripts/test-lib.sh`; parallelismo e timeout in
  `scripts/test-linux.env` / `scripts/test-win.env`. Le **liste di VM** non stanno
  li': sono derivate da [`vms.tsv`](vms.tsv) (colonna `e2e`). Il report si
  auto-aggiorna ogni 15s.

> Le VM con contratto non uniforme (es. Silverblue per via di SELinux sul guest-exec, e
> niri sperimentale) restano in `TEST_EXCLUDED_ITEMS`.

---

## Deploy su disco fisico — Virtual-to-Physical (V2P)

Scrive il disco di una VM (qcow2) su un **disco fisico reale**, per portare su hardware
una VM provata nel lab (es. niri+noctalia su `/dev/sda`).

```bash
make v2p VM=niri                 # selezione guidata del disco di destinazione
V2P_DRYRUN=1 bash scripts/v2p-deploy.sh niri   # anteprima, non scrive nulla
```

Operazione **distruttiva** (azzera il disco scelto) con salvaguardie: VM dev'essere
spenta, esclude il disco di sistema e i device con partizioni montate, richiede di
digitare il device + `CONFERMO`. Usa `qemu-img convert -O raw`. Le VM del lab bootano
in **UEFI**: avviare la macchina fisica in modalità UEFI.

---

## Cheat sheet virsh

Bignami a colori dei comandi `virsh` più usati del lab (avvio/stop, screenshot,
guest-agent, dischi/pool, snapshot, diagnostica, eliminazione sicura, virtiofs).

```bash
make cheatsheet     # rigenera docs/virsh-cheatsheet.pdf da docs/virsh-cheatsheet.html
```

Sorgente: [docs/virsh-cheatsheet.html](docs/virsh-cheatsheet.html) · PDF: `docs/virsh-cheatsheet.pdf`.

---

## Strategia ISO (nota tecnica)

Le ISO Ubuntu vengono modificate con `xorriso` usando `-indev/-outdev -boot_image any replay`.
Questo approccio preserva intatti El Torito, la partizione EFI appended e l'MBR dall'originale — al contrario di approcci basati su `-dev/-commit` o `isohybrid`, che rischiano di rompere il boot UEFI.

---

## Licenza

Uso personale / laboratorio. Adatta liberamente.
