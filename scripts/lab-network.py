#!/usr/bin/env python3
"""Backup delle appliance e gestione della LAN isolata del laboratorio.
"""

import argparse
import copy
from datetime import datetime, timezone
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import tempfile
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "network-lab"
URI = "qemu:///system"


def run(*args):
    return subprocess.check_output(args, text=True, env={**os.environ, "LC_ALL": "C"})


def virsh(*args):
    return run("virsh", "--connect", URI, *args)


def digest(path):
    checksum = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def backup(p):
    roles = ("pfsense", "pihole", "lubuntu")
    originals = {}
    for role in roles:
        name = p[role]["source"]
        require_stopped(name)
        root = ET.fromstring(virsh("dumpxml", name, "--inactive"))
        disks = root.findall("devices/disk[@device='disk']")
        if len(disks) != 1 or root.find("os/nvram") is not None:
            raise ValueError(f"Backup {name}: attesi un disco e firmware BIOS")
        disk = Path(disks[0].find("source").get("file"))
        info = json.loads(run("qemu-img", "info", "--output=json", str(disk)))
        if info.get("format") != "qcow2" or info.get("backing-filename"):
            raise ValueError(f"Backup {name}: serve un qcow2 completo senza backing file")
        originals[role] = (root, disk)
    base = Path(os.environ.get("VM_BASE_DIR", str(Path.home() / "Workspaces/qemu")))
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = base / "storage/backups/network-lab" / (stamp + "-" + secrets.token_hex(3))
    dest.mkdir(mode=0o700, parents=True)
    manifest = {"created_utc": stamp, "uri": URI, "vms": {}}
    for role, (root, disk) in originals.items():
        name = p[role]["source"]
        require_stopped(name)
        print(f"Backup {name}: copia del disco, inclusi snapshot interni...", flush=True)
        target = dest / (role + ".qcow2")
        run("cp", "--reflink=auto", "--sparse=always", str(disk), str(target))
        target.chmod(0o600)
        xml = dest / (role + ".xml")
        xml.write_text(xml_text(root))
        xml.chmod(0o600)
        snapshots = []
        for i, snapshot in enumerate(virsh("snapshot-list", name, "--name").splitlines()):
            if not snapshot:
                continue
            snapfile = dest / f"{role}-snapshot-{i}.xml"
            snapfile.write_text(virsh("snapshot-dumpxml", name, snapshot))
            snapfile.chmod(0o600)
            snapshots.append(snapfile.name)
        print(f"Backup {name}: controllo qcow2 e verifica SHA-256 sorgente/copia...", flush=True)
        run("qemu-img", "check", "-f", "qcow2", str(target))
        checksum = digest(target)
        if checksum != digest(disk):
            raise ValueError(f"Backup {name}: checksum diverso, backup NON completo in {dest}")
        require_stopped(name)
        manifest["vms"][role] = {"source": name, "disk": target.name, "xml": xml.name,
                                 "sha256": checksum, "xml_sha256": digest(xml), "snapshots": snapshots}
    for role in roles:
        require_stopped(p[role]["source"])
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (dest / "manifest.json").chmod(0o600)
    print(f"Backup completo e verificato: {dest}", flush=True)


def profile():
    p = json.loads((DATA / "profile.json").read_text())
    net = ipaddress.ip_network(p["lan"]["subnet"])
    reserved = [p["lan"]["host"], p["pfsense"]["ip"], p["pihole"]["ip"]]
    if len(set(reserved)) != len(reserved):
        raise ValueError("Indirizzi host/firewall/Pi-hole duplicati")
    for addr in reserved + [p["dhcp"]["start"], p["dhcp"]["end"]]:
        ip = ipaddress.ip_address(addr)
        if ip not in net or ip in (net.network_address, net.broadcast_address):
            raise ValueError(f"Indirizzo non utilizzabile nella LAN: {addr}")
    low, high = (ipaddress.ip_address(p["dhcp"][k]) for k in ("start", "end"))
    if low > high:
        raise ValueError("Intervallo DHCP invertito")
    static = reserved + [line.split()[0] for line in (DATA / "pihole-custom.list").read_text().splitlines() if line.strip()]
    if any(low <= ipaddress.ip_address(addr) <= high for addr in static):
        raise ValueError("Il pool DHCP si sovrappone agli indirizzi statici")
    # Indirizzamento condiviso dalla configurazione pfSense e dai guest Linux.
    fw = ET.parse(DATA / "pfsense-network.xml").getroot()
    if fw.findtext("interfaces/lan/ipaddr") != p["pfsense"]["ip"] or int(fw.findtext("interfaces/lan/subnet")) != net.prefixlen:
        raise ValueError("Profilo e configurazione pfSense non concordano")
    return p


def network_xml(p):
    root = ET.Element("network")
    ET.SubElement(root, "name").text = p["lan"]["name"]
    ET.SubElement(root, "bridge", name=p["lan"]["bridge"], stp="on", delay="0")
    ET.SubElement(root, "dns", enable="no")
    ET.SubElement(root, "ip", address=p["lan"]["host"], prefix=str(ipaddress.ip_network(p["lan"]["subnet"]).prefixlen))
    return root


def xml_text(root):
    ET.indent(root)
    return ET.tostring(root, encoding="unicode") + "\n"


def check_network(root, p):
    ip = root.find("ip")
    if (root.find("forward") is not None or root.find(".//dhcp") is not None
            or root.find("dns") is None or root.find("dns").get("enable") != "no"
            or root.find("bridge") is None or root.find("bridge").get("name") != p["lan"]["bridge"]
            or len(root.findall("ip")) != 1 or ip is None or ip.get("address") != p["lan"]["host"]):
        raise ValueError("La rete esistente non corrisponde alla LAN isolata attesa; nessuna modifica eseguita")
    mask = ip.get("prefix") or ip.get("netmask")
    if ipaddress.ip_network(f"{ip.get('address')}/{mask}", strict=False) != ipaddress.ip_network(p["lan"]["subnet"]):
        raise ValueError("Subnet della rete esistente diversa dal profilo")


def check_routes(p):
    net = ipaddress.ip_network(p["lan"]["subnet"])
    for route in json.loads(run("ip", "-j", "-4", "route", "show", "table", "all")):
        dst = route.get("dst", "default")
        if dst == "default" or route.get("dev") == p["lan"]["bridge"]:
            continue
        if net.overlaps(ipaddress.ip_network(dst, strict=False)):
            raise ValueError(f"LAN in conflitto con la route host {dst} su {route.get('dev')}; adattare il profilo e gli IP guest prima di creare la rete")


def network_up(p):
    names = virsh("net-list", "--all", "--name").splitlines()
    check_routes(p)
    name = p["lan"]["name"]
    if name in names:
        check_network(ET.fromstring(virsh("net-dumpxml", name)), p)
    else:
        with tempfile.TemporaryDirectory(prefix="kvm-lab-net-") as tmp:
            path = Path(tmp) / "network.xml"
            path.write_text(xml_text(network_xml(p)))
            virsh("net-define", str(path))
    if name not in virsh("net-list", "--name").splitlines():
        virsh("net-start", name)
    virsh("net-autostart", name)
    print(f"Rete {name} pronta: niente NAT, DHCP o DNS libvirt sulla LAN.")


def require_stopped(name):
    if virsh("domstate", name).strip() != "shut off":
        raise ValueError(f"La VM {name} deve essere spenta")


def attach(vm, p, apply):
    protected = {p[role][key] for role in ("pfsense", "pihole") for key in ("name", "source")}
    if vm in protected:
        raise ValueError("Usare il generatore delle appliance, non il collegamento client")
    require_stopped(vm)
    root = ET.fromstring(virsh("dumpxml", vm, "--inactive"))
    nics = root.findall("devices/interface")
    if len(nics) != 1 or nics[0].get("type") != "network":
        raise ValueError("Il collegamento automatico richiede una VM con una sola NIC di tipo network")
    nic = nics[0]
    previous = nic.find("source").get("network")
    print(f"{vm}: {previous} -> {p['lan']['name']}; IP guest via DHCP o statico nella LAN")
    print(f"Gateway {p['pfsense']['ip']}, DNS {p['pihole']['ip']}. Nessuna modifica automatica nel guest.")
    if not apply or previous == p["lan"]["name"]:
        return
    check_network(ET.fromstring(virsh("net-dumpxml", p["lan"]["name"])), p)
    backup_dir = ROOT / ".local" / "network-backups"
    backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    safe_name = re.sub(r"[^a-zA-Z0-9_.-]", "_", vm)
    backup = backup_dir / f"{safe_name}-{uuid.uuid4().hex}.xml"
    with backup.open("x", opener=lambda path, flags: os.open(path, flags, 0o600)) as f:
        f.write(xml_text(root))
    nic.find("source").attrib = {"network": p["lan"]["name"]}
    for el in nic.findall("target"):
        nic.remove(el)
    with tempfile.TemporaryDirectory(prefix="kvm-lab-attach-") as tmp:
        path = Path(tmp) / "domain.xml"
        path.write_text(xml_text(root))
        virsh("define", str(path), "--validate")
    print(f"Backup per ripristino (a VM spenta): virsh -c {URI} define {shlex.quote(str(backup))}")


def merge_pfsense(base, output):
    root = ET.parse(base).getroot()
    if root.tag != "pfsense" or root.find("system") is None:
        raise ValueError("Serve un backup completo della nuova installazione pfSense")
    captured = ET.parse(DATA / "pfsense-network.xml").getroot()
    for section in captured:
        if section.tag == "system":
            system = root.find("system")
            for key in {el.tag for el in section} | {"dnsallowoverride"}:
                for el in system.findall(key):
                    system.remove(el)
            for el in section:
                system.append(copy.deepcopy(el))
        else:
            for el in root.findall(section.tag):
                root.remove(el)
            root.append(copy.deepcopy(section))
    # output contiene le credenziali del backup fornito; mai sovrascriverlo.
    with open(output, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as f:
        f.write(xml_text(root))
    print(f"Configurazione pronta per il ripristino pfSense: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("plan")
    sub.add_parser("up")
    sub.add_parser("backup")
    ap = sub.add_parser("attach")
    ap.add_argument("vm")
    ap.add_argument("--apply", action="store_true")
    mp = sub.add_parser("pfsense-config")
    mp.add_argument("--base", required=True, type=Path)
    mp.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    p = profile()
    if args.command == "plan":
        print(f"Internet -> {p['wan']} (NAT libvirt) -> {p['pfsense']['name']} -> {p['lan']['name']} -> client scelti")
        print(f"Gateway {p['pfsense']['ip']}; Pi-hole DNS {p['pihole']['ip']}; host {p['lan']['host']}")
        print(f"DHCP Pi-hole: {p['dhcp']}; originariamente spento su entrambe le appliance")
        print(xml_text(network_xml(p)))
    elif args.command == "up":
        network_up(p)
    elif args.command == "backup":
        backup(p)
    elif args.command == "attach":
        attach(args.vm, p, args.apply)
    else:
        merge_pfsense(args.base, args.output)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, ET.ParseError) as exc:
        raise SystemExit(f"ERRORE: {exc}") from exc
