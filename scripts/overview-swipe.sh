#!/usr/bin/env bash
# Build, try, install or roll back the patched cosmic-workspaces (the COSMIC
# workspace overview) on Pop!_OS 24.04.
#
#   scripts/overview-swipe.sh deps      # apt build dependencies (sudo)
#   scripts/overview-swipe.sh build     # clone at the installed revision, patch, cargo build
#   scripts/overview-swipe.sh try       # use the patched build (copy + wrapper in ~/.local, no sudo)
#   scripts/overview-swipe.sh untry     # remove them, back to the stock overview
#   scripts/overview-swipe.sh install   # copy to /usr/local/bin (sudo), shadows the package
#   scripts/overview-swipe.sh rollback  # remove it (sudo), back to the stock package
#
#   cosmic-comp (no wrap-around when swiping past the first/last workspace):
#   scripts/overview-swipe.sh comp-deps      # extra apt build dependencies (sudo)
#   scripts/overview-swipe.sh comp-build     # clone at the installed revision, patch, build
#   scripts/overview-swipe.sh comp-install   # copy to /usr/local/bin (sudo); log out and in
#   scripts/overview-swipe.sh comp-rollback  # remove it (sudo); log out and in
#
# The stock packages are never modified, so rolling back is just removing the
# copies in /usr/local/bin (cosmic-session starts both by name through PATH).
# If you ever overwrote the files in /usr/bin by hand:
#   sudo apt install --reinstall cosmic-workspaces cosmic-comp
# If the patched compositor ever fails to start, log in on a TTY
# (Ctrl+Alt+F3) and run: sudo rm /usr/local/bin/cosmic-comp
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$HOME/src/cosmic-workspaces-epoch}"
UPSTREAM="https://github.com/pop-os/cosmic-workspaces-epoch"
# Patches per upstream revision: patches/cosmic-workspaces/<git rev>/*.patch
PATCH_ROOT="$REPO_DIR/patches/cosmic-workspaces"
BIN="$SRC_DIR/target/release/cosmic-workspaces"
DEST=/usr/local/bin/cosmic-workspaces
TRY_LINK="$HOME/.local/bin/cosmic-workspaces"
# `try` runs a copy from here, never the build directory itself: a later
# `cargo build` there (another branch, another revision) must not change what
# the session starts at the next login.
TRY_DIR="$HOME/.local/opt/overview-swipe"
# cosmic-session doesn't pass `systemctl --user set-environment` vars to its
# children, so `try` installs a wrapper that sources this file (e.g.
# RUST_LOG=cosmic_workspaces=debug, COSMIC_WORKSPACES_SWIPE_MM=45).
ENV_FILE="$HOME/.config/cosmic-overview-swipe.env"

COMP_SRC_DIR="${COMP_SRC_DIR:-$HOME/src/cosmic-comp}"
COMP_UPSTREAM="https://github.com/pop-os/cosmic-comp"
COMP_PATCHES=("$REPO_DIR"/patches/cosmic-comp/*.patch)
COMP_BIN="$COMP_SRC_DIR/target/release/cosmic-comp"
COMP_DEST=/usr/local/bin/cosmic-comp

installed_rev() {
    # Version looks like 0.1.0~1765315332~24.04~954a45c: the last field is the git revision.
    dpkg-query -W -f='${Version}' "${1:-cosmic-workspaces}" | awk -F'~' '{print $NF}'
}

# Clone $2 into $1 if needed, create branch $3 at the installed revision of
# package $4 with the patches applied, and build it.
patched_build() {
    local dir=$1 upstream=$2 branch=$3 pkg=$4
    shift 4
    local rev
    rev="$(installed_rev "$pkg")"
    echo "installed $pkg revision: $rev"
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || git clone "$upstream" "$dir"
    cd "$dir"
    if ! git rev-parse -q --verify "$branch" >/dev/null; then
        git fetch origin
        git checkout -b "$branch" "$rev"
        git am "$@"
    else
        git checkout "$branch"
    fi
    cargo build --release
}

# PIDs of the running overview, by executable (the stock one or a `try`
# copy). Not by command line: that also matches any shell whose command
# merely mentions the path, and the process name is cut to 15 characters.
overview_pids() {
    local p exe
    for p in $(pgrep -f cosmic-workspaces); do
        exe="$(readlink "/proc/$p/exe" 2>/dev/null)" || continue
        exe="${exe% (deleted)}"
        case "${exe##*/}" in cosmic-workspaces | cosmic-workspaces-*) echo "$p" ;; esac
    done
}

restart_overview() {
    # cosmic-session supervises cosmic-workspaces and respawns it by name
    # through its PATH (~/.local/bin, /usr/local/bin, then /usr/bin) as soon
    # as it exits. So "restart" = kill it and wait for the respawn.
    local old new
    old="$(overview_pids | tr '\n' ' ')"
    [ -n "$old" ] && kill $old
    for _ in $(seq 50); do
        sleep 0.1
        new="$(overview_pids | head -1)"
        if [ -n "$new" ] && [[ " $old " != *" $new "* ]]; then
            echo "overview running: pid $new -> $(readlink "/proc/$new/exe")"
            return 0
        fi
    done
    echo "no new cosmic-workspaces yet; it will start on the next Super+W" >&2
}

case "${1:-}" in
deps)
    sudo apt install -y cargo pkg-config libegl1-mesa-dev libgbm-dev libinput-dev \
        libudev-dev libxkbcommon-dev libwayland-dev
    ;;
build)
    rev="$(installed_rev cosmic-workspaces)"
    if [ ! -d "$PATCH_ROOT/$rev" ]; then
        echo "no patches for the installed cosmic-workspaces ($rev)." >&2
        echo "available: $(ls "$PATCH_ROOT" | tr '\n' ' ')" >&2
        exit 1
    fi
    patched_build "$SRC_DIR" "$UPSTREAM" "overview-swipe-$rev" cosmic-workspaces "$PATCH_ROOT/$rev"/*.patch
    echo "built $BIN"
    ;;
comp-deps)
    sudo apt install -y cmake libfontconfig-dev libpixman-1-dev libseat-dev \
        libsystemd-dev libdisplay-info-dev
    ;;
comp-build)
    patched_build "$COMP_SRC_DIR" "$COMP_UPSTREAM" no-gesture-wrap cosmic-comp "${COMP_PATCHES[@]}"
    echo "built $COMP_BIN"
    ;;
comp-install)
    [ -x "$COMP_BIN" ] || { echo "run '$0 comp-build' first" >&2; exit 1; }
    sudo install -m 755 "$COMP_BIN" "$COMP_DEST"
    echo "installed $COMP_DEST; log out and back in to use it"
    echo "if the session fails to start: Ctrl+Alt+F3, log in, sudo rm $COMP_DEST"
    ;;
comp-rollback)
    sudo rm -f "$COMP_DEST"
    echo "removed $COMP_DEST; log out and back in to use the stock /usr/bin/cosmic-comp"
    ;;
try)
    [ -x "$BIN" ] || { echo "run '$0 build' first" >&2; exit 1; }
    rev="$(installed_rev cosmic-workspaces)"
    branch="$(git -C "$SRC_DIR" branch --show-current)"
    if [ "$branch" != "overview-swipe-$rev" ]; then
        echo "$SRC_DIR is on '$branch', not overview-swipe-$rev (the installed revision);" >&2
        echo "its build may not match this system. Run '$0 build' first." >&2
        exit 1
    fi
    mkdir -p "$TRY_DIR"
    run_bin="$TRY_DIR/cosmic-workspaces-$rev"
    # Replace, don't overwrite in place: the running overview keeps its inode.
    install -m 755 "$BIN" "$run_bin.new" && mv -f "$run_bin.new" "$run_bin"
    echo "$(git -C "$SRC_DIR" log -1 --format='%h %s')" > "$run_bin.commit"
    mkdir -p "$(dirname "$TRY_LINK")"
    [ -f "$ENV_FILE" ] || printf '%s\n' 'RUST_LOG=cosmic_workspaces=debug' '#COSMIC_WORKSPACES_SWIPE_MM=20' > "$ENV_FILE"
    rm -f "$TRY_LINK"
    # Same wrapper as get.sh: runs the build for the installed revision, or
    # the stock overview after a system update brings a revision without one.
    cat > "$TRY_LINK" <<WRAPPER
#!/bin/sh
# cosmic-overview-swipe wrapper (overview-swipe try wrapper; remove with: $0 untry)
set -a; [ -f "$ENV_FILE" ] && . "$ENV_FILE"; set +a
rev=\$(dpkg-query -W -f='\${Version}' cosmic-workspaces 2>/dev/null | awk -F'~' '{print \$NF}')
bin="$TRY_DIR/cosmic-workspaces-\$rev"
[ -n "\$rev" ] && [ -x "\$bin" ] && exec "\$bin" "\$@"
exec /usr/bin/cosmic-workspaces "\$@"
WRAPPER
    chmod +x "$TRY_LINK"
    restart_overview
    echo "press Super+W and swipe. Settings: $ENV_FILE (rerun 'try' after editing)"
    echo "logs: journalctl --user -f | grep cosmic_workspaces"
    echo "undo: $0 untry"
    ;;
untry)
    if grep -qs "overview-swipe try wrapper" "$TRY_LINK" || [ -L "$TRY_LINK" ]; then rm "$TRY_LINK"; fi
    rm -rf "$TRY_DIR"
    restart_overview
    ;;
install)
    [ -x "$BIN" ] || { echo "run '$0 build' first" >&2; exit 1; }
    sudo install -m 755 "$BIN" "$DEST"
    if grep -qs "overview-swipe try wrapper" "$TRY_LINK" || [ -L "$TRY_LINK" ]; then rm "$TRY_LINK"; fi
    restart_overview
    echo "installed $DEST (shadows /usr/bin/cosmic-workspaces)"
    ;;
rollback)
    sudo rm -f "$DEST"
    if grep -qs "overview-swipe try wrapper" "$TRY_LINK" || [ -L "$TRY_LINK" ]; then rm "$TRY_LINK"; fi
    restart_overview
    echo "removed $DEST; the stock /usr/bin/cosmic-workspaces is used again"
    ;;
*)
    sed -n '2,25p' "$0"
    exit 1
    ;;
esac
