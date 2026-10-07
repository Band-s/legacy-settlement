package com.northwind.settlement;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Per-transaction fee from SETTLE01 paragraph {@code 2230-CALCULATE}
 * ({@code cobol/SETTLE01.cbl}).
 *
 * <p>The result is the amount that paragraph adds to {@code WS-GRP-FEES}.
 * On a sale that is the fixed fee plus the percentage fee. On a refund the
 * percentage fee is given back and the fixed fee is still charged, so the
 * result is fixed minus percentage ({@code SETTLE01.cbl:242-252}).
 *
 * <p>VB6 {@code ExpectedFee} is not consulted. It rounds charity percentages
 * and it has no JPY path.
 *
 * <p>Every money step uses {@link BigDecimal}. Rounding modes:
 * <ul>
 * <li>{@link #PERCENTAGE_HALF_UP} for a normal percentage: COBOL {@code ROUNDED}
 *     ({@code SETTLE01.cbl:217} for JPY whole yen, {@code :222} for cents).</li>
 * <li>{@link #CHARITY_TRUNCATE} when the merchant id starts with {@code '9'}
 *     (board memo FIN-98-014, {@code SETTLE01.cbl:226-240}): COBOL {@code COMPUTE}
 *     without {@code ROUNDED}, which truncates toward zero. The fixed fee is zero.</li>
 * <li>JPY fixed fee: exact scale shift by two places ({@code 0.10} becomes 10 yen,
 *     {@code SETTLE01.cbl:220}). No rounding.</li>
 * </ul>
 */
public final class FeeCalculator {
    /** COBOL {@code ROUNDED}: half away from zero. Amounts in this batch are unsigned. */
    static final RoundingMode PERCENTAGE_HALF_UP = RoundingMode.HALF_UP;

    /** Charity percentage: truncate toward zero. Do not "fix" this to a round. */
    static final RoundingMode CHARITY_TRUNCATE = RoundingMode.DOWN;

    private static final int CENT_SCALE = 2;
    private static final int YEN_SCALE = 0;

    private FeeCalculator() {}

    public static BigDecimal calculate(SettlementRecord detail) {
        FeeSchedule schedule = FeeSchedule.forBrand(detail.cardBrand());
        boolean jpy = "JPY".equals(detail.currency());
        boolean charity = detail.charity();
        int scale = jpy ? YEN_SCALE : CENT_SCALE;
        RoundingMode percentageMode = charity ? CHARITY_TRUNCATE : PERCENTAGE_HALF_UP;

        BigDecimal percentage = detail.amount().multiply(schedule.percentage()).setScale(scale, percentageMode);
        BigDecimal fixed = fixedFee(schedule, jpy, charity);

        if (detail.transactionType() == TransactionType.REFUND) {
            return fixed.subtract(percentage);
        }
        return fixed.add(percentage);
    }

    private static BigDecimal fixedFee(FeeSchedule schedule, boolean jpy, boolean charity) {
        if (charity) {
            return BigDecimal.ZERO.setScale(jpy ? YEN_SCALE : CENT_SCALE);
        }
        if (jpy) {
            // Quoted in cents, applied 1:1 as yen. 0.10 * 100 = 10 exactly.
            return schedule.fixedFee().scaleByPowerOfTen(2);
        }
        return schedule.fixedFee();
    }
}
