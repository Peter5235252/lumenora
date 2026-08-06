# Lumenora Migration Plan

Status: KDE Plasma pivot (v0.6.0-alpha) on `kde-migration` branch.

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

## Phase 3 - Hardware Detection (Fedora Atomic / bootc)
- [x] Base image stays driver-clean (Intel/AMD open drivers, no-op)
- [x] `recipes/recipe-nvidia.yml` with akmods (ublue kmods buildroot) variant
- [x] First-boot `lumenora-gpu-detect.service`: NVIDIA -> `bootc switch` + reboot
- [x] Escape hatch kernel arg `lumenora-no-auto-gpu`
- [x] NVIDIA job in `.github/workflows/build.yml`
- [x] Generation-aware selection: `lumenora-nvidia` (proprietary, pre-Turing)
      vs `lumenora-nvidia-open` (open kernel, Turing+) via PCI device ID
      threshold 0x1E00

## Release
- [x] Push kde-migration, PR into main, merge
- [ ] Fix akmods module schema error in recipe-nvidia.yml (nvidia-driver
      string + install list) and get green build of all three images
- [ ] Tag v0.6.0-alpha -> build base + nvidia images + installer ISO
- [ ] Verify: cosign both images, VM test in GNOME Boxes