#!/usr/bin/env bash
set -ouex pipefail

skel_dir="/usr/etc/skel"
if [[ ! -d "$skel_dir" ]]; then
    skel_dir="/etc/skel"
fi

sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release

echo "Fixing script permissions..."
find "$skel_dir/.config/" -type f -name "*.sh" -exec chmod +x {} +

echo "Preparing Lumenora runtime state directory..."
mkdir -p /var/lib/lumenora

# User creation is intentionally left to the installer. The installer should
# collect the desired username and password through its normal customization
# flow; the image itself must not contain user credentials.
