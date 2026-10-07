package com.northwind.settlement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * One case per fee rule in {@code 2230-CALCULATE}, using the amounts in
 * {@code scripts/make-inputs.mjs}. Expectations are the SETTLE01 results
 * (golden reports under {@code data/golden/}), not VB6 {@code ExpectedFee}.
 */
class FeeCalculatorTest {

    /**
     * Percentage fee rounds half-up to the cent.
     * {@code SETTLE01.cbl:222-223}: {@code COMPUTE WS-PCT-FEE ROUNDED}.
     * {@code scripts/make-inputs.mjs} basic: AX 5.00 * 2.90% = 0.145, which
     * half-up sends to 0.15 (half-even or truncation would stay at 0.14, and
     * the fee would be 0.29 instead of 0.30).
     */
    @Test
    void percentageFeeRoundsHalfUpToTheCent() {
        assertEquals(new BigDecimal("0.30"), fee("10000002", "AX", "S", "EUR", "5.00"));
        // 55.55 * 1.95% = 1.083225 -> 1.08, plus the 0.10 fixed fee.
        assertEquals(new BigDecimal("1.18"), fee("10000001", "MC", "S", "USD", "55.55"));
        // 1234.56 * 2.90% = 35.80224 -> 35.80, plus 0.15.
        assertEquals(new BigDecimal("35.95"), fee("10000002", "AX", "S", "EUR", "1234.56"));
        // 100.00 * 1.80% = 1.80 exactly, plus 0.10. No tie to break.
        assertEquals(new BigDecimal("1.90"), fee("10000001", "VI", "S", "USD", "100.00"));
    }

    /**
     * Merchant ids that start with 9 are charities: no fixed fee, and the
     * percentage is truncated toward zero. {@code SETTLE01.cbl:226-240}
     * (board memo FIN-98-014). {@code 19000001} is not a charity; only the
     * first character counts ({@code make-inputs.mjs} charity batch).
     */
    @Test
    void charityPercentageIsTruncatedAndFixedFeeIsZero() {
        // 10.00 * 1.95% = 0.195. Half-up would be 0.20 plus 0.10 fixed = 0.30.
        assertEquals(new BigDecimal("0.30"), fee("19000001", "MC", "S", "USD", "10.00"));
        // Same product, truncated to 0.19, fixed fee forced to 0.
        assertEquals(new BigDecimal("0.19"), fee("90000001", "MC", "S", "USD", "10.00"));
        // 99.99 * 1.80% = 1.79982, truncated to 1.79 (half-up would be 1.80).
        assertEquals(new BigDecimal("1.79"), fee("90000001", "VI", "S", "USD", "99.99"));
        // 5.00 * 2.90% = 0.145, truncated to 0.14 (half-up would be 0.15).
        assertEquals(new BigDecimal("0.14"), fee("90000001", "AX", "S", "USD", "5.00"));
    }

    /**
     * JPY has no minor unit. The percentage rounds half-up to the whole yen
     * (scale 0) and the fixed fee, quoted in cents, becomes yen 1:1.
     * {@code SETTLE01.cbl:213-220}. Amounts are the jpy batch in
     * {@code make-inputs.mjs}: 12345 VI and 999 AX.
     */
    @Test
    void jpyPercentageRoundsHalfUpToWholeYenAndFixedFeeScalesByOneHundred() {
        // 12345 * 1.80% = 222.21 -> 222 yen, fixed 0.10 -> 10 yen.
        assertEquals(new BigDecimal("232"), fee("30000001", "VI", "S", "JPY", "12345.00"));
        // 999 * 2.90% = 28.971 -> 29 yen, fixed 0.15 -> 15 yen.
        assertEquals(new BigDecimal("44"), fee("30000001", "AX", "S", "JPY", "999.00"));
    }

    /**
     * Charity JPY truncates the percentage to the whole yen and charges no
     * fixed fee. {@code SETTLE01.cbl:232-236}. The batch amount 12345 truncates
     * and rounds to the same 222 yen. 999, the other JPY amount in
     * {@code make-inputs.mjs}, does not: 28.971 truncates to 28 and half-up
     * rounds to 29. GnuCOBOL {@code COMPUTE} without {@code ROUNDED} into
     * {@code PIC 9(09)} yields 28.
     */
    @Test
    void jpyCharityTruncatesPercentageToWholeYen() {
        assertEquals(new BigDecimal("222"), fee("90000003", "VI", "S", "JPY", "12345.00"));
        assertEquals(new BigDecimal("28"), fee("90000003", "AX", "S", "JPY", "999.00"));
    }

    /**
     * Refunds give the percentage fee back and still charge the fixed fee.
     * {@code SETTLE01.cbl:242-248}. Amounts are the refunds batch, plus the
     * charity refund (fixed fee already zero, so the charge is just minus the
     * truncated percentage).
     */
    @Test
    void refundReturnsPercentageFeeAndStillChargesFixedFee() {
        // Sale 200.00 * 1.80% = 3.60 + 0.10.
        assertEquals(new BigDecimal("3.70"), fee("20000001", "VI", "S", "USD", "200.00"));
        // Refund 50.00 * 1.80% = 0.90 given back, fixed 0.10 still charged.
        assertEquals(new BigDecimal("-0.80"), fee("20000001", "VI", "R", "USD", "50.00"));
        // Refund-only merchant: 80.00 * 1.95% = 1.56, charge 0.10 - 1.56.
        assertEquals(new BigDecimal("-1.46"), fee("20000002", "MC", "R", "GBP", "80.00"));
        // Charity refund: 20.00 * 1.80% = 0.36 truncated stays 0.36, fixed 0.
        assertEquals(new BigDecimal("-0.36"), fee("90000001", "VI", "R", "USD", "20.00"));
    }

    /** Every accepted detail in {@code scripts/make-inputs.mjs}. */
    @ParameterizedTest(name = "{0} {1} {2} {3} {4} -> {5}")
    @CsvSource({
        "10000001, VI, S, USD, 100.00, 1.90",
        "10000001, MC, S, USD, 55.55, 1.18",
        "10000002, AX, S, EUR, 1234.56, 35.95",
        "10000002, AX, S, EUR, 5.00, 0.30",
        "20000001, VI, S, USD, 200.00, 3.70",
        "20000001, VI, R, USD, 50.00, -0.80",
        "20000002, MC, R, GBP, 80.00, -1.46",
        "30000001, VI, S, JPY, 12345.00, 232",
        "30000001, AX, S, JPY, 999.00, 44",
        "90000003, VI, S, JPY, 12345.00, 222",
        "19000001, MC, S, USD, 10.00, 0.30",
        "90000001, MC, S, USD, 10.00, 0.19",
        "90000001, VI, S, USD, 99.99, 1.79",
        "90000001, AX, S, USD, 5.00, 0.14",
        "90000001, VI, R, USD, 20.00, -0.36",
        "40000001, VI, S, USD, 25.00, 0.55",
        "40000002, MC, S, USD, 12.34, 0.34",
        "50000001, VI, S, USD, 10.00, 0.28",
        "50000001, VI, S, USD, 20.00, 0.46",
        "60000001, MC, S, USD, 10.00, 0.30"
    })
    void acceptedDetailFromMakeInputs(
            String merchant, String brand, String type, String currency, String amount, String expected) {
        assertEquals(new BigDecimal(expected), fee(merchant, brand, type, currency, amount));
    }

    /**
     * Summed fees are the fee column of {@code data/golden/*.out}. JPY group
     * totals are whole yen (the report picture prints them with {@code .00}).
     */
    @Test
    void groupFeesMatchGoldenReports() {
        assertEquals(new BigDecimal("3.08"), sum("10000001", "VI", "S", "USD", "100.00", "10000001", "MC", "S", "USD", "55.55"));
        assertEquals(new BigDecimal("36.25"), sum("10000002", "AX", "S", "EUR", "1234.56", "10000002", "AX", "S", "EUR", "5.00"));
        assertEquals(new BigDecimal("2.90"), sum("20000001", "VI", "S", "USD", "200.00", "20000001", "VI", "R", "USD", "50.00"));
        assertEquals(new BigDecimal("-1.46"), fee("20000002", "MC", "R", "GBP", "80.00"));
        assertEquals(new BigDecimal("276"), sum("30000001", "VI", "S", "JPY", "12345.00", "30000001", "AX", "S", "JPY", "999.00"));
        assertEquals(new BigDecimal("222"), fee("90000003", "VI", "S", "JPY", "12345.00"));
        assertEquals(new BigDecimal("0.30"), fee("19000001", "MC", "S", "USD", "10.00"));
        assertEquals(
                new BigDecimal("1.76"),
                fee("90000001", "MC", "S", "USD", "10.00")
                        .add(fee("90000001", "VI", "S", "USD", "99.99"))
                        .add(fee("90000001", "AX", "S", "USD", "5.00"))
                        .add(fee("90000001", "VI", "R", "USD", "20.00")));
        assertEquals(new BigDecimal("0.55"), fee("40000001", "VI", "S", "USD", "25.00"));
        assertEquals(new BigDecimal("0.34"), fee("40000002", "MC", "S", "USD", "12.34"));
        assertEquals(new BigDecimal("0.74"), sum("50000001", "VI", "S", "USD", "10.00", "50000001", "VI", "S", "USD", "20.00"));
        assertEquals(new BigDecimal("0.30"), fee("60000001", "MC", "S", "USD", "10.00"));
    }

    /** The first priced line of {@code data/input/basic.dat} is the 100.00 Visa sale. */
    @Test
    void parsesBasicDetailAndPricesIt() throws Exception {
        Path input = repoRoot().resolve("data/input/basic.dat");
        List<String> lines = Files.readAllLines(input);
        SettlementRecord detail = SettlementRecord.parseDetail(lines.get(1));
        assertEquals("10000001", detail.merchantId());
        assertEquals("VI", detail.cardBrand());
        assertEquals(TransactionType.SALE, detail.transactionType());
        assertEquals("USD", detail.currency());
        assertEquals(new BigDecimal("100.00"), detail.amount());
        assertEquals(new BigDecimal("1.90"), FeeCalculator.calculate(detail));
    }

    /**
     * Unknown brands never reach {@code 2230-CALCULATE}
     * ({@code SETTLE01.cbl:163-168}). The rejects batch uses brand DS.
     */
    @Test
    void unknownBrandHasNoFee() {
        IllegalArgumentException error = assertThrows(
                IllegalArgumentException.class, () -> fee("40000001", "DS", "S", "USD", "25.00"));
        assertEquals("Unknown card brand DS", error.getMessage());
    }

    private static BigDecimal fee(String merchant, String brand, String type, String currency, String amount) {
        return FeeCalculator.calculate(SettlementRecord.of(
                merchant, brand, TransactionType.fromCode(type.charAt(0)), currency, new BigDecimal(amount)));
    }

    private static BigDecimal sum(String... fields) {
        BigDecimal total = BigDecimal.ZERO;
        for (int i = 0; i < fields.length; i += 5) {
            total = total.add(fee(fields[i], fields[i + 1], fields[i + 2], fields[i + 3], fields[i + 4]));
        }
        return total;
    }

    private static Path repoRoot() {
        Path cwd = Path.of("").toAbsolutePath().normalize();
        if (Files.exists(cwd.resolve("data/input/basic.dat"))) {
            return cwd;
        }
        Path parent = cwd.getParent();
        if (parent != null && Files.exists(parent.resolve("data/input/basic.dat"))) {
            return parent;
        }
        throw new IllegalStateException("data/input/basic.dat not found from " + cwd);
    }
}
