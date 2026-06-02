# Fedora Silverblue — kickstart unattended per QEMU/KVM
# Consegnato ad Anaconda via volume etichettato OEMDRV (file ks.cfg).
# Placeholder __VM_*__ resi da render_template (lab.env); __OSTREE_REF__ dallo
# script install-silverblue.sh.

text
keyboard --xlayouts='it'
lang it_IT.UTF-8
timezone Europe/Rome --utc
rootpw --lock
user --name=__VM_USER__ --groups=wheel --password=__VM_PASS_HASH__ --iscrypted --gecos="__VM_REALNAME__"
firstboot --disable
selinux --enforcing
network --bootproto=dhcp --device=link --activate --hostname=silverblue-lab
zerombr
clearpart --all --initlabel
autopart --noswap
bootloader --location=mbr --timeout=2

# Sorgente ostree dall'ISO offline. Il ref e' version-specific (vedi docs/new-distros.md).
ostreesetup --osname="fedora" --remote="fedora" --url="file:///ostree/repo" --ref="__OSTREE_REF__" --nogpg

%post --erroronfail
# --- autologin GDM ---
install -d -m0755 /etc/gdm
cat > /etc/gdm/custom.conf <<EOF
[daemon]
WaylandEnable=true
AutomaticLoginEnable=True
AutomaticLogin=__VM_USER__
EOF

# --- cartella condivisa virtiofs (tag 'shared') ---
install -d -m0755 /mnt/shared
echo 'shared /mnt/shared virtiofs defaults,nofail 0 0' >> /etc/fstab

# --- target grafico + display-manager ---
systemctl set-default graphical.target
systemctl enable gdm.service

# --- qemu-guest-agent: su ostree va layerato e applicato dopo un reboot ---
# Un servizio oneshot al primo boot installa l'agente e riavvia una volta sola.
cat > /etc/systemd/system/lab-layer.service <<'EOF'
[Unit]
Description=Lab: layer qemu-guest-agent/spice-vdagent e reboot (una tantum)
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/lab-layered
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/rpm-ostree install --idempotent --allow-inactive qemu-guest-agent spice-vdagent
ExecStartPost=/usr/bin/touch /var/lib/lab-layered
ExecStartPost=/usr/bin/systemctl disable lab-layer.service
ExecStartPost=/usr/bin/systemctl reboot
[Install]
WantedBy=multi-user.target
EOF
systemctl enable lab-layer.service
%end

poweroff
