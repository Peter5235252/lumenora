# Changelog

## v0.6.0-alpha - unreleased

Early-alpha KDE Plasma edition. Complete pivot from Hyprland to KDE Plasma:

- Base image changed to Fedora Atomic KDE Plasma (Kinoite) 44.
- Removed all Hyprland/Wayblue/ML4W dotfiles, packages, and scripts.
- Gaming stack: GameMode, MangoHud, Gamescope, Steam/Lutris/Heroic/Bottles/OBS
  flatpaks, Bazaar Store, Oh My Posh, Eza.
- Automatic GPU driver handling at first boot: NVIDIA GPUs trigger a
  `bootc switch` rebase to the matching NVIDIA variant; Intel/AMD use the
  built-in open drivers. Escape hatch: `lumenora-no-auto-gpu` kernel argument.
- Generation-aware NVIDIA selection: `lumenora-nvidia` (proprietary driver
  flavor) targeted at Maxwell/Pascal/Volta/Turing-Ada, and
  `lumenora-nvidia-open` (open kernel flavor) for Turing and newer GPUs,
  chosen by PCI device ID (threshold `0x1E00`).
- NVIDIA variant images built with the akmods module (prebuilt kmods) so no
  runtime package layering is needed on the immutable system.

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
- Fixed COPR repositories for `bazaar-store` (now `kylegospo/bazaar`) and
  `swww` (added `alebastr/sway-extras`); all `fedora-44`.
- Rotated the Cosign keypair to an unencrypted key; `SIGNING_SECRET` now holds
  raw PEM and `COSIGN_PASSWORD` is unset, matching BlueBuild's signer.
- Removed the generated `.bluebuild-scripts_*` directory from tracking and
  ignored it in `.gitignore`.