#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -eu

source /usr/lib/lumenora/gpu-common.sh

marker="/var/lib/lumenora/gpu-checked"
failed_marker="/var/lib/lumenora/gpu-switch-failed"
hybrid_marker="/var/lib/lumenora/gpu-hybrid-laptop"
state_dir="/var/lib/lumenora"
# bootc switch pulls the variant image from the registry; give transient
# registry failures (e.g. truncated layer downloads) a few retries.
attempts=3
retry_base_sleep=10

# Devices on this list are the ones NVIDIA's own open GPU kernel modules
# documentation ("open-gpu-kernel-modules" README, Compatible GPUs table,
# v610.57.04) confirms as supported by the open kernel modules — Turing and
# newer. Every NVIDIA GPU that NVIDIA does list there keeps its own vendor
# subsystem caveats; the device ID alone is the discriminator we support here.
#
# Any NVIDIA GPU not on this list — including pre-Turing (Maxwell, Pascal,
# Volta), specific Turing-era mobile/Quadro parts, and unknown-only-by-ID
# devices — falls back to the proprietary driver image, which NVIDIA supports
# on all NVIDIA GPUs. This avoids a flat numeric ">= 0x1E00" boundary that
# misclassifies devices; we opt IN to the open flavor only for device IDs
# NVIDIA explicitly supports.
#
# Source: https://github.com/NVIDIA/open-gpu-kernel-modules/blob/main/README.md
# (Compatible GPUs table, retrieved 2026-08). Keep this list in sync when a
# driver release adds support for new device IDs.

# Opt out: lumenora-no-auto-gpu on the kernel command line disables the
# whole self-selection mechanism (stays on the base image forever).
if grep -q "lumenora-no-auto-gpu" /proc/cmdline; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

mkdir -p "$state_dir"

# Override: lumenora-force-auto-gpu forces the switch even on a hybrid
# multi-GPU laptop, where the automatic path stays conservative by default.
force_auto_gpu="${LUMENORA_FORCE_AUTO_GPU:-no}"
if grep -q "lumenora-force-auto-gpu" /proc/cmdline; then
    force_auto_gpu="yes"
fi

# Single flight: the service is oneshot, but two invocations can still race
# (reboot during a second boot cycle). flock makes the switch exclusive.
exec 9>"${state_dir}/gpu-switch.lock"
flock -n 9 || { echo "Lumenora: another GPU switch is already running" >&2; exit 0; }

# A previous switch failed all its attempts: don't retry forever on every
# boot. Leave a marker and the log for the user to act on, while still
# booting the base image normally.
if [[ -e "$failed_marker" ]]; then
    echo "Lumenora: GPU auto-switch previously failed; see $failed_marker" >&2
    exit 1
fi

# Enumerate every display controller (VGA-compatible and 3D controllers), not
# just the first one. This is what lets us detect hybrid multi-GPU laptops.
controllers="$(lspci -nnk 2>/dev/null | grep -iE "vga compatible|3d controller" || true)"
if [[ -z "$controllers" ]]; then
    echo "Lumenora: no VGA/3D controllers found; staying on the base image"
    touch "$marker"
    exit 0
fi

nvidia_controllers="$(printf '%s\n' "$controllers" | grep -i "\[10de:" || true)"
if [[ -z "$nvidia_controllers" ]]; then
    echo "Lumenora: no NVIDIA GPU detected; staying on the base image"
    touch "$marker"
    exit 0
fi

if bootc status 2>/dev/null | grep -qE "lumenora-nvidia"; then
    echo "Lumenora: already on an NVIDIA variant; nothing to do"
    touch "$marker"
    exit 0
fi

# Hybrid-graphics laptop trap: when an Intel/AMD (or other) controller sits
# alongside the NVIDIA GPU, the initial display pipeline is usually driven by
# the iGPU and the system is an Optimus/PRIME hybrid. A blind hard `bootc
# switch` + reboot here can black-screen such machines. Stay conservative on
# the base image and let the user rebase manually, unless the override
# kernel argument is present.
non_nvidia_controllers="$(printf '%s\n' "$controllers" | grep -vi "\[10de:" || true)"
if [[ -n "$non_nvidia_controllers" && "$force_auto_gpu" != "yes" ]]; then
    echo "Lumenora: hybrid Intel/AMD + NVIDIA graphics detected; not auto-switching" >&2
    echo "Lumenora: staying on the base image (iGPU drives the display). To" >&2
    echo "Lumenora: use the NVIDIA GPU on this laptop, rebase manually, e.g.:" >&2
    echo "Lumenora:   sudo bootc switch ${nvidia_image}:latest" >&2
    echo "Lumenora:   sudo bootc switch ${nvidia_open_image}:latest" >&2
    echo "Lumenora: To force the automatic switch anyway, add the kernel arg" >&2
    echo "Lumenora: 'lumenora-force-auto-gpu' and remove:" >&2
    echo "Lumenora:   ${marker} ${hybrid_marker}" >&2
    printf 'Hybrid laptop detected %s\nNVIDIA controller still present.\nManual rebase required.\n' \
        "$(date -Is)" > "${hybrid_marker}"
    touch "$marker"
    exit 0
fi

nvidia_line="$(printf '%s\n' "$nvidia_controllers" | head -n 1)"
device_id="$(printf '%s\n' "$nvidia_line" | grep -oE "\[10de:[0-9a-fA-F]{4}\]" | head -n 1 | sed -E 's/\[10de://; s/\]//')"
if [[ -z "$device_id" ]]; then
    # No PCI ID in the line: fall back to the proprietary driver, which is
    # the safest choice when we cannot identify the device at all.
    device_id="0000"
fi
device_id="$(printf '%s\n' "$device_id" | tr '[:lower:]' '[:upper:]')"

if is_open_supported "$device_id"; then
    target="$nvidia_open_image"
    echo "Lumenora: NVIDIA device ${device_id} is on NVIDIA's open-kernel-module"
    echo "Lumenora: supported list; switching to ${target}"
else
    # Proprietary supports every NVIDIA GPU, so an unknown device, a pre-Turing
    # GPU, or a Turing-era part NVIDIA does not list for the open modules all
    # land on the proprietary variant.
    target="$nvidia_image"
    echo "Lumenora: NVIDIA device ${device_id} is not on the open-kernel-module"
    echo "Lumenora: supported list; switching to ${target}:latest (proprietary)"
fi

# Verify the signed image and resolve its manifest to an immutable digest before switching.
resolved_target=""
if ! resolved_target="$(verify_and_resolve_image "$target")"; then
    echo "Lumenora: signature or digest verification failed for $target." >&2
    touch "$failed_marker"
    touch "$marker"
    exit 1
fi
echo "Lumenora: verified $target as $resolved_target"

switch_ok=0
for ((i=1; i<=attempts; i++)); do
    echo "Lumenora: bootc switch attempt ${i}/${attempts} ($resolved_target)"
    if bootc switch "$resolved_target"; then
        switch_ok=1
        break
    fi
    if (( i < attempts )); then
        retry_sleep=$((retry_base_sleep * i))
        echo "Lumenora: bootc switch attempt ${i} failed; retrying in ${retry_sleep}s" >&2
        sleep "$retry_sleep"
    fi
done

if (( switch_ok != 1 )); then
    echo "Lumenora: bootc switch failed after ${attempts} attempts" >&2
    touch "$failed_marker"
    touch "$marker"
    exit 1
fi

echo "Lumenora: switching to $resolved_target succeeded; rebooting"
systemctl reboot
