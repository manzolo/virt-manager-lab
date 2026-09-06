#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p /var/lib/kvm-lab
trap 'touch /var/lib/kvm-lab/failed' ERR
export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 /etc/pihole
install -m 0644 /root/kvm-lab/pihole.toml /etc/pihole/pihole.toml
install -m 0644 /root/kvm-lab/adlists.list /etc/pihole/adlists.list
# Il file TOML preconfigurato fa saltare tutti i dialoghi dell'installer v6.
curl --fail --location --retry 3 https://install.pi-hole.net -o /root/kvm-lab/basic-install.sh
bash /root/kvm-lab/basic-install.sh --unattended
pihole setpassword "$(cat /root/kvm-lab/web-password)"
rm -f /root/kvm-lab/web-password
systemctl is-active --quiet pihole-FTL
pihole version > /var/lib/kvm-lab/pihole-version.txt
touch /var/lib/kvm-lab/ready
