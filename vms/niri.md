# niri

## Identificazione

| Campo | Valore                                            |
|-------|---------------------------------------------------|
| Nome  | niri                                              |
| OS    | Arch Linux + **niri** (compositor Wayland scrollable-tiling) + **noctalia** (shell Quickshell) |
| Stato | first-draft sperimentale, deployata su disco fisico (V2P) 2026-06-02 |

## Hardware

| Risorsa  | Valore                                              |
|----------|-----------------------------------------------------|
| RAM      | 4 GB                                                |
| vCPU     | 4                                                   |
| Machine  | q35                                                |
| Firmware | UEFI (OVMF `OVMF_CODE_4M.fd`, **senza Secure Boot**) |
| CPU mode | host-passthrough                                   |
| Memory   | memfd + shared (richiesto da virtiofs)             |

## Storage

| Dispositivo | File                                | Bus    | Formato | Opzioni       | Dim. |
|-------------|--------------------------------------|--------|---------|---------------|------|
| vda (disco) | `…/storage/hd/niri.qcow2`            | virtio | qcow2   | discard=unmap | 40 GB|

## Rete / Video

| Componente | Valore                   |
|------------|--------------------------|
| NIC        | virtio su rete `default` |
| Video      | virtio · Display SPICE   |

## Cartella condivisa (virtiofs)

| Parametro   | Valore                          |
|-------------|---------------------------------|
| Tag/target  | `shared`                        |
| Mount guest | `/mnt/shared` (fstab, `nofail`) |
| Sorgente    | `…/storage/shared`              |

## Stato sistema

| Campo       | Valore                                                 |
|-------------|--------------------------------------------------------|
| Sessione    | **niri** (Wayland) via **SDDM** con autologin (`Session=niri`) |
| Shell       | noctalia (Quickshell) — buildata da AUR al primo boot  |
| Hostname    | arch-lab                                               |
| Tastiera    | IT · Browser: Firefox + `firefox-i18n-it`              |
| guest-agent | qemu-guest-agent attivo                                |

## Installazione (unattended)

- Script: `scripts/install-niri.sh` (Makefile: `make niri`) — wrapper di
  `install-arch.sh` con `ARCH_PROFILE=niri`.
- Base identica ad [arch.md](arch.md): bootstrap archiso + `pacstrap`. Profilo niri:
  pacchetti `niri sddm foot fuzzel …`, autologin SDDM sulla sessione `niri`.
- **noctalia** non è nei repo ufficiali → un servizio oneshot `niri-firstboot.service`
  (`scripts/assets/niri-firstboot.sh`) la builda da AUR (con `paru`) al primo boot.

## Deploy su hardware fisico (V2P)

Questa VM è stata scritta su un disco fisico con `make v2p` /
`scripts/v2p-deploy.sh` (`qemu-img convert -O raw`). Avviare la macchina reale in **UEFI**.

## Note

- ⚠️ Parte più sperimentale: la build AUR non presidiata di noctalia/quickshell è la
  più fragile. Lo screenshot SPICE di un compositor Wayland puro può risultare nero.
- Resta in `TEST_EXCLUDED_ITEMS` (vedi `scripts/test-linux.env`) finché non si stabilizza.
