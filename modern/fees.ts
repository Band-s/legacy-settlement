// Fee calculation from SETTLE01 2230-CALCULATE (cobol/SETTLE01.cbl:212-253)
// and the brand table in cobol/copybooks/MERCHFEE.cpy.
//
// Money is integer minor units of the settlement record: 2 implied decimals
// in every currency, including JPY. No floating point.
//
// Rounding, named per path:
//   USD, EUR, GBP percentage — HALF_UP to the minor unit (0.01).
//   JPY percentage            — HALF_UP to the whole yen, stored as yen.00.
//   JPY fixed fee             — schedule minor units × 100 (0.10 → 10 yen).
//   Merchant id prefix "9"    — fixed fee 0; percentage recomputed DOWN
//                               (truncate toward zero) at that same scale.
//   Refund                    — fee contribution is fixed − percentage.
//   Sale                      — fee contribution is fixed + percentage.

export const CARD_BRANDS = ["VI", "MC", "AX"] as const;
export type CardBrand = (typeof CARD_BRANDS)[number];

export const CURRENCIES = ["USD", "EUR", "GBP", "JPY"] as const;
export type Currency = (typeof CURRENCIES)[number];

export type TransactionType = "S" | "R";

/** FEE-PCT is PIC 9V9999, so 180 means 0.0180. */
const PCT_DENOMINATOR = 10_000n;

const SCHEDULE: Record<CardBrand, { pct: bigint; fixedMinor: bigint }> = {
  VI: { pct: 180n, fixedMinor: 10n },
  MC: { pct: 195n, fixedMinor: 10n },
  AX: { pct: 290n, fixedMinor: 15n },
};

export interface FeeInput {
  merchantId: string;
  brand: CardBrand;
  transactionType: TransactionType;
  currency: Currency;
  /** Unsigned amount in minor units (PIC 9(09)V99). */
  amountMinor: bigint;
}

export interface FeeResult {
  /** Percentage component, always >= 0, in minor units. */
  percentageMinor: bigint;
  /** Fixed component, always >= 0, in minor units. Zero for a charity. */
  fixedMinor: bigint;
  /** Signed contribution to the merchant fee total. */
  feeMinor: bigint;
}

/** HALF_UP. Numerator is non-negative; denominator is positive. */
function divideHalfUp(numerator: bigint, denominator: bigint): bigint {
  return (numerator + denominator / 2n) / denominator;
}

/** DOWN, toward zero. COBOL truncation into a PIC with no ROUNDED phrase. */
function divideDown(numerator: bigint, denominator: bigint): bigint {
  return numerator / denominator;
}

function isBrand(brand: string): brand is CardBrand {
  return (CARD_BRANDS as readonly string[]).includes(brand);
}

function isCurrency(currency: string): currency is Currency {
  return (CURRENCIES as readonly string[]).includes(currency);
}

/**
 * Signed fee contribution of one accepted detail.
 * Mirrors 2230-CALCULATE: round first, then the charity prefix overwrites
 * both components (SETTLE01.cbl:216-253).
 */
export function calculateFee(input: FeeInput): FeeResult {
  if (!isBrand(input.brand)) {
    throw new Error(`Unknown card brand ${input.brand}`);
  }
  if (!isCurrency(input.currency)) {
    throw new Error(`Unsupported currency ${input.currency}`);
  }
  if (input.transactionType !== "S" && input.transactionType !== "R") {
    throw new Error(`Unknown transaction type ${input.transactionType}`);
  }
  if (input.amountMinor < 0n) {
    throw new Error("Amount must be unsigned");
  }

  const schedule = SCHEDULE[input.brand];
  const charity = input.merchantId.charAt(0) === "9";

  let percentageMinor: bigint;
  let fixedMinor: bigint;

  if (input.currency === "JPY") {
    if (input.amountMinor % 100n !== 0n) {
      throw new Error("JPY amount has minor units");
    }
    const yen = input.amountMinor / 100n;
    const product = yen * schedule.pct;
    const wholeYen = divideHalfUp(product, PCT_DENOMINATOR);
    percentageMinor = wholeYen * 100n;
    fixedMinor = schedule.fixedMinor * 100n;
  } else {
    percentageMinor = divideHalfUp(input.amountMinor * schedule.pct, PCT_DENOMINATOR);
    fixedMinor = schedule.fixedMinor;
  }

  if (charity) {
    fixedMinor = 0n;
    if (input.currency === "JPY") {
      const yen = input.amountMinor / 100n;
      percentageMinor = divideDown(yen * schedule.pct, PCT_DENOMINATOR) * 100n;
    } else {
      percentageMinor = divideDown(input.amountMinor * schedule.pct, PCT_DENOMINATOR);
    }
  }

  const feeMinor =
    input.transactionType === "R" ? fixedMinor - percentageMinor : fixedMinor + percentageMinor;

  return { percentageMinor, fixedMinor, feeMinor };
}
