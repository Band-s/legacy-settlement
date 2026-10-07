#!/usr/bin/env bash
# Regenerates data/golden/*.out by running the real SETTLE01 on every
# data/input/*.dat. Only run this when the COBOL behavior is meant to change;
# the characterization test exists to catch unintended changes.
set -uo pipefail
cd "$(dirname "$0")/.."

scripts/build.sh || exit $?
mkdir -p data/golden
for input in data/input/*.dat; do
  name="$(basename "$input" .dat)"
  scripts/run.sh "$input" "data/golden/$name.out"
  echo "regen-golden.sh: data/golden/$name.out (SETTLE01 return code $?)"
done
