# silverblue

## Identificazione

| Campo | Valore                                  |
|-------|-----------------------------------------|
| Nome  | silverblue                              |
| OS    | Fedora Linux 44 (Silverblue, immutabile ostree) |
| Stato | installata e validata a schermo ✓ (2026-06-02)  |

## Hardware

| Risorsa  | Valore                                   |
|----------|------------------------------------------|
| RAM      | 4 GB                                     |
| vCPU     | 2                                        |
| Machine  | q35                                     |
| Firmware | UEFI (OVMF; Secure Boot abilitato — Fedora usa shim firmato) |
| CPU mode | host-passthrough                        |
| Memory   | memfd + shared (richiesto da virtiofs)  |

## Storage

| Dispositivo | File                                                | Bus    | Formato | Opzioni       | Dim. |
|-------------|------------------------------------------------------|--------|---------|---------------|------|
| vda (disco) | `…/storage/hd/silverblue.qcow2`                      | virtio | qcow2   | discard=unmap | 40 GB|
| cdrom 1     | ISO Fedora Silverblue (installer)                    | sata   | raw     | —             | —    |
| cdrom 2     | `silverblue-oemdrv-ks.iso` (kickstart, label OEMDRV) | sata   | raw     | —             | —    |

## Rete / Video

| Componente | Valore                   |
|------------|--------------------------|
| NIC        | virtio su rete `default` |
| Video      | virtio · Display SPICE   |

## Cartella condivisa (virtiofs)

| Parametro    | Valore                                              |
|--------------|-----------------------------------------------------|
| Tag/target   | `shared`                                            |
| Mount guest  | `/mnt/shared` (→ `/var/mnt/shared` su ostree)       |
| Sorgente     | `…/storage/shared`                                  |
| Segnalibro   | "Shared" → `/mnt/shared` nel file manager           |

## Stato sistema

| Campo       | Valore                                       |
|-------------|----------------------------------------------|
| Desktop     | GNOME + GDM, **autologin** utente lab        |
| Hostname    | silverblue-lab                               |
| Browser     | Firefox (presente nella base Silverblue)     |
| guest-agent | qemu-guest-agent attivo (risponde a guest-ping) |
| SELinux     | enforcing                                    |

## Installazione (unattended)

- Script: `scripts/install-silverblue.sh` (Makefile: `make silverblue`)
- Meccanismo: **kickstart** consegnato ad Anaconda via volume etichettato **OEMDRV**
  (`fedora-silverblue.ks`); l'ISO Fedora originale non viene modificata. Il ref ostree
  viene ricavato dalla ISO (fallback `fedora/<VER>/x86_64/silverblue`). Boot dall'ISO via
  `--cdrom`; a fine install la VM si spegne e parte il primo boot (autologin GDM).
- Variabili: `FED_VER` (default 44), `FED_BUILD` (default 1.7), `FIRSTBOOT_AUTOSTART`.

## Note

- **Limite e2e**: SELinux confina il `guest-exec` del guest-agent → comandi come
  `systemctl`/`rpm` via agent risultano negati/vuoti. La verifica e2e standard (via
  agent) non è affidabile: Silverblue è validata **a schermo** (screenshot).
- Su ostree i pacchetti extra si layerano con `rpm-ostree` (applicati dopo un reboot).
