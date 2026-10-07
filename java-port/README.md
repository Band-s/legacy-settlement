# java-port/ (modernization target)

Empty on purpose. The port is done live in the demo, or in a pre-run on its own
branch. Nothing here is a port yet.

## Target

- **Java 21**, plain Maven project, no framework: `SettlementBatch` reads a
  SETTLREC file and writes the same report as SETTLE01.
- Money in `java.math.BigDecimal` with explicit `RoundingMode` per rule:
  `HALF_UP` for standard fees, `DOWN` (truncate) for charity merchants, scale 0
  for JPY. No `double` anywhere in a money path.
- Record layouts from `cobol/copybooks/` become immutable records
  (`SettlementRecord`, `FeeSchedule`) with fixed-width parsing in one place.
- The VB6 `ExpectedFee` rule is **not** the source of truth: SETTLE01 is. Any
  difference (VB6 rounds charity fees with banker's `Round()`) is reported, not
  copied.

## Definition of done for the first slice

1. Fee calculation only (`2230-CALCULATE`), as a pure function with unit tests
   that cite the COBOL line each case comes from.
2. The full port passes the existing characterization suite: for every
   `data/input/*.dat`, the Java output equals `data/golden/*.out` byte for byte,
   and the exit status equals the COBOL return code.
3. No change to `cobol/`, `data/` or `test/` in the same PR.
