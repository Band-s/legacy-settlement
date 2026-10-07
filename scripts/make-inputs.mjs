// Writes data/input/*.dat: fixed-width 80-byte SETTLREC records
// (cobol/copybooks/SETTLREC.cpy). Inputs are hand-designed edge cases; the
// golden outputs are NOT written here, only by running SETTLE01
// (scripts/regen-golden.sh).
import fs from "node:fs";
import path from "node:path";

const dir = path.join(path.dirname(new URL(import.meta.url).pathname), "..", "data", "input");
const pad = (s, n) => String(s).padEnd(n, " ").slice(0, n);
const num = (s, n) => String(s).padStart(n, "0");
const cents = (amount) => (typeof amount === "string" ? amount : num(Math.round(amount * 100), 11));

const header = (batch, date) => pad("H" + pad(batch, 10) + date, 80);
const detail = (merchant, brand, type, currency, amount, auth = "A00001") =>
  pad("D" + pad(merchant, 8) + pad(brand, 2) + type + pad(currency, 3) + cents(amount) + "20260930" + pad(auth, 6), 80);
const trailer = (count, hash) => pad("T" + num(count, 7) + num(Math.round(hash * 100), 15), 80);

const files = {
  // Rounding half-up: AX 5.00 * 2.90% = 0.145 -> 0.15.
  basic: [
    header("B260930001", "20260930"),
    detail("10000001", "VI", "S", "USD", 100.0),
    detail("10000001", "MC", "S", "USD", 55.55),
    detail("10000002", "AX", "S", "EUR", 1234.56),
    detail("10000002", "AX", "S", "EUR", 5.0),
    trailer(4, 1395.11),
  ],
  // Refund: percentage fee given back, fixed fee still charged; a refund-only merchant nets negative.
  refunds: [
    header("B260930002", "20260930"),
    detail("20000001", "VI", "S", "USD", 200.0),
    detail("20000001", "VI", "R", "USD", 50.0),
    detail("20000002", "MC", "R", "GBP", 80.0),
    trailer(3, 330.0),
  ],
  // JPY: whole-yen rounding, fixed fee 0.10 -> 10 yen, minor units rejected, charity JPY truncated.
  jpy: [
    header("B260930003", "20260930"),
    detail("30000001", "VI", "S", "JPY", 12345.0),
    detail("30000001", "AX", "S", "JPY", 999.0),
    detail("30000002", "MC", "S", "JPY", 100.5),
    detail("90000003", "VI", "S", "JPY", 12345.0),
    trailer(4, 25789.5),
  ],
  // Charity (merchant id starts with 9): no fixed fee, percentage truncated. 19000001 is NOT a charity.
  charity: [
    header("B260930004", "20260930"),
    detail("19000001", "MC", "S", "USD", 10.0),
    detail("90000001", "MC", "S", "USD", 10.0),
    detail("90000001", "VI", "S", "USD", 99.99),
    detail("90000001", "AX", "S", "USD", 5.0),
    detail("90000001", "VI", "R", "USD", 20.0),
    trailer(5, 144.99),
  ],
  // Every reject reason, plus an unknown record type; trailer still balances (RC 4).
  rejects: [
    header("B260930005", "20260930"),
    detail("40000001", "VI", "S", "USD", 25.0),
    detail("40000001", "DS", "S", "USD", 25.0),
    detail("40000001", "VI", "X", "USD", 25.0),
    detail("40000001", "VI", "S", "CHF", 25.0),
    detail("40000001", "VI", "S", "USD", "000000ABC00"),
    pad("X40000001 THIS IS NOT A SETTLEMENT RECORD", 80),
    detail("40000002", "MC", "S", "USD", 12.34),
    trailer(6, 112.34),
  ],
  // Trailer count and hash both wrong (RC 8).
  "out-of-balance": [
    header("B260930006", "20260930"),
    detail("50000001", "VI", "S", "USD", 10.0),
    detail("50000001", "VI", "S", "USD", 20.0),
    trailer(3, 40.0),
  ],
  // No trailer at all (RC 8).
  "missing-trailer": [header("B260930007", "20260930"), detail("60000001", "MC", "S", "USD", 10.0)],
};

fs.mkdirSync(dir, { recursive: true });
for (const [name, lines] of Object.entries(files)) {
  for (const l of lines) if (l.length !== 80) throw new Error(`${name}: record is ${l.length} bytes, not 80`);
  fs.writeFileSync(path.join(dir, `${name}.dat`), lines.join("\n") + "\n");
  console.log(`wrote data/input/${name}.dat (${lines.length} records)`);
}
