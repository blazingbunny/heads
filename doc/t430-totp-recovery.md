# T430 TOTP recovery and fixed-ROM validation

This guide is for validating the T430 no-HOTP Heads build after the TPM/TOTP
failure investigation. It is preserve-first: first test whether the existing
sealed TOTP still works, and do not reset or re-own the real TPM merely because
Heads reports an error.

The Nitrokey Pi emulator is not needed for this procedure. Keep it and any
physical Nitrokey detached from the T430 boot path.

## Current artifact

The current worktree build for `EOL_t430-maximized` is:

```text
heads-EOL_t430-maximized-202609161014-.rom
SHA-256: 1111f5c49c689006d2b100a5f6ec9d451be13026d21b7df1ce1d7d726dc86f29
```

Verify the ROM you intend to use against its published or operator-provided
hash before copying it to removable media. The older USB candidate hashes
recorded in the recovery notes are not this current worktree build.

Keep these items unchanged and available:

- a read-only backup of the currently installed ROM;
- the original `debug.log` and `measuring_trace.log` from the USB;
- the existing sealed TOTP state;
- charger power and recovery media.

Do not attach the emulator to the T430, run `dd` against a device, or overwrite
the original logs.

## Prepare the USB

Use a plain USB storage device with one intended data partition. An ext4
partition mounted by Heads is the baseline. Put the ROM and its hash file in
the root of that partition, not only inside a Ventoy ISO tree.

On Linux, identify the device by transport, size, filesystem, and label before
using it:

```sh
lsblk -o NAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS
blkid
sha256sum /path/to/heads-EOL_t430-maximized-202609161014-.rom
```

Copy the ROM only after confirming the destination mountpoint. Verify the
copied file again:

```sh
sha256sum /media/<USB-LABEL>/heads-EOL_t430-maximized-202609161014-.rom
```

The resulting hash must be exactly the artifact hash above. Do not repartition,
format, or write to a whole-disk device as part of this procedure.

## Flashing the candidate (only with separate authorization)

If the candidate is not already installed, flashing is a separate destructive
operation. First confirm that the ROM backup is readable and that you have
recovery access. Then:

1. Connect AC power and keep the machine stationary.
2. Boot Heads and verify that the machine is identified as the intended T430.
3. In the recovery shell, use the board-specific flash probe to confirm the
   internal programmer and locked regions. Do not improvise a generic command.
4. Return to `Options -> Flash/Update BIOS` and choose the supported
   retain-settings workflow.
5. Select the ROM from the verified USB partition and recheck its SHA-256 when
   Heads presents the verification step.
6. Wait for the explicit success message. Do not interrupt power or remove the
   USB during the write.

If the hash, board identity, flash probe, or success message is not exactly as
expected, stop and preserve the evidence. A failed flash is not a TOTP
diagnosis.

## Preserve-first cold boot 1

1. Record the Heads version/build identity shown before the operating system.
2. Choose the normal/default boot entry. Do not select recovery mode merely to
   make the boot continue.
3. If Heads asks for the existing TOTP, use the existing sealed-secret path.
4. If it reports an unseal failure, PCR4 recovery extension, missing
   `/boot/kexec.sig`, missing rollback metadata, counter exhaustion, or asks to
   reset the TPM, stop.
   Do not select `Reset the TPM`, `OEM Factory Reset / Re-Ownership`, or
   `Generate a new TOTP` in the preserve-first test.
5. If the operating system reaches its login screen, record that as a normal
   boot. Do not change TPM, firmware, or boot configuration.

Save a separate, redacted record for boot 1. It must contain no TOTP/HOTP
values, QR data, PINs, passphrases, private keys, sealed blobs, or secret-file
contents. Keep the original USB logs untouched.

## Preserve-first cold boot 2

1. From the operating system, perform a normal shutdown.
2. Wait until the machine is fully powered off, then wait about 30 seconds.
3. Power it on and repeat the same normal/default boot path.
4. Confirm that the operating system reaches login again.
5. Save a separate redacted record for boot 2.

Two cold boots are required because one boot can appear successful while the
sealed TOTP or rollback state still fails after power loss. The second boot
tests persistence across a fresh PCR measurement and TPM startup.

## Pass criteria

The preserve-first physical gate passes only when both boots:

- use the verified candidate ROM;
- reach the installed operating system normally;
- unseal the existing TOTP without a PCR-policy failure;
- do not extend PCR4 for recovery;
- find `/boot/kexec.sig` and rollback metadata; and
- do not report TPM counter resource exhaustion.

If boot 1 fails any criterion, stop. Do not continue to boot 2 merely to
collect a second failure.

## Authorized replacement path

This path abandons the old sealed secret and must not be inferred from a
failed unseal. Use it only after the operator has explicitly recorded that the
old secret is no longer being preserved.

1. Save a redacted integrity report and record the non-secret authorization,
   ROM hash, reason, operator, and UTC time.
2. Select the supported TPM reset/re-ownership action.
3. Accept the initial warning, enter a new TPM owner passphrase, and read the
   final force-clear confirmation immediately before accepting it.
4. If reset fails, stop. Do not continue to counter creation, signing, or
   secret generation after a partial reset.
5. Heads rebuilds rollback metadata and signs `/boot`, then reboots before
   replacement TOTP sealing. This reboot is required because TPM 1.2 forceclear
   invalidates the live PCR context for the remainder of that boot.
6. On the next measured boot, use the normal `Generate new TOTP/HOTP secret`
   action. Confirm the integrity gate before resealing.
7. Never photograph, copy, or paste the displayed TOTP, QR code, owner
   passphrase, or PIN.
8. Repeat the two cold-boot validation above using the replacement state.

The reset path is not a recovery method for the old TOTP. It destroys the old
sealed secret and TPM rollback state.

## Common stop conditions

Stop and preserve evidence if any of the following occurs:

- the displayed Heads build is not the verified candidate;
- Heads enters recovery or extends PCR4 unexpectedly;
- TOTP unseal or rollback-counter validation fails;
- `/boot` signature or rollback metadata is missing;
- the machine hangs, powers off unexpectedly, or requires guessed keystrokes;
- a QEMU test says no bootable OS was found. For QEMU, use a bootable
  live/hybrid image and an installed disk with a separate `/boot` partition;
  a Debian `netinst` ISO is not suitable for the USB-file boot path.

Record the screen and redacted logs, then stop. Do not repeatedly reboot, flash,
reset, or attach the emulator while the cause is unknown.

For the disposable validation procedure and headless QEMU controls, see
[`qemu.md`](qemu.md). For TPM implementation details, see [`tpm.md`](tpm.md).
