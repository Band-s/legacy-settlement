#!/usr/bin/env bash
# Compiles cobol/SETTLE01.cbl into build/SETTLE01 with GnuCOBOL.
# Exits non-zero, with an install hint, if cobc is not installed.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v cobc >/dev/null 2>&1; then
  echo "build.sh: cobc (GnuCOBOL) is not installed." >&2
  echo "  macOS:  brew install gnucobol" >&2
  echo "  Ubuntu: sudo apt-get install -y gnucobol" >&2
  exit 127
fi

mkdir -p build
cobc -x -std=default -I cobol/copybooks -o build/SETTLE01 cobol/SETTLE01.cbl
echo "build.sh: built build/SETTLE01 with $(cobc --version | head -1)"
