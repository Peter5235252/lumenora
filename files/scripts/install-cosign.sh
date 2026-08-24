#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -ouex pipefail

# Install cosign from the official Sigstore release binary.
# The Fedora 44 base repositories do not provide a `cosign` RPM that
# rpm-ostree can resolve, so we use the upstream GitHub release binary
# (a documented, supported installation method per https://docs.sigstore.dev).
COSIGN_VERSION="v3.0.4"
echo "==> Installing cosign ${COSIGN_VERSION} from Sigstore releases"
curl -Lo /usr/bin/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
chmod +x /usr/bin/cosign
cosign version
