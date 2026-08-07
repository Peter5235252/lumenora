#!/usr/bin/env bash
set -ouex pipefail

# Bring the whole image to the latest packages, most importantly the
# newest KDE Plasma (6.7.x) from the Fedora 44 updates repository.
# Kernel packages are excluded: the OGC kernel swap that runs right
# after this must still see a lower kernel version to replace.

echo "==> Updating OS packages to the latest (Plasma 6.7.x)"

if command -v dnf5 >/dev/null 2>&1; then
  dnf5 -y --refresh update --exclude='kernel*' || exit 1
else
  dnf -y --refresh update --exclude='kernel*' || exit 1
fi

PLASMA_VER="$(rpm -q --qf '%{VERSION}' plasma-desktop 2>/dev/null || echo unknown)"
echo "==> Plasma desktop version: ${PLASMA_VER}"
