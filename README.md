# Lumenora

Lumenora is a Fedora Atomic gaming desktop image built with BlueBuild. It uses the
latest Wayblue Hyprland image and the rolling ML4W Hyprland dotfiles, with
Lumenora branding and gaming-focused tools.

## What it is based on

- Fedora Atomic through [Wayblue](https://github.com/wayblueorg/wayblue)
- Wayblue's Hyprland image
- [ML4W](https://github.com/mylinuxforwork/dotfiles) rolling dotfiles from the upstream `main` branch
- [BlueBuild](https://blue-build.org/) for image generation
- Fedora's Anaconda installer and unified [Image Builder](https://osbuild.org/docs/developer-guide/projects/image-builder/)

The image build downloads the current ML4W rolling `main` branch into
`/etc/skel` each time it builds. This means ML4W updates are picked up by the
next image build. The bundled files remain as a fallback for offline inspection
and local development.

## Gaming and desktop software

Lumenora includes MangoHud, GameMode, Distrobox, Quickshell, Fastfetch,
Hyprpaper, Swww, Bazaar Store, SwayNotificationCenter, and Oh My Posh, in
addition to the software provided by Wayblue and ML4W.

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

Both build paths fetch ML4W's rolling `main` branch during the build, so they
require network access.

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

The normal workflow builds and publishes the Lumenora image on pushes to
`main` and weekly. The installer workflow runs manually or when a version tag
such as `v1.0.0` is pushed. It publishes the ISO as a GitHub Actions artifact.

The repository needs these GitHub Actions secrets for image publishing:

- `SIGNING_SECRET`: the Cosign private key expected by the BlueBuild action.
- `COSIGN_PASSWORD`: the password protecting that private key. Leave it empty
  only if the key is intentionally unencrypted.

The public verification key is stored identically at `cosign.pub` (the path
used by BlueBuild) and `keys/cosign.pub` (the documented distribution path).
Run `bash scripts/validate.sh` to verify that they remain synchronized. The
private key must never be committed to this repository.

The build currently follows rolling upstream inputs (`latest` Wayblue,
ML4W `main`, and the latest Image Builder CLI). This keeps the image current
but is not reproducible; pin those inputs to immutable tags or digests before
using Lumenora for production deployments.

## Installing or rebasing

Use the graphical ISO for a fresh installation. For an existing Fedora Atomic
system, follow Wayblue's rebase instructions for your hardware. Use the regular
Hyprland image for non-NVIDIA systems or the matching NVIDIA variant when
required.

## Project layout

- `recipes/recipe.yml` is the canonical BlueBuild recipe.
- `Containerfile` is the matching direct-build definition.
- `installer/Containerfile` defines the Anaconda installer environment.
- `installer/iso.yaml` defines the boot menu and ISO label.
- `installer/interactive-defaults.ks` points Anaconda at the Lumenora payload.
- `.github/workflows/installer.yml` builds and uploads the graphical ISO.
- `files/etc/skel` contains the fallback user configuration.
- `files/scripts/rebrand.sh` syncs rolling ML4W files, applies Lumenora branding, and fixes permissions.

## Upstream work

Lumenora includes configuration and software derived from ML4W and Wayblue.
Check their repositories for applicable licenses and attribution terms before
redistributing modified images.
