#!/bin/zsh
set -euo pipefail

script_name=${0:t}

usage() {
  printf 'Usage: %s [device UUID or name (default: booted)]\n' "$script_name"
}

display_path() {
  if [[ "$1" == /* && "$1" == *' '* ]]; then
    printf '%s' "${(qqq)1}"
  else
    printf '%s' "$1"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

device=${1:-booted}
app_id=org.fcitx.Fcitx5
group_id=group.org.fcitx.Fcitx5
local_storage_id=group.com.apple.FileProvider.LocalStorage

if ! app_bundle=$(xcrun simctl get_app_container "$device" "$app_id" app); then
  printf 'Unable to find Fcitx5. Start the simulator and install the app first.\n' >&2
  exit 1
fi
app_data=$(xcrun simctl get_app_container "$device" "$app_id" data)
simulator_data=$(xcrun simctl getenv "$device" HOME)

# simctl does not expose extension data containers. Resolve their UUID directories
# (and the App Group) from Mobile Container Manager metadata, not hardcoded paths.
typeset -A containers
for metadata in \
  "$simulator_data"/Containers/Shared/AppGroup/*/.com.apple.mobile_container_manager.metadata.plist(N) \
  "$simulator_data"/Containers/Data/PluginKitPlugin/*/.com.apple.mobile_container_manager.metadata.plist(N); do
  container_id=$(/usr/bin/plutil -extract MCMMetadataIdentifier raw -o - "$metadata" 2>/dev/null) || continue
  [[ "$container_id" == "$group_id" || "$container_id" == "$local_storage_id" || "$container_id" == "$app_id".* ]] || continue
  containers[$container_id]="${metadata:h}"
done

printf 'Simulator: %s\n' "${simulator_data:h:t}"
printf 'On My iPhone:\n'
local_storage=${containers[$local_storage_id]:-}
if [[ -n "$local_storage" && -d "$local_storage/File Provider Storage" ]]; then
  printf '  %s\n\n' "$(display_path "$local_storage/File Provider Storage")"
else
  printf '  (not created)\n\n'
fi
printf 'Bundle:\n  %s\n\n' "$(display_path "$app_bundle")"
printf 'Documents:\n  %s\n\n' "$(display_path "$app_data/Documents")"
printf 'App Group (%s):\n  %s\n' "$group_id" "$(display_path "${containers[$group_id]:-(not created)}")"

extensions=("$app_bundle"/PlugIns/*.appex(N))
if (( ${#extensions} == 0 )); then
  printf '\nNo keyboard extensions installed.\n'
fi
for extension in "${extensions[@]}"; do
  extension_id=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$extension/Info.plist")
  container=${containers[$extension_id]:-}
  printf '\nKeyboard extension (%s):\n' "$extension_id"
  if [[ -n "$container" ]]; then
    printf '  %s\n' "$(display_path "$container/Documents")"
  else
    printf '  (not created; activate this keyboard first)\n'
  fi
done
