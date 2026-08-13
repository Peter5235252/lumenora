#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -eu

marker="/var/lib/lumenora/gpu-checked"
failed_marker="/var/lib/lumenora/gpu-switch-failed"
hybrid_marker="/var/lib/lumenora/gpu-hybrid-laptop"
nvidia_image="ghcr.io/peter5235252/lumenora-nvidia"
nvidia_open_image="ghcr.io/peter5235252/lumenora-nvidia-open"
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
open_supported_ids=(
    1E02 1E04 1E07 1E09 1E30 1E36 1E78 1E81 1E82 1E84 1E87 1E89 1E90 1E91
    1E93 1EB0 1EB1 1EB5 1EB6 1EB8 1EC2 1EC7 1ED0 1ED1 1ED3 1EF5 1F02 1F03
    1F06 1F07 1F08 1F0A 1F0B 1F10 1F11 1F12 1F14 1F15 1F36 1F42 1F47 1F50
    1F51 1F54 1F55 1F76 1F82 1F83 1F91 1F95 1F96 1F97 1F98 1F99 1F9C 1F9D
    1F9F 1FA0 1FB0 1FB1 1FB2 1FB6 1FB7 1FB8 1FB9 1FBA 1FBB 1FBC 1FDD 1FF0
    1FF2 1FF9 20B0 20B2 20B3 20B5 20B6 20B7 20BD 20F1 20F3 20F5 20F6 20FD
    2182 2184 2187 2188 2189 2191 2192 21C4 21D1 2203 2204 2206 2207 2208
    220A 220D 2216 2230 2231 2232 2233 2235 2236 2237 2238 230E 2321 2322
    2324 2329 232C 2330 2331 2335 2339 233A 233B 2342 2348 2414 2420 2438
    2460 2482 2484 2486 2487 2488 2489 248A 249C 249D 24A0 24B0 24B1 24B6
    24B7 24B8 24B9 24BA 24BB 24C7 24C9 24DC 24DD 24E0 24FA 2503 2504 2507
    2508 2520 2521 2523 2531 2544 2560 2563 2571 2582 2584 25A0 25A2 25A5
    25A6 25A7 25A9 25AA 25AB 25AC 25AD 25B0 25B2 25B6 25B8 25B9 25BA 25BB
    25BC 25BD 25E0 25E2 25E5 25EC 25ED 25F9 25FA 25FB 2684 2685 2689 26B1
    26B2 26B3 26B5 26B9 26BA 2702 2704 2705 2709 2717 2730 2757 2770 2782
    2783 2786 2788 27A0 27B0 27B1 27B2 27B6 27B8 27BA 27BB 27E0 27FB 2803
    2805 2808 2820 2822 2838 2860 2882 28A0 28A1 28A3 28B0 28B8 28B9 28BA
    28BB 28E0 28E1 28E3 28F8 2901 2909 2941 29BB 2B85 2B87 2B8C 2BB1 2BB3
    2BB4 2BB5 2BB9 2C02 2C05 2C18 2C19 2C31 2C33 2C34 2C38 2C39 2C3A 2C58
    2C59 2C77 2C79 2D04 2D05 2D18 2D19 2D30 2D39 2D58 2D59 2D79 2D83 2D98
    2DB8 2DB9 2DD8 2DF9 2E03 2E06 2E12 2F04 2F06 2F18 2F38 2F58 3182 31C2
    31C3
)

is_open_supported() {
    local id="$1" dev
    for dev in "${open_supported_ids[@]}"; do
        if [[ "$dev" == "$id" ]]; then
            return 0
        fi
    done
    return 1
}

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
force_auto_gpu="no"
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
    echo "Lumenora: supported list; switching to ${target}:latest"
else
    # Proprietary supports every NVIDIA GPU, so an unknown device, a pre-Turing
    # GPU, or a Turing-era part NVIDIA does not list for the open modules all
    # land on the proprietary variant.
    target="$nvidia_image"
    echo "Lumenora: NVIDIA device ${device_id} is not on the open-kernel-module"
    echo "Lumenora: supported list; switching to ${target}:latest (proprietary)"
fi

# GHCR pre-flight: the runtime pull is anonymous. GHCR requires the token
# "dance" (fetch a pull token, then request the manifest with it) even for
# public packages, so replicate what podman/bootc do. Private packages reject
# the unauthenticated token request with 401. The multi-format Accept header
# is needed because `latest` resolves to an OCI image index on GHCR.
registry_check_ok=0
for ((i=1; i<=attempts; i++)); do
    token=""
    token_resp="$(curl -fsSL --retry 1 \
        "https://ghcr.io/token?scope=repository:peter5235252/${target##*/}:pull" 2>/dev/null || true)"
    if printf '%s' "$token_resp" | grep -q '"token"'; then
        token="$(printf '%s' "$token_resp" | sed -E 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    fi
    if [[ -n "$token" ]]; then
        code="$(curl -sSL -o /dev/null -w '%{http_code}' --retry 1 \
            -H "Authorization: Bearer ${token}" \
            -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json' \
            "https://ghcr.io/v2/peter5235252/${target##*/}/manifests/latest" || true)"
        if [[ "$code" == "200" ]]; then
            registry_check_ok=1
            break
        fi
    fi
    if (( i < attempts )); then
        echo "Lumenora: GHCR public-pull check for ${target} failed (attempt ${i}); retrying" >&2
        sleep "$retry_base_sleep"
    fi
done

if (( registry_check_ok != 1 )); then
    echo "Lumenora: ${target}:latest is not anonymously pullable from GHCR." >&2
    echo "Lumenora: make the '${target##*/}' package Public in GitHub package" >&2
    echo "Lumenora: settings, or check the network. Ran out of retries." >&2
    touch "$failed_marker"
    touch "$marker"
    exit 1
fi

switch_ok=0
for ((i=1; i<=attempts; i++)); do
    echo "Lumenora: bootc switch attempt ${i}/${attempts}"
    if bootc switch "${target}:latest"; then
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

echo "Lumenora: switching to ${target}:latest succeeded; rebooting"
systemctl reboot