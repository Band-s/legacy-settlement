// Merchant fee totals checked against data/golden, which is SETTLE01's own
// output. Acceptance filtering matches 2200-DETAIL so rejected rows stay out
// of the sum the way the batch leaves them out.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { calculateFee, CARD_BRANDS, CURRENCIES, type CardBrand, type Currency, type TransactionType } from "./fees.js";

const root = path.resolve(import.meta.dirname, "..");

interface Detail {
  merchantId: string;
  brand: string;
  transactionType: string;
  currency: string;
  amountField: string;
}

interface Group {
  merchantId: string;
  currency: string;
  count: number;
  grossMinor: bigint;
  feeMinor: bigint;
  netMinor: bigint;
}

function inputNames(): string[] {
  return fs
    .readdirSync(path.join(root, "data/input"))
    .filter((name) => name.endsWith(".dat"))
    .map((name) => name.replace(/\.dat$/, ""))
    .sort();
}

function parseDetails(name: string): Detail[] {
  const text = fs.readFileSync(path.join(root, "data/input", `${name}.dat`), "latin1");
  const details: Detail[] = [];
  for (const line of text.split(/\r?\n/)) {
    if (line.length === 0 || line[0] !== "D") continue;
    details.push({
      merchantId: line.slice(1, 9),
      brand: line.slice(9, 11),
      transactionType: line.slice(11, 12),
      currency: line.slice(12, 15),
      amountField: line.slice(15, 26),
    });
  }
  return details;
}

/** 2200-DETAIL acceptance. Rejected details contribute nothing to the group. */
function isAccepted(detail: Detail): detail is Detail & {
  brand: CardBrand;
  transactionType: TransactionType;
  currency: Currency;
} {
  if (!(CARD_BRANDS as readonly string[]).includes(detail.brand)) return false;
  if (detail.transactionType !== "S" && detail.transactionType !== "R") return false;
  if (!/^\d{11}$/.test(detail.amountField)) return false;
  if (!(CURRENCIES as readonly string[]).includes(detail.currency)) return false;
  if (detail.currency === "JPY" && detail.amountField.slice(9) !== "00") return false;
  return true;
}

function aggregate(name: string): Group[] {
  const groups: Group[] = [];
  const index = new Map<string, Group>();
  for (const detail of parseDetails(name)) {
    if (!isAccepted(detail)) continue;
    const key = `${detail.merchantId}:${detail.currency}`;
    let group = index.get(key);
    if (!group) {
      group = {
        merchantId: detail.merchantId,
        currency: detail.currency,
        count: 0,
        grossMinor: 0n,
        feeMinor: 0n,
        netMinor: 0n,
      };
      index.set(key, group);
      groups.push(group);
    }
    const amountMinor = BigInt(detail.amountField);
    const sign = detail.transactionType === "R" ? -1n : 1n;
    const fee = calculateFee({
      merchantId: detail.merchantId,
      brand: detail.brand,
      transactionType: detail.transactionType,
      currency: detail.currency,
      amountMinor,
    });
    group.count += 1;
    group.grossMinor += sign * amountMinor;
    group.feeMinor += fee.feeMinor;
  }
  for (const group of groups) {
    group.netMinor = group.grossMinor - group.feeMinor;
  }
  return groups;
}

function parseMinor(text: string): bigint {
  const negative = text.startsWith("-");
  const [whole, frac] = text.replace(/[,-]/g, "").split(".");
  if (frac?.length !== 2) {
    throw new Error(`Not a minor-unit amount: ${text}`);
  }
  const minor = BigInt(whole) * 100n + BigInt(frac);
  return negative ? -minor : minor;
}

function goldenGroups(name: string): Group[] {
  const text = fs.readFileSync(path.join(root, "data/golden", `${name}.out`), "latin1");
  const groups: Group[] = [];
  for (const line of text.split(/\r?\n/)) {
    const match = /^(\d{8}) ([A-Z]{3})\s+(\d+)\s+(-?[\d,]+\.\d{2})\s+(-?[\d,]+\.\d{2})\s+(-?[\d,]+\.\d{2})\s*$/.exec(line);
    if (!match) continue;
    const grossMinor = parseMinor(match[4]);
    const feeMinor = parseMinor(match[5]);
    const netMinor = parseMinor(match[6]);
    groups.push({
      merchantId: match[1],
      currency: match[2],
      count: Number(match[3]),
      grossMinor,
      feeMinor,
      netMinor,
    });
  }
  return groups;
}

test("every golden merchant total matches calculateFee", () => {
  const names = inputNames();
  assert.ok(names.includes("charity"));
  assert.ok(names.includes("jpy"));
  for (const name of names) {
    assert.deepEqual(aggregate(name), goldenGroups(name), name);
  }
});

test("charity 90000001 matches charity.out", () => {
  const actual = aggregate("charity").find((group) => group.merchantId === "90000001");
  const expected = goldenGroups("charity").find((group) => group.merchantId === "90000001");
  assert.ok(actual);
  assert.deepEqual(actual, expected);
  assert.equal(actual.feeMinor, 176n);
  assert.equal(actual.netMinor, 9323n);
});

test("yen groups match jpy.out, including charity 90000003", () => {
  const actual = aggregate("jpy");
  const expected = goldenGroups("jpy");
  assert.deepEqual(actual, expected);
  assert.deepEqual(
    actual.map((group) => group.merchantId),
    ["30000001", "90000003"],
  );
  const charity = actual.find((group) => group.merchantId === "90000003");
  assert.ok(charity);
  assert.equal(charity.feeMinor, 22200n);
  assert.equal(charity.netMinor, 1212300n);
});
