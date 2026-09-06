#!/usr/bin/env python3
"""Installa pfSense, Pi-hole e Lubuntu su dischi NUOVI, senza usare i backup."""

import argparse
import base64
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import shutil
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET

import yaml

SPEC = importlib.util.spec_from_file_location("lab_network", Path(__file__).with_name("lab-network.py"))
net = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(net)
DATA = net.DATA


def credentials():
    user = os.environ.get("VM_USER", "")
    password = os.environ.get("VM_PASS", "")
    password_hash = os.environ.get("VM_PASS_HASH", "")
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", user) or not password or not password_hash:
        raise ValueError("Configurare VM_USER, VM_PASS e VM_PASS_HASH in scripts/lab.env")
    return user, password, password_hash


def write(path, content, mode=0o600):
    if path.exists():
        path.chmod(mode)
    path.write_text(content)
    path.chmod(mode)


def final_netplan(role, p):
    return yaml.safe_dump({"network": {"version": 2,
        "renderer": "NetworkManager" if role == "lubuntu" else "networkd",
        "ethernets": {"enp1s0": {"dhcp4": False, "dhcp6": False,
            "addresses": [p[role]["ip"] + "/" + str(ipaddress.ip_network(p['lan']['subnet']).prefixlen)],
            "routes": [{"to": "default", "via": p["pfsense"]["ip"]}],
            "nameservers": {"addresses": [p["pihole"]["ip"]], "search": [p["domain"]]}}}}}, sort_keys=False)


def pihole_toml(p):
    hosts = (DATA / "pihole-custom.list").read_text().splitlines()
    cnames = [line.removeprefix("cname=") for line in (DATA / "pihole-cname.conf").read_text().splitlines()]
    d = p["dhcp"]
    return f'''# Configurazione Pi-hole v6; DHCP attivato solo dopo il passaggio sulla LAN.
[dns]
upstreams = {json.dumps(p['pihole']['upstream'])}
hosts = {json.dumps(hosts)}
cnameRecords = {json.dumps(cnames)}
interface = "enp1s0"
listeningMode = "LOCAL"
domainNeeded = true
bogusPriv = true
queryLogging = true
[dns.domain]
name = "{p['domain']}"
[dns.cache]
size = 10000
[dhcp]
active = false
start = "{d['start']}"
end = "{d['end']}"
router = "{p['pfsense']['ip']}"
netmask = "{ipaddress.ip_network(p['lan']['subnet']).netmask}"
leaseTime = "{d['lease_hours']}h"
ipv6 = false
[misc]
privacylevel = 0
'''


def cloud_file(path, content, permissions="0600"):
    return {"path": path, "permissions": permissions, "encoding": "b64",
            "content": base64.b64encode(content.encode()).decode()}


def ubuntu_config(role, p, mac):
    user, password, password_hash = credentials()
    ai = {"version": 1, "locale": "it_IT.UTF-8", "keyboard": {"layout": "it"},
          "identity": {"hostname": "qpi-hole" if role == "pihole" else "lubuntu",
                       "username": user, "password": password_hash,
                       "realname": os.environ.get("VM_REALNAME", user)},
          "network": {"version": 2, "ethernets": {"enp1s0": {
              "match": {"macaddress": mac}, "set-name": "enp1s0", "dhcp4": True}}},
          "storage": {"layout": {"name": "direct"}},
          "ssh": {"install-server": False},
          "packages": ["qemu-guest-agent", "curl", "ca-certificates", "dnsutils"],
          "late-commands": ["curtin in-target -- systemctl enable qemu-guest-agent"],
          "shutdown": "poweroff"}
    files = [cloud_file("/root/kvm-lab/lan.yaml", final_netplan(role, p))]
    if role == "pihole":
        files += [cloud_file("/root/kvm-lab/pihole.toml", pihole_toml(p)),
                  cloud_file("/root/kvm-lab/adlists.list", (DATA / "pihole-adlists.list").read_text()),
                  cloud_file("/root/kvm-lab/web-password", password),
                  cloud_file("/root/kvm-lab/firstboot.sh", (DATA / "pihole-firstboot.sh").read_text(), "0700")]
        commands = [["bash", "-c", "bash /root/kvm-lab/firstboot.sh > /var/log/kvm-lab-pihole.log 2>&1"]]
    else:
        ai["packages"] += ["lubuntu-desktop", "spice-vdagent", "arc-theme"]
        ai["late-commands"] += ["curtin in-target -- systemctl set-default graphical.target",
                                "curtin in-target -- systemctl enable sddm"]
        files.append(cloud_file("/etc/sddm.conf.d/kvm-lab-autologin.conf",
                                f"[Autologin]\nUser={user}\nSession=Lubuntu\n"))
        commands = [["bash", "-c", "mkdir -p /var/lib/kvm-lab; touch /var/lib/kvm-lab/ready"]]
    ai["user-data"] = {"write_files": files, "runcmd": commands}
    return "#cloud-config\n" + yaml.safe_dump({"autoinstall": ai}, sort_keys=False)


def build_ubuntu(role, p, mac, original, iso, tmp):
    data, meta, grub = (Path(tmp) / f for f in ("user-data", "meta-data", "grub.cfg"))
    write(data, ubuntu_config(role, p, mac))
    write(meta, "")
    write(grub, """set default=0
set timeout=2
menuentry 'KVM Lab unattended' {
    linux /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/ fsck.mode=skip ---
    initrd /casper/initrd
}
""")
    net.run("xorriso", "-indev", str(original), "-outdev", str(iso), "-boot_image", "any", "replay",
            "-map", str(data), "/user-data", "-map", str(meta), "/meta-data",
            "-map", str(grub), "/boot/grub/grub.cfg", "-commit", "-eject", "all")


def pfsense_config(p, tmp):
    import bcrypt
    user, password, _ = credentials()
    base = Path(tmp) / "base.xml"
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    write(base, (DATA / "pfsense-base.xml").read_text().replace("__PFSENSE_PASSWORD_HASH__", hashed))
    output = Path(tmp) / "config.xml"
    net.merge_pfsense(base, output)
    root = ET.parse(output).getroot()
    system = root.find("system")
    if user != "admin":
        account = ET.SubElement(system, "user")
        for key, value in {"name": user, "descr": "Amministratore laboratorio", "scope": "user",
                           "uid": "2000", "groupname": "admins", "bcrypt-hash": hashed,
                           "priv": "user-shell-access"}.items():
            ET.SubElement(account, key).text = value
        for group in system.findall("group"):
            if group.findtext("name") in ("admins", "all"):
                ET.SubElement(group, "member").text = "2000"
        system.find("nextuid").text = "2001"
    # VirtIO: opzione raccomandata da Netgate per il traffico host/guest.
    ET.SubElement(system, "disablechecksumoffloading")
    ET.SubElement(system, "enableserial")
    ET.SubElement(system, "serialspeed").text = "115200"
    write(output, net.xml_text(root))
    return output.read_text()


def build_pfsense(p, original, iso, tmp):
    extracted = Path(tmp) / "rc.original"
    scripted = Path(tmp) / "bsdinstall-script"
    net.run("xorriso", "-osirrox", "on", "-indev", str(original),
            "-extract", "/etc/rc.local", str(extracted),
            "-extract", "/usr/libexec/bsdinstall/script", str(scripted))
    if "bsdinstall script /etc/installerconfig" not in extracted.read_text():
        raise ValueError("ISO incompatibile: questo profilo richiede l'installer offline pfSense CE 2.7.2")
    config = Path(tmp) / "installerconfig"
    write(config, (DATA / "pfsense-installerconfig").read_text().replace("__PFSENSE_CONFIG__", pfsense_config(p, tmp)))
    rc = Path(tmp) / "rc.local"
    write(rc, (DATA / "pfsense-rc.local").read_text(), 0o755)
    # ZFS non ha mount ordinari in fstab: umount -a puo' restituire 1 anche
    # quando non resta nulla da smontare. L'export del pool seguente e' vincolante.
    script = scripted.read_text()
    needle = 'bsdinstall umount\nif [ "$ZFSBOOT_DISKS" ]; then'
    if needle not in script:
        raise ValueError("Versione bsdinstall inattesa: controllare il passaggio ZFS di unmount")
    write(scripted, script.replace(needle, 'bsdinstall umount || [ -n "$ZFSBOOT_DISKS" ]\nif [ "$ZFSBOOT_DISKS" ]; then'), 0o755)
    # FreeBSD ha immagini El Torito nascoste: il replay xorriso le scarta.
    # L'aggiornamento in-place di una COPIA mantiene gli extent di boot originali.
    net.run("cp", str(original), str(iso))
    net.run("growisofs", "-M", str(iso), "-d", "-l", "-r", "-V", "PFSENSE", "-graft-points",
            f"/etc/installerconfig={config}", f"/etc/rc.local={rc}",
            f"/usr/libexec/bsdinstall/script={scripted}")


def wait_stopped(name, timeout=7200):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if net.virsh("domstate", name).strip() == "shut off":
            return
        time.sleep(10)
    raise TimeoutError(f"Timeout spegnimento {name}: controllare console/installer")


def guest_exec(name, script, timeout=30):
    def agent(payload):
        return json.loads(subprocess.check_output(
            ["virsh", "--connect", net.URI, "qemu-agent-command", name, json.dumps(payload)],
            text=True, stderr=subprocess.DEVNULL))
    payload = {"execute": "guest-exec", "arguments": {
        "path": "/bin/bash", "arg": ["-c", script], "capture-output": True}}
    started = agent(payload)
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        payload = {"execute": "guest-exec-status", "arguments": {"pid": started["return"]["pid"]}}
        status = agent(payload)["return"]
        if status.get("exited"):
            out = base64.b64decode(status.get("out-data", "")).decode(errors="replace")
            out += base64.b64decode(status.get("err-data", "")).decode(errors="replace")
            return status.get("exitcode", 1), out
        time.sleep(1)
    raise TimeoutError(f"Guest-exec non concluso per {name}")


def finalize_script(role, p):
    """Script eseguito nel guest al primo avvio, via guest agent, prima del collegamento alla LAN."""
    script = ("set -e; rm -f /etc/netplan/*.yaml; "
              "install -m 0600 /root/kvm-lab/lan.yaml /etc/netplan/01-lab.yaml; "
              "printf 'network: {config: disabled}\\n' > /etc/cloud/cloud.cfg.d/99-kvm-lab-network.cfg; ")
    if role == "pihole":
        script += f"systemctl stop pihole-FTL; pihole-FTL --config dhcp.active {str(p['dhcp']['enabled']).lower()}; "
    else:
        # lan.yaml passa a renderer NetworkManager: networkd non gestisce piu' nessun link, ma il suo
        # wait-online (abilitato dalla base Ubuntu Server) resterebbe attivo e, senza link da attendere,
        # bloccherebbe il boot per 120 s fino al timeout. Lo si disabilita insieme a networkd.
        script += ("systemctl disable systemd-networkd-wait-online.service "
                   "systemd-networkd.service systemd-networkd.socket; ")
    return script + "echo network-config-ready"


def wait_ready(name, timeout=3600):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            code, _ = guest_exec(name, "test ! -f /var/lib/kvm-lab/failed || exit 42; test -f /var/lib/kvm-lab/ready")
            if code == 42:
                raise ValueError(f"Bootstrap {name} fallito: /var/log/kvm-lab-pihole.log nel guest")
            if code == 0:
                return
        except subprocess.CalledProcessError:
            pass
        time.sleep(10)
    raise TimeoutError(f"Timeout bootstrap di {name}; controllare cloud-init e la console")


def connect_lan(name, p, tmp):
    root = ET.fromstring(net.virsh("dumpxml", name, "--inactive"))
    root.find("devices/interface/source").attrib = {"network": p["lan"]["name"]}
    for cd in root.findall("devices/disk[@device='cdrom']"):
        for source in cd.findall("source"):
            cd.remove(source)
    path = Path(tmp) / "lan-domain.xml"
    write(path, net.xml_text(root))
    net.virsh("define", str(path), "--validate")


def install(role, iso_only=False):
    p = net.profile()
    credentials()
    base = Path(os.environ["VM_BASE_DIR"]) / "storage"
    name = p[role]["name"]
    disk = base / "hd" / f"{name}-unattended.qcow2"
    iso = base / "Iso/Distro" / f"{name}-network-autoinstall.iso"
    original = Path(os.environ.get("PFSENSE_ISO", str(base / "Iso/Distro/pfSense-CE-2.7.2-RELEASE-amd64.iso"))) if role == "pfsense" else base / "Iso/Distro/ubuntu-22.04.5-live-server-amd64.iso"
    if not original.is_file():
        raise ValueError(f"ISO originale mancante: {original}")
    if not iso_only:
        if name in net.virsh("list", "--all", "--name").splitlines() or disk.exists():
            raise ValueError(f"VM/disco {name} gia' esistente. Nessuna sovrascrittura: backup e pulizia espliciti prima di reinstallare")
        net.check_network(ET.fromstring(net.virsh("net-dumpxml", p["lan"]["name"])), p)
        active = net.virsh("net-list", "--name").splitlines()
        if p["lan"]["name"] not in active or p["wan"] not in active:
            raise ValueError("Reti non attive: make network-up")
    mac = "52:54:00:" + ":".join(f"{b:02x}" for b in secrets.token_bytes(3))
    with tempfile.TemporaryDirectory(prefix="kvm-lab-install-") as tmp:
        temp_iso = Path(tmp) / "autoinstall.iso"
        if role == "pfsense":
            build_pfsense(p, original, temp_iso, tmp)
        else:
            build_ubuntu(role, p, mac, original, temp_iso, tmp)
        iso.parent.mkdir(parents=True, exist_ok=True)
        # Rigenera le ISO obsolete, ma mai un supporto collegato a una VM.
        if iso.exists():
            for vm in net.virsh("list", "--all", "--name").splitlines():
                if not vm:
                    continue
                definition = ET.fromstring(net.virsh("dumpxml", vm, "--inactive"))
                if any(Path(src.get("file", "/")).resolve() == iso.resolve()
                       for src in definition.findall("devices/disk/source")):
                    raise ValueError(f"ISO ancora collegata a {vm}: {iso}")
        with tempfile.NamedTemporaryFile(prefix=".network-iso-", dir=iso.parent, delete=False) as pending:
            pending_path = Path(pending.name)
        try:
            shutil.copyfile(temp_iso, pending_path)
            pending_path.chmod(0o600)
            os.replace(pending_path, iso)
        finally:
            pending_path.unlink(missing_ok=True)
        print(f"ISO unattended pronta: {iso}", flush=True)
        if iso_only:
            return
        disk.parent.mkdir(parents=True, exist_ok=True)
        net.run("qemu-img", "create", "-f", "qcow2", str(disk), "30G" if role == "lubuntu" else "20G")
        args = ["virt-install", "--connect", net.URI, "--name", name,
                "--memory", "2048", "--vcpus", "2", "--machine", "pc" if role == "pfsense" else "q35",
                "--cpu", "host-passthrough", "--os-variant", "freebsd14.0" if role == "pfsense" else "ubuntu22.04",
                "--disk", f"path={disk},bus=virtio,format=qcow2", "--cdrom", str(iso),
                "--network", f"network={p['wan']},model=virtio,mac={mac}",
                "--graphics", "spice,listen=127.0.0.1", "--video", "qxl",
                "--boot", "hd,cdrom", "--noautoconsole", "--noreboot"]
        serial = base / "hd" / f"{name}-install.serial.log"
        if role == "pfsense":
            args += ["--network", f"network={p['lan']['name']},model=virtio",
                     "--serial", f"file,path={serial}"]
        else:
            args += ["--channel", "unix,target.type=virtio,target.name=org.qemu.guest_agent.0"]
        subprocess.run(args, check=True)
        print(f"Installazione {name} su disco vuoto in corso...", flush=True)
        wait_stopped(name)
        if role == "pfsense":
            try:
                serial_output = serial.read_text(errors="replace")
            except PermissionError:
                serial_output = net.run("sudo", "-n", "cat", str(serial))
            if "KVM_LAB_INSTALL_OK" not in serial_output:
                raise ValueError(f"Installazione pfSense non confermata; vedere {serial}")
            print("pfSense installato. Avvio del firewall...", flush=True)
            net.virsh("start", name)
            return
        net.virsh("start", name)
        print(f"Primo avvio {name}: applicazione configurazione...", flush=True)
        wait_ready(name)
        code, output = guest_exec(name, finalize_script(role, p))
        if code:
            raise ValueError(f"Configurazione finale {name} fallita: {output}")
        net.virsh("shutdown", name)
        wait_stopped(name, 300)
        connect_lan(name, p, tmp)
        net.virsh("start", name)
        print(f"{name} installata e collegata a {p['lan']['name']} ({p[role]['ip']}).", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("role", choices=("pfsense", "pihole", "lubuntu"))
    parser.add_argument("--iso-only", action="store_true")
    opts = parser.parse_args()
    try:
        install(opts.role, opts.iso_only)
    except (ValueError, OSError, TimeoutError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"ERRORE: {exc}") from exc
