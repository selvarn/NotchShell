#!/usr/bin/env bash
#
# NotchShell bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/selvarn/NotchShell/master/install.sh | bash
#
# All this does is get hold of `tools/notchshell` and hand over to it: the
# installer and the updater are the same program, so there is only ever one
# place where installing is described.
set -euo pipefail

REPO_URL="${NOTCHSHELL_REPO:-https://github.com/selvarn/NotchShell.git}"
BRANCH="${NOTCHSHELL_BRANCH:-master}"
RAW="${NOTCHSHELL_RAW:-https://raw.githubusercontent.com/selvarn/NotchShell/$BRANCH}"

die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# Running from a checkout (`./install.sh`) uses that checkout's copy, so the
# script you are reading is the script that runs.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "$here" && -x "$here/tools/notchshell" ]]; then
    exec "$here/tools/notchshell" install "$@"
fi

command -v git >/dev/null || die "git is required (sudo pacman -S git)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if command -v curl >/dev/null; then
    curl -fsSL "$RAW/tools/notchshell" -o "$tmp/notchshell" || die "could not download the installer"
elif command -v wget >/dev/null; then
    wget -qO "$tmp/notchshell" "$RAW/tools/notchshell" || die "could not download the installer"
else
    die "curl or wget is required"
fi

[[ -s "$tmp/notchshell" ]] || die "the downloaded installer is empty"
chmod +x "$tmp/notchshell"

NOTCHSHELL_REPO="$REPO_URL" NOTCHSHELL_BRANCH="$BRANCH" exec bash "$tmp/notchshell" install "$@"
