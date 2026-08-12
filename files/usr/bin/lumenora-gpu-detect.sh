#!/usr/bin/env bash
set -eu

marker="/var/lib/lumenora/gpu-checked"
failed_marker="/var/lib/lumenora/gpu-switch-failed"
nvidia_image="ghcr.io/peter5235252/lumenora-nvidia"
nvidia_open_image="ghcr.io/peter5235252/lumenora-nvidia-open"
state_dir="/var/lib/lumenora"
turing_id_threshold=1e00
# bootc switch pulls the variant image from the registry; give transient
# registry failures (e.g. truncated layer downloads) a few retries.
attempts=3
retry_base_sleep=10

# Opt out: lumenora-no-auto-gpu on the kernel command line disables the
# whole self-selection mechanism.
if grep -q "lumenora-no-auto-gpu" /proc/cmdline; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

mkdir -p "$state_dir"

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

nvidia_line="$(lspci -nnk 2>/dev/null | grep -iE "vga compatible|3d controller" | grep -i nvidia | head -n 1 || true)"
if [[ -z "$nvidia_line" ]]; then
    echo "Lumenora: no NVIDIA GPU detected; staying on the base image"
    touch "$marker"
    exit 0
fi

if bootc status 2>/dev/null | grep -qE "lumenora-nvidia"; then
    echo "Lumenora: already on an NVIDIA variant; nothing to do"
    touch "$marker"
    exit 0
fi

device_id="$(echo "$nvidia_line" | grep -oE "\[10de:[0-9a-fA-F]{4}\]" | head -n 1 | sed -E 's/\[10de://; s/\]//')"
if [[ -z "$device_id" ]]; then
    device_id="0000"
fi
device_id="$(echo "$device_id" | tr '[:upper:]' '[:lower:]')"

if (( 16#$device_id >= 16#$turing_id_threshold )); then
    target="$nvidia_open_image"
    echo "Lumenora: NVIDIA Turing or newer GPU detected (device $device_id), switching to ${target}:latest"
else
    target="$nvidia_image"
    echo "Lumenora: pre-Turing NVIDIA GPU detected (device $device_id), switching to ${target}:latest"
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
