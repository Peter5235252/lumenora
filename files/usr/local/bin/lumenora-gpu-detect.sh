#!/usr/bin/env bash
set -eu

marker="/var/lib/lumenora/gpu-checked"
nvidia_image="ghcr.io/peter5235252/lumenora-nvidia"
state_dir="/var/lib/lumenora"

if grep -q "lumenora-no-auto-gpu" /proc/cmdline; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

if ! lspci -nnk 2>/dev/null | grep -iE "vga compatible|3d controller" | grep -qi nvidia; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

if bootc status 2>/dev/null | grep -q "lumenora-nvidia"; then
    mkdir -p "$state_dir"
    touch "$marker"
    exit 0
fi

echo "Lumenora: NVIDIA GPU detected, switching to ${nvidia_image}:latest"
if ! bootc switch "${nvidia_image}:latest"; then
    echo "Lumenora: bootc switch failed; will retry on next boot" >&2
    exit 1
fi
systemctl reboot
