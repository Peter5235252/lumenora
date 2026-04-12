#!/usr/bin/env bash
set -ouex pipefail

# 1. Rebrand
sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release

# 2. Fix Permissions for ML4W
# We target /usr/etc/skel because that's where BlueBuild puts them
echo "Fixing script permissions..."
find /usr/etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} +
find /usr/etc/skel/.config/ml4w/scripts/ -type f -exec chmod +x {} +
find /usr/etc/skel/.config/hypr/scripts/ -type f -exec chmod +x {} +

# 3. Create a default user automatically (User: lumen | Pass: lumen)
# This makes it truly "Plug and Play"
if ! getent passwd lumen > /dev/null; then
    useradd -m -G wheel -p $(openssl passwd -1 lumen) lumen
fi
