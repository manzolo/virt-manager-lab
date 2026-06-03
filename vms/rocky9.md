# Rocky Linux 9

| Campo | Valore |
| --- | --- |
| VM | rocky9 |
| Installer | Kickstart via ISO OEMDRV |
| Desktop | GNOME + GDM autologin |
| Disco | 40G qcow2 virtio |
| UEFI | si |
| Shared | virtiofs tag `shared` su `/mnt/shared` |

Uso:

```bash
make rocky9
```

Override principali:

```bash
EL_MAJOR=10 make rocky9
DISK_SIZE=60G make rocky9
```
