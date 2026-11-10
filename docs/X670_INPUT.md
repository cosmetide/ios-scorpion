# X670 input bring-up

## Evidence collected

- The public TWRP device tree is a generated recovery tree, not a full kernel
  source tree. Its `BoardConfig.mk` targets `mt6781` and carries a prebuilt DTB.
- The local stock firmware DTB describes the MT6781 keypad at `0x10010000`,
  keypad GIC SPI 73, EINT at `0x1000b000`, and PMIC wrapper at `0x1000d000`.
- The stock DTB labels the PMIC node `mediatek,mt6358-pmic`; the successful XNU
  boot log identifies the physical PMIC as hwcid `0x6610` (MT6366), which the
  existing PMIC implementation supports.
- The extracted X670 vendor partition contains
  `gt9896s_cfg_6781v01_1080x2300.bin`. Its Goodix package identifies the
  controller as `yellowstone_s`, PID `9896S`, with coordinate register `0x4180`,
  PID register `0x4022`, and config address `0x96f8`. This matches the existing
  Viva Yellowstone protocol family.
- The stock DTB's Goodix node does not publish X670 touch IRQ, reset GPIO, or
  power GPIOs. Viva's GPIO pins (17, 73, 166) and EINT 13 are therefore not
  assumed to match X670.

## Passive touch test

The X670 ADT now exposes MT6781 I2C0 and a GT9896S node. The new kernel patch
uses the existing Goodix HID driver in passive mode: it does not toggle reset
or power GPIOs, and polls coordinate register `0x4180` every 50 ms. A valid
contact is sent to the iOS digitizer and logged with raw coordinates. The probe
also reads PID register `0x4022` once at startup.

Boot with one core and the SD logging arguments (`cpus=1 sweetlog=1
sweetlogsecs=1 scorpion=SCORPION_BOOT`). Expected SCORPION log lines include
`X670 TOUCH TEST: ... PID read ...`, followed by coordinate-read errors if the
controller is not responding, or contact coordinates when a touch is detected.
A readable PID alone does not prove the panel reports contacts; touch the screen
while capturing the SD log.

This test depends on the bootloader leaving the controller powered and I2C0
pins configured. If the probe fails, the log narrows the issue to controller
power/pin mux, bus setup, or address; no unverified rail/reset GPIO is driven.

## References

- [X670 TWRP device tree](https://github.com/twrpdtgen/android_device_infinix_Infinix-X670)
- [X670 BoardConfig.mk](https://github.com/twrpdtgen/android_device_infinix_Infinix-X670/blob/vnd_x670_h814-user-12-SP1A.210812.016-478980-release-keys/BoardConfig.mk)
