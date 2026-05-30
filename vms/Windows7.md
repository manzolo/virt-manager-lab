# Windows7

## Identificazione

| Campo   | Valore                                   |
|---------|------------------------------------------|
| Nome    | Windows7                                 |
| UUID    | dd2e5bee-bfb2-4263-8bc4-9da4940ea7d1    |
| OS      | Windows 7                                |
| Stato   | terminato                                |

## Hardware

| Risorsa   | Valore                      |
|-----------|-----------------------------|
| RAM       | 4 GB (4194304 KiB)          |
| vCPU      | 2                           |
| Arch      | x86_64                      |
| Machine   | pc-q35-8.2                  |
| Firmware  | BIOS (boot dev='hd')        |
| CPU mode  | host-passthrough            |
| Clock     | localtime (Windows)         |
| HyperV    | relaxed, vapic, spinlocks   |

## Storage

| Dispositivo | File                                                         | Bus  | Formato | Dimensione |
|-------------|--------------------------------------------------------------|------|---------|------------|
| sda (disco) | `/home/manzolo/Workspaces/qemu/storage/hd/Windows7.qcow2`   | sata | qcow2   | 26 GB      |

> Nessun CDROM configurato.

## Rete

| NIC | MAC               | Modello | Rete    |
|-----|-------------------|---------|---------|
| 1   | 52:54:00:93:20:cc | e1000e  | default |

## Video & Audio

| Componente | Valore  |
|------------|---------|
| Video      | QXL     |
| Audio      | ich9    |
| Display    | SPICE   |

## Cartella condivisa

Nessuna.

## Stato sistema (rilevato offline via virt-inspector)

| Campo       | Valore                          |
|-------------|---------------------------------|
| OS rilevato | Windows 7 Ultimate              |
| Hostname    | Win7-PC                         |
| App rilevate| 38                              |

### Applicazioni installate

| Applicazione                     | Versione      |
|----------------------------------|---------------|
| 7-Zip                            | 16.04         |
| AutoIt v3                        | 3.3.18.0      |
| SciTE4AutoIt3                    | 15.920.938.0  |
| Microsoft Edge (legacy compat.)  | 109.0.1518.78 |
| Mozilla Firefox ESR (it, x86)    | 115.8.0       |
| Notepad++                        | 8.6           |
| SpiceGuestTools                  | 0.141         |
| Microsoft Office 2010 (hint)     | 11.0.6361.0   |
| .NET Framework 4.8               | vari          |
| Visual C++ Redistributable       | 2012/2013/2019|

> Hostname **Win7-PC** → configurata e usata.  
> **AutoIt + SciTE4AutoIt3** installati → uso per automazione/scripting.  
> Molti Visual C++ e .NET redistributable → suite software complessa installata.

## Note

- USB controller: ich9-ehci1 (USB 2.0 legacy)
- Watchdog: itco
- Memballoon: virtio
- Nessun QEMU guest agent Windows configurato
- **AutoIt installato** → usata per automazione
- **SpiceGuestTools** installato → integrazione clipboard/display SPICE attiva
