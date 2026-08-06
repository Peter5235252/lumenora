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
  the system to the NVIDIA variant image
  (`ghcr.io/peter5235252/lumenora-nvidia`) using `bootc switch`, then
  reboots. The NVIDIA image is built with the same BlueBuild recipe plus the
  akmods module (prebuilt kmods), avoiding runtime package layering.
- To disable the automatic switch, add the kernel argument
  `lumenora-no-auto-gpu` (e.g. with `bootc`'s kernel arg support or at
  install time). Manual rebase to the NVIDIA image:
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

Both build paths produce images for local testing; the NVIDIA variant is
defined in `recipes/recipe-nvidia.yml`.

## Graphical installer ISO

Lumenora uses a separate Anaconda installer environment and the unified
Image Builder `bootc-generic-iso` image type. The installer embeds the
selected Lumenora image as its payload and asks for installation settings
interactively. The desktop payload remains credential-free.

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

This installer path is intended for testing initially. The Image Builder
documentation notes that bootc installations through Anaconda currently have
a known `systemd-remount-fs.service` issue, so test the ISO in a VM before
using it on a real machine.

## GitHub Actions

The normal workflow builds and publishes the Lumenora images (base and
NVIDIA) on pushes to `main` and weekly. The installer workflow runs manually
or when a version tag such as `v0.6.0-alpha` is pushed. It publishes the ISO
as a GitHub Actions artifact.

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

- `v0.6.0-alpha` — first KDE Plasma edition with automatic NVIDIA driver
  handling. ISO attached to the release and available as a workflow artifact.
- `v0.5.0` — archived Hyprland/Wayblue/ML4W edition. Moved to the
  `legacy-hyprland` branch; no longer under active development.

## Installing or rebasing

Use the graphical ISO for a fresh installation. For an existing Fedora Atomic
system, rebase with:

```bash
sudo bootc switch ghcr.io/peter5235252/lumenora:latest
```

The NVIDIA variant is selected automatically at first boot when an NVIDIA
GPU is detected (see GPU driver handling above).

## Project layout

- `recipes/recipe.yml` is the canonical BlueBuild recipe (KDE base).
- `recipes/recipe-nvidia.yml` adds the NVIDIA driver variant.
- `Containerfile` is the matching direct-build definition.
- `installer/Containerfile` defines the Anaconda installer environment.
- `installer/iso.yaml` defines the boot menu and ISO label.
- `installer/interactive-defaults.ks` points Anaconda at the Lumenora payload.
- `.github/workflows/build.yml` builds and signs both images.
- `.github/workflows/installer.yml` builds and uploads the graphical ISO.
- `files/usr/lib/systemd/system/lumenora-gpu-detect.service` performs
  first-boot GPU detection and the NVIDIA rebase.
- `files/usr/local/bin/lumenora-gpu-detect.sh` implements the detection logic.
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
