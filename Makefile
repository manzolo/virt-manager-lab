SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

.DEFAULT_GOAL := help

VMS := Debian13 ubuntu24.04 ubuntu26.04 lubuntu20.04 lubuntu22.04 lubuntu24.04 lubuntu26.04 kubuntu22.04 xubuntu22.04 ubuntu-mate22.04 ubuntu-budgie22.04 kubuntu24.04 xubuntu24.04 ubuntu-mate24.04 ubuntu-budgie24.04 kubuntu26.04 xubuntu26.04 ubuntu-mate26.04 ubuntu-budgie26.04 silverblue arch niri Windows10 Windows11 Windows7U

SCRIPT_debian13 := scripts/install-debian13.sh
SCRIPT_ubuntu24 := scripts/install-ubuntu24.04.sh
SCRIPT_ubuntu26 := scripts/install-ubuntu26.04.sh
SCRIPT_lubuntu20 := scripts/install-lubuntu20.04.sh
SCRIPT_lubuntu22 := scripts/install-lubuntu22.04.sh
SCRIPT_lubuntu24 := scripts/install-lubuntu24.04.sh
SCRIPT_lubuntu26 := scripts/install-lubuntu26.04.sh
SCRIPT_kubuntu22 := scripts/install-kubuntu22.04.sh
SCRIPT_xubuntu22 := scripts/install-xubuntu22.04.sh
SCRIPT_mate22 := scripts/install-mate22.04.sh
SCRIPT_budgie22 := scripts/install-budgie22.04.sh
SCRIPT_kubuntu24 := scripts/install-kubuntu24.04.sh
SCRIPT_xubuntu24 := scripts/install-xubuntu24.04.sh
SCRIPT_mate24 := scripts/install-mate24.04.sh
SCRIPT_budgie24 := scripts/install-budgie24.04.sh
SCRIPT_kubuntu26 := scripts/install-kubuntu26.04.sh
SCRIPT_xubuntu26 := scripts/install-xubuntu26.04.sh
SCRIPT_mate26 := scripts/install-mate26.04.sh
SCRIPT_budgie26 := scripts/install-budgie26.04.sh
SCRIPT_win10 := scripts/win10/create_win10_vm.sh
SCRIPT_win11 := scripts/win11/create_win11_vm.sh
SCRIPT_win7u := scripts/win7u/create_win7u_vm.sh
SCRIPT_silverblue := scripts/install-silverblue.sh
SCRIPT_arch := scripts/install-arch.sh
SCRIPT_niri := scripts/install-niri.sh

VM_debian13 := Debian13
VM_ubuntu24 := ubuntu24.04
VM_ubuntu26 := ubuntu26.04
VM_lubuntu20 := lubuntu20.04
VM_lubuntu22 := lubuntu22.04
VM_lubuntu24 := lubuntu24.04
VM_lubuntu26 := lubuntu26.04
VM_kubuntu22 := kubuntu22.04
VM_xubuntu22 := xubuntu22.04
VM_mate22 := ubuntu-mate22.04
VM_budgie22 := ubuntu-budgie22.04
VM_kubuntu24 := kubuntu24.04
VM_xubuntu24 := xubuntu24.04
VM_mate24 := ubuntu-mate24.04
VM_budgie24 := ubuntu-budgie24.04
VM_kubuntu26 := kubuntu26.04
VM_xubuntu26 := xubuntu26.04
VM_mate26 := ubuntu-mate26.04
VM_budgie26 := ubuntu-budgie26.04
VM_win10 := Windows10
VM_win11 := Windows11
VM_win7u := Windows7U
VM_silverblue := silverblue
VM_arch := arch
VM_niri := niri

WINDOWS_IDS := win10 win11 win7u

.PHONY: help list status report cheatsheet v2p test-all test-linux test-win setup setup-check
help:
	@printf '%s\n' \
		'virt-manager-lab - gestione VM unattended' \
		'' \
		'USO RAPIDO' \
		'  make setup                Installa dipendenze + pool/rete libvirt (idempotente)' \
		'  make setup-check          Verifica l'\''ambiente (sola lettura, exit !=0 se manca qualcosa)' \
		'  make list                 Mostra ID Makefile e nomi VM libvirt' \
		'  make status               Stato libvirt + mappa ID Makefile' \
		'  make <id>                 Installa/crea una VM, es. make win11' \
		'  make reinstall-<id>       Reinstalla rispondendo S se la VM esiste' \
		'  make start-<id>           Avvia una VM, es. make start-lubuntu24' \
		'  make shutdown-<id>        Spegne ordinatamente una VM' \
		'' \
		'PROFILI LINUX' \
		'  Debian:      debian13' \
		'  Ubuntu:      ubuntu24 ubuntu26' \
		'  Lubuntu:     lubuntu20 lubuntu22 lubuntu24 lubuntu26' \
		'  Kubuntu:     kubuntu22 kubuntu24 kubuntu26' \
		'  Xubuntu:     xubuntu22 xubuntu24 xubuntu26' \
		'  Ubuntu MATE: mate22 mate24 mate26' \
		'  Budgie:      budgie22 budgie24 budgie26' \
		'  Altri:       silverblue (Fedora immutabile) · arch · niri' \
		'' \
		'PROFILI WINDOWS' \
		'  win10 win11 win7u' \
		'  make iso-win11            Rigenera solo la ISO unattended Windows' \
		'' \
		'GESTIONE VM' \
		'  make status-<id>          Dettaglio libvirt della VM gestita' \
		'  make destroy-<id>         Spegnimento forzato' \
		'  make undefine-<id>        Rimuove definizione libvirt, non il disco' \
		'  make clean-<id>           Rimuove VM + suo disco qcow2 (non ISO/altri dischi)' \
		'  make all                  Pulisce TUTTE le VM gestite (VM+disco, con conferma)' \
		'  make report               Rigenera vm-report.html' \
		'  make cheatsheet           Rigenera docs/virsh-cheatsheet.pdf' \
		'  make v2p [VM=nome]        Scrive il disco di una VM su un disco FISICO (V2P, distruttivo)' \
		'  make test-all [PAR=N]     Test e2e Linux + Windows, report unico (reinstall+verifica)' \
		'  make test-linux [PAR=N]   Test e2e delle sole VM Linux' \
		'  make test-win [PAR=N]     Test e2e delle sole VM Windows' \
		'' \
		'NOTE' \
		'  <id> e uno degli ID mostrati da make list, es. win11 o xubuntu24.' \
		'  L ID numerico di virsh, es. 2, vale solo mentre la VM e accesa.' \
		'  make status-2 non esiste: usa virsh dominfo 2 se vuoi quel numero.'

list:
	@printf '%-10s %s\n' 'ID' 'VM'
	@printf '%-10s %s\n' 'debian13' '$(VM_debian13)'
	@printf '%-10s %s\n' 'ubuntu24' '$(VM_ubuntu24)'
	@printf '%-10s %s\n' 'ubuntu26' '$(VM_ubuntu26)'
	@printf '%-10s %s\n' 'lubuntu20' '$(VM_lubuntu20)'
	@printf '%-10s %s\n' 'lubuntu22' '$(VM_lubuntu22)'
	@printf '%-10s %s\n' 'lubuntu24' '$(VM_lubuntu24)'
	@printf '%-10s %s\n' 'lubuntu26' '$(VM_lubuntu26)'
	@printf '%-10s %s\n' 'kubuntu22' '$(VM_kubuntu22)'
	@printf '%-10s %s\n' 'xubuntu22' '$(VM_xubuntu22)'
	@printf '%-10s %s\n' 'mate22' '$(VM_mate22)'
	@printf '%-10s %s\n' 'budgie22' '$(VM_budgie22)'
	@printf '%-10s %s\n' 'kubuntu24' '$(VM_kubuntu24)'
	@printf '%-10s %s\n' 'xubuntu24' '$(VM_xubuntu24)'
	@printf '%-10s %s\n' 'mate24' '$(VM_mate24)'
	@printf '%-10s %s\n' 'budgie24' '$(VM_budgie24)'
	@printf '%-10s %s\n' 'kubuntu26' '$(VM_kubuntu26)'
	@printf '%-10s %s\n' 'xubuntu26' '$(VM_xubuntu26)'
	@printf '%-10s %s\n' 'mate26' '$(VM_mate26)'
	@printf '%-10s %s\n' 'budgie26' '$(VM_budgie26)'
	@printf '%-10s %s\n' 'win10' '$(VM_win10)'
	@printf '%-10s %s\n' 'win11' '$(VM_win11)'
	@printf '%-10s %s\n' 'win7u' '$(VM_win7u)'
	@printf '%-10s %s\n' 'silverblue' '$(VM_silverblue)'
	@printf '%-10s %s\n' 'arch' '$(VM_arch)'
	@printf '%-10s %s\n' 'niri' '$(VM_niri)'

status:
	virsh list --all
	@printf '\n%s\n' 'VM gestite dal Makefile:'
	@printf '%-10s %-14s %-10s %s\n' 'ID' 'VM' 'LibvirtId' 'Stato'
	@for row in \
		'debian13:$(VM_debian13)' \
		'ubuntu24:$(VM_ubuntu24)' \
		'ubuntu26:$(VM_ubuntu26)' \
		'lubuntu20:$(VM_lubuntu20)' \
		'lubuntu22:$(VM_lubuntu22)' \
		'lubuntu24:$(VM_lubuntu24)' \
		'lubuntu26:$(VM_lubuntu26)' \
		'kubuntu22:$(VM_kubuntu22)' \
		'xubuntu22:$(VM_xubuntu22)' \
		'mate22:$(VM_mate22)' \
		'budgie22:$(VM_budgie22)' \
		'kubuntu24:$(VM_kubuntu24)' \
		'xubuntu24:$(VM_xubuntu24)' \
		'mate24:$(VM_mate24)' \
		'budgie24:$(VM_budgie24)' \
		'kubuntu26:$(VM_kubuntu26)' \
		'xubuntu26:$(VM_xubuntu26)' \
		'mate26:$(VM_mate26)' \
		'budgie26:$(VM_budgie26)' \
		'win10:$(VM_win10)' \
		'win11:$(VM_win11)' \
		'win7u:$(VM_win7u)' \
		'silverblue:$(VM_silverblue)' \
		'arch:$(VM_arch)' \
		'niri:$(VM_niri)'; do \
		make_id="$${row%%:*}"; \
		vm="$${row#*:}"; \
		libvirt_id="$$(virsh domid "$$vm" 2>/dev/null | head -n 1 || true)"; \
		state="$$(virsh domstate "$$vm" 2>/dev/null | head -n 1 || true)"; \
		[[ -n "$$libvirt_id" ]] || libvirt_id='-'; \
		[[ -n "$$state" ]] || state='non definita'; \
		printf '%-10s %-14s %-10s %s\n' "$$make_id" "$$vm" "$$libvirt_id" "$$state"; \
	done

setup:
	bash scripts/setup.sh

setup-check:
	bash scripts/setup.sh --check

report:
	bash scripts/vm-report.sh vm-report.html

# Rigenera il PDF del cheat sheet virsh da docs/virsh-cheatsheet.html (Chrome headless).
cheatsheet:
	bash scripts/gen-cheatsheet.sh

# Scrive il disco di una VM su un disco FISICO reale (virtual->physical). DISTRUTTIVO:
# selezione guidata + conferme. Anteprima senza scrivere: make v2p V2P_DRYRUN=1
# Es.: make v2p VM=ubuntu26.04
v2p:
	bash scripts/v2p-deploy.sh $(VM)

# Test end-to-end completo (Linux + Windows) con un UNICO report HTML.
# Parallelismo: make test-all PAR=3  (default 2, perche' include le Windows).
# REINSTALLA tutte le VM elencate in test-linux.env e test-win.env.
test-all:
	bash scripts/test-all.sh $(PAR)

# Test end-to-end delle VM Linux in test-linux.env (reinstall + verifica + report HTML).
# Parallelismo: make test-linux PAR=6  (default 4). REINSTALLA le VM elencate.
test-linux:
	bash scripts/test-linux.sh $(PAR)

# Test end-to-end delle VM Windows in test-win.env (reinstall + verifica + report HTML).
# Parallelismo: make test-win PAR=1  (default 2). REINSTALLA le VM elencate.
test-win:
	bash scripts/test-win.sh $(PAR)

define INSTALL_TARGETS
.PHONY: $(1) install-$(1) reinstall-$(1) iso-$(1) status-$(1) start-$(1) shutdown-$(1) destroy-$(1) undefine-$(1) clean-$(1)

$(1): install-$(1)

install-$(1):
	bash $$(SCRIPT_$(1))

reinstall-$(1):
	printf 'S\n' | bash $$(SCRIPT_$(1))

iso-$(1):
	@if [[ " $$(WINDOWS_IDS) " != *" $(1) "* ]]; then \
		echo "Il target iso-$(1) e' disponibile solo per: $$(WINDOWS_IDS)"; \
		exit 2; \
	fi
	bash $$(SCRIPT_$(1)) --iso-only

status-$(1):
	virsh dominfo "$$(VM_$(1))"

start-$(1):
	virsh start "$$(VM_$(1))"

shutdown-$(1):
	virsh shutdown "$$(VM_$(1))"

destroy-$(1):
	virsh destroy "$$(VM_$(1))"

undefine-$(1):
	virsh undefine "$$(VM_$(1))" --snapshots-metadata --nvram || \
	virsh undefine "$$(VM_$(1))" --snapshots-metadata

clean-$(1):
	bash scripts/clean-vm.sh "$$(VM_$(1))"
endef

$(eval $(call INSTALL_TARGETS,debian13))
$(eval $(call INSTALL_TARGETS,ubuntu24))
$(eval $(call INSTALL_TARGETS,ubuntu26))
$(eval $(call INSTALL_TARGETS,lubuntu20))
$(eval $(call INSTALL_TARGETS,lubuntu22))
$(eval $(call INSTALL_TARGETS,lubuntu24))
$(eval $(call INSTALL_TARGETS,lubuntu26))
$(eval $(call INSTALL_TARGETS,kubuntu22))
$(eval $(call INSTALL_TARGETS,xubuntu22))
$(eval $(call INSTALL_TARGETS,mate22))
$(eval $(call INSTALL_TARGETS,budgie22))
$(eval $(call INSTALL_TARGETS,kubuntu24))
$(eval $(call INSTALL_TARGETS,xubuntu24))
$(eval $(call INSTALL_TARGETS,mate24))
$(eval $(call INSTALL_TARGETS,budgie24))
$(eval $(call INSTALL_TARGETS,kubuntu26))
$(eval $(call INSTALL_TARGETS,xubuntu26))
$(eval $(call INSTALL_TARGETS,mate26))
$(eval $(call INSTALL_TARGETS,budgie26))
$(eval $(call INSTALL_TARGETS,win10))
$(eval $(call INSTALL_TARGETS,win11))
$(eval $(call INSTALL_TARGETS,win7u))
$(eval $(call INSTALL_TARGETS,silverblue))
$(eval $(call INSTALL_TARGETS,arch))
$(eval $(call INSTALL_TARGETS,niri))

# Pulizia di tutte le VM gestite (VM + disco qcow2 principale, MAI ISO/altri dischi).
# Chiede conferma perche' include anche le VM Windows (reinstall lunghe).
.PHONY: clean-all all
clean-all all:
	@echo "ATTENZIONE: rimuove definizione VM + disco qcow2 principale di TUTTE le VM gestite."
	@echo "  ISO e volumi in altri pool NON vengono toccati."
	@echo "  VM coinvolte: $(VMS)"
	@read -rp "Confermi la rimozione di tutte? [s/N] " a; \
	if [ "$$a" != "s" ] && [ "$$a" != "S" ]; then echo "Annullato."; exit 0; fi; \
	for vm in $(VMS); do bash scripts/clean-vm.sh "$$vm"; done
