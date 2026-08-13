# Release Checklist

This is the release gate for Lumenora. A Git tag is not a release sign-off by
itself; the image, installer, signatures, and hardware notes must agree.

## Before Tagging

- [ ] Update `CHANGELOG.md`, `README.md`, and `todo.md` with the exact status.
- [ ] Confirm the intended image commit and record its immutable GHCR tag or
      digest in the release notes.
- [ ] Run `bash scripts/validate.sh` locally.
- [ ] Confirm all three image jobs are green: base, proprietary NVIDIA, and
      NVIDIA open-kernel.
- [ ] Confirm the image smoke tests pass for all three variants.
- [ ] Verify the three published images with `cosign` and `keys/cosign.pub`.
- [ ] Confirm the kernel pin and NVIDIA akmods buildroot use the same version.
- [ ] If the NVIDIA driver pin changed, re-sync the `open_supported_ids`
      allowlist in `files/usr/bin/lumenora-gpu-detect.sh` from NVIDIA's
      open-gpu-kernel-modules "Compatible GPUs" table and bump the
      `( count >= N )` floor in `scripts/validate.sh`.

## Installer

- [ ] Create the release tag only after the payload image is available in GHCR.
- [ ] Confirm the tag-triggered installer workflow uses the intended immutable
      payload reference rather than an unreviewed `latest` image.
- [ ] Confirm the ISO is attached to the matching GitHub release.
- [ ] Boot the ISO in a VM and verify Anaconda text, branding, networking, and
      a successful GRUB installation.
- [ ] Test first boot from the installed disk and confirm rollback is usable.
- [ ] Record the ISO filename, size, checksum, and payload reference in the
      release notes.

## Hardware Gate

- [ ] Base image: validate on the supported Intel/AMD integrated-graphics test
      system and at least one VM configuration.
- [ ] Proprietary NVIDIA variant: boot on representative pre-Turing hardware
      and verify display, suspend/resume, Vulkan, and a game launch.
- [ ] NVIDIA open variant: boot on representative Turing-or-newer hardware
      and verify display, suspend/resume, Vulkan, and a game launch.
- [ ] Exercise automatic GPU selection and the
      `lumenora-no-auto-gpu` recovery path.
- [ ] Document hardware that remains untested instead of implying coverage.

## After Publishing

- [ ] Verify the GitHub release has the expected ISO and release notes.
- [ ] Verify the release image reference and signature from a clean machine.
- [ ] Keep the previous known-good image reference available for rollback.
- [ ] Move unfinished hardware or installer work into the next section of
      `todo.md`.

Stable release timing is deliberately validation-driven. It may land between
August and November, or later if the hardware gate is not complete.
