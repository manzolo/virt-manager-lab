# Windows11

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows11                                |
| UUID    | a212f607-4234-4ac5-b749-497d69964ebb    |
| OS      | Windows 11                               |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                                          |
|-----------|-------------------------------------------------|
| RAM       | 8 GB (8388608 KiB)                              |
| vCPU      | 4                                               |
| Arch      | x86_64                                          |
| Machine   | pc-q35-8.2                                      |
| Firmware  | EFI + Secure Boot (enrolled keys)               |
| NVRAM     | `/var/lib/libvirt/qemu/nvram/Windows11_VARS.fd` |
| CPU mode  | host-passthrough                                |
| Clock     | localtime (Windows)                             |
| TPM       | tpm-crb emulato v2.0                            |
| HyperV    | relaxed, vapic, spinlocks                       |

## Storage

| Dispositivo | File                                                         | Bus  | Formato | Opzioni       | Dimensione |
|-------------|--------------------------------------------------------------|------|---------|---------------|------------|
| sda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/Windows11.qcow2`  | sata | qcow2   | discard=unmap | 65 GB      |
| sdb (cdrom) | —                                                            | sata | raw     | —             | —          |

> Il disco usa bus **sata** (non virtio), probabilmente per compatibilità con il driver di installazione.

## Rete

| NIC | MAC               | Modello | Rete    | Stato |
|-----|-------------------|---------|---------|-------|
| 1   | 52:54:00:ad:d0:98 | e1000e  | default | up    |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato a runtime — screenshot)

| Campo       | Valore                                                      |
|-------------|-------------------------------------------------------------|
| OS rilevato | Windows 11 (italiano)                                       |
| Hostname    | non assegnato — OOBE non completata                         |
| App rilevate| nessuna — setup mai terminato                               |

**Schermata osservata al boot:**
- **OOBE** (Out-Of-Box Experience): "Assegnare un nome per il dispositivo"
- Primo step della configurazione guidata post-installazione
- Il setup iniziale non è mai stato completato
- Nessun utente creato, nessuna app installata

> **Installazione incompleta**: Windows 11 è stato installato ma l'OOBE non è mai stato terminato.  
> 65 GB occupati sul disco perché il setup espande i file di sistema, non per software aggiuntivo.  
> virt-inspector non riusciva perché il disco era in uno stato di setup non standard.

## Note

- Watchdog: itco
- Memballoon: virtio
- `discard=unmap` sul disco (TRIM abilitato)
- Nessun QEMU guest agent Windows configurato
- **OOBE non completata**: nessun utente configurato, nessun software
- **ELIMINATA il 2026-05-29** — OOBE incompleta, 65 GB recuperati
