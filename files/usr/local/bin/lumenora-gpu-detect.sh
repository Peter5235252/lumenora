#!/usr/bin/env bash
set -eu

marker="/var/lib/lumenora/gpu-checked"
nvidia_image="ghcr.io/peter5235252/lumenora-nvidia"
nvidia_open_image="ghcr.io/peter5235252/lumenora-nvidia-open"
state_dir="/var/lib/lumenora"
turing_id_threshold=0x1E00

if grep -q "lumenora-no-auto-gpu" /proc/cmdline; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

nvidia_line="$(lspci -nnk 2>/dev/null | grep -iE "vga compatible|3d controller" | grep -i nvidia | head -n 1 || true)"
if [[ -z "$nvidia_line" ]]; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

if bootc status 2>/dev/null | grep -qE "lumenora-nvidia"; then
    mkdir -p "$state_dir"
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

if ! bootc switch "${target}:latest"; then
    echo "Lumenora: bootc switch failed; will retry on next boot" >&2
    exit 1
fi
systemctl reboot
