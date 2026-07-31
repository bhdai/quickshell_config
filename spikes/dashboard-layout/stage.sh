#!/usr/bin/env bash
#
# Assembles a throwaway config directory for the spike and echoes its path.
#
# The spike cannot be run in place: `import qs.modules.common` resolves against the config
# root, so the spike needs a root that holds both its own files and the real shell's
# widgets. Symlinks rather than copies, so editing a spike file still hot-reloads. This is
# the `tests/lock-clock.sh` pattern.

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$here/../.." && pwd)"
stage="${DASH_STAGE:-/tmp/qs-dashboard-spike}"

rm -rf "$stage"
mkdir -p "$stage/config/modules" "$stage/runtime"
chmod 700 "$stage/runtime"

ln -s "$repo_root/modules/common" "$stage/config/modules/common"
ln -s "$repo_root/assets" "$stage/config/assets"

for f in "$here"/*.qml "$here"/mock.js; do
    ln -s "$f" "$stage/config/$(basename "$f")"
done

# The real month-grid arithmetic, not a spike copy of it.
ln -s "$repo_root/modules/bar/calendar_layout.js" "$stage/config/calendar_layout.js"

echo "$stage"
