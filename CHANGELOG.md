# Changelog

## v0.8.0-beta.1 - 2026-08-09

First beta. The long-running dark-text bug is finally closed at its root
cause, and the base image is verified live in a VM.

- **Root cause of the persistent black text (finally found).**
  `[Colors:View]`, `[Colors:Complementary]` and `[Colors:Tooltip]` had *no*
  `ForegroundNormal` key in `Lumen.colors`. KDE color lookups fall back to
  the default `#232629` (near-black) text for any section missing a normal
  foreground — which is why text stayed black across the earlier alpha
  rounds: the white passes only recolored keys that *already existed* and
  never added the missing ones, so the fallback dark text kept winning.
- **Fixed** in `files/scripts/lumen-theme.sh`: the white pass now inserts
  `ForegroundNormal=#ffffff` into any color group that lacks it (tracked
  per section while rebuilding the file). A per-section assert now fails
  the build if any `[Colors:*]` section is missing `ForegroundNormal`, so
  this cannot silently regress.
- **Caches invalidated**: LAF + Lumen Plasma Style bumped to `0.7.6` and
  the fallback `default` desktop theme to `-lumen8`, so Plasma rebuilds its
  `plasma_theme_*.kcache` palettes instead of serving the old dark one.
- **Verified live**: all sections carry a white `ForegroundNormal` in
  `Lumen.colors`, the `BreezeLight`/`BreezeDark` regenerations, and both
  desktoptheme copies; Qt palette Text role `#232629` → `#ffffff`; VM
  rebooted onto the fixed image and confirmed light text in apps, panels,
  window decorations and the PLM greeter (which also shows the blurred
  nebula).

### ⚠ NVIDIA variants not tested

`lumenora-nvidia` and `lumenora-nvidia-open` compile and push cleanly but
have **not** been booted or validated on NVIDIA hardware. Treat them as
experimental until verified.

### Roadmap

Targeting a **stable release (exiting beta)** in **late August or
September 2026, if everything goes well** — i.e. NVIDIA variant validation,
broader hardware testing and a clean feedback loop. This is a **solo
project**: progress depends on time and can stall or burn out. Releases may
lag behind GitHub activity for that reason; treat them as the source of
truth for what is actually shippable.

White-text lockdown, at last done right. The previous round's "force pure
white" pass was a silent no-op — its regex matched only the `[Colors:...]`
header lines, so every `Foreground*` key kept its original (dark-ish) value
and every derived copy shipped the same. Rev 2 replaces that pass with a
line-by-line rebuild plus a hard whitelist assert, so the build now *fails*
if any non-white foreground survives. In the same round: a blurred nebula
for the PLM greeter and the Anaconda installer, and a fully white-text
Anaconda GTK stylesheet.

- **Why text was still dark after the Id fix**: the heredoc in
  `files/scripts/lumen-theme.sh` ran
  `re.sub(r"(?ms)^\[Colors:Window\].*?(?=^\[|$)", ...)` — with `(?s)` not
  set, `.` never crosses the newline, and with the multiline `$`, the match
  stops right after `[Colors:Window]`. The inner `Foreground...=#ffffff`
  rewrite therefore never executed, on any section. Reproduced standalone:
  the pass changed nothing.
- **Fixed**: `Lumen.colors` is now rebuilt line-by-line — every
  `Foreground*` key becomes `#ffffff`, except the blue/purple accents
  (Link/Visited/Active and Inactive) which keep their hue but are lightened
  for contrast on the deep-space scheme (`#a3c4ff`, `#c9a8ff`, `#d9d5ea`).
- **Hard assert**: a whitelist check runs right after the rebuild — only
  `#ffffff` and the three lightened accents are allowed; `ForegroundNormal`
  must be pure white; any other value aborts the build (exit 1). The
  desktoptheme `Lumen`/`default` colors and BreezeLight/BreezeDark names are
  copies of this verified file, so all surfaces inherit it.
- **PLM greeter shows the blurred nebula**: `nebula-blurred.jpg`
  (Gaussian blur, radius 90, ~80% brightness) shipped inside the Lumen
  wallpaper package; both `/etc/plasmalogin.conf.d/lumen.conf` and
  `/usr/lib/plasmalogin/defaults.conf` now point Image/PreviewImage at it.
- **Anaconda installer surfaces match**: `installer-background.png`
  (blur radius 120, 55% brightness for a readable scrim) is the full-window
  `background-image` of `AnacondaSpokeWindow` with `background-size: cover`;
  the stylesheet forces `color: #ffffff` on every widget scope (labels,
  buttons, entries, combos, checks, radios, treeviews, textviews, scales,
  switches, spinners), lightens links/emphasized text to `#cfc9e8`, and
  dims disabled text to `#cfc9e8`. Buttons keep the Lumen purple accent.

### Known rough edges (v0.7.5-alpha rev 2)

- Visual confirmation is still the single open check: the rebuilt VM must be
  eyeballed at the greeter and the logged-in desktop (black text would have
  failed the whitelist, but color fidelity is a visual thing).
- The Anaconda GTK CSS targets `AnacondaSpokeWindow` scopes; text inside
  stock GTK dialogs that escape that scope keeps the generic dark GTK theme
  unless overridden by `@define-color`/widget matches still to be added on a
  per-dialog basis.

## v0.7.5-alpha - 2026-08-09

Theme lockdown round: Welcome Center removed, Lumen is now the *only*
selectable Plasma look, and white text is forced at multiple layers.
**Text color and PLM background root cause identified and fixed in the
image; visual confirmation on a full desktop session is the last step
before this is called done.**

- **Root cause of the black text — LAF metadata `<Id>` mismatch.** KDE
  requires "the `Id` entry should match the name of the theme folder name"
  (see develop.kde.org, *Understanding Plasma Styles*). The folder is
  `org.lumenora.lumen.desktop` but `metadata.json` declared
  `"Id": "org.lumenora.lumen"`. A look-and-feel package whose Id does not
  match its folder is not loadable: Plasma silently drops the global theme,
  falls back to the stock light Breeze look (dark text over the dark
  wallpaper), and then even re-writes the user's `kdeglobals` to a *deleted*
  theme name (`org.kde.breezedark.desktop`) at the next login. Fixed: the
  Id now equals the folder name, and both the LAF and the Lumen desktop
  theme got a `Version` bump so Plasma invalidates its cached theme
  rendering (per KDE docs, "...update the Version so Plasma can properly
  refresh its cache").
- **Second culprit — the fallback "default" desktop theme had no `colors`
  file.** KDE docs: "if a theme is missing an SVG file, it will fall back to
  the default Breeze theme." Our deliberately thin Lumen desktop theme only
  ships colors/metadata/plasmarc, so widgets with a missing SVG render from
  the stock `desktoptheme/default` — which had *no* `colors` file at all,
  i.e. the stock light palette with dark text. Fixed: `default/colors` now
  ships a copy of the white-forced `Lumen.colors` plus a version bump.
- **Welcome Center removed**: `plasma-welcome` + `plasma-welcome-fedora`
  dropped from all three recipes.
- **White text forced at the source**: all `Foreground*` in `Lumen.colors`
  set to `#ffffff` *before* any derived copy (desktoptheme colors, the
  BreezeLight/BreezeDark regenerations).
- **Single-theme lockdown**: all stock global themes and desktop themes
  deleted; `BreezeLight`/`BreezeDark` color scheme *names* rebuilt on the
  Lumen palette (PLM greeter and Breeze consumers reference them by name).
- **Existing accounts pinned to Lumen**: the first-boot `lumenora-fish-default`
  unit writes `ColorScheme=Lumen` and `LookAndFeelPackage=org.lumenora.lumen.desktop`
  into every human account's `kdeglobals`, so Plasma cannot resolve to a
  different look at login.
- **Auto look-and-feel disabled**: `AutomaticLookAndFeel=false` system-wide
  (skel, `/etc/xdg/kdeglobals`) and per account — previously Plasma
  re-resolved every login against the deleted system default and restored a
  stock light look.

### Known rough edges (v0.7.5-alpha)

- **Visual proof still pending.** The VM was rebuilt and rebased with the
  Id fix; the session now keeps the Lumen LAF across reboots. A screenshot
  was captured but not yet visually inspected on a real display (greeter +
  login desktop). This is the single remaining check before calling the
  dark-text bug closed.
- **Theme lockdown is aggressive by design**: with only Lumen present, apps
  requesting a missing stock theme name get the Lumen palette (white text on
  the deep-space scheme) instead of a graceful fallback.
- First-boot pinning touches accounts that predate the theme change;
  `desktoptheme/default/colors` and version bumps now cover the fallback
  paths for any account.

## v0.7.4-alpha - 2026-08-09

Stability round on the v0.7.3 debloat: the Plasma Login Manager greeter now
actually renders the Lumen Nebula wallpaper (was black after the Fedora
wallpaper cleanup), and the OGC kernel pin tracks the akmods buildroot again.

- **PLM greeter wallpaper fixed**: Fedora ships
  `/usr/lib/plasmalogin/defaults.conf` with
  `Image=file:///usr/share/wallpapers/Fedora/`; that compiled-in system
  config beats the `/etc/plasmalogin.conf.d/*` drop-ins in the KConfig
  cascade, so the greeter fell back to a black screen once the cleanup
  removed `/usr/share/wallpapers/Fedora/`. The image now ships its own
  `defaults.conf` pointing at `/usr/share/wallpapers/Lumen/.../nebula.jpg`
  (`files/usr/lib/plasmalogin/defaults.conf`); `files/etc/plasmalogin.conf.d/
  lumen.conf` repeats it for user-level overrides. Verified live in the VM:
  the login screen shows the nebula.
- **OGC kernel pin bumped** `7.1.6-ogc5.1-fc44` -> `7.1.7-ogc1.1-fc44`:
  the akmods `ogc-44` buildroot rebuilt for the newer kernel, and the guard
  in `files/scripts/swap-ogc-kernel.sh` (buildroot kernel must equal shipped
  kernel) was fatally aborting all three image builds.

## v0.7.3-alpha - 2026-08-08

App/packaging debloat round on top of the v0.7.2 polish (builds clean on
all three images and verified in the VM — removed apps are actually gone,
ProtonPlus lands in the system flatpak batch).

- **Discover removed**: plasma-discover package family dropped from all
  three recipes (software center unavailable on purpose; flatpaks are
  managed via Bazaar Store / CLI).
- **Extra apps removed**: kwrite (KWrite), kdeconnectd (KDE Connect;
  pulled in with kde-connect / kde-connect-libs), kfind (KFind),
  kcharselect (KCharSelect), khelpcenter (Help Center / Fedora
  documentation) — gone from all three recipes.
- **Dock pins**: the default Plasma panel template now pins Konsole and
  Bazaar Store in the Icons-Only Task Manager
  (`files/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js`).
- **ProtonPlus**: `com.vysp3r.ProtonPlus` (Proton compatibility-tools
  manager for Steam and other apps) added to the system flatpak batch.
- **Gaming flatpaks**: add RetroArch, PCSX2, Dolphin, DuckStation to all
  three recipes.
- **fish as default shell**: `fish-default.sh` sets useradd's default and a
  first-boot `lumenora-fish-default.service` that flips existing accounts
  (UID 1000-65533) to fish; fastfetch already runs on interactive startup
  via the skel dotfiles; oh-my-posh invoked from PATH instead of
  `~/.local/bin`; canonical `/var/home/<user>` home so the prompt shows `~`
  instead of `/v/h/<user>`.
- **Anaconda installer branding**: `installer/anaconda-gtk.css` (Lumen
  colors) plus pixmaps (sidebar background/logo, top bar) shipped into the
  installer container.
- **Light text fix**: BreezeLight/BreezeDark scheme names are rebuilt from
  the Lumen palette (PLM's greeter hard-requests "BreezeLight" and fell back
  to dark text); all Lumen foregrounds forced light.
- **Wallpaper cleanup**: only the Lumen (Nebula) wallpaper package remains
  in `/usr/share/wallpapers`.
- **PLM greeter branding**: `files/etc/plasmalogin.conf.d/lumen.conf` pins
  the greeter to the org.kde.image wallpaper plugin.
- **MangoHud flatpak layer dropped** (multi-branch ref aborts the
  system-flatpak-setup batch; MangoHud stays as an RPM).

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