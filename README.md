# legacy-settlement

> **Demo code written for the Cursor Field Engineer exercise.** This is not real
> Northwind Commerce code; Northwind Commerce is fictional, and the fee schedule
> is invented. It exists to show understanding, characterizing and modernizing
> legacy code with Cursor.

Northwind Commerce's legacy card settlement, as it might look after 30 years:

| Path | What it is | Runs here? |
|---|---|---|
| `cobol/SETTLE01.cbl` | Nightly batch: reads fixed-width settlement records, computes merchant fees and net settlement | yes, with GnuCOBOL |
| `cobol/copybooks/` | Record layouts: `SETTLREC.cpy` (input record), `MERCHFEE.cpy` (brand fee table) | |
| `data/input/*.dat` | Settlement batches, including edge cases (refunds, JPY, charity merchants, rejects, out of balance) | |
| `data/golden/*.out` | SETTLE01's actual output for each input, captured by running it | |
| `test/characterization.test.ts` | Runs SETTLE01 on every input and compares with the golden output byte for byte | yes |
| `vb6/` | Finance Ops' VB6 reconciliation tool: matches SETTLE01 totals against the bank statement | no (read-only, for business-rule extraction) |
| `java-port/` | Modernization target (README only) | |

## Run it

```bash
brew install gnucobol          # macOS; Ubuntu: sudo apt-get install -y gnucobol3
npm ci
scripts/build.sh               # -> build/SETTLE01
scripts/run.sh data/input/basic.dat /tmp/basic.out; echo "rc=$?"
npm test                       # characterization suite
```

Without `cobc`, `build.sh` and `run.sh` exit 127 with an install hint, and
`npm test` fails on "GnuCOBOL is installed".

## How the golden files were made

`node scripts/make-inputs.mjs` writes the inputs (80-byte records, see the
copybook). `scripts/regen-golden.sh` builds SETTLE01 and runs it on each input;
whatever it writes is the golden file. The golden files are observed behavior,
not a specification: if SETTLE01 is wrong, the golden file is wrong the same way,
and the characterization test protects that until someone decides otherwise.

This repo is **not** part of the VulnFleet CMDB, scan or eval.
