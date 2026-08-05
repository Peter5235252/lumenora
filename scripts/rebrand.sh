#!/usr/bin/env bash
set -ouex pipefail

skel_dir="/usr/etc/skel"
if [[ ! -d "$skel_dir" ]]; then
    skel_dir="/etc/skel"
fi

ml4w_tmp="$(mktemp -d)"
trap 'rm -rf "$ml4w_tmp"' EXIT

echo "Syncing ML4W rolling dotfiles from upstream main..."
curl -fsSL https://github.com/mylinuxforwork/dotfiles/archive/refs/heads/main.tar.gz | tar -xz -C "$ml4w_tmp"
cp -a "$ml4w_tmp/dotfiles-main/dotfiles/." "$skel_dir/"

sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release

echo "Fixing script permissions..."
find "$skel_dir/.config/" -type f -name "*.sh" -exec chmod +x {} +
find "$skel_dir/.config/ml4w/scripts/" -type f -exec chmod +x {} +
find "$skel_dir/.config/hypr/scripts/" -type f -exec chmod +x {} +

# User creation is intentionally left to the installer. The installer should
# collect the desired username and password through its normal customization
# flow; the image itself must not contain user credentials.
