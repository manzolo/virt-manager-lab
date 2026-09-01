SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

.DEFAULT_GOAL := help

# =============================================================================
# Registro VM — UNICA fonte di verita'. Per aggiungere una VM: una riga in
# vms.tsv (piu' lo script di install). Non serve toccare questo Makefile.
# =============================================================================
REGISTRY ?= vms.tsv

ifeq ($(wildcard $(REGISTRY)),)
$(error Registro VM non trovato: $(REGISTRY))
endif

# Un record per VM: "id|vm|script|family|agent|e2e|group". Il campo 'note' ha
# spazi e al Makefile non serve, quindi viene scartato. Le righe dati sono
# quelle il cui primo campo inizia con [a-z0-9] (commenti e header iniziano con
# il carattere di commento).
RECORDS := $(shell awk -F'\t' '$$1 ~ /^[a-z0-9]/ && NF>=7 \
	{print $$1"|"$$2"|"$$3"|"$$4"|"$$5"|"$$6"|"$$7}' $(REGISTRY))

# $(1) e' il record con i campi separati da spazio. Nota: $(call) divide gli
# argomenti PRIMA di espanderli, quindi non si possono generare $(2),$(3)... da
# una sostituzione: i campi vanno letti con $(word N,...).
define REGISTER_VM
VM_$(word 1,$(1))     := $(word 2,$(1))
SCRIPT_$(word 1,$(1)) := $(word 3,$(1))
FAMILY_$(word 1,$(1)) := $(word 4,$(1))
AGENT_$(word 1,$(1))  := $(word 5,$(1))
E2E_$(word 1,$(1))    := $(word 6,$(1))
GROUP_$(word 1,$(1))  := $(word 7,$(1))
endef
$(foreach r,$(RECORDS),$(eval $(call REGISTER_VM,$(subst |, ,$(r)))))

IDS         := $(foreach r,$(RECORDS),$(firstword $(subst |, ,$(r))))
VMS         := $(strip $(foreach id,$(IDS),$(VM_$(id))))
WINDOWS_IDS := $(strip $(foreach id,$(IDS),$(if $(filter windows,$(FAMILY_$(id))),$(id))))
TEST_VMS    := $(strip $(foreach id,$(IDS),$(if $(filter yes,$(E2E_$(id))),$(VM_$(id)))))

# Deduplica preservando l'ordine del registro (a differenza di $(sort)).
uniq   = $(if $(1),$(firstword $(1)) $(call uniq,$(filter-out $(firstword $(1)),$(1))))
GROUPS = $(strip $(call uniq,$(foreach id,$(IDS),$(GROUP_$(id)))))
ids_in_group = $(strip $(foreach id,$(IDS),$(if $(filter $(1),$(GROUP_$(id))),$(id))))

.PHONY: help list status report cheatsheet v2p test-all test-linux test-win setup setup-check check-registry
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
		'PROFILI (generati da $(REGISTRY))'
	@$(foreach g,$(GROUPS),printf '  %-14s %s\n' '$(g):' '$(call ids_in_group,$(g))';)
	@printf '%s\n' \
		'' \
		'  make iso-<id>             Rigenera solo la ISO unattended (solo: $(WINDOWS_IDS))' \
		'' \
		'GESTIONE VM' \
		'  make status-<id>          Dettaglio libvirt della VM gestita' \
		'  make destroy-<id>         Spegnimento forzato' \
		'  make undefine-<id>        Rimuove definizione libvirt, non il disco' \
		'  make clean-<id>           Rimuove VM + suo disco qcow2 (non ISO/altri dischi)' \
		'  make clean-all            Pulisce TUTTE le VM gestite (VM+disco, con conferma)' \
		'  make clean-test           Pulisce solo le VM dei test e2e (con conferma)' \
		'  make report               Rigenera vm-report.html' \
		'  make cheatsheet           Rigenera docs/virsh-cheatsheet.pdf' \
		'  make check-registry       Valida $(REGISTRY) (script mancanti, id duplicati, schede)' \
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
	@printf '%-12s %-20s %-8s %s\n' 'ID' 'VM' 'FAMILY' 'NOTE'
	@awk -F'\t' '$$1 ~ /^[a-z0-9]/ {printf "%-12s %-20s %-8s %s\n", $$1, $$2, $$4, $$8}' $(REGISTRY)

status:
	virsh list --all
	@printf '\n%s\n' 'VM gestite dal registro ($(REGISTRY)):'
	@printf '%-12s %-20s %-10s %s\n' 'ID' 'VM' 'LibvirtId' 'Stato'
	@for row in $(foreach r,$(RECORDS),'$(r)'); do \
		make_id="$${row%%|*}"; rest="$${row#*|}"; vm="$${rest%%|*}"; \
		libvirt_id="$$(virsh domid "$$vm" 2>/dev/null | head -n 1 || true)"; \
		state="$$(virsh domstate "$$vm" 2>/dev/null | head -n 1 || true)"; \
		[[ -n "$$libvirt_id" ]] || libvirt_id='-'; \
		[[ -n "$$state" ]] || state='non definita'; \
		printf '%-12s %-20s %-10s %s\n' "$$make_id" "$$vm" "$$libvirt_id" "$$state"; \
	done

check-registry:
	VMLAB_REGISTRY="$(REGISTRY)" bash scripts/vms-registry.sh --check

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
# REINSTALLA tutte le VM con e2e=yes nel registro.
test-all:
	bash scripts/test-all.sh $(PAR)

# Test end-to-end delle VM Linux con e2e=yes (reinstall + verifica + report HTML).
# Parallelismo: make test-linux PAR=6  (default 4). REINSTALLA le VM coinvolte.
test-linux:
	bash scripts/test-linux.sh $(PAR)

# Test end-to-end delle VM Windows con e2e=yes (reinstall + verifica + report HTML).
# Parallelismo: make test-win PAR=1  (default 2). REINSTALLA le VM coinvolte.
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

$(foreach id,$(IDS),$(eval $(call INSTALL_TARGETS,$(id))))

# Pulizia di tutte le VM del registro (VM + disco qcow2 principale, MAI ISO/altri
# dischi). Chiede conferma perche' include anche le Windows (reinstall lunghe).
.PHONY: clean-all
clean-all:
	@echo "ATTENZIONE: rimuove definizione VM + disco qcow2 principale di TUTTE le VM del registro."
	@echo "  ISO e volumi in altri pool NON vengono toccati."
	@echo "  VM coinvolte: $(VMS)"
	@read -rp "Confermi la rimozione di tutte? [s/N] " a; \
	if [ "$$a" != "s" ] && [ "$$a" != "S" ]; then echo "Annullato."; exit 0; fi; \
	for vm in $(VMS); do bash scripts/clean-vm.sh "$$vm"; done

# Pulizia delle SOLE VM coperte dai test e2e (quelle con e2e=yes nel registro).
.PHONY: clean-test
clean-test:
	@echo "ATTENZIONE: rimuove definizione VM + disco qcow2 principale delle SOLE VM di test."
	@echo "  ISO e volumi in altri pool NON vengono toccati."
	@echo "  VM coinvolte: $(TEST_VMS)"
	@read -rp "Confermi la rimozione delle VM di test? [s/N] " a; \
	if [ "$$a" != "s" ] && [ "$$a" != "S" ]; then echo "Annullato."; exit 0; fi; \
	for vm in $(TEST_VMS); do bash scripts/clean-vm.sh "$$vm"; done
