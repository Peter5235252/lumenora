#!/usr/bin/env bash
set -ouex pipefail

sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release

echo "Fixing script permissions..."
find /usr/etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} +
find /usr/etc/skel/.config/ml4w/scripts/ -type f -exec chmod +x {} +
find /usr/etc/skel/.config/hypr/scripts/ -type f -exec chmod +x {} +

# User creation is intentionally left to the installer. The installer should
# collect the desired username and password through its normal customization
# flow; the image itself must not contain user credentials.
