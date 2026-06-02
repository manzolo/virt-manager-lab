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
  gnome) EXTRA="gnome gdm" ;;
  niri)  EXTRA="niri sddm foot fuzzel xdg-desktop-portal-gtk wl-clipboard base-devel" ;;
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
echo arch-lab > /etc/hostname
useradd -m -G wheel -c "$REALNAME" "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
install -d -m0755 /mnt/shared
systemctl enable NetworkManager qemu-guest-agent
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
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
  install -d -m0755 /mnt/etc/sddm.conf.d
  # il pacchetto niri fornisce /usr/share/wayland-sessions/niri.desktop
  printf '[Autologin]\nUser=%s\nSession=niri\n' "$USERNAME" \
    > /mnt/etc/sddm.conf.d/autologin.conf
  # firstboot: build di noctalia (Quickshell) da AUR, una tantum
  if [ -f "$MEDIA/niri-firstboot.sh" ]; then
    install -m0755 "$MEDIA/niri-firstboot.sh" /mnt/usr/local/bin/niri-firstboot.sh
    sed -i "s|__VM_USER__|$USERNAME|g" /mnt/usr/local/bin/niri-firstboot.sh
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
