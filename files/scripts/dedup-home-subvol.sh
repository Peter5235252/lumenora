#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

# Bundle a first-boot unit that drops a shadowing btrfs /home subvolume
# mount from /etc/fstab. On ostree atomic images the real home lives at
# /var/home (via the /home -> var/home symlink). If the installer carved an
# empty btrfs home subvolume and mounts it at /home, it shadows that
# symlink: plasmalogin-helper's chdir(/home/<user>) fails, so the session
# dies and Plasma Login Manager bounces straight back to the greeter.

SCRIPT=/usr/sbin/lumenora-dedup-home-subvol.sh
UNIT=/usr/lib/systemd/system/lumenora-dedup-home.service

cat > "$SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

fstab_org=/etc/fstab
fstab_new=/etc/fstab.lumenora

# Only touch the entry when /home is mounted from a btrfs subvolume
# and that mount point is empty (i.e. it shadows var/home with nothing).
if ! findmnt -n -o FSTYPE /home | grep -qx btrfs; then
    exit 0
fi

if find /home -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    exit 0
fi

awk '
!($2 == "/home" && $3 == "btrfs" && $4 ~ /subvol=/)
{ print }
' "$fstab_org" > "$fstab_new"

if ! cmp -s "$fstab_org" "$fstab_new"; then
    cp "$fstab_new" "$fstab_org"
    systemctl daemon-reload
    umount /home 2>/dev/null || true
fi
rm -f "$fstab_new"
EOS
chmod +x "$SCRIPT"

cat > "$UNIT" <<EOU
[Unit]
Description=Drop shadowing btrfs /home subvolume mount (use /var/home)
DefaultDependencies=no
After=home.mount
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=$SCRIPT

[Install]
WantedBy=multi-user.target
EOU

systemctl enable "$(basename "$UNIT" .service)"