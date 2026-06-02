# Ampliamento parco VM — Arch, Fedora Silverblue, niri+noctalia

Branch: `feat/fleet-arch-fedora-niri`.

Obiettivo: aggiungere tre nuove VM al flusso unattended/e2e esistente, sullo stesso
contratto delle Linux attuali:

> install non presidiato → la VM si spegne → `virsh start` → `qemu-guest-agent`
> risponde → `graphical.target` + `display-manager.service` attivi → screenshot.

Per restare dentro questo contratto **senza modificare il motore e2e** servono in ogni
guest: `qemu-guest-agent` abilitato, un **display-manager** (gdm/sddm), **autologin**,
e il mount virtiofs su `/mnt/shared`.

---

## 1. Fedora Silverblue (GNOME, immutabile) — confidenza ALTA

- **Meccanismo**: Anaconda **kickstart**. Consegna via volume etichettato `OEMDRV`
  (Anaconda carica in automatico `ks.cfg` da una media con quel label): si costruisce
  una ISO minuscola `OEMDRV` con `ks.cfg` e la si attacca come secondo cdrom. L'ISO
  Fedora originale resta intatta.
- **Display-manager**: `gdm` (presente di base) + autologin in `%post`.
- **Punti da validare al primo run**:
  - riga `ostreesetup`/`ostreecontainer` **version-specific** (ref `fedora/<VER>/x86_64/silverblue`).
    Il template usa `FED_VER` (default 41) — verificare che combaci con la ISO scaricata.
  - `qemu-guest-agent`: su ostree i pacchetti si *layerano* con `rpm-ostree` e si
    applicano **dopo** un reboot. Se non è nell'immagine base, il primo boot post-install
    potrebbe risultare WARN (agent assente) finché il layer non è attivo. Mitigazione nel
    template: layering in `%post` + un reboot extra gestito via `firstboot`.

## 2. Arch Linux (archinstall) — confidenza MEDIA

- **Meccanismo**: `archinstall --config user_configuration.json --creds credentials.json --silent`.
  L'ISO Arch non esegue script da sola: si usa la feature archiso **`script=`** (il live
  esegue lo script indicato dal parametro di boot `script=`). Si remastera l'ISO
  (estrai→inietta `automated.sh` + i json→ricostruisci, come per Debian) e si imposta
  `script=` nella entry di boot.
- **Desktop/DM**: profilo `gnome` → `gdm` (per restare nel contratto). Pacchetti:
  `qemu-guest-agent`, `gnome`, `gdm`.
- **Punti da validare**:
  - **schema JSON di archinstall cambia tra versioni**: la config va verificata contro
    la versione di `archinstall` sulla ISO del mese.
  - meccanismo `script=`: path esatto (`/run/archiso/bootmnt/...`) e cmdline.
  - autologin gdm + virtiofs via `custom-commands`/`%post` equivalenti.

## 3. niri + noctalia (su base Arch) — confidenza BASSA (sperimentale)

- niri è un **compositor** Wayland scrollable-tiling (in repo `extra`); **noctalia** è una
  shell su **Quickshell**, non pacchettizzata nei repo ufficiali → va da **AUR/git**.
- **Strategia**: stesso installer Arch, profilo *minimal* + pacchetti `niri sddm
  qemu-guest-agent`, sessione Wayland `niri-session` esposta a **sddm** con **autologin**
  (così `display-manager.service` esiste e il contratto e2e regge). noctalia +
  dipendenze (quickshell) installate al **primo boot** via servizio oneshot
  `niri-firstboot.service` che builda da AUR con un helper (`paru`/`yay`) come utente.
- **Punti da validare** (i più incerti):
  - build AUR non presidiata (quickshell/noctalia) → tempi lunghi, possibili rotture.
  - sessione niri sotto sddm + autologin Wayland.
  - lo screenshot SPICE di un compositor Wayland puro può risultare nero: eventualmente
    accettare WARN basato su screenshot.

---

## Stato implementazione

| VM         | script                         | template                     | stato        |
|------------|--------------------------------|------------------------------|--------------|
| silverblue | scripts/install-silverblue.sh  | fedora-silverblue.ks         | first-draft  |
| arch       | scripts/install-arch.sh        | arch-archinstall.json        | first-draft  |
| niri       | scripts/install-niri.sh        | arch-niri.json + asset       | first-draft  |

**Tutti i draft vanno validati con un run reale** (download ISO + install), non eseguibile
finché è in corso il test e2e. Procedura per ciascuno:

```bash
make arch          # o silverblue / niri  → scarica ISO, installa, si spegne
virsh start <VM>   # boot
# verifica: guest-ping, graphical.target, display-manager, /mnt/shared
make test-linux PAR=1   # quando inseriti in test-linux.env
```
