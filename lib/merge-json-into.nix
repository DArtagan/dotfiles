# For config files an app also writes runtime state into, where a read-only home.file
# symlink won't do. Returns an activation script that deep-merges `settings` over the
# file at $HOME/`target` on each switch. Managed keys win; other keys are preserved;
# arrays are replaced wholesale, not appended.
{ pkgs }:
name: target: settings: ''
  settingsFile="$HOME/${target}"
  mkdir -p "$(dirname "$settingsFile")"
  managed=${pkgs.writeText "${name}.json" (builtins.toJSON settings)}
  if [ -f "$settingsFile" ]; then
    merged=$(${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$settingsFile" "$managed")
  else
    merged=$(${pkgs.jq}/bin/jq '.' "$managed")
  fi
  echo "$merged" > "$settingsFile"
''
