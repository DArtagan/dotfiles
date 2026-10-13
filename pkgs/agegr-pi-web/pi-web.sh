#!@shell@
# shellcheck shell=bash
# Runs pi-web from a per-launch directory, so that it can rewrite Next's preview-mode
# secrets at startup. The npm release ships them in .next/prerender-manifest.json, the
# same in every copy, and a request carrying its previewModeId skips pi-web's proxy:
# the Host/Origin checks and the password. pi-web rotates them before starting Next,
# which fails in the read-only store and leaves them in place.
#
# The directory links to the package, except bin/ (pi-web finds the app from its own
# location) and the manifest, which are copies. Directories of launches that have
# exited are removed on the next launch.
set -euo pipefail

pkg=@pkg@

if [[ -n ${XDG_RUNTIME_DIR-} ]]; then
  base=$XDG_RUNTIME_DIR/agegr-pi-web
else
  base=${TMPDIR:-/tmp}/agegr-pi-web-$(id -u)
fi
[[ -d $base ]] || mkdir -m 700 "$base"
if [[ ! -O $base ]]; then
  echo "pi-web: $base belongs to another user" >&2
  exit 1
fi

for dir in "$base"/*; do
  [[ -d $dir ]] || continue
  kill -0 "${dir##*/}" 2>/dev/null || rm -rf "$dir"
done

# exec keeps this PID, which names the directory.
app=$base/$$
rm -rf "$app"
mkdir "$app" "$app/.next"
for entry in "$pkg"/* "$pkg"/.[!.]*; do
  case ${entry##*/} in
    bin) cp -r "$entry" "$app/" ;;
    .next) ;;
    *) ln -s "$entry" "$app/" ;;
  esac
done
for entry in "$pkg"/.next/*; do
  case ${entry##*/} in
    prerender-manifest.json) cp "$entry" "$app/.next/" ;;
    *) ln -s "$entry" "$app/.next/" ;;
  esac
done
chmod -R u+w "$app"

export NEXT_TELEMETRY_DISABLED=${NEXT_TELEMETRY_DISABLED-1}
exec @node@ "$app/bin/pi-web.js" "$@"
