#!/bin/sh
set -u

# Allow git to operate on repos owned by other users (provisioner runs as root,
# repo may be owned by truenas_admin on the host volume).
git config --global --add safe.directory "$REPO_DEST"
git config --global --add safe.directory '*'

git config --global user.name "killakam3084"
git config --global user.email "cameron.rison@gmail.com"

# Clone the monorepo if not already present; otherwise refresh in a fail-safe way.
if [ ! -d "$REPO_DEST/.git" ]; then
  echo "[provisioner] Cloning $REPO_URL into $REPO_DEST"
  git clone --recurse-submodules "$REPO_URL" "$REPO_DEST" || {
    echo "[provisioner] Clone failed; container will remain alive for manual recovery" >&2
  }
else
  echo "[provisioner] Repo already present at $REPO_DEST — refreshing"
  git -C "$REPO_DEST" fetch --all --prune --tags || \
    echo "[provisioner] Fetch failed; continuing with existing checkout"

  if git -C "$REPO_DEST" rev-parse --verify main >/dev/null 2>&1; then
    git -C "$REPO_DEST" checkout main >/dev/null 2>&1 || true
    if git -C "$REPO_DEST" merge --ff-only origin/main >/dev/null 2>&1; then
      echo "[provisioner] Fast-forwarded to origin/main"
    else
      echo "[provisioner] Local checkout diverged from origin/main; leaving repo intact so container stays alive"
    fi
  else
    git -C "$REPO_DEST" checkout -B main origin/main >/dev/null 2>&1 || true
  fi

  git -C "$REPO_DEST" submodule sync --recursive || true
  git -C "$REPO_DEST" submodule update --init --recursive || true
fi

echo "[provisioner] Bootstrap complete. Repo at $REPO_DEST"

# Keep the container running so it can be exec'd into for ad-hoc tasks.
exec tail -f /dev/null
