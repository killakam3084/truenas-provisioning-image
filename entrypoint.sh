#!/bin/sh
set -e

# Clone the monorepo if not already present; pull if it is.
if [ ! -d "$REPO_DEST/.git" ]; then
  echo "[provisioner] Cloning $REPO_URL into $REPO_DEST"
  git clone --recurse-submodules "$REPO_URL" "$REPO_DEST"
else
  echo "[provisioner] Repo already present at $REPO_DEST — pulling"
  git -C "$REPO_DEST" pull --recurse-submodules
fi

echo "[provisioner] Bootstrap complete. Repo at $REPO_DEST"

# Keep the container running so it can be exec'd into for ad-hoc tasks.
exec tail -f /dev/null
