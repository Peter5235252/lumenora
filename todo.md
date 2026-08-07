# Lumenora Migration Plan

Status: OGC kernel work released as v0.6.1-alpha on `main`.

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