# virt-manager-lab

Script di installazione unattended e documentazione del mio lab personale di virtualizzazione KVM/QEMU su Linux.

Il repo raccoglie tutto quello che serve per ricreare da zero le VM del lab: script bash che costruiscono la ISO con autoinstall integrato, la creano e la avviano in un unico comando — senza toccare tastiera durante l'installazione.

---

## Cosa c'è nel repo

```
virt-manager-lab/
├── scripts/
│   ├── install-debian13.sh        # Debian 13 unattended (preseed)
│   ├── install-ubuntu24.04.sh     # Ubuntu 24.04 LTS unattended (autoinstall)
│   ├── install-ubuntu26.04.sh     # Ubuntu 26.04 LTS unattended (autoinstall)
│   ├── win10/
│   │   ├── create_win10_vm.sh     # Windows 10 con autounattend
│   │   └── autounattend.xml       # risposta automatica setup Win10
│   └── win11/
│       ├── create_win11_vm.sh     # Windows 11 con autounattend
│       └── autounattend.xml       # risposta automatica setup Win11
├── Debian13-preseed.cfg           # configurazione preseed Debian
├── ubuntu24.04-autoinstall.yaml   # cloud-init autoinstall Ubuntu 24.04
├── ubuntu26.04-autoinstall.yaml   # cloud-init autoinstall Ubuntu 26.04
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

---

## Cosa installano le VM Linux

Ogni script installa un sistema GNOME completo con questi pacchetti aggiuntivi:

| Pacchetto | Scopo |
|---|---|
| `bpfcc-tools`, `bpftrace`, `python3-bpfcc` | debugging/tracing kernel con eBPF |
| `openvpn`, `network-manager-openvpn*` | VPN integrata in GNOME |
| `qemu-guest-agent` | integrazione con l'host (snapshot, IP, ecc.) |
| `spice-vdagent` | copia/incolla e ridimensionamento schermo con SPICE |
| `bind9-dnsutils` | tool DNS (dig, nslookup) |
| `aspell` | correttore ortografico |
| `linux-generic-hwe-*` | kernel HWE più recente |

Credenziali default: utente **`manzolo`**, password **`manzolo`** — cambia l'hash nei YAML/preseed prima di usare in ambienti non isolati.

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
| Debian13 | Debian 13 | GNOME, Apache2, Docker CE |
| Windows10 | Windows 10 | autounattend, virtiofs, Firefox, Notepad++ |
| Windows11 | Windows 11 | autounattend, KMS generico |
| Windows7/XP/98/95/NT | Windows legacy | per test compatibilità |
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
