# X670 SD boot

This boot path uses a removable microSD card and leaves Android's internal UFS
and `userdata` partition alone.

The card layout is GPT with a 1 GiB FAT32 partition named `SCORPION_BOOT` and
a 16 GiB HFS+ partition named `iosroot`. Put the XNU shim boot image at
`SCORPION_BOOT:/scorpion-boot.img`. U-Boot loads that Android boot image from
FAT and starts its shim using its retained bootloader FDT; the shim starts XNU.
XNU initializes MSDC1 and mounts the named HFS+ partition read-only with
`rd=sdroot0` (the driver defaults to
partition name `iosroot`).

## Save XNU logs on the SCORPION FAT volume

Before booting, create a preallocated `XNU.LOG` file in the FAT partition's
root directory from PowerShell:

```powershell
.\tools\prepare-sd-log.ps1 -Drive D:
```

Use the drive letter currently assigned to the SCORPION volume. The file is
4,198,400 bytes (4 KiB header plus 4 MiB log ring). XNU follows its FAT32
cluster chain and writes only into the file's allocated data clusters; it does
not update FAT metadata. Keep the file in the volume root and do not resize or
delete it while testing.

The XNU SD logger flushes once per second by default. After a test, power the
phone down, connect the card to the host, then decode the log:

```powershell
.\tools\sweet-sd-log-pull.ps1 -Drive D: -OutFile .\logs\x670-boot.txt
```

`viva_usb_probe()` is not called on the X670 path; this diagnostic uses the
preallocated FAT log file instead of the viva USB link.

## Build inputs

1. Build the `SWEET` XNU kernel with the patches in `xnu/patches/` using the
   `xnu.yml` GitHub Actions workflow.
2. Build `iosroot.img` from the local iOS 16.5 OS and cryptex DMGs using
   `tools/viva-build-iosroot.sh`. It requires Linux `apfs-fuse`, `hfsprogs`,
   `rsync`, loop mounts, and root privileges.
3. Rebuild the SD-root shim boot image with
   `VIVA_DEV=x670 tools/viva-mkboot.sh KERNEL STOCK_BOOT_IMG sd-ro`, then copy
   `shim/out/viva-boot.img` to `scorpion-boot.img`.
4. Build the X670 U-Boot artifact from `scorpion-uboot`. Its `build-x670.yml`
   workflow applies patches 0001 through 0015.

## Write the removable card

On Linux, run:

```sh
sudo tools/prepare-sdcard.sh /dev/SD_CARD scorpion-boot.img iosroot.img
```

The script checks that the target is removable and asks for the complete
device path before erasing it. Confirm the SD card reader and device path with
`lsblk` first. It writes only the selected removable device.

This is an experimental bring-up path. The MT6781 SD driver and U-Boot host
setup still require a real card and handset boot test. No internal storage
operation is part of this procedure.
