# Heads T430 Preserve-First No-HOTP v0.1.0

Release status: candidate. The real T430 is still running the older
`Heads-v0.2.1-3213-gbfd2935-dirty` image. The current candidate has been copied
to the USB but has not been flashed to the machine, and the real-device
cold-boot gate remains open.

## Artifact

USB filename:

```text
Nitrokey-Heads/heads-EOL_t430-maximized-202609170503-fix.rom
```

Local build artifact:

```text
build/x86/EOL_t430-maximized/heads-EOL_t430-maximized-202609170503-.rom
```

SHA-256:

```text
71b8b298dd6bb09e6285b8f07dcc943466586161109314f8f094e0726997677f
```

Source commit: `661089211d9e138f78b24a7ede358c7dcb8546ba`

## Included behavior

- TPM 1.2 support and native TPM-backed TOTP remain enabled.
- Internal T430 SPI flashing remains available through `flashprog`,
  `/bin/flash.sh`, and the Heads flash GUI.
- HOTP is explicitly disabled and its runtime binary/sealing helpers are
  excluded from the image.
- Traditional non-BLS `/boot` integrity checks ignore mutable GRUB
  `grubenv`; BLS layouts remain protected.
- GPG, PIN, dialog, unseal-path, and other sensitive debug output is redacted.
- Single-character prompts restore the tty state and do not consume a queued
  newline intended for a later dialog.

## Validation

- Emulator suite: `62 passed`.
- Offline TPM replay: no hardware access and no secret output.
- Disposable QEMU: two fresh cold boots reached the disposable OS login
  screen using an isolated virtual TPM and public test key.
- Custom image scan: no HOTP binary or HOTP sealing helper in the packaged
  runtime payload.

## Safety boundary

The saved USB capture records that the older ROM already completed TPM
force-clear/re-ownership. Treat the old sealed state as invalidated and do not
reset or re-own the real TPM again. Do not re-seal a replacement secret or
attach the emulator to the T430 boot path until the current candidate has
booted and its `/boot` signing path is verified. Any future reset/re-ownership flow must follow
`nitrokey-pi-otp-emulator/docs/next-version-tpm-reset-gate.md` and receive
separate operator authorization.

Before any physical flash, independently verify the artifact hash, retain a
read-only backup of the current firmware, and use the supported Heads flash
workflow. A successful QEMU result does not prove a physical flash or a real
T430 boot.
