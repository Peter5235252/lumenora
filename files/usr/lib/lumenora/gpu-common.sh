#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

nvidia_image="ghcr.io/peter5235252/lumenora-nvidia:latest"
nvidia_open_image="ghcr.io/peter5235252/lumenora-nvidia-open:latest"
base_image="ghcr.io/peter5235252/lumenora:latest"
cosign_public_key="/etc/lumenora/cosign.pub"
attempts=3
retry_base_sleep=10

open_supported_ids=(
    1E02 1E04 1E07 1E09 1E30 1E36 1E78 1E81 1E82 1E84 1E87 1E89 1E90 1E91
    1E93 1EB0 1EB1 1EB5 1EB6 1EB8 1EC2 1EC7 1ED0 1ED1 1ED3 1EF5 1F02 1F03
    1F06 1F07 1F08 1F0A 1F0B 1F10 1F11 1F12 1F14 1F15 1F36 1F42 1F47 1F50
    1F51 1F54 1F55 1F76 1F82 1F83 1F91 1F95 1F96 1F97 1F98 1F99 1F9C 1F9D
    1F9F 1FA0 1FB0 1FB1 1FB2 1FB6 1FB7 1FB8 1FB9 1FBA 1FBB 1FBC 1FDD 1FF0
    1FF2 1FF9 20B0 20B2 20B3 20B5 20B6 20B7 20BD 20F1 20F3 20F5 20F6 20FD
    2182 2184 2187 2188 2189 2191 2192 21C4 21D1 2203 2204 2206 2207 2208
    220A 220D 2216 2230 2231 2232 2233 2235 2236 2237 2238 230E 2321 2322
    2324 2329 232C 2330 2331 2335 2339 233A 233B 2342 2348 2414 2420 2438
    2460 2482 2484 2486 2487 2488 2489 248A 249C 249D 24A0 24B0 24B1 24B6
    24B7 24B8 24B9 24BA 24BB 24C7 24C9 24DC 24DD 24E0 24FA 2503 2504 2507
    2508 2520 2521 2523 2531 2544 2560 2563 2571 2582 2584 25A0 25A2 25A5
    25A6 25A7 25A9 25AA 25AB 25AC 25AD 25B0 25B2 25B6 25B8 25B9 25BA 25BB
    25BC 25BD 25E0 25E2 25E5 25EC 25ED 25F9 25FA 25FB 2684 2685 2689 26B1
    26B2 26B3 26B5 26B9 26BA 2702 2704 2705 2709 2717 2730 2757 2770 2782
    2783 2786 2788 27A0 27B0 27B1 27B2 27B6 27B8 27BA 27BB 27E0 27FB 2803
    2805 2808 2820 2822 2838 2860 2882 28A0 28A1 28A3 28B0 28B8 28B9 28BA
    28BB 28E0 28E1 28E3 28F8 2901 2909 2941 29BB 2B85 2B87 2B8C 2BB1 2BB3
    2BB4 2BB5 2BB9 2C02 2C05 2C18 2C19 2C31 2C33 2C34 2C38 2C39 2C3A 2C58
    2C59 2C77 2C79 2D04 2D05 2D18 2D19 2D30 2D39 2D58 2D59 2D79 2D83 2D98
    2DB8 2DB9 2DD8 2DF9 2E03 2E06 2E12 2F04 2F06 2F18 2F38 2F58 3182 31C2
    31C3
)

is_open_supported() {
    local id="$1" dev
    for dev in "${open_supported_ids[@]}"; do
        if [[ "$dev" == "$id" ]]; then
            return 0
        fi
    done
    return 1
}

image_ref_for_variant() {
    case "$1" in
        base) printf '%s\n' "$base_image" ;;
        proprietary|nvidia) printf '%s\n' "$nvidia_image" ;;
        open|nvidia-open) printf '%s\n' "$nvidia_open_image" ;;
        *) return 2 ;;
    esac
}

resolve_manifest_digest() {
    local ref="$1" repository token_resp token digest
    repository="${ref#ghcr.io/}"
    repository="${repository%%:*}"
    token_resp="$(curl -fsSL --retry 1 "https://ghcr.io/token?scope=repository:${repository}:pull" 2>/dev/null || true)"
    token="$(printf '%s' "$token_resp" | sed -n -E 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
    [[ -n "$token" ]] || return 1
    digest="$(curl -sSL -D - -o /dev/null --retry 1 \
        -H "Authorization: Bearer ${token}" \
        -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json' \
        "https://ghcr.io/v2/${repository}/manifests/latest" \
        | awk 'tolower($1) == "docker-content-digest:" {print $2}' | tr -d '\r' | tail -n 1)"
    [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] || return 1
    printf '%s\n' "$digest"
}

verify_and_resolve_image() {
    local ref="$1" digest resolved
    command -v cosign >/dev/null 2>&1 || {
        echo "Lumenora: cosign is required to verify GPU images." >&2
        return 1
    }
    [[ -r "$cosign_public_key" ]] || {
        echo "Lumenora: public verification key missing at $cosign_public_key." >&2
        return 1
    }
    cosign verify --key "$cosign_public_key" "$ref" >/dev/null
    digest="$(resolve_manifest_digest "$ref")" || {
        echo "Lumenora: could not resolve an immutable digest for $ref." >&2
        return 1
    }
    resolved="${ref%%:*}@${digest}"
    cosign verify --key "$cosign_public_key" "$resolved" >/dev/null
    printf '%s\n' "$resolved"
}
