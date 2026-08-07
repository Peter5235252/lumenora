# Lumenora Migration Plan

Status: GRUB bootloader restored + Lumen Plasma theming on `main` (unreleased).

## Phase 7 - GRUB restore + ISO/VM test (unreleased)
- [x] Diagnose failed mid-install (Boxes): full deployment written, ESP left
      empty — Fedora 44 Anaconda finalizes the bootloader with GRUB2, which
      the systemd-boot-only image removed
- [x] Revert to GRUB: remove `force-systemd-boot.sh` from all recipes, delete
      script + `00-lumenora.toml`; grub2/shim/bootupd ship stock again
      (Secure Boot + Anaconda ISO path work again)
- [ ] Local rebuild base + validate grub restored (no systemd-boot-unsigned,
      no 00-lumenora.toml), OGC kernel + Lumen intact
- [ ] Push to main + green Actions build
- [ ] Build fresh installer ISO from the reverted image
- [ ] Install ISO in GNOME Boxes (user session; pkexec Boxes segfaults)
- [ ] VM sanity check: Lumen theme, nebula wallpaper, Plasma 6.7.4,
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
- [ ] Track kernel pin drift: bump `OGC_KERNEL_TAG` when OGC releases a
      new 7.1.x kernel build

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