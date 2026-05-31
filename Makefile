SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

.DEFAULT_GOAL := help

VMS := Debian13 ubuntu24.04 ubuntu26.04 Windows10 Windows11 Windows7U

SCRIPT_debian13 := scripts/install-debian13.sh
SCRIPT_ubuntu24 := scripts/install-ubuntu24.04.sh
SCRIPT_ubuntu26 := scripts/install-ubuntu26.04.sh
SCRIPT_win10 := scripts/win10/create_win10_vm.sh
SCRIPT_win11 := scripts/win11/create_win11_vm.sh
SCRIPT_win7u := scripts/win7u/create_win7u_vm.sh

VM_debian13 := Debian13
VM_ubuntu24 := ubuntu24.04
VM_ubuntu26 := ubuntu26.04
VM_win10 := Windows10
VM_win11 := Windows11
VM_win7u := Windows7U

WINDOWS_IDS := win10 win11 win7u

.PHONY: help list status report
help:
	@printf '%s\n' \
		'Gestione installazioni unattended' \
		'' \
		'Target installazione:' \
		'  make debian13 | ubuntu24 | ubuntu26 | win10 | win11 | win7u' \
		'  make install-<id>       Avvia lo script in modalita interattiva' \
		'  make reinstall-<id>     Risponde S allo script se la VM esiste gia' \
		'  make iso-<id>           Rigenera solo la ISO unattended (solo Windows)' \
		'' \
		'Target gestione VM:' \
		'  make status             Mostra tutte le VM libvirt' \
		'  make status-<id>        Mostra stato della VM' \
		'  make start-<id>         Avvia la VM' \
		'  make shutdown-<id>      Spegne ordinatamente la VM' \
		'  make destroy-<id>       Spegne forzatamente la VM' \
		'  make undefine-<id>      Rimuove la definizione libvirt, non il disco' \
		'' \
		'Target utili:' \
		'  make report             Rigenera vm-report.html' \
		'  make list               Lista ID e nomi VM gestiti'

list:
	@printf '%-10s %s\n' 'ID' 'VM'
	@printf '%-10s %s\n' 'debian13' '$(VM_debian13)'
	@printf '%-10s %s\n' 'ubuntu24' '$(VM_ubuntu24)'
	@printf '%-10s %s\n' 'ubuntu26' '$(VM_ubuntu26)'
	@printf '%-10s %s\n' 'win10' '$(VM_win10)'
	@printf '%-10s %s\n' 'win11' '$(VM_win11)'
	@printf '%-10s %s\n' 'win7u' '$(VM_win7u)'

status:
	virsh list --all

report:
	bash scripts/vm-report.sh vm-report.html

define INSTALL_TARGETS
.PHONY: $(1) install-$(1) reinstall-$(1) iso-$(1) status-$(1) start-$(1) shutdown-$(1) destroy-$(1) undefine-$(1)

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
endef

$(eval $(call INSTALL_TARGETS,debian13))
$(eval $(call INSTALL_TARGETS,ubuntu24))
$(eval $(call INSTALL_TARGETS,ubuntu26))
$(eval $(call INSTALL_TARGETS,win10))
$(eval $(call INSTALL_TARGETS,win11))
$(eval $(call INSTALL_TARGETS,win7u))
