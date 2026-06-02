# arch

## Identificazione

| Campo | Valore                              |
|-------|-------------------------------------|
| Nome  | arch                                |
| OS    | Arch Linux (rolling)                |
| Stato | installata e validata ✓ (2026-06-02)|

## Hardware

| Risorsa  | Valore                                                   |
|----------|----------------------------------------------------------|
| RAM      | 4 GB                                                     |
| vCPU     | 4                                                        |
| Machine  | q35                                                     |
| Firmware | UEFI (OVMF `OVMF_CODE_4M.fd`, **senza Secure Boot**)     |
| CPU mode | host-passthrough                                        |
| Memory   | memfd + shared (richiesto da virtiofs)                  |

> niri usa lo stesso installer con profilo `niri` (vedi [niri.md](niri.md)). Il
> Secure Boot è disabilitato perché GRUB/systemd-boot di Arch non sono firmati.

## Storage

| Dispositivo | File                                                      | Bus    | Formato | Opzioni       | Dim. |
|-------------|-----------------------------------------------------------|--------|---------|---------------|------|
| vda (disco) | `…/storage/hd/arch.qcow2`                                 | virtio | qcow2   | discard=unmap | 40 GB|
| cdrom       | install ISO (`arch-auto.iso`) — **espulso dopo l'install**| sata   | raw     | —             | —    |

## Rete / Video

| Componente | Valore                          |
|------------|---------------------------------|
| NIC        | virtio su rete `default`        |
| Video      | virtio · Display SPICE          |

## Cartella condivisa (virtiofs)

| Parametro    | Valore                                    |
|--------------|-------------------------------------------|
| Tag/target   | `shared`                                  |
| Mount guest  | `/mnt/shared` (fstab, `nofail`)           |
| Sorgente     | `…/storage/shared`                        |
| Segnalibro   | "Shared" → `/mnt/shared` nel file manager |

## Stato sistema

| Campo       | Valore                                 |
|-------------|----------------------------------------|
| Desktop     | GNOME + GDM, **autologin** utente lab  |
| Kernel      | linux (rolling, es. 7.0.10-arch1-1)    |
| Hostname    | arch-lab                               |
| Tastiera    | IT (console `vconsole` + GNOME via dconf + X11 `00-keyboard.conf`) |
| Browser     | Firefox + `firefox-i18n-it`            |
| guest-agent | qemu-guest-agent attivo                |

## Installazione (unattended)

- Script: `scripts/install-arch.sh` (Makefile: `make arch`)
- Meccanismo: ISO archiso con cartella `arch-lab/` iniettata; boot diretto del kernel
  via `virt-install --location … --extra-args "… script=…/arch-lab/bootstrap.sh"`
  (autorun archiso `script=`). Il bootstrap `scripts/assets/arch-bootstrap.sh`
  partiziona, `pacstrap` (base + GNOME + GDM + Firefox + qemu-guest-agent),
  configura locale/tastiera IT, `/etc/hosts`, autologin, virtiofs, poi spegne.

## Note

- `/etc/hosts` mappa l'hostname al loopback (necessario: senza, Firefox dava
  "Profile Missing" al primo avvio perché non risolveva l'hostname).
- Dopo l'install la VM è riconfigurata per il boot da disco (niente kernel diretto).
