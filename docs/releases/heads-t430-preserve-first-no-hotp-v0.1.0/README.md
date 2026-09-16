# Heads T430 Preserve-First No-HOTP v0.1.0

Release status: candidate. The real T430 is still running the older
`Heads-v0.2.1-3213-gbfd2935-dirty` image. This candidate has not been flashed
to the machine, and the real-device cold-boot gate remains open.

## Artifact

Recommended filename:

```text
t430-maximized-no-hotp-totp-grubenv-logfix-c754f75.rom
```

Local build artifact:

```text
build/x86/EOL_t430-maximized/heads-EOL_t430-maximized-202609160936-.rom
```

SHA-256:

```text
345eaaa577d02fe0e6d04d141d95c5f2132d5e1bf3220525f1443a6a89aeb0d6
```

Source commit: `c754f757cd81573034dc69687d484ca3c4f4ded9`

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

- Emulator suite: `53 passed`.
- Offline TPM replay: no hardware access and no secret output.
- Disposable QEMU: two fresh cold boots reached the disposable OS login
  screen using an isolated virtual TPM and public test key.
- Custom image scan: no HOTP binary or HOTP sealing helper in the packaged
  runtime payload.

## Safety boundary

Preserve the existing sealed TOTP first. Do not reset or re-own the real TPM,
re-seal a replacement secret, or attach the emulator to the T430 boot path
for this candidate. Any next-version reset/re-ownership flow must follow
`nitrokey-pi-otp-emulator/docs/next-version-tpm-reset-gate.md` and receive
separate operator authorization.

Before any physical flash, independently verify the artifact hash, retain a
read-only backup of the current firmware, and use the supported Heads flash
workflow. A successful QEMU result does not prove a physical flash or a real
T430 boot.
