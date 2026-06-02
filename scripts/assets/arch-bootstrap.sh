#!/usr/bin/env bash
# Bootstrap unattended Arch Linux — eseguito DENTRO il live archiso (via script=).
# Partiziona /dev/vda, pacstrap, configura utente/locale/DM, abilita guest-agent e
# virtiofs, poi spegne. Profilo: gnome (gdm) oppure niri (sddm + niri-session).
# Placeholder resi da install-arch.sh: __PROFILE__ __VM_USER__ __VM_PASS__ __VM_REALNAME__
#
# STATO: first-draft, da validare al primo run reale (vedi docs/new-distros.md).

set -euo pipefail
PROFILE="__PROFILE__"
USERNAME="__VM_USER__"
PASSWORD="__VM_PASS__"
REALNAME="__VM_REALNAME__"
DISK=/dev/vda
MEDIA=/run/archiso/bootmnt/arch-lab

# Sicurezza: gira solo nel live archiso.
[ -d /run/archiso ] || { echo "Non e' un ambiente archiso, esco."; exit 1; }

# L'autorun script= dell'archiso parte mentre pacman-init/keyring puo' essere
# ancora in corso: attendi che il sistema live sia pronto prima di pacstrap.
echo "[bootstrap] attendo che il live sia pronto (pacman-init/keyring)..."
systemctl is-system-running --wait 2>/dev/null || true

timedatectl set-ntp true 2>/dev/null || true

# --- partizionamento GPT/UEFI ---
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI  "$DISK"
sgdisk -n2:0:0     -t2:8300 -c2:root "$DISK"
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F  "${DISK}2"
mount "${DISK}2" /mnt
mount --mkdir "${DISK}1" /mnt/boot

# --- pacchetti ---
BASE="base linux linux-firmware sudo networkmanager qemu-guest-agent spice-vdagent grub efibootmgr git vim"
case "$PROFILE" in
  gnome) EXTRA="gnome gdm firefox firefox-i18n-it" ;;
  niri)  EXTRA="niri sddm foot fuzzel firefox firefox-i18n-it xwayland-satellite xdg-desktop-portal-gtk wl-clipboard base-devel" ;;
  *)     EXTRA="" ;;
esac
pacstrap -K /mnt $BASE $EXTRA

genfstab -U /mnt >> /mnt/etc/fstab
echo 'shared /mnt/shared virtiofs defaults,nofail 0 0' >> /mnt/etc/fstab

# --- configurazione base in chroot ---
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc || true
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
echo 'it_IT.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=it_IT.UTF-8' > /etc/locale.conf
echo 'KEYMAP=it' > /etc/vconsole.conf
# layout tastiera per GDM/console (X11)
mkdir -p /etc/X11/xorg.conf.d
printf 'Section "InputClass"\n  Identifier "system-keyboard"\n  MatchIsKeyboard "on"\n  Option "XkbLayout" "it"\nEndSection\n' > /etc/X11/xorg.conf.d/00-keyboard.conf
# layout IT anche nella sessione GNOME (Wayland usa input-sources, non xorg):
# default dconf di sistema per tutti gli utenti.
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
printf "[org/gnome/desktop/input-sources]\nsources=[('xkb','it')]\n" > /etc/dconf/db/local.d/00-input-sources
dconf update
echo arch-lab > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1  localhost arch-lab arch-lab.localdomain
::1        localhost arch-lab arch-lab.localdomain
EOF
useradd -m -G wheel -c "$REALNAME" "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
install -d -m0755 /mnt/shared
# segnalibro "Shared" -> /mnt/shared nel file manager dell'utente
install -d -o "$USERNAME" -g "$USERNAME" /home/$USERNAME/.config /home/$USERNAME/.config/gtk-3.0
echo 'file:///mnt/shared Shared' > /home/$USERNAME/.config/gtk-3.0/bookmarks
chown "$USERNAME:$USERNAME" /home/$USERNAME/.config/gtk-3.0/bookmarks
systemctl enable NetworkManager qemu-guest-agent
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
if [ "$PROFILE" = "niri" ]; then
  grep -q simpledrm_platform_driver_init /etc/default/grub || \
    sed -i 's#^GRUB_CMDLINE_LINUX_DEFAULT="#GRUB_CMDLINE_LINUX_DEFAULT="initcall_blacklist=simpledrm_platform_driver_init #' /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg
systemctl set-default graphical.target
CHROOT

# --- display-manager + autologin per profilo ---
if [ "$PROFILE" = "gnome" ]; then
  arch-chroot /mnt systemctl enable gdm
  install -d -m0755 /mnt/etc/gdm
  printf '[daemon]\nWaylandEnable=true\nAutomaticLoginEnable=True\nAutomaticLogin=%s\n' "$USERNAME" \
    > /mnt/etc/gdm/custom.conf
elif [ "$PROFILE" = "niri" ]; then
  arch-chroot /mnt systemctl enable sddm
  install -d -m0755 /mnt/etc/systemd/system/sddm.service.d
  cat > /mnt/etc/systemd/system/sddm.service.d/wait-firstboot.conf <<'EOF'
[Unit]
After=niri-firstboot.service
EOF
  install -d -m0755 /mnt/etc/sddm.conf.d
  # il pacchetto niri fornisce /usr/share/wayland-sessions/niri.desktop
  printf '[Autologin]\nUser=%s\nSession=niri\n' "$USERNAME" \
    > /mnt/etc/sddm.conf.d/autologin.conf
  # firstboot: build di noctalia (Quickshell) da AUR, una tantum
  if [ -f "$MEDIA/niri-firstboot.sh" ]; then
    install -m0755 "$MEDIA/niri-firstboot.sh" /mnt/usr/local/bin/niri-firstboot.sh
    sed -i "s|__VM""_USER__|$USERNAME|g" /mnt/usr/local/bin/niri-firstboot.sh
    cat > /mnt/etc/systemd/system/niri-firstboot.service <<EOF
[Unit]
Description=Lab: setup niri + noctalia (una tantum)
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/niri-firstboot-done
[Service]
Type=oneshot
ExecStart=/usr/local/bin/niri-firstboot.sh
[Install]
WantedBy=multi-user.target
EOF
    arch-chroot /mnt systemctl enable niri-firstboot.service
  fi
fi

sync
umount -R /mnt || true
poweroff
