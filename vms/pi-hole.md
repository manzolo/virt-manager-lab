# pi-hole

Installazione da zero verificata il 6 settembre 2026: Ubuntu Server 22.04.5,
Pi-hole Core 6.4.3, Web 6.6, FTL 6.7. 2 vCPU, 2 GB RAM, disco VirtIO da 20 GB,
BIOS/Q35, guest agent abilitato.

- Generazione: `make pihole` (richiede ISO Ubuntu Server e `make network-up`).
- Disco nuovo: `$VM_BASE_DIR/storage/hd/pi-hole-unattended.qcow2`.
- Hostname `qpi-hole`; NIC `enp1s0` su `lab-lan`.
- IP `192.168.0.10/24`; gateway `192.168.0.1` (pfSense).
- DNS upstream OpenDNS `208.67.222.222`, `208.67.220.220`.
- Recuperati 18 record locali, 3 CNAME e la lista StevenBlack.
- DHCP aggiunto: `.150`–`.199`, gateway `.1`, DNS `.10`, dominio `qlan`.
- GUI: http://192.168.0.10/admin/ (password `VM_PASS` di `lab.env`).
- Account Linux: `VM_USER` / `VM_PASS`, parametrizzati.
- Bootstrap: `/var/log/kvm-lab-pihole.log` nel guest.

La VM precedente usava Pi-hole v5, 1 GB RAM e DHCP disabilitato.
Il disco originale è conservato; il backup è stato eliminato su richiesta
dell'utente dopo l'approvazione della nuova VM.

Vedi [configurazioni recuperate e riproduzione](../docs/network-lab.md).
