# X670 SD boot build status

Build outputs for the current SD path are in the local `work/x670-sd-flash-package/` directory (not tracked in git). See its `README.txt` for hashes and intended roles.

- U-Boot with patches 0001-0015: GitHub Actions runs 42383564623 and 42383652657 succeeded. Latest U-Boot source commit: `572153a`.
- XNU SD-root changes: GitHub Actions run 42383001572 succeeded at compile time. Source commit: `503030c`.
- Packaged outputs: `x670-uboot-boot.img` to start the experimental U-Boot through LK; `scorpion-boot.img` is the XNU shim/kernel Android boot image that U-Boot loads from the FAT partition.
- The boot image headers and retained stock DTBs were inspected, and SHA256 hashes are in the package README.
- The SD `iosroot` HFS+ image is still missing. The IPSW components have been identified, but the builder needs Linux APFS FUSE, HFS+ tools and root mounts. Until `iosroot.img` is built and the device probes/mounts the card, this is not an iOS userspace boot.
- No SD card was inserted or written. No phone flash occurred. Android `userdata`/UFS remains untouched.

