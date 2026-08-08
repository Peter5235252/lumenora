# Changelog

## v0.7.1-alpha - 2026-08-08 (UNSTABLE backup build)

Version-bumped backup snapshot of the current `main` (v0.7.0-alpha + license
scope rewrite). This is the golden image for the virtual-machine / fresh
install test campaign, because it reached the Plasma Login Manager on first
boot.

**Status: UNSTABLE — may fail on reboot or first login.**

- Image keeps: GRUB2/shim restore, Lumen Plasma theming (6.7.x), OGC kernel
  `7.1.6-ogc5.1-fc44`, generated initramfs, kernel pin matching the akmods
  buildroot.
- Docs: LICENSE scope clarified (MIT covers only Lumenora's own files;
  bundled software keeps its own GPL/LGPL/Apache/proprietary licenses).

Known issue tracked from the GNOME Boxes VM run:

- First installation boots into **Plasma Login Manager** (PLM) — Fedora 44
  KDE/Kinoite replaced SDDM with PLM as the default display manager (see
  Fedora Change accepted for F44, Plasma 6.6+). Visuals (Lumen wallpaper,
  theme) load fine.
- The guest repeatedly returned to the PLM login manager instead of starting
  a Plasma session — **root-caused and fixed**. Anaconda carved a separate
  btrfs `home` subvolume and fstab-mounted it at `/home`, but it was empty:
  it shadowed the ostree `/home -> var/home` symlink, so
  `plasmalogin-helper`'s `chdir(/home/<user>)` failed and the session died.
- Fix: the image now ships `lumenora-dedup-home.service`, a first-boot unit
  that removes a shadowing empty `/home` subvolume mount from `/etc/fstab`
  (falls back to `/var/home`). Verified in the VM: login reaches Plasma.

## v0.7.0-alpha - 2026-08-08

KDE Plasma branding ("Lumen"):

- Switched to the latest KDE Plasma 6.7.x (all packages refreshed from the
  Fedora 44 updates repo at build time).
- New "Lumen" deep space blue/purple hybrid theming, applied by default:
  color scheme (`Lumen.colors`), Plasma global theme
  (`org.lumenora.lumen.desktop`), and Plasma Style (`desktoptheme/Lumen`),
  all derived from Breeze dark at build time.
- Default wallpaper: the Tarantula Nebula image shipped as the `Lumen`
  wallpaper package and wired in as the fresh-desktop default (look-and-feel
  defaults + `org.kde.image` plugin default + desktoptheme `plasmarc`).
- Snappier animations: `AnimationDurationFactor=0.5` in `kdeglobals`.
- Stock Breeze (light/dark/twilight), Breeze Classic, and the Fedora global
  themes are removed from the image so only Lumen is selectable. The Breeze
  window decoration engine stays (it follows the Lumen color scheme).
- Layout is untouched: the default Plasma panel/widget layout is preserved.

GRUB bootloader restored:

- **systemd-boot-only reverted** — the v0.6.5-alpha experiment (GRUB/shim/
  bootupd erased, `bootloader = "systemd"`) was dropped because Fedora 44's
  Anaconda installer finalizes the bootloader with GRUB2, so the image could
  not be installed from the graphical ISO (deployment wrote but the ESP was
  left empty). `files/scripts/force-systemd-boot.sh` and the
  `/usr/lib/bootc/install/00-lumenora.toml` config were removed.
- GRUB2, shim, and bootupd ship stock again, so Secure Boot works with the
  Fedora-signed shim chain and the Anaconda installer ISO flow works.
- Kernel and theming work unchanged (OGC pinned 7.1.6-ogc4.1-fc44, Lumen).

OGC kernel initramfs fix:

- The swapped-in OGC kernel shipped **no initramfs** — the kernel `%post`
  dracut run is shimmed to a no-op at build time, so deploys copied only
  `vmlinuz` to the boot partition and first boot kernel-panicked with
  `VFS: Unable to mount root fs on unknown-block(0,0)`.
- `files/scripts/swap-ogc-kernel.sh` now regenerates the initramfs
  (`dracut --add ostree --no-hostonly`) into `/usr/lib/modules/<kver>/`, so
  every deploy ships its initrd and fresh installs boot normally. Verified
  by installing the vanilla ISO in GNOME Boxes: the fix booted the deploy
  through systemd switch-root.
- Kernel pin bumped to `7.1.6-ogc5.1-fc44` to match the akmods `base: ogc`
  buildroot (kmods are keyed to that kver; the previous `ogc4.1` pin failed
  the NVIDIA variant builds with "nothing provides kernel-uname-r").

## v0.6.5-alpha - 2026-08-07

Point release of the alpha line: GRUB replaced by systemd-boot.

- **systemd-boot is now the only bootloader** — GRUB2, shim, and bootupd
  are erased from the image at build time
  (`files/scripts/force-systemd-boot.sh`), and the default install config
  (`/usr/lib/bootc/install/00-lumenora.toml`) forces
  `bootloader = "systemd"` with DPS root discovery and an ext4 root.
- The unsigned `systemd-boot-unsigned` EFI loader (matching systemd 259.8)
  is shipped in the image.
- Secure Boot is therefore off by default (no Fedora shim chain); custom
  key enrollment is future work.
- The Anaconda-based graphical installer ISO flow is paused (it expects
  GRUB); installs go through `bootc install to-disk`.
- Kernel unchanged (OGC 7.1.6-ogc4.1-fc44, version-locked).

## v0.6.1-alpha - 2026-08-07

Point release of the alpha line: gaming kernel and bootloader work.

Gaming kernel and bootloader work:

- Replaced the stock Fedora kernel with the OGC gaming kernel
  (`ghcr.io/opengamingcollective/kernel-packages-fedora`, pinned to
  `7.1.6-ogc4.1-fc44`) at build time via `files/scripts/swap-ogc-kernel.sh`;
  the stock kernel packages are erased, the OGC kernel is fetched over OCI
  and installed, and the kernel is version-locked.
- NVIDIA variant images now build their kmods against the OGC kernel with
  the akmods `base: ogc` buildroot, so modules and kernel always match.
- Documented the systemd-boot path (`bootc install to-disk
  --bootloader systemd`) alongside the default GRUB installer flow, with
  Secure Boot caveats.
- Validated locally: base and `nvidia-open` images build with the OGC
  kernel; NVIDIA kmods land in
  `/usr/lib/modules/7.1.6-ogc4.1.fc44.x86_64/extra`.

## v0.6.0-alpha - 2026-08-07

First KDE Plasma edition. Complete pivot from Hyprland to KDE Plasma:

- Base image changed to Fedora Atomic KDE Plasma (Kinoite) 44.
- Removed all Hyprland/Wayblue/ML4W dotfiles, packages, and scripts.
- Gaming stack: GameMode, MangoHud, Gamescope, Steam/Lutris/Heroic/Bottles/OBS
  flatpaks, Bazaar Store, Oh My Posh, Eza.
- Automatic GPU driver handling at first boot: NVIDIA GPUs trigger a
  `bootc switch` rebase to the matching NVIDIA driver variant; Intel/AMD use
  the built-in open drivers. Escape hatch: `lumenora-no-auto-gpu` kernel
  argument.
- Generation-aware NVIDIA selection: `lumenora-nvidia` (proprietary driver
  flavor) targeted at Maxwell, Pascal, Volta, and Turing through Ada, and
  `lumenora-nvidia-open` (open kernel flavor) for Turing and newer, chosen by
  PCI device ID (threshold `0x1E00`).
- NVIDIA variant images built with the akmods module (prebuilt kmods) so no
  runtime package layering is needed on the immutable system.
- All three images built, published, and Cosign-signed at
  `ghcr.io/peter5235252/lumenora` (+ `lumenora-nvidia`, + `lumenora-nvidia-open`),
  verified against `keys/cosign.pub`.

## v0.5.0 - 2026-08-06

Archived Hyprland/Wayblue/ML4W edition. Moved to the `legacy-hyprland`
branch; not under active development.

First public release with a graphical installer ISO.

Highlights:

- Signed, published container image at
  `ghcr.io/peter5235252/lumenora` (tags, e.g. `latest`, `44`,
  `20260806-44`), verified with Cosign.
- Graphical Anaconda installer ISO (bootc-generic-iso), attached to the
  release and uploaded as a workflow artifact.
- Rolling upstream inputs: Wayblue Hyprland `latest`, ML4W dotfiles `main`,
  latest Image Builder CLI.

Internal fixes leading to this release:

- Moved the canonical recipe to `recipes/recipe.yml` (BlueBuild only scans
  `config/` or `recipes/`); `scripts/validate.sh` and README updated.
- Moved `rebrand.sh` into `files/scripts/` (BlueBuild script module
  requirement); `Containerfile` updated.
- Fixed COPR repositories for `bazaar` store (now `kylegospo/bazaar`) and
  `swww` (added `alebastr/sway-extras`); all `fedora-44`.
- Rotated the Cosign keypair to an unencrypted key; `SIGNING_SECRET` now holds
  raw PEM and `COSIGN_PASSWORD` is unset, matching BlueBuild's signer.
- Removed the generated `.bluebuild-scripts_*` directory from tracking and
  ignored it in `.gitignore`.