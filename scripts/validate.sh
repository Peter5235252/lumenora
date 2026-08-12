#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Checking shell syntax..."
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find . -type f -name '*.sh' -print0)

echo "Checking GPU generation threshold..."
gpu_script="files/usr/bin/lumenora-gpu-detect.sh"
grep -q '^turing_id_threshold=1e00$' "$gpu_script"
threshold="$(awk -F= '/^turing_id_threshold=/{print $2}' "$gpu_script")"
(( 16#1d00 < 16#$threshold ))
(( 16#1e00 >= 16#$threshold ))

echo "Checking YAML syntax..."
if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "yaml"; ARGV.each { |file| YAML.load_file(file); puts file }' \
        .github/workflows/build.yml \
        .github/workflows/installer.yml \
        .github/workflows/runner-diagnostic.yml \
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
openssl pkey -pubin -in cosign.pub -out /dev/null >/dev/null 2>&1

echo "Validation passed."
