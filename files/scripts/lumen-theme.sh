#!/usr/bin/env bash
set -ouex pipefail

# Lumenora Plasma branding ("Lumen"):
#   - deep space blue/purple "Lumen" color scheme
#   - "Lumen" Plasma global theme (look-and-feel) and Plasma Style
#   - snappier animations (AnimationDurationFactor 0.5)
#   - Nebula wallpaper as the default
#   - stock Breeze / Fedora themes removed so only Lumen is selectable

LAF=/usr/share/plasma/look-and-feel
DT=/usr/share/plasma/desktoptheme
CS=/usr/share/color-schemes
WP=/usr/share/wallpapers
PROFILE=/usr/share/kde-settings/kde-profile/default

echo "==> Applying Lumen Plasma theming"

# --- 1. Lumen color scheme (deep space blue/purple hybrid) -------------
cat > "${CS}/Lumen.colors" <<'EOF'
[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0
ColorEffect=0
ContrastAmount=0.1
ContrastEffect=1
IntensityAmount=0
IntensityEffect=0

[General]
Name=Lumen
shadeSortColumn=true

[Colors:Complementary]
BackgroundAlternate=#322771
BackgroundNormal=#2a2157
ForegroundActive=#b388ff
ForegroundInactive=#cfc9e8
ForegroundLink=#82aaff
ForegroundNegative=#ff6b81
ForegroundNeutral=#ffb454
ForegroundPositive=#7ee787
ForegroundVisited=#b388ff

[Colors:View]
BackgroundAlternate=#191334
BackgroundNormal=#0e0a1f
DecorationFocus=#8a6bff
DecorationHover=#5f9bff
ForegroundActive=#b388ff
ForegroundInactive=#a7a1c9
ForegroundLink=#82aaff
ForegroundNegative=#ff6b81
ForegroundNeutral=#ffb454
ForegroundPositive=#7ee787
ForegroundVisited=#b388ff

[Colors:Window]
BackgroundAlternate=#1c1736
BackgroundNormal=#14102a
BackgroundNegative=#3d1a24
BackgroundNeutral=#3a2e17
BackgroundPositive=#16321f
DecorationFocus=#8a6bff
DecorationFocusColor=#8a6bff
DecorationFocusContrast=#14102a
DecorationFocusCandy=#b79bff
DecorationHover=#5c8dff
DecorationHoverColor=#5c8dff
DecorationHoverContrast=#14102a
DecorationHoverCandy=#7aa2ff
ForegroundActive=#b388ff
ForegroundAlternate=#cfc9e8
ForegroundInactive=#a7a1c9
ForegroundLink=#82aaff
ForegroundNegative=#ff6b81
ForegroundNeutral=#ffb454
ForegroundNormal=#e9e7f5
ForegroundPositive=#7ee787
ForegroundVisited=#b388ff
NegativeText=#ff6b81
NeutralText=#ffb454
PositiveText=#7ee787

[Colors:Button]
BackgroundAlternate=#2a2157
BackgroundNormal=#241b47
DecorationFocus=#8a6bff
DecorationHover=#5c8dff
ForegroundAlternate=#d9d5ea
ForegroundInactive=#a7a1c9
ForegroundNegative=#ff6b81
ForegroundNeutral=#ffb454
ForegroundNormal=#e9e7f5
ForegroundPositive=#7ee787
ForegroundLink=#82aaff
ForegroundVisited=#b388ff

[Colors:Selection]
BackgroundAlternate=#7d6fff
BackgroundNormal=#6a5cff
ForegroundActive=#ffffff
ForegroundInactive=#e9e7f5
ForegroundLink=#ffffff
ForegroundNegative=#ffffff
ForegroundNeutral=#ffffff
ForegroundNormal=#ffffff
ForegroundPositive=#ffffff
ForegroundVisited=#ffffff

[Colors:Tooltip]
BackgroundAlternate=#2a2157
BackgroundNormal=Void
ForegroundActive=#e9e7f5
ForegroundInactive=#a7a1c9
ForegroundLink=#82aaff
ForegroundNegative=#ff6b81
ForegroundNeutral=#ffb454
ForegroundPositive=#7ee787
ForegroundVisited=#b388ff
EOF
# The Tooltip background trips the KDE color parser on literal "Void";
# normalize it (empty look-and-feel bug guard).
sed -i 's/^BackgroundNormal=Void$/BackgroundNormal=#241b47/' "${CS}/Lumen.colors"

# --- 1b. Force every foreground to pure white, lighten accents -----------
# HAARD GUARD: do NOT derive foregrounds. Text that is not #ffffff on the
# deep-space scheme is unreadable (dark text on the nebula surfaces). This
# pass rebuilds the file line-by-line: every Foreground* key is rewritten
# to #ffffff, missing ForegroundNormal keys are added, and accent keys
# (Link/Visited/Active) keep their blue/purple hue but are LIGHTENED so they
# stay distinguishable on dark planes.
python3 - <<'PY'
import re
p = "/usr/share/color-schemes/Lumen.colors"
lines = open(p).read().splitlines()
fg_re = re.compile(r"^Foreground\w*=")
color_sections = {"Complementary", "View", "Window", "Button", "Selection", "Tooltip"}
# accent keys mapped to slightly lighter blue/purple (visible on #14102a)
accent = {
    "ForegroundLink": "#a3c4ff",       # lighter blue  (#82aaff -> up)
    "ForegroundVisited": "#c9a8ff",    # lighter purple
    "ForegroundActive": "#c9a8ff",     # lighter purple
    "ForegroundInactive": "#d9d5ea",
}
out = []
section = None
has_normal = False
for ln in lines:
    if ln.startswith("["):
        if section in color_sections and not has_normal:
            out.append("ForegroundNormal=#ffffff")
        match = re.fullmatch(r"\[Colors:(.+)\]", ln)
        section = match.group(1) if match else None
        has_normal = False
        out.append(ln)
        continue
    if fg_re.match(ln):
        key = ln.split("=", 1)[0]
        ln = f"{key}={accent.get(key, '#ffffff')}"
        if key == "ForegroundNormal":
            has_normal = True
    out.append(ln)
if section in color_sections and not has_normal:
    out.append("ForegroundNormal=#ffffff")
open(p, "w").write("\n".join(out) + "\n")
print("REBUILT Lumen.colors: all Foreground*={} or lightened accents".format("#ffffff"))
PY

# --- 1c. HARD ASSERT: no dark foreground may survive anywhere -------------
# whitelist: pure white + the lightened accents only
WHITE_FGS="$(grep -iE '^Foreground(Normal|Alternate|Inactive|Link|Visited|Positive|Negative|Neutral|Active)=' "${CS}/Lumen.colors" || true)"
BAD="$(printf '%s\n' "$WHITE_FGS" | grep -viE '=(#ffffff|#a3c4ff|#c9a8ff|#d9d5ea)$' || true)"
if [[ -n "$BAD" ]]; then
  echo "FATAL: non-whitelisted foregrounds left in Lumen.colors" >&2
  printf '%s\n' "$BAD"
  exit 1
fi
grep -qE '^ForegroundNormal=#ffffff$' "${CS}/Lumen.colors" \
  || { echo "FATAL: ForegroundNormal is not pure white" >&2; exit 1; }
# Every color group must carry ForegroundNormal: a missing key makes KDE fall
# back to the default (dark #232629) text, which is how black text survived
# the rewrite pass before. Reject any section without it.
awk -F']' '/^\[Colors:/{s=$0} /^ForegroundNormal=#ffffff$/{s=""} END{exit (s!="")}' "${CS}/Lumen.colors" \
  || { echo "FATAL: a [Colors:*] section lacks ForegroundNormal=#ffffff" >&2; exit 1; }
echo "==> assert: Lumen.colors has only white/light foregrounds, none missing"

# --- 2. Lumen global theme (look-and-feel) ------------------------------
rm -rf "${LAF}/org.lumenora.lumen.desktop"
cp -a "${LAF}/org.kde.breezedark.desktop" "${LAF}/org.lumenora.lumen.desktop"
# reuse the splash art (breeze.desktop carries one) so it resolves
if [[ -d "${LAF}/org.kde.breeze.desktop/contents/splash" ]]; then
  cp -a "${LAF}/org.kde.breeze.desktop/contents/splash" \
        "${LAF}/org.lumenora.lumen.desktop/contents/"
fi

python3 - <<'PY'
import json
p = "/usr/share/plasma/look-and-feel/org.lumenora.lumen.desktop/metadata.json"
with open(p) as f:
    j = json.load(f)
k = j.setdefault("KPlugin", {})
k["Id"] = "org.lumenora.lumen.desktop"
k["Name"] = "Lumen"
k["Version"] = "0.7.6"
k["Comment"] = "Lumenora default: deep space blue/purple hybrid"
for key in [x for x in k if x.startswith("Name[")]:
    del k[key]
with open(p, "w") as f:
    json.dump(j, f, indent=1)
PY

cat > "${LAF}/org.lumenora.lumen.desktop/contents/defaults" <<'EOF'
[kdeglobals][KDE]
widgetStyle=Breeze
AnimationDurationFactor=0.5

[kdeglobals][General]
ColorScheme=Lumen

[kdeglobals][Icons]
Theme=breeze-dark

[plasmarc][Theme]
name=Lumen

[Wallpaper]
Image=Lumen

[kcminputrc][Mouse]
cursorTheme=breeze_cursors

[kwinrc][org.kde.kdecoration2]
library=org.kde.breeze
theme=Breeze

[ksplashrc][KSplash]
Theme=org.lumenora.lumen.desktop
EOF

# --- 3. Lumen Plasma Style (desktoptheme) -------------------------------
rm -rf "${DT}/Lumen"
cp -a "${DT}/breeze-dark" "${DT}/Lumen"

python3 - <<'PY'
import json
p = "/usr/share/plasma/desktoptheme/Lumen/metadata.json"
with open(p) as f:
    j = json.load(f)
k = j.setdefault("KPlugin", {})
k["Id"] = "Lumen"
k["Name"] = "Lumen"
k["Version"] = "0.7.6"
k["Comment"] = "Lumenora Plasma Style (deep space blue/purple)"
for key in [x for x in k if x.startswith("Name[")]:
    del k[key]
with open(p, "w") as f:
    json.dump(j, f, indent=1)
PY

cat > "${DT}/Lumen/plasmarc" <<'EOF'
[Wallpaper]
defaultWallpaperTheme=Lumen
defaultFileSuffix=.jpg
defaultWidth=3840
defaultHeight=2160

[AdaptiveTransparency]
enabled=true
EOF

rm -f "${DT}/Lumen/colors"
cp "${CS}/Lumen.colors" "${DT}/Lumen/colors"
# The stock "default" desktop theme has NO colors file: any widget whose SVG
# is missing from Lumen falls back to it, and without a colors file Plasma
# bakes the stock LIGHT palette (black text). Never let that happen: write
# the white Lumen palette into "default" and bump its version so Plasma's
# theme cache cannot keep the old one.
cp "${CS}/Lumen.colors" "${DT}/default/colors"
python3 - <<'PY'
import json
p = "/usr/share/plasma/desktoptheme/default/metadata.json"
with open(p) as f:
    j = json.load(f)
k = j.setdefault("KPlugin", {})
k["Version"] = k.get("Version", "1.0") + "-lumen8"
with open(p, "w") as f:
    json.dump(j, f, indent=1)
PY

# --- 4. System-wide defaults (honored when a home is created) -----------
write_lumen_kdeglobals() {
  local f="$1"
  if [[ -f "$f" ]] && grep -q "ColorScheme=Lumen" "$f"; then
    return
  fi
  cat >> "$f" <<'EOF'

[General]
ColorScheme=Lumen

[KDE]
AutomaticLookAndFeel=false
LookAndFeelPackage=org.lumenora.lumen.desktop
AnimationDurationFactor=0.5
EOF
}
write_lumen_kdeglobals "${PROFILE}/share/config/kdeglobals"
write_lumen_kdeglobals "${PROFILE}/xdg/kdeglobals"
write_lumen_kdeglobals "/etc/xdg/kdeglobals"

# --- 5. Make only Lumen selectable: drop the stock themes --------------
rm -rf "${LAF}/org.kde.breeze.desktop"
rm -rf "${LAF}/org.kde.breezedark.desktop"
rm -rf "${LAF}/org.kde.breezetwilight.desktop"
rm -rf "${LAF}/org.fedoraproject.fedora.desktop"
rm -rf "${LAF}/org.fedoraproject.fedoralight.desktop"
rm -rf "${LAF}/org.fedoraproject.fedoradark.desktop"
rm -rf "${DT}/breeze-dark"
rm -rf "${DT}/breeze-light"
rm -f "${CS}/BreezeClassic.colors"

# The PLM greeter (Plasma Login Manager) hard-uses the color scheme named
# "BreezeLight" ("Could not find color scheme BreezeLight, falling back")
# and Breeze consumers reference "BreezeDark". Do NOT delete those names;
# rebuild them on the Lumen palette so any fallback resolves to white text
# on the deep-space scheme instead of the stock dark-text palette.
for scheme in BreezeLight BreezeDark; do
  cp "${CS}/Lumen.colors" "${CS}/${scheme}.colors"
  python3 - "${CS}/${scheme}.colors" "$scheme" <<'PY'
import sys
p, name = sys.argv[1], sys.argv[2]
text = open(p).read()
import re
text = re.sub(r"(?ms)^\[General\].*?(?=^\[)", "[General]\nName=" + name + "\nshadeSortColumn=true\n\n", text, count=1)
open(p, "w").write(text)
PY
done

# --- 5b. Only the Lumen (cosmic Nebula) wallpaper stays -----------------
find "${WP}" -mindepth 1 -maxdepth 1 ! -name Lumen -exec rm -rf {} +
echo "==> Wallpapers remaining:"
ls "${WP}"

# --- 6. Fresh-desktop fallback wallpaper (org.kde.image defaults) ------
python3 - <<'PY'
import re
p = "/usr/share/plasma/wallpapers/org.kde.image/contents/config/main.xml"
text = open(p).read()
# point the Image entry default at the Lumen wallpaper package
text, n = re.subn(
    r'(<entry name="Image"[^>]*>)(.*?)(<default>)[^<]*(</default>)(.*?)</entry>',
    lambda m: m.group(1) + m.group(2) + m.group(3)
              + "file:///usr/share/wallpapers/Lumen/contents/images/nebula.jpg"
              + m.group(4) + m.group(5) + "</entry>",
    text, count=1, flags=re.S)
open(p, "w").write(text)
print("patched Image default in org.kde.image:", n)
PY

# --- 7. Sanity checks ----------------------------------------------------
echo "==> Global themes available:"
ls "${LAF}" | grep -v "^\." || true
echo "==> Plasma Styles available:"
ls "${DT}"
echo "==> Color schemes available:"
ls "${CS}"
echo "==> Lumen wallpaper package:"
ls -l "${WP}/Lumen/contents/images/" 2>/dev/null || echo "WARNING: wallpaper package missing"
