# pfSense

Installazione da zero verificata il 6 settembre 2026: pfSense CE 2.7.2,
BIOS, ZFS, 2 vCPU, 2 GB RAM, disco VirtIO da 20 GB.

- Generazione: `make pfsense` (richiede l'ISO locale e `make network-up`).
- Disco nuovo: `$VM_BASE_DIR/storage/hd/pfSense-unattended.qcow2`.
- WAN `vtnet0`: DHCP sulla rete libvirt `default`.
- LAN `vtnet1`: `192.168.0.1/24` sulla rete isolata `lab-lan`.
- NAT automatico; DHCP pfSense disabilitato; DNS di sistema Pi-hole `.10`.
- Regola attiva: blocca TCP verso `192.168.1.50:22` dalla LAN.
- Regola disattivata conservata: blocca TCP da `192.168.0.220`.
- GUI: http://192.168.0.1 (utente `VM_USER`, password `VM_PASS` di `lab.env`).
- Account integrato `admin` conservato, password `VM_PASS`.
- Nessun guest agent; console SPICE e log seriale.

La vecchia VM aveva 1 GB RAM/1 vCPU ed entrambe le NIC su `default`.
Il disco originale è conservato; il backup è stato eliminato su richiesta
dell'utente dopo l'approvazione della nuova VM.

Vedi [configurazioni recuperate e riproduzione](../docs/network-lab.md).
