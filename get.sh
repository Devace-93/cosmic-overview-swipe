#!/bin/sh
# cosmic-overview-swipe installer: touchpad swipes that follow your fingers
# inside the COSMIC workspace overview (Super+W) on Pop!_OS 24.04.
#
#   curl -fsSL https://raw.githubusercontent.com/Devace-93/cosmic-overview-swipe/main/get.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/Devace-93/cosmic-overview-swipe/main/get.sh | sh -s uninstall
#   ... | sh -s status     what is installed and running
#   ... | sh -s restart    restart the overview (after editing the settings)
#
# No sudo, nothing in /usr is touched. It downloads the patched overview built
# for the cosmic-workspaces revision you have installed, verifies its
# checksum, puts it in ~/.local/opt/overview-swipe and adds a small wrapper
# at ~/.local/bin/cosmic-workspaces, which COSMIC starts instead of
# /usr/bin/cosmic-workspaces. When a system update brings a revision there is
# no build for, the wrapper starts the stock overview; run this again then.
#
# Environment knobs:
#   OVERVIEW_SWIPE_VERSION=v0.1.0  install from a specific release instead of the latest
#   OVERVIEW_SWIPE_DRY_RUN=1       print what would be done, change nothing
set -eu

REPO="Devace-93/cosmic-overview-swipe"
BASE_URL="${OVERVIEW_SWIPE_BASE_URL:-https://github.com/$REPO/releases/download}"
VERSION="${OVERVIEW_SWIPE_VERSION:-}"
DRY="${OVERVIEW_SWIPE_DRY_RUN:-}"
OPT_DIR="$HOME/.local/opt/overview-swipe"
WRAPPER="$HOME/.local/bin/cosmic-workspaces"
ENV_FILE="$HOME/.config/cosmic-overview-swipe.env"
STOCK=/usr/bin/cosmic-workspaces
MARK="cosmic-overview-swipe wrapper"

say() { printf '>> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
run() { if [ -n "$DRY" ]; then printf '   %s\n' "$*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

installed_rev() {
    # Version looks like 0.1.0~1765315332~24.04~954a45c: the last field is the git revision.
    dpkg-query -W -f='${Version}' cosmic-workspaces 2>/dev/null | awk -F'~' '{print $NF}'
}

# PIDs of the running overview, by executable (stock or ours).
overview_pids() {
    for p in $(pgrep -f cosmic-workspaces 2>/dev/null || true); do
        exe=$(readlink "/proc/$p/exe" 2>/dev/null) || continue
        exe=${exe% (deleted)}
        case "${exe##*/}" in cosmic-workspaces | cosmic-workspaces-*) echo "$p" ;; esac
    done
}

# cosmic-session respawns the overview by name through its PATH as soon as it
# exits, so restarting it is just stopping it.
restart_overview() {
    old=$(overview_pids | tr '\n' ' ')
    [ -n "$old" ] || { say "the overview is not running; it starts with your next login"; return 0; }
    run kill $old
    [ -n "$DRY" ] && return 0
    i=0
    while [ $i -lt 50 ]; do
        sleep 0.1
        new=$(overview_pids | head -n1)
        case " $old " in *" $new "*) new="" ;; esac
        if [ -n "$new" ]; then
            say "overview restarted: $(readlink "/proc/$new/exe")"
            return 0
        fi
        i=$((i + 1))
    done
    say "the overview has not come back yet; it will on the next Super+W or login"
}

# Whether the session (cosmic-session) looks up programs in ~/.local/bin.
session_has_local_bin() {
    sp=$(pgrep -x cosmic-session | head -n1)
    [ -n "$sp" ] || return 0
    tr '\0' '\n' < "/proc/$sp/environ" 2>/dev/null | grep -q "^PATH=\(.*:\)\?$HOME/.local/bin\(:.*\)\?$"
}

write_wrapper() {
    if [ -e "$WRAPPER" ] && ! grep -qs "$MARK\|overview-swipe try wrapper" "$WRAPPER"; then
        die "$WRAPPER exists and is not ours; move it away first"
    fi
    run mkdir -p "$(dirname "$WRAPPER")"
    [ -n "$DRY" ] && { printf '   write %s\n' "$WRAPPER"; return 0; }
    cat > "$WRAPPER.tmp" <<EOF
#!/bin/sh
# $MARK (https://cosmic-swipe.3m4.net)
# Runs the patched overview built for the installed cosmic-workspaces
# revision, or the stock one when there is no build for it.
# Remove: curl -fsSL https://raw.githubusercontent.com/$REPO/main/get.sh | sh -s uninstall
set -a; [ -f "$ENV_FILE" ] && . "$ENV_FILE"; set +a
rev=\$(dpkg-query -W -f='\${Version}' cosmic-workspaces 2>/dev/null | awk -F'~' '{print \$NF}')
bin="$OPT_DIR/cosmic-workspaces-\$rev"
[ -n "\$rev" ] && [ -x "\$bin" ] && exec "\$bin" "\$@"
exec $STOCK "\$@"
EOF
    chmod +x "$WRAPPER.tmp"
    mv -f "$WRAPPER.tmp" "$WRAPPER"
}

do_install() {
    [ "$(uname -s)" = Linux ] || die "this is for Linux"
    have curl || die "curl is required"
    have tar || die "tar is required"
    have dpkg-query || die "dpkg-query not found: this needs Pop!_OS (or another Debian-based COSMIC install)"
    rev=$(installed_rev)
    [ -n "$rev" ] || die "the cosmic-workspaces package is not installed"
    case "$(uname -m)" in
        x86_64|amd64) arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) die "unsupported architecture: $(uname -m)" ;;
    esac
    if [ -z "$VERSION" ]; then
        VERSION=$(curl -fsSI "https://github.com/$REPO/releases/latest" | tr -d '\r' \
                  | sed -n 's/^[Ll]ocation: .*\/tag\///p' | tail -n1)
        [ -n "$VERSION" ] || die "could not find the latest release (no network, or no release yet)"
    fi
    say "release $VERSION, your cosmic-workspaces revision $rev ($arch)"

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$BASE_URL/$VERSION/SHA256SUMS" || die "could not download SHA256SUMS"
    asset="cosmic-workspaces-$rev-$arch-linux.tar.gz"
    if ! grep -q " $asset\$" "$tmp/SHA256SUMS"; then
        supported=$(sed -n 's/.*cosmic-workspaces-\([0-9a-f]*\)-.*/\1/p' "$tmp/SHA256SUMS" | sort -u | tr '\n' ' ')
        echo "error: release $VERSION has no build for cosmic-workspaces $rev ($arch)." >&2
        echo "       Supported revisions: $supported" >&2
        echo "       Your system is newer or older than the patches. Check for a newer release, or" >&2
        echo "       open an issue: https://github.com/$REPO/issues" >&2
        exit 1
    fi
    say "downloading $asset"
    curl -fsSL --retry 3 -o "$tmp/$asset" "$BASE_URL/$VERSION/$asset" || die "download failed"
    if have sha256sum; then
        (cd "$tmp" && grep " $asset\$" SHA256SUMS | sha256sum -c --quiet -) || die "checksum mismatch for $asset"
        say "checksum ok"
    else
        die "sha256sum not available; refusing to install an unverified binary"
    fi
    tar xzf "$tmp/$asset" -C "$tmp"
    dir="$tmp/${asset%.tar.gz}"
    [ -x "$dir/cosmic-workspaces" ] || die "the archive has no cosmic-workspaces binary"

    run mkdir -p "$OPT_DIR"
    # Replace, never overwrite in place: the running overview keeps its file.
    run cp "$dir/cosmic-workspaces" "$OPT_DIR/cosmic-workspaces-$rev.new"
    run mv -f "$OPT_DIR/cosmic-workspaces-$rev.new" "$OPT_DIR/cosmic-workspaces-$rev"
    run cp "$dir/SOURCE" "$OPT_DIR/cosmic-workspaces-$rev.source"
    run cp "$dir/LICENSE-GPL-3.0" "$OPT_DIR/LICENSE-GPL-3.0"
    [ -n "$DRY" ] || printf '%s %s\n' "$VERSION" "$rev" > "$OPT_DIR/installed"
    if [ ! -f "$ENV_FILE" ] && [ -z "$DRY" ]; then
        mkdir -p "$(dirname "$ENV_FILE")"
        cat > "$ENV_FILE" <<'EOF'
# cosmic-overview-swipe settings, read when the overview starts.
# Apply a change: run the installer with "restart" (see https://cosmic-swipe.3m4.net), or log out and in.
#COSMIC_WORKSPACES_SWIPE_MM=20   # finger travel (mm) per workspace; higher = slower
#COSMIC_WORKSPACES_SWIPE_WRAP=0  # older COSMIC only: stop at the first/last workspace
EOF
    fi
    write_wrapper
    say "installed $OPT_DIR/cosmic-workspaces-$rev"
    restart_overview
    if ! session_has_local_bin; then
        say "your session does not look in ~/.local/bin yet: log out and back in once"
    fi
    say "done: press Super+W and swipe with 3 or 4 fingers."
    say "settings: $ENV_FILE    remove: ... | sh -s uninstall"
}

do_uninstall() {
    if grep -qs "$MARK\|overview-swipe try wrapper" "$WRAPPER"; then
        run rm -f "$WRAPPER"
    fi
    run rm -rf "$OPT_DIR"
    say "removed; the stock overview is used again ($ENV_FILE kept)"
    restart_overview
}

do_status() {
    rev=$(installed_rev)
    echo "cosmic-workspaces revision: ${rev:-not installed}"
    if [ -f "$OPT_DIR/installed" ]; then echo "installed release: $(cat "$OPT_DIR/installed")"; else echo "installed release: none"; fi
    if [ -n "$rev" ] && [ -x "$OPT_DIR/cosmic-workspaces-$rev" ]; then
        echo "build for this revision: yes"
    else
        echo "build for this revision: no (the stock overview runs; run the installer again)"
    fi
    grep -qs "$MARK\|overview-swipe try wrapper" "$WRAPPER" && echo "wrapper: $WRAPPER" || echo "wrapper: not installed"
    for p in $(overview_pids); do echo "running: pid $p $(readlink "/proc/$p/exe")"; done
}

case "${1:-install}" in
    install) do_install ;;
    uninstall|remove) do_uninstall ;;
    status) do_status ;;
    restart) restart_overview ;;
    *) die "usage: get.sh [install|uninstall|status|restart]" ;;
esac
