import base64
import copy
import importlib.util
import os
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import bcrypt
import yaml

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("installer", ROOT / "scripts/install-network-vm.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
net = installer.net


class NetworkLabTest(unittest.TestCase):
    def setUp(self):
        self.p = net.profile()

    def test_lan_has_no_alternate_gateway_or_dhcp_server(self):
        root = net.network_xml(self.p)
        net.check_network(root, self.p)
        self.assertIsNone(root.find("forward"))
        self.assertIsNone(root.find(".//dhcp"))
        self.assertEqual(root.find("dns").get("enable"), "no")
        for extra in ('<forward mode="nat"/>', '<ip address="10.0.0.1"/>'):
            invalid = copy.deepcopy(root)
            invalid.append(ET.fromstring(extra))
            with self.assertRaises(ValueError):
                net.check_network(invalid, self.p)

    def test_does_not_adopt_malformed_or_dhcp_network(self):
        with self.assertRaises(ValueError):
            net.check_network(ET.fromstring("<network/>"), self.p)
        root = net.network_xml(self.p)
        ET.SubElement(root.find("ip"), "dhcp")
        with self.assertRaises(ValueError):
            net.check_network(root, self.p)

    def test_host_route_conflict_prevents_creation(self):
        with patch.object(net, "run", return_value='[{"dst":"192.168.0.0/24","dev":"eth0"}]'):
            with self.assertRaises(ValueError):
                net.check_routes(self.p)

    def test_firewall_rule_order_and_disabled_rule_survive_rendering(self):
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ, {
                "VM_USER": "tester", "VM_PASS": "special'$\\password", "VM_PASS_HASH": "$6$test"}):
            root = ET.fromstring(installer.pfsense_config(self.p, d))
        rules = root.findall("filter/rule")
        self.assertEqual(rules[0].findtext("type"), "block")
        self.assertEqual(rules[0].findtext("destination/address"), "192.168.1.50")
        self.assertEqual(rules[0].findtext("destination/port"), "22")
        self.assertIsNone(rules[0].find("disabled"))
        self.assertEqual(rules[1].findtext("source/address"), "192.168.0.220")
        self.assertIsNotNone(rules[1].find("disabled"))
        self.assertEqual(rules[2].findtext("type"), "pass")
        self.assertIsNone(root.find("dhcpd/lan/enable"))
        user = next(u for u in root.findall("system/user") if u.findtext("name") == "tester")
        self.assertTrue(bcrypt.checkpw(b"special'$\\password", user.findtext("bcrypt-hash").encode()))
        self.assertIsNone(root.find("cert"))

    def test_merge_retains_new_installation_accounts(self):
        with tempfile.TemporaryDirectory() as d:
            source, output = Path(d) / "base.xml", Path(d) / "out.xml"
            source.write_text('<pfsense><version>future</version><system><user><name>new-admin</name></user></system></pfsense>')
            net.merge_pfsense(source, output)
            root = ET.parse(output).getroot()
            self.assertEqual(root.findtext("system/user/name"), "new-admin")
            self.assertEqual(root.findtext("version"), "future")
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                net.merge_pfsense(source, output)

    def test_bootstrap_dhcp_is_off_and_local_dns_is_preserved(self):
        config = tomllib.loads(installer.pihole_toml(self.p))
        self.assertFalse(config["dhcp"]["active"])
        self.assertEqual(len(config["dns"]["hosts"]), 18)
        self.assertEqual(len(config["dns"]["cnameRecords"]), 3)
        self.assertIn("pfsense.qlan,firewall.qlan", config["dns"]["cnameRecords"])
        self.assertEqual(config["dhcp"]["router"], "192.168.0.1")

    def test_linux_credentials_and_static_route_are_parameterized(self):
        with patch.dict(os.environ, {"VM_USER": "tester", "VM_PASS": "some'password", "VM_PASS_HASH": "$6$test"}):
            config = yaml.safe_load(installer.ubuntu_config("pihole", self.p, "52:54:00:11:22:33"))["autoinstall"]
        self.assertEqual(config["identity"]["username"], "tester")
        self.assertEqual(config["identity"]["password"], "$6$test")
        files = {f["path"]: base64.b64decode(f["content"]).decode() for f in config["user-data"]["write_files"]}
        self.assertEqual(files["/root/kvm-lab/web-password"], "some'password")
        final = yaml.safe_load(files["/root/kvm-lab/lan.yaml"])["network"]["ethernets"]["enp1s0"]
        self.assertFalse(final["dhcp4"])
        self.assertEqual(final["routes"][0]["via"], self.p["pfsense"]["ip"])
        self.assertEqual(final["nameservers"]["addresses"], [self.p["pihole"]["ip"]])

    def test_preserves_lubuntu_static_address(self):
        config = yaml.safe_load(installer.final_netplan("lubuntu", self.p))["network"]
        self.assertEqual(config["renderer"], "NetworkManager")
        self.assertEqual(config["ethernets"]["enp1s0"]["addresses"], ["192.168.0.100/24"])

    def test_lubuntu_finalize_disables_networkd_wait_online(self):
        # Con renderer NetworkManager, systemd-networkd-wait-online non ha link da attendere
        # e allungherebbe ogni boot di 120 s (timeout): va disabilitato.
        script = installer.finalize_script("lubuntu", self.p)
        self.assertIn("systemctl disable systemd-networkd-wait-online.service", script)
        self.assertIn("/etc/netplan/01-lab.yaml", script)
        self.assertTrue(script.endswith("echo network-config-ready"))
        pihole = installer.finalize_script("pihole", self.p)
        self.assertNotIn("wait-online", pihole)
        self.assertIn("pihole-FTL --config dhcp.active", pihole)


if __name__ == "__main__":
    unittest.main()
