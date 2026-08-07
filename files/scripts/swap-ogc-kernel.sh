#!/usr/bin/env bash
set -ouex pipefail

# Swap the stock Fedora kernel for the OGC (Open Gaming Collective) gaming
# kernel, matching the kver that ghcr.io/ublue-os/akmods:ogc-44 kmods are
# built against. The akmods module must run AFTER this script (with
# `base: ogc`) so NVIDIA kmods match this exact kernel version.
#
# To bump the kernel: update OGC_KERNEL_TAG below to the desired
# `linux-*-ogc*` release, and confirm the matching akmods ogc buildroot
# exists for the same kver (skopeo inspect ghcr.io/ublue-os/akmods:ogc-44).
OGC_KERNEL_TAG="7.1.6-ogc4.1-fc44"
OGC_REGISTRY="ghcr.io/opengamingcollective/kernel-packages-fedora"
KERNEL_DIR="/tmp/ogc-kernel"
FEDORA_VERSION="$(rpm -E %fedora)"

# The OGC kernel OCI is a set of raw RPM blobs (one layer per RPM).
fetch_ogc_kernel() {
  echo "Fetching OGC kernel ${OGC_KERNEL_TAG} from ${OGC_REGISTRY}"
  skopeo copy --retry-times 5 --retry-delay 5s \
    "docker://${OGC_REGISTRY}:${OGC_KERNEL_TAG}" "dir:${KERNEL_DIR}"
}

# One layer per RPM; the header embeds the NEVRA as the first string.
detect_rpm_name() {
  strings -n 6 "$1" | grep -m 1 -E '^(kernel|linux)' || true
}

extract_rpms() {
  mkdir -p "${KERNEL_DIR}/rpms"
  local digest name
  while read -r digest; do
    name="$(detect_rpm_name "${KERNEL_DIR}/${digest}")"
    # Skip source RPMs and anything that is not the kernel package set
    if [[ -z "${name}" || "${name}" == *".src.rpm" ]]; then
      continue
    fi
    cp "${KERNEL_DIR}/${digest}" "${KERNEL_DIR}/rpms/${name}.rpm"
  done < <(jq -r '.layers[].digest' "${KERNEL_DIR}/manifest.json" | cut -d : -f 2)
  ls -1 "${KERNEL_DIR}/rpms"
}

# Kernel %post scripts would try to run dracut/rpm-ostree inside the build
# container; shim them out for the duration of this transaction (Bazzite's
# install-kernel-akmods approach).
shim_kernel_install_hooks() {
  local hook
  for hook in /usr/lib/kernel/install.d/05-rpmostree.install \
              /usr/lib/kernel/install.d/50-dracut.install; do
    if [[ -f "${hook}" && ! -f "${hook}.bak" ]]; then
      mv "${hook}" "${hook}.bak"
      printf '#!/bin/sh\nexit 0\n' > "${hook}"
      chmod +x "${hook}"
    fi
  done
}

restore_kernel_install_hooks() {
  local hook
  for hook in /usr/lib/kernel/install.d/05-rpmostree.install \
              /usr/lib/kernel/install.d/50-dracut.install; do
    if [[ -f "${hook}.bak" ]]; then
      mv -f "${hook}.bak" "${hook}"
    fi
  done
}

remove_stock_kernel() {
  local pkg
  for pkg in kernel kernel-core kernel-modules kernel-modules-core \
             kernel-modules-extra kernel-tools kernel-tools-libs \
             kernel-devel kernel-devel-matched; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
      rpm --erase "${pkg}" --nodeps
    fi
  done
  # Clean leftovers not covered by the kernel-* packages
  rm -rf /usr/lib/modules
}

install_ogc_kernel() {
  if command -v dnf5 >/dev/null 2>&1; then
    dnf5 -y install "${KERNEL_DIR}"/rpms/*.rpm
  else
    dnf -y install "${KERNEL_DIR}"/rpms/*.rpm
  fi
}

lock_kernel_version() {
  if command -v dnf5 >/dev/null 2>&1; then
    dnf5 versionlock add \
      kernel kernel-devel kernel-devel-matched kernel-core kernel-modules \
      kernel-headers kernel-tools kernel-tools-libs || \
      echo "WARNING: dnf5 versionlock failed; kernel is not version-pinned"
  fi
}

echo "==> Swapping stock kernel for OGC ${OGC_KERNEL_TAG} (Fedora ${FEDORA_VERSION})"
shim_kernel_install_hooks
remove_stock_kernel
fetch_ogc_kernel
extract_rpms
install_ogc_kernel
lock_kernel_version
restore_kernel_install_hooks

echo "==> Installed kernels:"
rpm -q kernel kernel-core kernel-modules kernel-devel kernel-devel-matched kernel-headers kernel-tools || true
