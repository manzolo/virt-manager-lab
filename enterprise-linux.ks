# Rocky/AlmaLinux - kickstart unattended per QEMU/KVM
# Placeholder __VM_*__ resi da render_template (scripts/lab.env).

text
keyboard --xlayouts='it'
lang it_IT.UTF-8
timezone Europe/Rome --utc
rootpw --lock
user --name=__VM_USER__ --groups=wheel --password=__VM_PASS_HASH__ --iscrypted --gecos="__VM_REALNAME__"
firstboot --disable
selinux --enforcing
firewall --enabled --service=ssh
network --bootproto=dhcp --device=link --activate --hostname=__EL_HOSTNAME__
url --url="__EL_REPO_URL__"
zerombr
clearpart --all --initlabel
autopart --type=lvm --fstype=xfs --noswap
bootloader --location=mbr --timeout=2
reboot --eject

%packages
@^graphical-server-environment
@guest-agents
@standard
qemu-guest-agent
spice-vdagent
git
curl
wget
vim-enhanced
%end

%post --erroronfail
systemctl set-default graphical.target
systemctl enable gdm.service
systemctl enable qemu-guest-agent.service
# Abilita guest-exec (disabilitato di default su RHEL per sicurezza, necessario per e2e test)
sed -i 's/^BLACKLIST_RPC=.*/BLACKLIST_RPC=/' /etc/sysconfig/qemu-ga 2>/dev/null || true

install -d -m0755 /etc/gdm
cat > /etc/gdm/custom.conf <<EOF
[daemon]
WaylandEnable=true
AutomaticLoginEnable=True
AutomaticLogin=__VM_USER__
EOF
restorecon -Rv /etc/gdm

install -d -m0755 /mnt/shared
echo 'shared /mnt/shared virtiofs defaults,nofail 0 0' >> /etc/fstab

install -d -o __VM_USER__ -g __VM_USER__ /home/__VM_USER__/.config/gtk-3.0
echo 'file:///mnt/shared Shared' > /home/__VM_USER__/.config/gtk-3.0/bookmarks
chown -R __VM_USER__:__VM_USER__ /home/__VM_USER__/.config
%end
