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
