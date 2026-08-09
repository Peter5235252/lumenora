#!/usr/bin/env bash

set -euo pipefail

# Make fish the default login shell.
#   1) /etc/default/useradd -> future useradd-created users
#   2) one-shot systemd unit -> users created at install time by Anaconda,
#      re-parented to fish on first boot
# Fastfetch output on interactive fish start is handled by the skel
# dotfiles (files/etc/skel/.config/fish/conf.d/30-autostart.fish).
#
# The first-boot script also canonicalizes each human user's home directory
# to the physical /var/home/<user> path (Fedora Atomic convention). If the
# passwd entry keeps the symlinked /home/<user>, a session that starts at
# /var/home/<user> renders /v/h/<user> in the prompt instead of "~" because
# fish only abbreviates $HOME when PWD starts with it.
#
# It additionally pins the Lumen look (color scheme + look-and-feel) on every
# human account: homes created before the stock Plasma themes were dropped
# reference the removed "org.kde.breeze.desktop", and Plasma's fallback to
# the embedded LIGHT Breeze renders black text over the dark UI.

# --- 1. Default for future useradd calls --------------------------------
USERADD_DEF=/etc/default/useradd
touch "$USERADD_DEF"
if grep -q '^SHELL=' "$USERADD_DEF"; then
    sed -i 's|^SHELL=.*|SHELL=/usr/bin/fish|' "$USERADD_DEF"
else
    printf 'SHELL=/usr/bin/fish\n' >> "$USERADD_DEF"
fi

# --- 2. First-boot one-shot that flips existing accounts -----------------
SERVICE=/usr/lib/systemd/system/lumenora-fish-default.service
SCRIPT=/usr/libexec/lumenora-fish-default.sh

cat > "$SCRIPT" <<'EOS'
#!/usr/bin/bash
set -euo pipefail

[ -x /usr/bin/fish ] || exit 0

# shellcheck disable=SC2044
for pw in $(getent passwd); do
    user="${pw%%:*}"
    uid=$(awk -F: '{print $3}' <<<"$pw")
    shell=$(awk -F: '{print $7}' <<<"$pw")
    # interactive human users only, and only when not already fish
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] && [ "$shell" != "/usr/bin/fish" ]; then
        chsh -s /usr/bin/fish "$user" || true
    fi
    # canonicalize the home dir to physical /var/home/<user> so the fish
    # prompt (and everything else) shows "~" instead of /v/h/...
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
        realhome=$(realpath -m "/var/home/$user" 2>/dev/null || true)
        passwdhome=$(awk -F: '{print $6}' <<<"$pw")
        if [ -n "$realhome" ] && [ "$realhome" != "$passwdhome" ] && [ -d "$realhome" ]; then
            usermod -d "$realhome" "$user" || true
        fi
    fi
    # Force the Lumen look on accounts whose home pre-dates the theming:
    # those born before the stock themes were dropped carry a kdeglobals
    # pointing at the now-removed org.kde.breeze.desktop, and Plasma then
    # falls back to the embedded LIGHT Breeze — black text over the dark
    # chrome, unreadable everywhere. Pin scheme + look-and-feel, drop the
    # stale hash so the white foregrounds get regenerated.
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
        home=$(awk -F: '{print $6}' <<<"$pw")
        if [ -d "$home" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
            export HOME="$home" XDG_CONFIG_HOME="$home/.config"
            kwriteconfig6 --file kdeglobals --group General --key ColorScheme "Lumen" || true
            kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "org.lumenora.lumen.desktop" || true
            kwriteconfig6 --file kdeglobals --group General --unset ColorSchemeHash || true
        fi
    fi
done

systemd-notify --ready 2>/dev/null || true
EOS
chmod +x "$SCRIPT"

cat > "$SERVICE" <<EOU
[Unit]
Description=Set fish as the default login shell
DefaultDependencies=no
After=local-fs.target
Before=systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=$SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOU

systemctl enable "$(basename "$SERVICE" .service)"