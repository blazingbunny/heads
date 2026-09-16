# T430 TOTP failure: the exact recovery procedure

This is the procedure for the T430 and the custom no-HOTP Heads build from
this investigation. It is not a generic Heads flashing guide.

## What the saved logs showed

The failure is in Heads' native TPM 1.2 TOTP state, not in HOTP or in the
Nitrokey Pi emulator:

1. The old TOTP secret was sealed to measured-boot PCRs, including PCR7.
2. The custom ROM produced a different PCR7 measurement, so the old secret no
   longer matched its TPM policy.
3. The recovery path extended PCR4, creating another policy mismatch.
4. `/boot/kexec.sig` and rollback metadata were missing or could not be
   validated.
5. The TPM rollback-counter operation returned `0x15` (resource/state
   exhaustion).

That combination explains why Heads could boot into recovery but could not
unseal the existing TOTP. A displayed `HOTP: N/A` is expected for this custom
ROM and is not the defect. Do not attach the Pi emulator or a physical
Nitrokey while testing the T430's native TPM.

## The repair strategy

There are two different outcomes. Choose the first one that applies:

- **Preserve the old TOTP:** test the installed custom ROM twice without
  changing the TPM. If it works, the repair is complete.
- **Replace the old TOTP:** only if you explicitly accept that the old secret
  and TPM rollback state will be destroyed. Reset/re-own the TPM, rebuild and
  sign `/boot`, reboot, then create a replacement TOTP on the next measured
  boot.

An unseal failure does not authorize a reset. If the old TOTP must be
preserved and the preserve-first test fails, stop and keep the old ROM/TPM
state intact until you decide how to recover it.

## Before touching the T430

Do these steps on the laptop first:

1. Keep the original `debug.log` and `measuring_trace.log` unchanged. Make a
   separate copy for annotations; do not edit or overwrite the originals.
2. Keep a read-only backup of the currently installed ROM and confirm that it
   can be read back.
3. Keep the T430 on AC power for every boot and any firmware operation.
4. Keep the Pi emulator and any physical Nitrokey detached from the T430.
5. Prepare recovery media before starting. Do not begin if you cannot return
   to the prior ROM or reach a recovery shell.

The candidate built for this investigation is:

```text
build/x86/EOL_t430-maximized/heads-EOL_t430-maximized-202609161014-.rom
SHA-256: 1111f5c49c689006d2b100a5f6ec9d451be13026d21b7df1ce1d7d726dc86f29
```

Verify the exact file before copying it to USB:

```sh
sha256sum build/x86/EOL_t430-maximized/heads-EOL_t430-maximized-202609161014-.rom
```

Do not use an older ROM merely because its filename looks similar. The older
USB candidate hashes in the investigation are historical and are not the
candidate above.

## Decide whether flashing is needed

Flashing is only a prerequisite if the verified candidate is not already
installed. It is not the TOTP repair itself.

1. If the T430 is already running the verified custom build, skip to
   **Preserve-first boot 1**.
2. If you are not certain which build is installed, stop and verify the Heads
   build identity and board identity first. Do not infer it from a ROM file
   merely being present on the USB.
3. If flashing is required, put the `.rom` file at the root of the intended
   USB data partition. It must be a ROM file, not an ISO and not a Debian
   installer image. A plain one-partition USB is the baseline; do not hide the
   file only inside a Ventoy ISO tree.
4. Identify the USB by transport, size, filesystem, label, and mountpoint:

   ```sh
   lsblk -o NAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS
   blkid
   sha256sum /media/<USB-LABEL>/heads-EOL_t430-maximized-202609161014-.rom
   ```

   The copied hash must be
   `1111f5c49c689006d2b100a5f6ec9d451be13026d21b7df1ce1d7d726dc86f29`.
5. Only with separate authorization, use the T430's supported Heads
   `Options -> Flash/Update BIOS` retain-settings workflow. Confirm the board
   identity and any flash-probe result before writing.
6. Wait for the explicit success result. Do not remove AC or USB during the
   write. If the board, hash, or result differs, stop; do not continue into a
   TPM reset.

## Preserve-first boot 1: test the existing TOTP

This is the most important test. It must happen before any reset, re-ownership,
new-secret generation, or integrity repair that changes TPM state.

1. Start the T430 on AC power.
2. Record the Heads version/build and confirm that the machine is identified as
   the intended T430.
3. Select the normal/default installed-OS boot entry. Do not choose recovery
   just to make the boot continue.
4. If Heads requests the existing TOTP, use the existing TOTP path. Do not
   generate a new secret.
5. If Heads reports any of the following, stop immediately and photograph or
   transcribe only the non-secret diagnostic text:

   - TOTP unseal or PCR-policy failure;
   - PCR4 recovery extension;
   - missing `/boot/kexec.sig`;
   - missing or invalid rollback metadata;
   - TPM counter resource exhaustion (`0x15` or equivalent); or
   - a prompt to reset/re-own the TPM.

   Do not select `Reset the TPM`, `OEM Factory Reset / Re-Ownership`, or
   `Generate a new TOTP` during this preserve-first test.
6. If the installed operating system reaches login, record boot 1 as a pass.
   Do not change firmware, TPM, boot files, or key configuration after
   reaching the OS.

When saving evidence, redact TOTP/HOTP values, QR codes, PINs, owner
passphrases, private keys, sealed blobs, and secret-file contents. Keep the
original USB logs untouched.

## Preserve-first boot 2: prove persistence

Only perform boot 2 if boot 1 passed.

1. Shut down from the installed operating system normally.
2. Wait until the T430 is fully powered off, then wait about 30 seconds.
3. Power it on and repeat the same normal/default boot path.
4. Confirm that the existing TOTP still works and the operating system reaches
   login.
5. Save a second redacted record.

Two cold boots are required. A single successful boot does not prove that the
TPM policy, PCR measurements, rollback counter, and sealed TOTP survive a
fresh TPM startup and power loss. Do not perform boot 2 if boot 1 failed.

## When the preserve-first repair is complete

The current issue is resolved for the existing secret only when both boots:

- use the verified custom ROM;
- reach the installed operating system normally;
- unseal the existing TOTP without a PCR-policy failure;
- do not enter recovery or extend PCR4 unexpectedly;
- validate `/boot/kexec.sig` and rollback metadata; and
- do not report TPM counter exhaustion.

If all conditions pass, leave the TPM and TOTP state unchanged. The emulator
is not required for this result.

## Replacement path: only after explicit approval

Use this section only after recording that preserving the old TOTP is no longer
required or possible. This path is destructive: TPM forceclear destroys the old
sealed TOTP, rollback state, and other TPM-bound secrets.

1. Save a redacted integrity report and record the ROM hash, reason, operator,
   and UTC time. Do not record any secret value.
2. From the TPM/TOTP/HOTP options, select `Reset the TPM` or the supported
   `OEM Factory Reset / Re-Ownership` path.
3. Accept the first warning and enter the new TPM owner passphrase.
4. Read the `Final TPM Reset Confirmation` immediately before accepting it.
   This final confirmation is the authorization to forceclear the TPM.
5. If reset reports an error, stop. Do not continue to counter creation,
   `/boot` signing, TOTP generation, or disk-key resealing after a partial
   reset.
6. After a successful reset, Heads removes the invalid rollback files, creates
   fresh rollback state, and requires access to the GPG signing key to rebuild
   and sign `/boot`. Follow the on-screen signing-card prompts; do not bypass
   the integrity gate.
7. Heads must reboot before replacement TOTP sealing. This is intentional:
   TPM 1.2 forceclear invalidates the live PCR context for the remainder of
   that boot. Do not try to seal a new TOTP before the reboot.
8. On the next measured boot, select `Generate new TOTP/HOTP secret`, approve
   the integrity report, and complete the normal sealing flow.
9. Never photograph, copy, paste, or otherwise record the displayed TOTP,
   QR code, PIN, or owner passphrase.
10. Repeat the two cold-boot procedure above to prove the replacement secret
    persists.

## Edge cases and stop rules

- **The ROM file is on USB but Heads does not detect it:** this is a USB layout,
  mountpoint, filename, or format problem. It is not evidence that the TPM
  TOTP repair worked. Confirm that the `.rom` is on the mounted data
  partition's root and recheck its hash; do not use an ISO as the ROM.
- **Heads shows `HOTP: N/A`:** expected for this no-HOTP custom ROM. Do not
  attach the emulator to “fix” it.
- **The first boot fails:** stop. Do not reboot repeatedly, reset the TPM, or
  guess keys. Preserve the screen and redacted logs.
- **The second boot fails after the first passed:** treat it as a persistence
  failure, not a reason to reset immediately. Preserve both boot records.
- **A recovery/PCR4 path appears:** it changes measurements and can make a
  previously valid sealed policy unusable. Stop unless you are intentionally
  entering the replacement path.
- **The GPG card is unavailable during replacement:** stop at the signing gate.
  Do not continue to TOTP generation with unsigned or unverified `/boot`.
- **A QEMU run says “no bootable OS was found”:** that is a QEMU disk/image
  fixture problem. A Debian `netinst` ISO is not a substitute for a bootable
  installed disk with a separate `/boot`; do not use that result as evidence
  about the T430's TPM.
- **The machine hangs or powers off:** keep AC connected, record the last
  visible state, and stop. Do not keep cycling power while the cause is
  unknown.

The disposable QEMU reproduction and controls are documented in
[`qemu.md`](qemu.md). TPM implementation details are in [`tpm.md`](tpm.md).
