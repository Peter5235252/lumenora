# Lumenora

Lumenora is a Fedora Atomic desktop image built with BlueBuild. It uses the
latest Wayblue Hyprland image as its base and bundles an ML4W-based Hyprland
desktop configuration with Lumenora branding.

## What it is based on

- Fedora Atomic through [Wayblue](https://github.com/wayblueorg/wayblue)
- Wayblue's Hyprland image
- [ML4W](https://github.com/mylinuxforwork/dotfiles) Hyprland dotfiles and tools
- [BlueBuild](https://blue-build.org/) for image generation

The recipe tracks Wayblue's `latest` image tag. This follows the current
upstream Fedora Atomic and Wayblue base, but upstream changes should still be
tested before deployment.

## Included software

Fastfetch, Hyprpaper, Swww, Bazaar Store, Distrobox, MangoHud, GameMode,
Quickshell, SwayNotificationCenter, and Oh My Posh are installed in addition
to the software already provided by Wayblue and ML4W.

## User setup and security

Lumenora doesn't create a `lumen` user or bake a Lumenora password into the
image. Username and password setup belongs to the installer.

The repository's `config.toml` uses `root` / `root` as the installer default,
as requested. Don't deploy those defaults unchanged. Set a unique username
and strong password in the installer before first boot.

## Building locally

Install BlueBuild, then run:

```bash
bluebuild generate recipe.yml -o Containerfile.generated
bluebuild build recipe.yml
```

The committed `Containerfile` is retained for direct Podman builds and mirrors
the package and base-image choices in `recipe.yml`:

```bash
podman build -t lumenora:latest -f Containerfile .
```

## GitHub Actions

The workflow builds on pushes to `main` and weekly. It publishes to:

```text
ghcr.io/peter5235252/lumenora:latest
```

The repository needs a `SIGNING_SECRET` GitHub Actions secret containing the
Cosign private key expected by the BlueBuild action. The public key is kept in
`keys/cosign.pub`.

## Installing or rebasing

Follow Wayblue's installation and rebase instructions for your hardware. Use
the regular Hyprland image for non-NVIDIA systems or the matching NVIDIA
variant when required. Replace the Wayblue image name with the Lumenora image
published by this repository, then set the desired installer username and
password before rebooting.

## Project layout

- `recipe.yml` is the canonical BlueBuild recipe.
- `Containerfile` is the matching direct-build definition.
- `files/etc/skel` contains the default user configuration.
- `scripts/rebrand.sh` applies Lumenora branding and permissions at build time.
- `.github/workflows/build.yml` builds and publishes the image.

## Upstream work

Lumenora includes configuration and software derived from ML4W and Wayblue.
Check their repositories for applicable licenses and attribution terms before
redistributing modified images.
