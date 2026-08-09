Status: v0.8.0-beta.1 current (FIRST BETA). Black-text root cause closed
(missing ForegroundNormal keys in View/Complementary/Tooltip -> KDE default
#232629); whitelist + per-section asserts added; version bumps clear stale
theme caches; base image verified live in the VM (light text in apps, panels,
decorations, PLM greeter with blurred nebula). NVIDIA variants (lumenora-nvidia
/ lumenora-nvidia-open) compile but are UNTESTED — flagged in README, CHANGELOG
 and release notes; next priority is validating them on NVIDIA hardware.

## Phase 10 - Beta 1 (released v0.8.0-beta.1)
- [x] REBASE VM onto the fixed image and confirm light text post-reboot
- [x] NVIDIA-untested warning added to README + CHANGELOG + release notes
- [ ] Validate lumenora-nvidia / lumenora-nvidia-open on real NVIDIA hardware
      (open vs proprietary per-GPU selection not yet exercised)

Status: v0.7.5-alpha (rev 2) — MORE dark text found: the "force pure-white
foregrounds" pass in lumen-theme.sh was a NO-OP (regex matched only the
[Colors:...] header line, never the Foreground keys). Rev 2 rebuilds
Lumen.colors line-by-line (all Foreground*=#ffffff, Link/Visited/Active
lightened blue/purple #a3c4ff/#c9a8ff/#c9a8ff) + hard whitelist assert, so
build FAILS if any dark foreground survives. Also ships a blurred nebula for
the PLM greeter and Anaconda installer, and forces full white text in the
Anaconda GTK UI.
TODO next session: open /tmp/opencode/lumen-fixed.png (and/or boot the VM to
tty1/lock screen) to visually confirm the fixed session; then close out this
alpha.

## Phase 9 - White text everywhere + blurred nebula surfaces (unreleased)
- [x] ROOT CAUSE (rev 2): `lumen-theme.sh` "force white" heredoc regex
      `(?ms)^\[Colors:Window\].*?(?=^\[|$)` matches only the section header
      line — inner Foreground rewrite never fires. Verified by reproducing
      the pass standalone: output unchanged (#e9e7f5 / #a7a1c9 / dark keys
      survive in Lumen.colors AND in every derived copy).
- [x] REBUILT the pass: line-by-line rewrite, every `Foreground*` ->
      `#ffffff`; accents (Link/Visited/Active) keep blue/purple hue but
      lightened to #a3c4ff/#c9a8ff/#c9a8ff (visible on #14102a).
- [x] HARD ASSERT: whitelist check after the pass (only #ffffff + the three
      lightened accents allowed; ForegroundNormal must be pure white) —
      build exits 1 on any dark foreground, so this can't regress silently.
- [x] Blurred nebula: `nebula-blurred.jpg` (GaussianBlur r=90, ~80%
      brightness) added to the Lumen wallpaper package; PLM greeter
      (/etc/plasmalogin.conf.d + /usr/lib/plasmalogin/defaults.conf) now
      points Image/PreviewImage at it.
- [x] Anaconda installer: `installer-background.png` (blur r=120, 55%
      brightness) as full-window background-image in anaconda-gtk.css with
      background-size:cover; every widget scope forced `color:#ffffff`
      (labels, buttons, entries, combos, treeviews, switches, spinners);
      links/emphasized labels lightened to #cfc9e8; disabled text #cfc9e8.
- [ ] Rebuild all three images + green CI, rebase VM, verify on-disk every
      Foreground* in color-schemes/desktoptheme is white/lightened.
- [ ] Rebuild installer ISO, boot in Boxes, confirm blurred nebula + white
      text on first screen.

Status: v0.7.4-alpha current — PLM greeter wallpaper fixed + kernel pin bumped; approaching beta.

## Phase 8 - Lumen-only theme + white-text fix (unreleased)
- [ ] **VISUAL CONFIRMATION PENDING**: caccd50 rebuilt with the real fix;
      VM rebased, session running Lumen, screenshot saved at
      /tmp/opencode/lumen-fixed.png. Check the greeter AND the logged-in
      desktop for black text / dark backgrounds.
- [x] ROOT CAUSE FOUND (KDE docs): "The Id entry should match the name of
      the theme folder name." Our look-and-feel folder is
      org.lumenora.lumen.desktop but metadata.json declared Id
      "org.lumenora.lumen" -> KPackage cannot load the global theme, Plasma
      falls back to stock light Breeze (black text) and even rewrote user
      config to LookAndFeelPackage=org.kde.breezedark.desktop (deleted).
- [x] FIXED: LAF metadata Id -> org.lumenora.lumen.desktop (matches folder),
      Version bumped on LAF + Lumen desktoptheme so Plasma drops its mashed
      caches (KDE: "update Version so Plasma refreshes its cache").
- [x] "default" desktoptheme shipped with NO colors file -> any widget
      missing an SVG in the thin Lumen theme falls back to it with the stock
      LIGHT palette (dark text). FIXED: default/colors = copy of the
      white-forced Lumen.colors + version bump.
- [x] Remove Welcome Center (plasma-welcome + plasma-welcome-fedora) from all
      three recipes
- [x] Force every Foreground* to pure white in Lumen.colors BEFORE any derived
      copy (desktoptheme colors, BreezeLight/BreezeDark regenerations, LAF) so
      white text is baked into every lookup (apps, panels, tooltips, greeter)
- [x] Keep Lumen as the ONLY global theme + desktop theme; delete stock
      org.kde.breeze* / org.fedoraproject.fedora* looks and breeze-dark/light
      desktop themes; rebuild BreezeLight/BreezeDark color names on the Lumen
      palette (PLM greeter + Breeze consumers reference them by name)
- [x] First-boot `lumenora-fish-default` pins ColorScheme=Lumen +
      LookAndFeelPackage=org.lumenora.lumen.desktop on every human account
      (kdeglobals no longer points at the deleted org.kde.breeze.desktop)
- [x] Fix the pinning script: iterate getent passwd line-by-line (word-split
      broke on GECOS names with spaces) and use kwriteconfig6 --delete
      (--unset does not exist)
- [x] Kill the revert loop: Plasma re-resolves look-and-feel every login via
      AutomaticLookAndFeel=true and lands on the deleted system default.
      Set AutomaticLookAndFeel=false in per-account kdeglobals AND system-wide
      (skel profile + /etc/xdg/kdeglobals, created if missing)
- [x] VM rebase + reboot: config survives the live Plasma session
      (ColorScheme=Lumen, AutomaticLookAndFeel=false, LAF=Lumen, hash
      regenerated by Plasma is harmless; only Lumen/*.colors schemes remain,
      all foregrounds #ffffff/#e9e7f5)

Status: v0.7.3-alpha released (debloat round).

## Phase 7 - GRUB restore + ISO/VM test (unreleased)
- [x] Diagnose failed mid-install (Boxes): full deployment written, ESP left
      empty — Fedora 44 Anaconda finalizes the bootloader with GRUB2, which
      the systemd-boot-only image removed
- [x] Revert to GRUB: remove `force-systemd-boot.sh` from all recipes, delete
      script + `00-lumenora.toml`; grub2/shim/bootupd ship stock again
      (Secure Boot + Anaconda ISO path work again)
- [x] Local rebuild base + validate grub restored (no systemd-boot-unsigned,
      no 00-lumenora.toml), OGC kernel + Lumen intact
- [x] Push to main + green Actions build
- [x] Build fresh installer ISO from the reverted image
- [x] Install vanilla ISO in GNOME Boxes — install **succeeded** but first
      boot **kernel-panicked** (`VFS: Unable to mount root fs on
      unknown-block(0,0)`). Root cause: the OGC kernel ships no initramfs
      (dracut `%post` shimmed to a no-op at build), so deploy boot has no
      `initrd` line. Fix: `files/scripts/swap-ogc-kernel.sh` regens the
      initramfs (`dracut --add ostree --no-hostonly`). Verified by injecting
      a manually-built initramfs into the stalled VM: it then booted through
      systemd switch-root.
- [x] Tag v0.7.0-alpha + release notes (all fix CI builds green).
- [x] VM sanity check: Lumen theme, nebula wallpaper, Plasma 6.7.4,
      OGC 7.1.6-ogc4.1 kernel, GRUB boot, Secure Boot shim intact

## Phase 6 - KDE Plasma branding "Lumen" (unreleased)
- [x] Latest KDE Plasma 6.7.x via `files/scripts/update-os.sh` (update step)
- [x] `Lumen` deep-space blue/purple theme: color scheme, global theme
      (`org.lumenora.lumen.desktop`), Plasma Style (`desktoptheme/Lumen`),
      baked from Breeze dark at build time (`files/scripts/lumen-theme.sh`)
- [x] Tarantula Nebula default wallpaper as `Lumen` wallpaper kpackage
      (`files/usr/share/wallpapers/Lumen`), wired as the fresh-desktop default
- [x] Snappier animations (`AnimationDurationFactor=0.5`)
- [x] Stock Breeze (light/dark/twilight) + Breeze Classic + Fedora global
      themes removed so only Lumen is selectable; layout untouched
- [x] New-user defaults via skel `kdeglobals`/`plasmarc` + kde-profile
- [x] Local build validation: Plasma >= 6.7.4, Lumen present, stock themes
      gone, wallpaper default set, OGC kernel + systemd-boot intact
- [x] Local build validation: Plasma >= 6.7.4, Lumen present, stock themes
      gone, wallpaper default set, OGC kernel intact
- [x] Push to main + green Actions build (all 3 images, 2026-08-07)
- [x] Fresh installer ISO for the systemd-boot image built and downloaded —
      install failed mid-install; diagnosed as the Anaconda/GRUB2 finalize
      blocker (ESP empty) → reverted to GRUB (Phase 7)

## Phase 5 - systemd-boot only (v0.6.5-alpha) — REVERTED on main
- [x] `files/scripts/force-systemd-boot.sh`: install `systemd-boot-unsigned`,
      write `/usr/lib/bootc/install/00-lumenora.toml`
      (`bootloader = "systemd"`, DPS, ext4 root), erase grub2-*/shim-*/bootupd
- [x] Wire script into all three recipes (after swap-ogc-kernel.sh)
- [x] Validate locally: config present, no grub/shim/bootupd left,
      systemd-bootx64.efi present, kernel still OGC, builds green
- [x] Push to main, green Actions build, cosign verify all three images
- [x] Tag v0.6.5-alpha + release notes (no ISO: Anaconda flow paused)
- [x] ~~Revisit installer ISO for systemd-boot~~ — superseded: the
      Anaconda/GRUB2 incompatibility (ESP left empty mid-install) led to the
      **permanent revert to GRUB** (Phase 7)

## Phase 4 - Gaming kernel and bootloader (v0.6.1-alpha)
- [x] Research OGC kernel + akmods compat (akmods `base: ogc` buildroot)
- [x] `files/scripts/swap-ogc-kernel.sh`: pin `7.1.6-ogc4.1-fc44`, erase
      stock kernel, fetch OGC kernel over OCI (skopeo), extract RPM layers,
      install + versionlock
- [x] Validate locally: base + `nvidia-open` build with OGC kernel and
      matching NVIDIA kmods in `/usr/lib/modules/7.1.6-ogc4.1.fc44.x86_64/extra`
- [x] Document systemd-boot path (`bootc install to-disk --bootloader systemd`)
      + Secure Boot caveats; README/CHANGELOG/todo updated
- [x] Push to main, green Actions build of all three images (incl. the
      `nvidia` proprietary flavor akmods `base: ogc`): kernel swapped
      (7.1.6-ogc4.1) in all, kmod-nvidia rpms keyed to the OGC kver
      (proprietary 580.173.02, open 610.43.03), all three cosign-verified
      against keys/cosign.pub (2026-08-07)
- [ ] Tag v0.6.1-alpha -> fresh installer ISO with OGC-kernel payload,
      attached to the release
- [x] Track kernel pin drift: bump `OGC_KERNEL_TAG` when OGC releases a
      new 7.1.x kernel build — bumped to `7.1.6-ogc5.1-fc44` (akmods
      `base: ogc` kmods now keyed to that kver)

## Phase 3 - Hardware Detection (Fedora Atomic / bootc)
- [x] Move v0.5.0 Hyprland cut to `legacy-hyprland` branch
- [x] Publish v0.5.0 release as the archived Hyprland edition
- [x] README: prominent EARLY ALPHA banner + KDE rewrite
- [x] `todo.md` created (this file)

## Phase 1 - Git and Documentation
- [x] Move v0.5.0 Hyprland cut to `legacy-hyprland` branch
- [x] Publish v0.5.0 release as the archived Hyprland edition
- [x] README: prominent EARLY ALPHA banner + KDE rewrite
- [x] `todo.md` created (this file)

## Phase 2 - Desktop Environment Migration
- [x] Swap base to KDE Plasma (kinoite:44)
- [x] Remove all Hyprland and ML4W files/packages/scripts
- [x] Add gaming stack: gamescope, mangohud, gamemode, eza, flatpaks (Steam/Lutris/Heroic/Bottles/OBS)
- [x] KDE dotfiles: kwinrc, MangoHud.conf, gamemode.ini, cleaned shell configs
- [x] Rebrand script reworked; Containerfile mirrored

- [x] Generation-aware selection: `lumenora-nvidia` (proprietary, pre-Turing)
      vs `lumenora-nvidia-open` (open kernel, Turing+) via PCI device ID
      threshold 0x1E00

## Release
- [x] Push kde-migration, PR into main, merge
- [x] Fix akmods module schema error in recipe-nvidia.yml (nvidia-driver
      string + install list) and get green build of all three images
- [x] Cosign verify all three published images (lumenora, lumenora-nvidia,
      lumenora-nvidia-open) against keys/cosign.pub
- [x] Tag v0.6.0-alpha -> installer ISO + GitHub release
      (release published 2026-08-07; ISO uploaded as workflow artifact
      `lumenora-installer-iso`, ~4.2 GB)
- [ ] Download the installer ISO artifact and attach it to the v0.6.0-alpha
      release (artifact expires 2026-11-05) — superseded by the fresh
      v0.6.1-alpha ISO
- [ ] VM test in GNOME Boxes (base + nvidia-open)