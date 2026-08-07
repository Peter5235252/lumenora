#!/usr/bin/env bash
set -ouex pipefail

# Replace GRUB with systemd-boot as the only bootloader in the image.
#
# - systemd-boot is only supported by bootc on the composefs backend
#   (Fedora 44 Atomic default), so this targets that stack.
# - The image ships its default install config at
#   /usr/lib/bootc/install/00-lumenora.toml, forcing systemd-boot on
#   every `bootc install to-disk`; GRUB/shim/bootupd are erased so no
#   GRUB path remains anywhere.
# - The unsigned systemd-boot EFI binary comes from the
#   systemd-boot-unsigned package (matches the systemd version).

# GRUB/shim/bootupd packages present in the Fedora Atomic Kinoite base.
GRUB_PACKAGES=(
  grub2-common grub2-efi-ia32 grub2-efi-x64 grub2-pc grub2-pc-modules
  grub2-tools grub2-tools-minimal shim-ia32 shim-x64 bootupd
)

echo "==> Forcing systemd-boot and removing GRUB from the image"

# Ship the systemd-boot EFI loader (unsigned; see README Secure Boot notes).
if command -v dnf5 >/dev/null 2>&1; then
  dnf5 -y install systemd-boot-unsigned
else
  dnf -y install systemd-boot-unsigned
fi

# Default install config: systemd-boot, DPS root discovery (default with
# systemd-boot but explicit here), ext4 root (matches the installer ISO).
install -d -m 0755 /usr/lib/bootc/install
cat > /usr/lib/bootc/install/00-lumenora.toml <<'EOF'
[install]
bootloader = "systemd"
discoverable-partitions = true

[install.filesystem.root]
type = "ext4"
EOF

# Remove every GRUB/shim/bootupd package. Nothing else requires them
# (verified with dnf repoquery --whatrequires on the base image).
for pkg in "${GRUB_PACKAGES[@]}"; do
  if rpm -q "${pkg}" >/dev/null 2>&1; then
    rpm --erase "${pkg}" --nodeps
  fi
done

# Sanity check: the loader entry bootc will deploy.
if [[ ! -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ]]; then
  echo "ERROR: systemd-bootx64.efi not found after install" >&2
  exit 1
fi

echo "==> Bootloader state:"
echo "install config:"
cat /usr/lib/bootc/install/00-lumenora.toml
echo "systemd-boot EFI binaries:"
ls -l /usr/lib/systemd/boot/efi/
echo "remaining GRUB/shim/bootupd packages (should be empty):"
rpm -qa | grep -E '^(grub|shim|bootupd)' || true
