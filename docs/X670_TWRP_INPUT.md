# X670 touch and USB from the TWRP DTB

Source: `twrpdtgen/android_device_infinix_Infinix-X670`, branch
`vnd_x670_h814-user-12-SP1A.210812.016-478980-release-keys`. Its
`BoardConfig.mk` uses a prebuilt kernel and DTB, so the XNU port consumes only
relevant hardware facts from `prebuilt/dtb.img`; it does not copy the full
Android DTB.

## Touch

The TWRP DTB's root `touch` node contains only the compatibles
`goodix,touch` and `mediatek,touch`. It has no I2C address, IRQ, reset pin, or
power-rail data. The adjacent I2C0 node identifies the bus at `0x11007000`, GIC
SPI 105 (`<0 0x69 4>`), clock divider 5, and SCL/SDA GPIO IDs 144/145.

The X670 vendor firmware adds the controller identity: GT9896S Yellowstone,
I2C address `0x5d`, PID register `0x4022`, and coordinate register `0x4180`.
These vendor details are not supplied by the TWRP touch node. Until the touch
IRQ and power/reset wiring are identified, the XNU test uses only I2C0 and a
passive 50 ms poll; it does not drive guessed pins.

## USB

The TWRP DTB describes `mediatek,mt6781-usb20` at `0x11200000` in OTG mode,
with T-PHY port 0 at `0x11ca0300`. Those match the existing XNU `viva_usb.c`
MUSB/T-PHY register bases. TWRP recovery init also addresses the `musb-hdrc`
UDC and starts `adbd`.

The SD-root XNU path now calls the existing USB probe, which remains disabled
unless the `vivausb` boot argument is set. Set `VIVA_USB=1` when packaging an
SD boot image to request `vivausb=3`; SCORPION FAT logging stays enabled.

No other TWRP nodes are copied into the XNU ADT. The X670-specific ADT addition
is limited to I2C0 and the GT9896S child; the existing PMIC wrapper remains for
SD-card rail control.

## References

- [TWRP X670 device tree](https://github.com/twrpdtgen/android_device_infinix_Infinix-X670/tree/vnd_x670_h814-user-12-SP1A.210812.016-478980-release-keys)
- [TWRP BoardConfig.mk](https://github.com/twrpdtgen/android_device_infinix_Infinix-X670/blob/vnd_x670_h814-user-12-SP1A.210812.016-478980-release-keys/BoardConfig.mk)
