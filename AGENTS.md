# legacy-settlement

> Demo code written for the Cursor Field Engineer exercise. Not real Northwind
> Commerce code; Northwind Commerce is fictional.

## What this is

Northwind Commerce's nightly card settlement. `cobol/SETTLE01.cbl` reads the
day's card transactions per merchant, applies the card-brand fee schedule and
writes what each merchant is paid (net settlement). Finance Ops then reconciles
those totals against the bank statement with the VB6 tool in `vb6/`. Getting a
fee rule wrong means paying thousands of merchants the wrong amount.

Not in the VulnFleet CMDB. Treat it as Tier 1, internal, PCI-adjacent
(settlement amounts, no card numbers).

## Layout

- `cobol/SETTLE01.cbl`: the batch program. `cobol/copybooks/SETTLREC.cpy`: the
  80-byte input record. `cobol/copybooks/MERCHFEE.cpy`: the fee table.
- `data/input/*.dat` and `data/golden/*.out`: inputs and SETTLE01's captured output.
- `test/characterization.test.ts`: byte-for-byte comparison, plus the exit code.
- `vb6/`: VB6 reconciliation (not buildable here; read it, don't run it).
- `java-port/`: modernization target (see its README).

## Build, run, test

```bash
npm ci
scripts/build.sh                                   # cobc -> build/SETTLE01
scripts/run.sh data/input/basic.dat /tmp/basic.out # exit status = SETTLE01 return code
npm test                                           # characterization suite
```

Return codes: 0 OK, 4 some records rejected, 8 out of balance or no trailer,
16 cannot open files, 127 cobc or build missing.

## Conventions

- `cobol/`, `data/` and `test/` are the reference. A modernization PR must not
  change them; it must make the new code pass the same characterization tests.
- Golden files are regenerated only on purpose, with `scripts/regen-golden.sh`,
  and the PR must say why the behavior changed.
- When you explain a business rule, cite `file:line` and say how sure you are.
  Some rules live only in comments (see the change log at the top of SETTLE01).
- Money: never floating point in new code. Name the rounding mode for every rule.

## Cursor Cloud specific instructions

Verify command:

```bash
npm ci && scripts/build.sh && npm test
```

Before editing, run the verify command. If it fails, stop and report the failing command and output.

- The environment's install step (`.cursor/environment.json`) installs GnuCOBOL
  with apt if `cobc` is missing, then runs `npm ci` and `scripts/build.sh`.
- If `cobc` is still missing, report it; do not try to rewrite the tests to skip
  COBOL. The alternative image is `.cursor/Dockerfile.gnucobol` (see the comment
  at its top).
- For the Java port, also install a JDK (`sudo apt-get install -y openjdk-21-jdk-headless maven`)
  and keep the port in `java-port/`.
