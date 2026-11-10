#!/bin/bash
# XNU kernel -> viva boot image (shim + SWEETXNU payload in the ramdisk).
#   tools/viva-mkboot.sh KERNEL STOCK_BOOT_IMG [STAGE]   -> shim/out/viva-boot.img
#
# STAGE (default ufs-ro):
#   nostorage  no UFS node: the kernel never touches storage, panics at root mount
#   ufs-ro     UFS node, writes refused (no ufsrw): finds "userdata" and tries to mount it
#   ufs-rw     iOS root in userdata, read-write; writes stay inside that partition
#   sd-ro      X670 microSD root, read-only; finds GPT partition "iosroot"
#   sd-rw      X670 microSD root, read-write; requires the SD CMD24 write path
# Env: VIVA_CMDLINE replaces the whole command line; VIVA_EXTRA sets single
# boot-args on top of it (default "cpus=8 vivausb=3 vivagpu=2 vivascanout=1": all
# eight cores incl. the two A76s, USB link, GPU on, direct scanout of CA's
# framebuffers (0133: SwapWait retires them); VIVA_EXTRA= turns the defaults off).
# sweetfb_noconsole=1: no kernel text on the screen from the GUI's first frame
# (boot Apple) on; the USB link still gets the whole log, a panic still draws,
# link `console on` brings it back (or VIVA_EXTRA="sweetfb_noconsole=0").
# Every stage turns off sweet's Qualcomm drivers (keys, touch, USB, persistent
# log): their fixed MMIO addresses are other blocks on MT6781.
set -euo pipefail
cd "$(dirname "$0")/.."
KERNEL=${1:?usage: viva-mkboot.sh KERNEL STOCK_BOOT_IMG [nostorage|ufs-ro|ufs-rw|sd-ro|sd-rw]}
STOCK=${2:?usage: viva-mkboot.sh KERNEL STOCK_BOOT_IMG [nostorage|ufs-ro|ufs-rw|sd-ro|sd-rw]}
STAGE=${3:-ufs-ro}
# build-viva.sh runs from shim/: hand it absolute paths (Windows Git Bash / MSYS
# also needs this, and mkpayload runs from the repo root).
case $KERNEL in /*) ;; *) KERNEL=$PWD/$KERNEL ;; esac
case $STOCK in /*) ;; *) STOCK=$PWD/$STOCK ;; esac

BASE='debug=0xc serial=3 cpus=1 keepsyms=1 -enable_kprintf_spam -noprogress wdt=-1 wdt_test=no_user_checkin sweetkeys=0 sweettouch=0 sweetusb=0 sweetusblog=0 sweetlog=0'
case $STAGE in
nostorage) ADT_FLAGS=(--viva); CMDLINE="$BASE rd=ufsroot0 ufslun=2 sweetfb_noconsole=1" ;;
ufs-ro) ADT_FLAGS=(--viva --ufs); CMDLINE="$BASE rd=ufsroot0 ufslun=2 sweetfb_noconsole=1" ;;
ufs-rw) ADT_FLAGS=(--viva --ufs)
	CMDLINE="$BASE rd=ufsroot0 ufslun=2 ufsrw=1 rootrw=1 unentitled_ios_sim_launch=1 ignition_level=1 launchd_unsecure_cache=1 sweetfb_noconsole=1" ;;
sd-ro) ADT_FLAGS=(--viva --x670)
	# The SWEET kernel is built with the macOS platform config. Allow Apple's
	# iOS launchd to pass the kernel's platform check, then let libignition
	# discover the iOS 16.5 cryptex/shared cache from the SD root.
	CMDLINE="$BASE rd=sdroot0 sdroot=iosroot unentitled_ios_sim_launch=1 ignition_level=1 launchd_unsecure_cache=1" ;;
sd-rw) ADT_FLAGS=(--viva --x670)
	# launchd's mount phase remounts / read-write. This requires both the
	# SWEET rootrw patch and the X670 SD driver's single-sector write path.
	CMDLINE="$BASE rd=sdroot0 sdroot=iosroot rootrw=1 unentitled_ios_sim_launch=1 ignition_level=1 launchd_unsecure_cache=1" ;;
*) echo "unknown stage $STAGE" >&2; exit 2 ;;
esac
# X670: use its native panel dimensions and pixel density. Its iOS mode is
# still scale 3 (360x800 points); the compatible iPhone X canvas is for viva.
if [ "${VIVA_DEV:-viva}" = x670 ] || [ "$STAGE" = sd-ro ] || [ "$STAGE" = sd-rw ]; then
	# SD stages are X670 builds even when launched from PowerShell/WSL, where
	# Windows environment variables are not automatically exported to Linux.
	VIVA_DEV=x670
	export VIVA_DEV
	if [[ ! " ${ADT_FLAGS[*]} " =~ [[:space:]]--x670[[:space:]] ]]; then ADT_FLAGS+=(--x670); fi
	CMDLINE="$CMDLINE sweetfb_native=1"
fi
CMDLINE=${VIVA_CMDLINE:-$CMDLINE}
# VIVA_EXTRA="cpus=6 vivausb=3": set/replace single boot-args (XNU uses the first match)
if [ "$STAGE" = sd-ro ] || [ "$STAGE" = sd-rw ]; then
	DEFAULT_EXTRA='cpus=1 sweetlog=1 sweetlogsecs=1 scorpion=SCORPION_BOOT'
	# The X670 TWRP DTB confirms the MT6781 MUSB/T-PHY wiring used by the
	# existing viva USB link. Keep it opt-in while SD logging remains default.
	if [ "${VIVA_USB:-0}" = 1 ]; then DEFAULT_EXTRA="$DEFAULT_EXTRA vivausb=3"; fi
else
	DEFAULT_EXTRA='cpus=8 vivausb=3 vivagpu=2 vivascanout=1'
fi
for arg in ${VIVA_EXTRA-$DEFAULT_EXTRA}; do
	key=${arg%%=*}
	CMDLINE="$(printf ' %s ' "$CMDLINE" | sed -E "s/ -?$key(=[^ ]*)? / /g; s/^ +//; s/ +$//") $arg"
done
echo "stage $STAGE: $CMDLINE"

mkdir -p shim/out
python3 tools/mkadt.py shim/out/viva.adt "${ADT_FLAGS[@]}"
python3 tools/mkpayload.py "$KERNEL" shim/out/viva.adt shim/out/viva-payload.bin --cmdline "$CMDLINE"
# LK loads the ramdisk at 0x47c80000 and the DTB at 0x4bc80000: 64 MiB of room.
size=$(wc -c < shim/out/viva-payload.bin)
[ "$size" -lt $((0x4bc80000 - 0x47c80000)) ] || { echo "error: payload ($size bytes) would overrun LK's DTB" >&2; exit 1; }
shim/build-viva.sh "$STOCK" "$PWD/shim/out/viva-payload.bin"
