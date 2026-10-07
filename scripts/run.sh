#!/usr/bin/env bash
# Runs SETTLE01 on one settlement batch.
#   scripts/run.sh <input.dat> <output.out>
# Exit status is SETTLE01's return code (0, 4, 8 or 16), or 127 if cobc or
# the built program is missing.
set -uo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: scripts/run.sh <input.dat> <output.out>" >&2
  exit 2
fi
abs() { [[ "$1" == /* ]] && echo "$1" || echo "$PWD/$1"; }
in="$(abs "$1")"
out="$(abs "$2")"
cd "$(dirname "$0")/.."

if ! command -v cobc >/dev/null 2>&1; then
  echo "run.sh: cobc (GnuCOBOL) is not installed (macOS: brew install gnucobol; Ubuntu: sudo apt-get install -y gnucobol)." >&2
  exit 127
fi
if [[ ! -x build/SETTLE01 ]]; then
  echo "run.sh: build/SETTLE01 not found; run scripts/build.sh first." >&2
  exit 127
fi

SETTLE_IN="$in" SETTLE_OUT="$out" build/SETTLE01
