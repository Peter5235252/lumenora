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

## Kernel

Lumenora replaces the stock Fedora kernel at build time with the gaming-
optimized kernel from the [Open Game Collective](https://github.com/opengamingcollective/kernel-packages-fedora)
(`ghcr.io/opengamingcollective/kernel-packages-fedora`, e.g. Bazzite's
kernel of choice):

- The stock kernel packages are erased and the OGC kernel (currently pinned
  to `7.1.6-ogc4.1-fc44`) is installed from its OCI distribution, then
  version-locked with `dnf versionlock` so the image does not drift to a
  stock kernel on a later update.
- To update the kernel, bump the `OGC_KERNEL_TAG` pin in
  `files/scripts/swap-ogc-kernel.sh` and rebuild. The akmods `base: ogc`
  buildroot is kept in lockstep with that pin.
- The NVIDIA variant images build their prebuilt kmods against this same
  kernel version via the akmods module (`base: ogc`), so modules and kernel
  always match.

The kernel is version-locked and never drifts; its replacement (and the
bootloader swap) happen at build time in `files/scripts/swap-ogc-kernel.sh`
and `files/scripts/force-systemd-boot.sh`.

## Bootloader

Lumenora is **GRUB-free**: since v0.6.5-alpha the image ships **systemd-boot**
as its only bootloader, replacing GRUB entirely.

- The image erases all GRUB/shim/bootupd packages at build time and ships a
  default install config at `/usr/lib/bootc/install/00-lumenora.toml` that
  forces `bootloader = "systemd"` (with discoverable-partitions/DPS root
  discovery and an ext4 root). Every `bootc install to-disk` uses
  systemd-boot automatically — no flags needed:

  ```bash
  sudo bootc install to-disk /dev/sda
  ```

- systemd-boot manages boot entries, kernels, and upgrades automatically
  through the Boot Loader Interface (no manual menu updates, no
  `grub-mkconfig`).
- systemd-boot is only supported by bootc on the **composefs backend**
  (the Fedora 44 Atomic default), which Lumenora uses.
- The EFI loader comes from the `systemd-boot-unsigned` package.

Secure Boot caveats:

- The unsigned systemd-boot binary is **not signed by Fedora's shim chain**,
  so **Secure Boot must be disabled** (or custom keys enrolled).
- The shim is removed with GRUB; there is no Fedora-signed boot path in
  these images. This tradeoff is accepted to get the modern Boot Loader
  Interface bootloader.
- The Anaconda-based graphical installer ISO flow (which expects GRUB) is
  paused until it can install systemd-boot. For now, install with
  `bootc install to-disk` (or `to-filesystem`) directly.

## Gaming and desktop software

Lumenora includes GameMode, MangoHud, Gamescope, Distrobox, Bazaar Store,
Oh My Posh, Fastfetch, and Eza, plus gaming flatpaks (Steam, Lutris, Heroic,
Bottles, OBS) installed system-wide from Flathub. Kernel drivers for Intel and
AMD GPUs come from the open-source drivers already built into the Linux
kernel; no driver packages are layered for them.

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

> **Paused.** Since v0.6.5-alpha the images no longer contain GRUB/shim,
> which the Anaconda-based ISO flow expects. Reworking the installer to
> deploy systemd-boot is future work; install with `bootc install to-disk`
> directly in the meantime.

Lumenora's planned installer path is a separate Anaconda installer
environment and the unified Image Builder `bootc-generic-iso` image type.
The installer embeds the selected Lumenora image as its payload and asks
for installation settings interactively. The desktop payload remains
credential-free.

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
manually (paused — see above) and publishes the ISO as a GitHub Actions
artifact.

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

- `v0.6.5-alpha` — GRUB replaced by systemd-boot as the only bootloader
  (Secure Boot off until custom key enrollment); kernel unchanged.
- `v0.6.1-alpha` — OGC gaming kernel (pinned `7.1.6-ogc4.1-fc44`) with
  matching NVIDIA kmods, systemd-boot path documented.
- `v0.6.0-alpha` — first KDE Plasma edition with automatic NVIDIA driver
  handling. ISO attached to the release and available as a workflow artifact.
- `v0.5.0` — archived Hyprland/Wayblue/ML4W edition. Moved to the
  `legacy-hyprland` branch; no longer under active development.

## Installing or rebasing

Fresh installations use `bootc install to-disk` (systemd-boot is the
default, no flags needed; Secure Boot must be off). For an existing Fedora
Atomic system, rebase with:

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
- `files/scripts/force-systemd-boot.sh` removes GRUB/shim/bootupd, ships
  `systemd-boot-unsigned`, and sets the systemd-boot install default.
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
