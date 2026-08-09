# Lumenora

> **EARLY ALPHA**
>
> Lumenora is an early alpha. Expect bugs, stability issues, and missing
> features. It is not recommended as a daily driver yet. Test it in a VM
> before using it on real hardware.

[![GitHub release](https://img.shields.io/github/v/release/peter5235252/lumenora)](https://github.com/peter5235252/lumenora/releases)
[![Image build](https://github.com/peter5235252/lumenora/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/peter5235252/lumenora/actions/workflows/build.yml)

Lumenora is a gaming-focused desktop image built on Fedora Atomic (bootc)
with KDE Plasma, built with BlueBuild. It ships a gaming-oriented stack out of
the box and detects the GPU at first boot to select the right drivers.

## What it is based on

- Fedora Atomic Desktops KDE Plasma (Kinoite), Fedora 44
- [BlueBuild](https://blue-build.org/) for image generation
- [bootc](https://containers.github.io/bootc/) for immutable, OCI-based
  system management
- Fedora's Anaconda installer and unified Image Builder

## Theme ("Lumen")

Lumenora ships a custom deep space blue/purple theme called **Lumen** as the
default, and removes the stock Breeze (light/dark/twilight), Breeze Classic,
and Fedora themes so only Lumen is selectable:

- **Color scheme** `/usr/share/color-schemes/Lumen.colors` and matching
  Plasma Style `/usr/share/plasma/desktoptheme/Lumen`.
- **Global theme** `org.lumenora.lumen.desktop` applied to new users via
  `kdeglobals`/`plasmarc` defaults in `/etc/skel` and the kde profile.
- **Default wallpaper**: the deep-space Tarantula Nebula image, shipped as
  the `Lumen` wallpaper package and wired in as the fresh-desktop default;
  all stock wallpapers are removed so only `Lumen` remains.
- **Light text everywhere**: the palette forces light foregrounds, and the
  `BreezeLight`/`BreezeDark` scheme names are rebuilt from the Lumen palette
  (they are hard-requested by the Plasma Login Manager greeter), fixing
  "dark text on dark background" in the greeter and the desktop.
- **Snappier animations**: `AnimationDurationFactor=0.5`.
- **Layout identical to stock KDE Plasma** (default panels/widgets).
- The Breeze window decoration engine remains (it follows the Lumen color
  scheme); Secure Boot and bootloader sections above still apply.
- Applied at build time by `files/scripts/lumen-theme.sh`; the image is
  also brought to the latest KDE Plasma 6.7.x by `files/scripts/update-os.sh`.

## Kernel

Lumenora replaces the stock Fedora kernel at build time with the gaming-
optimized kernel from the [Open Game Collective](https://github.com/opengamingcollective/kernel-packages-fedora)
(`ghcr.io/opengamingcollective/kernel-packages-fedora`, e.g. Bazzite's
kernel of choice):

- The stock kernel packages are erased and the OGC kernel (currently pinned
  to `7.1.6-ogc5.1-fc44`) is installed from its OCI distribution, then
  version-locked with `dnf versionlock` so the image does not drift to a
  stock kernel on a later update.
- To update the kernel, bump the `OGC_KERNEL_TAG` pin in
  `files/scripts/swap-ogc-kernel.sh` and rebuild. The akmods `base: ogc`
  buildroot is kept in lockstep with that pin.
- The NVIDIA variant images build their prebuilt kmods against this same
  kernel version via the akmods module (`base: ogc`), so modules and kernel
  always match.

The kernel is version-locked and never drifts; its replacement happens at
build time in `files/scripts/swap-ogc-kernel.sh`.

## Bootloader

Lumenora uses the **stock GRUB2/shim bootloader** from Fedora Atomic (the
default for bootc images and the Anaconda installer flow):

- GRUB2, shim, and bootupd are left untouched at build time, so Secure Boot
  works out of the box with the Fedora-signed shim chain.
- `bootc install to-disk` (and the Anaconda graphical installer ISO) use the
  default GRUB2 path automatically — no flags needed:

  ```bash
  sudo bootc install to-disk /dev/sda
  ```

- The v0.6.5-alpha experiment (systemd-boot as the only bootloader, GRUB
  removed) was reverted: it blocked the Anaconda installer flow, which
  finalizes the bootloader with GRUB2. The systemd-boot-unsigned loader is
  no longer shipped.

## Gaming and desktop software

Lumenora includes GameMode, MangoHud, Gamescope, Distrobox, Bazaar Store,
Oh My Posh, Fastfetch, and Eza, plus gaming flatpaks (Steam, Lutris, Heroic,
Bottles, OBS, RetroArch, PCSX2, Dolphin, DuckStation) installed system-wide
from Flathub. **fish** is the default login shell for new user accounts and
for users created at install time (first-boot one-shot), with fastfetch
running on interactive startup via the shipped skel dotfiles. Kernel drivers
for Intel and AMD GPUs come from the open-source drivers already built into
the Linux kernel; no driver packages are layered for them.

## GPU driver handling

Lumenora is immutable (bootc): packages cannot be layered at runtime with
standard `dnf`. Instead:

- **Intel/AMD**: nothing is installed; the open kernel drivers are used.
- **NVIDIA**: a first-boot service detects the GPU with `lspci` and rebases
  the system to an NVIDIA variant image using `bootc switch`, then reboots.
  The NVIDIA images are built with the same BlueBuild recipe plus the akmods
  module (prebuilt kmods), avoiding runtime package layering. The variant is
  chosen by GPU generation:
  - `ghcr.io/peter5235252/lumenora-nvidia` — driver **proprietary** flavor,
    for Maxwell, Pascal, Volta, and Turing through Ada GPUs.
  - `ghcr.io/peter5235252/lumenora-nvidia-open` — driver **open kernel**
    flavor for Turing and newer GPUs (which defaults to the open driver).
  - The detection script uses the PCI device ID (`lspci`) with a Turing
    threshold of `0x1E00`: IDs at or above that boundary select the open
    flavor, lower IDs the proprietary flavor.
- To disable the automatic switch, add the kernel argument
  `lumenora-no-auto-gpu` (e.g. with `bootc`'s kernel arg support or at
  install time). Manual rebase to a specific NVIDIA image:
  `sudo bootc switch ghcr.io/peter5235252/lumenora-nvidia:latest`.

## User setup and security

Lumenora doesn't create a user or bake any username or password into the image.
The installer collects the desired username and password during installation.
No credentials are committed to this repository.

## Building locally

Install BlueBuild, then run:

```bash
bluebuild generate recipes/recipe.yml -o Containerfile.generated
bluebuild build recipes/recipe.yml
```

The committed `Containerfile` is retained for direct Podman builds and mirrors
the package and base-image choices in `recipes/recipe.yml`:

```bash
podman build -t lumenora:latest -f Containerfile .
```

Both build paths produce images for local testing; the NVIDIA variants are
defined in `recipes/recipe-nvidia.yml` (proprietary flavor) and
`recipes/recipe-nvidia-open.yml` (open kernel flavor).

## Graphical installer ISO

Lumenora's installer path is a separate Anaconda installer environment and
the unified Image Builder `bootc-generic-iso` image type. The installer
embeds the selected Lumenora image as its payload and asks for installation
settings interactively. The desktop payload remains credential-free.

To build an ISO locally:

```bash
podman pull ghcr.io/peter5235252/lumenora:latest
podman build -t localhost/lumenora-installer:latest -f installer/Containerfile installer
mkdir -p output
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v "$PWD/output:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  ghcr.io/osbuild/image-builder-cli:latest \
  build \
  --bootc-ref localhost/lumenora-installer:latest \
  --bootc-installer-payload-ref ghcr.io/peter5235252/lumenora:latest \
  --bootc-default-fs ext4 \
  bootc-generic-iso
```

The resulting ISO is written to `output/`. The installer workflow can also
be started manually from GitHub Actions with a chosen payload image. It uploads
the ISO as a workflow artifact.

## GitHub Actions

The normal workflow builds and publishes the Lumenora images (base and both
NVIDIA variants) on pushes to `main` and weekly. The installer workflow runs
manually and publishes the ISO as a GitHub Actions artifact.

The repository needs one GitHub Actions secret for image publishing:

- `SIGNING_SECRET`: the Cosign private key expected by the BlueBuild action,
  supplied as raw PEM.

The current key is intentionally unencrypted (passwordless), so no
`COSIGN_PASSWORD` secret is configured — BlueBuild always invokes Cosign with
an empty password and would reject an encrypted key.

The public verification key is stored identically at `cosign.pub` (the path
used by BlueBuild) and `keys/cosign.pub` (the documented distribution path).
Run `bash scripts/validate.sh` to verify that they remain synchronized. The
private key must never be committed to this repository.

The build currently follows rolling upstream inputs (`44` Kinoite, latest
Image Builder CLI). This keeps the image current but is not reproducible; pin
those inputs to immutable tags or digests before using Lumenora for
production deployments.

## Releases

- `v0.7.4-alpha` — current. PLM greeter shows the Lumen wallpaper (Fedora's
  `defaults.conf` overridden in-image after the black-screen regression),
  OGC kernel pin bumped to `7.1.7-ogc1.1-fc44` to match the akmods buildroot.
- `v0.7.3-alpha` — debloat round: Discover + extra apps removed, Konsole/
  Bazaar dock pins, ProtonPlus + gaming flatpaks, fish default shell,
  Anaconda installer branding, light-text greeter fix, rebuilt wallpapers.
- `v0.7.1-alpha` — unstable backup snapshot of `main` (v0.7.0-alpha +
  license scope). Also carries the verified fstab fix for the PLM session
  bounce (empty btrfs `home` subvolume was shadowing `/home -> var/home`).
- `v0.7.0-alpha` — latest stable-tagged. GRUB2/shim restored
  (systemd-boot-only reverted), latest KDE Plasma 6.7.x, Lumen theming, and a
  fixed OGC kernel that ships its initramfs (fresh installs no longer
  kernel-panic on first boot).
- `v0.6.5-alpha` — GRUB replaced by systemd-boot as the only bootloader
  (Secure Boot off until custom key enrollment); kernel unchanged.
  **Reverted on `main`.**
- `v0.6.1-alpha` — OGC gaming kernel (pinned `7.1.6-ogc4.1-fc44`) with
  matching NVIDIA kmods.
- `v0.6.0-alpha` — first KDE Plasma edition with automatic NVIDIA driver
  handling. ISO attached to the release and available as a workflow artifact.
- `v0.5.0` — archived Hyprland/Wayblue/ML4W edition. Moved to the
  `legacy-hyprland` branch; no longer under active development.

## Installing or rebasing

Fresh installations use `bootc install to-disk` (GRUB2/shim default, Secure
Boot works out of the box) or the Anaconda graphical installer ISO. For an
existing Fedora Atomic system, rebase with:

```bash
sudo bootc switch ghcr.io/peter5235252/lumenora:latest
```

The NVIDIA variant is selected automatically at first boot when an NVIDIA
GPU is detected (see GPU driver handling above).

## Project layout

- `recipes/recipe.yml` is the canonical BlueBuild recipe (KDE base).
- `recipes/recipe-nvidia.yml` and `recipes/recipe-nvidia-open.yml` add the
  NVIDIA driver variants (proprietary and open kernel flavors).
- `Containerfile` is the matching direct-build definition.
- `installer/Containerfile` defines the Anaconda installer environment.
- `installer/iso.yaml` defines the boot menu and ISO label.
- `installer/interactive-defaults.ks` points Anaconda at the Lumenora payload.
- `.github/workflows/build.yml` builds and signs all three images.
- `.github/workflows/installer.yml` builds and uploads the graphical ISO.
- `files/scripts/swap-ogc-kernel.sh` swaps the stock kernel for the OGC
  gaming kernel (pinned, version-locked) during the image build.
- `files/scripts/update-os.sh` refreshes all packages (latest Plasma 6.7).
- `files/scripts/lumen-theme.sh` applies the Lumen theme, removes stock
  KDE themes, and sets the Nebula wallpaper default.
- `files/usr/share/wallpapers/Lumen/` ships the default Nebula wallpaper.
- `files/usr/lib/systemd/system/lumenora-gpu-detect.service` performs
  first-boot GPU detection and the NVIDIA rebase.
- `files/usr/bin/lumenora-gpu-detect.sh` implements the detection logic.
- `files/etc/skel` contains the default user configuration (KDE, shells,
  MangoHud, GameMode).
- `files/scripts/rebrand.sh` applies Lumenora branding and fixes permissions.
- `CHANGELOG.md` tracks releases.
- `todo.md` tracks the migration plan.

## Upstream work

Lumenora includes configuration and software derived from Fedora Atomic
Desktops, BlueBuild, Universal Blue (akmods), and the Fedora Image Builder
tooling. Check their repositories for applicable licenses and attribution
terms before redistributing modified images.
