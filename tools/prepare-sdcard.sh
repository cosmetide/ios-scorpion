#!/usr/bin/env bash
# Prepare a removable SD card for X670 XNU boot.
# This intentionally destroys the selected device. It is never run by builds.
# Usage: sudo tools/prepare-sdcard.sh /dev/DEVICE scorpion-boot.img iosroot.img
set -euo pipefail

[[ $# -eq 3 ]] || {
	echo "usage: sudo $0 /dev/DEVICE scorpion-boot.img iosroot.img" >&2
	exit 2
}
dev=$(readlink -f "$1")
boot=$(realpath "$2")
root=$(realpath "$3")

[[ -b $dev ]] || { echo "not a block device: $dev" >&2; exit 2; }
[[ -f $boot && -f $root ]] || { echo "boot or root image not found" >&2; exit 2; }
for tool in lsblk sgdisk partprobe blockdev udevadm mkfs.vfat dd mount umount \
	fsck.hfsplus findmnt install stat; do
	command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 2; }
done

removable=$(lsblk -dnro RM "$dev" | head -n1)
[[ $removable == 1 ]] || {
	echo "refusing non-removable device ($dev); select the SD card reader device" >&2
	exit 1
}
[[ $(blockdev --getsize64 "$dev") -ge $((18 * 1024 * 1024 * 1024)) ]] || {
	echo "card must be at least 18 GiB" >&2
	exit 1
}
[[ $(stat -c %s "$root") -le $((16 * 1024 * 1024 * 1024)) ]] || {
	echo "root image is larger than the planned 16 GiB partition" >&2
	exit 1
}

echo "Selected removable device:"
lsblk -o NAME,MODEL,SIZE,RM,TYPE,MOUNTPOINTS "$dev"
echo "This erases every partition on $dev."
read -r -p "Type the full device path to continue: " confirm
[[ $confirm == "$dev" ]] || { echo "cancelled"; exit 1; }

while read -r part; do
	[[ -n $part ]] || continue
	findmnt -rn -S "$part" >/dev/null && umount "$part"
done < <(lsblk -lnpo NAME "$dev" | tail -n +2)

sgdisk --zap-all "$dev"
sgdisk --new=1:2048:+1G --typecode=1:0700 --change-name=1:SCORPION_BOOT \
	--new=2:0:+16G --typecode=2:af00 --change-name=2:iosroot "$dev"
partprobe "$dev"
udevadm settle

if [[ $dev =~ [0-9]$ ]]; then
	p1="${dev}p1" p2="${dev}p2"
else
	p1="${dev}1" p2="${dev}2"
fi
for _ in {1..20}; do [[ -b $p1 && -b $p2 ]] && break; sleep 1; done
[[ -b $p1 && -b $p2 ]] || { echo "partition nodes did not appear" >&2; exit 1; }
[[ $(blockdev --getsize64 "$p2") -ge $(stat -c %s "$root") ]] || {
	echo "iosroot partition is too small for the supplied image" >&2
	exit 1
}

mkfs.vfat -F 32 -n SCORPION "$p1"
mountpoint=$(mktemp -d)
trap 'mountpoint -q "$mountpoint" && umount "$mountpoint"; rmdir "$mountpoint" 2>/dev/null || true' EXIT
mount "$p1" "$mountpoint"
install -m 0644 "$boot" "$mountpoint/scorpion-boot.img"
sync
umount "$mountpoint"
dd if="$root" of="$p2" bs=4M conv=fsync status=progress
sync
fsck.hfsplus -f -n "$p2"
echo "SD card ready: FAT boot partition 1; read-only XNU root partition named iosroot."
