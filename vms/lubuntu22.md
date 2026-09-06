# lubuntu22

Client del laboratorio reinstallato da zero il 6 settembre 2026:
Ubuntu Server 22.04.5 + `lubuntu-desktop`, BIOS/Q35, 2 vCPU, 2 GB RAM,
disco VirtIO da 30 GB, guest agent e Spice abilitati.

- Generazione: `make lab-lubuntu22`.
- Il target preesistente `make lubuntu22` crea invece `lubuntu22.04`.
- Disco nuovo: `$VM_BASE_DIR/storage/hd/lubuntu22-unattended.qcow2`.
- Hostname `lubuntu`; NIC `enp1s0` sulla rete `lab-lan`.
- IP statico originale conservato: `192.168.0.100/24`.
- Gateway: `192.168.0.1` (pfSense).
- DNS: `192.168.0.10` (Pi-hole).
- Utente e autologin: `VM_USER`; password `VM_PASS`, da `scripts/lab.env`.
- Nessuna cartella condivisa aggiunta.
- `systemd-networkd` e `systemd-networkd-wait-online` disabilitati dall'installer:
  con renderer NetworkManager allungavano ogni boot di 120 s. Boot misurato: 6,7 s.

Il profilo NetworkManager originale confermava gateway pfSense e DNS Pi-hole;
la NIC libvirt era collegata a `default`. Il disco originale è conservato;
il backup è stato eliminato su richiesta dell'utente dopo l'approvazione della
nuova VM. I file personali precedenti non vengono copiati sulla VM nuova.

Vedi [topologia e procedure](../docs/network-lab.md).
