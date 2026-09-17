# Targets for running in qemu, including:
# * virtual TPM
# * virtual disk image (configurable size)
# * virtual USB flash drive
# * configurable guest memory size
# * forwarded USB security token

# Use the GPG-injected ROM if a key was given, since we can't reflash a GPG
# keyring in QEMU.  Otherwise use the plain ROM, some things can still be tested
# that way without a GPG key.
ifneq "$(PUBKEY_ASC)" ""
QEMU_BOOT_ROM := $(build)/$(BOARD)/$(CB_OUTPUT_FILE_GPG_INJ)
else
QEMU_BOOT_ROM := $(build)/$(BOARD)/$(CB_OUTPUT_FILE)
endif

ifeq "$(CONFIG_TPM2_TSS)" "y"
SWTPM_TPMVER := --tpm2
SWTPM_PRESETUP := swtpm_setup --create-config-files root,skip-if-exist
else
# TPM1 is the default
SWTPM_TPMVER :=
# No pre-setup
SWTPM_PRESETUP := true
endif

#borrowed from https://github.com/orangecms/webboot/blob/boot-via-qemu/run-webboot.sh
TPMDIR=$(build)/$(BOARD)/vtpm
CANOKEY_DIR=$(build)/$(BOARD)
$(TPMDIR)/.manufacture:
	mkdir -p "$(TPMDIR)"
	$(SWTPM_PRESETUP)
	swtpm_setup --tpm-state "$(TPMDIR)" --create-platform-cert --lock-nvram $(SWTPM_TPMVER)
	touch "$(TPMDIR)/.manufacture"
ROOT_DISK_IMG:=$(build)/$(BOARD)/root.qcow2
# Default to 20G disk
QEMU_DISK_SIZE?=20G
$(ROOT_DISK_IMG):
	qemu-img create -f qcow2 "$(ROOT_DISK_IMG)" $(QEMU_DISK_SIZE)
# Remember the amount of memory so it doesn't have to be specified every time.
# Default to 4G, most bootable OSes are not usable with less.
QEMU_MEMORY_SIZE?=4G
MEMORY_SIZE_FILE=$(build)/$(BOARD)/memory
$(MEMORY_SIZE_FILE):
	@echo "$(QEMU_MEMORY_SIZE)" >"$(MEMORY_SIZE_FILE)"
# Set QEMU_DISPLAY_OPT=-display none for headless validation on hosts without
# a usable GTK/X11 session.  Leave it empty to retain the normal framebuffer.
QEMU_DISPLAY_OPT?=
# Optional QEMU monitor socket for isolated automation.  This keeps GUI key
# events on the VM control plane instead of guessing whether serial input is
# connected to a framebuffer dialog or the recovery shell.
QEMU_MONITOR_SOCKET?=
ifneq "$(QEMU_MONITOR_SOCKET)" ""
QEMU_MONITOR_OPT := -monitor unix:$(QEMU_MONITOR_SOCKET),server=on,wait=off
else
QEMU_MONITOR_OPT :=
endif
# Optional serial socket for non-interactive recovery automation.  This keeps
# shell input out of docker attach, whose PTY can propagate Ctrl-C to QEMU.
QEMU_SERIAL_SOCKET?=
ifneq "$(QEMU_SERIAL_SOCKET)" ""
QEMU_SERIAL_OPT := -serial unix:$(QEMU_SERIAL_SOCKET),server=on,wait=off
else
QEMU_SERIAL_OPT := -serial stdio
endif
USB_FD_IMG=$(build)/$(BOARD)/usb_fd.raw
# Default USB flash drive size (accepts K/M/G suffixes).
# Raw sparse: only written blocks consume host disk space, so
# 128G virtual costs ~200K until ISOs are copied in.
QEMU_USB_SIZE?=64G
$(USB_FD_IMG):
	# Create raw sparse image, partition/format via parted + mkfs direct
	# ( -E offset= writes ext4 at partition offset without a loop device ).
	qemu-img create -f raw "$(USB_FD_IMG)" $(QEMU_USB_SIZE) >/dev/null 2>&1
	@if parted -s "$(USB_FD_IMG)" mklabel msdos mkpart primary ext4 2048s 100% \
	      >/dev/null 2>&1 && \
	    mkfs.ext4 -F -E offset=$$((2048*512)) "$(USB_FD_IMG)" >/dev/null 2>&1; then \
	  echo "USB: MBR+ext4 created"; \
	else \
	  echo "USB: warning — MBR creation failed, creating flat ext4" >&2; \
	  mkfs.ext4 -F "$(USB_FD_IMG)" >/dev/null 2>&1; \
	fi
# Pass INSTALL_IMG=<path_to_img.iso> to attach an installer as a USB flash drive instead
# of the temporary flash drive for exporting GPG keys.
ifneq "$(INSTALL_IMG)" ""
QEMU_USB_FD_IMG := $(INSTALL_IMG)
else
QEMU_USB_FD_IMG := $(USB_FD_IMG)
endif
# To forward a USB token, set USB_TOKEN to one of the following:
# - NitrokeyPro - forwards a Nitrokey Pro by VID:PID
# - NitrokeyStorage - forwards a Nitrokey Storage by VID:PID
# - Nitrokey3NFC - forwards a Nitrokey 3 by VID:PID
# - LibremKey - forwards a Librem Key by VID:PID
# - <other> - Provide the QEMU usb-host parameters, such as
#   'hostbus=<#>,hostport=<#>' or 'vendorid=<#>,productid=<#>'
# For no-HOTP integration tests, CANOKEY_FILE explicitly attaches a disposable
# canokey-qemu state file without making the final image depend on HOTP.  An
# explicit USB_TOKEN takes precedence so host-token tests remain unchanged.
ifeq "$(USB_TOKEN)" "NitrokeyPro"
QEMU_USB_TOKEN_DEV := -device usb-host,vendorid=8352,productid=16648
else ifeq "$(USB_TOKEN)" "NitrokeyStorage"
QEMU_USB_TOKEN_DEV := -device usb-host,vendorid=8352,productid=16649
else ifeq "$(USB_TOKEN)" "Nitrokey3NFC"
QEMU_USB_TOKEN_DEV := -device usb-host,vendorid=8352,productid=17074
else ifeq "$(USB_TOKEN)" "LibremKey"
QEMU_USB_TOKEN_DEV := -device usb-host,vendorid=12653,productid=19531
else ifneq "$(USB_TOKEN)" ""
QEMU_USB_TOKEN_DEV := -device "usb-host,$(USB_TOKEN)"
# Explicit virtual-card state is a test-only opt-in.  This is intentionally
# available to no-HOTP boards so the reset/signing gate can be integration
# tested with a disposable provisioned or unprovisioned card.
else ifneq "$(CANOKEY_FILE)" ""
QEMU_USB_TOKEN_DEV := -usb -device canokey,file=$(CANOKEY_FILE)
# If no USB token is specified, attach a disposable Canokey only for HOTP
# boards; no-HOTP boards must not acquire an OTP dependency implicitly.
else ifeq "$(CONFIG_HOTPKEY)" "y"
# HOTP-enabled boards get a disposable virtual Canokey by default.  A
# no-HOTP board must not depend on, or silently attach, an OTP token after
# setup; pass USB_TOKEN explicitly only for a dedicated token test.
QEMU_USB_TOKEN_DEV := -usb -device canokey,file=$(CANOKEY_DIR)/.canokey-file
else
QEMU_USB_TOKEN_DEV :=
endif


# QEMU must depend on the exact ROM selected above.  Without this dependency,
# changing GIT_VERSION_SUFFIX (for example after a commit) makes run construct
# a new timestamped ROM path and launch QEMU before that file exists.
run: $(QEMU_BOOT_ROM) $(TPMDIR)/.manufacture $(ROOT_DISK_IMG) $(MEMORY_SIZE_FILE) $(USB_FD_IMG)
	swtpm socket \
		$(SWTPM_TPMVER) \
		--tpmstate dir="$(TPMDIR)" \
		--flags "startup-clear" \
		--terminate \
		--ctrl type=unixio,path="$(TPMDIR)/sock" &
	sleep 0.5

	# The optional monitor is a host-side control channel.  Make only its
	# socket connectable by the host user; no secrets are created here.
	umask 000; \
	qemu-system-x86_64 -drive file="$(ROOT_DISK_IMG)",if=virtio \
		--machine q35,accel=kvm:tcg \
		-rtc base=utc \
		-smp 1 \
		-vga std \
		$(QEMU_DISPLAY_OPT) \
		-m "$$(cat "$(MEMORY_SIZE_FILE)")" \
		$(QEMU_SERIAL_OPT) \
		--bios "$(QEMU_BOOT_ROM)" \
		-object rng-random,filename=/dev/urandom,id=rng0 \
		-device virtio-rng-pci,rng=rng0 \
		-netdev user,id=u1 -device e1000,netdev=u1 \
		-chardev socket,id=chrtpm,path="$(TPMDIR)/sock" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-tis,tpmdev=tpm0 \
		-device qemu-xhci,id=usb \
		-device usb-tablet \
		$(QEMU_MONITOR_OPT) \
		-drive file="$(QEMU_USB_FD_IMG)",if=none,id=usb-fd-drive,format=raw \
		-device usb-storage,bus=usb.0,drive=usb-fd-drive \
		$(QEMU_USB_TOKEN_DEV) || true

	stty sane
	@echo
