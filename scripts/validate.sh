#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Checking shell syntax..."
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find . -type f -name '*.sh' -print0)

echo "Checking SPDX license headers on MIT-licensed scripts..."
for script in \
    files/scripts/dedup-home-subvol.sh \
    files/scripts/fish-default.sh \
    files/scripts/lumen-theme.sh \
    files/scripts/rebrand.sh \
    files/scripts/swap-ogc-kernel.sh \
    files/scripts/update-os.sh \
    files/usr/bin/lumenora-gpu-detect.sh \
    scripts/validate.sh; do
    if ! grep -q '^# SPDX-License-Identifier: MIT' "$script"; then
        echo "ERROR: $script is missing the SPDX-License-Identifier: MIT header" >&2
        exit 1
    fi
done

echo "Checking GPU open-kernel support allowlist..."
gpu_script="files/usr/bin/lumenora-gpu-detect.sh"
gpu_common="files/usr/lib/lumenora/gpu-common.sh"
python3 scripts/generate-recipes.py --check
grep -q '^open_supported_ids=(' "$gpu_common"
if grep -q 'turing_id_threshold' "$gpu_script"; then
    echo "ERROR: flat numeric GPU threshold removed; use open_supported_ids" >&2
    exit 1
fi
if ! grep -q 'is_open_supported()' "$gpu_script"; then
    echo "ERROR: open-kernel support lookup helper missing" >&2
    exit 1
fi
count=$(sed -n '/^open_supported_ids=(/,/^)$/p' "$gpu_common" \
    | grep -oE '[0-9A-Fa-f]{4}' | wc -l)
(( count >= 295 ))
for id in 1E04 1F0A 2187 2204 2504 2684 2C02 20B0; do
    if ! grep -qw "$id" "$gpu_script"; then
        echo "ERROR: expected NVIDIA open-supported device ${id} missing from allowlist" >&2
        exit 1
    fi
done
if ! grep -q 'non_nvidia_controllers' "$gpu_script"; then
    echo "ERROR: hybrid multi-GPU detection missing" >&2
    exit 1
fi
if ! grep -q 'lumenora-force-auto-gpu' "$gpu_script"; then
    echo "ERROR: hybrid override kernel argument missing" >&2
    exit 1
fi
if ! grep -q 'manifests/latest' "$gpu_script"; then
    echo "ERROR: GHCR anonymous-pull pre-flight check missing" >&2
    exit 1
fi

echo "Checking YAML syntax..."
if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "yaml"; ARGV.each { |file| YAML.load_file(file); puts file }' \
        .github/workflows/build.yml \
        .github/workflows/installer.yml \
        .github/workflows/validate.yml \
        recipes/recipe.yml \
        recipes/recipe-nvidia.yml \
        recipes/recipe-nvidia-open.yml \
        installer/iso.yaml
else
    echo "Ruby is unavailable; YAML parsing will run in CI."
fi

echo "Checking Cosign public-key consistency..."
cmp -s cosign.pub keys/cosign.pub
cmp -s cosign.pub files/etc/lumenora/cosign.pub
openssl pkey -pubin -in cosign.pub -out /dev/null >/dev/null 2>&1

echo "Validation passed."
