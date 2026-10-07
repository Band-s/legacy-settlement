package com.northwind.settlement;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * One accepted detail from {@code cobol/copybooks/SETTLREC.cpy} (the
 * {@code SR-DETAIL-BODY} redefinition). Header and trailer layouts are not part
 * of the fee calculation. Parsing of the 80-byte line lives here.
 */
public record SettlementRecord(
        String merchantId,
        String cardBrand,
        TransactionType transactionType,
        String currency,
        BigDecimal amount,
        int transactionDate,
        String authCode) {

    /** SETTLREC is a fixed 80-byte record. */
    public static final int RECORD_LENGTH = 80;

    public SettlementRecord {
        if (merchantId == null || merchantId.length() != 8) {
            throw new IllegalArgumentException("merchant id must be 8 characters");
        }
        if (cardBrand == null || cardBrand.length() != 2) {
            throw new IllegalArgumentException("card brand must be 2 characters");
        }
        if (transactionType == null) {
            throw new IllegalArgumentException("transaction type is required");
        }
        if (currency == null || currency.length() != 3) {
            throw new IllegalArgumentException("currency must be 3 characters");
        }
        if (amount == null) {
            throw new IllegalArgumentException("amount is required");
        }
        if (amount.signum() < 0) {
            throw new IllegalArgumentException("amount is unsigned");
        }
        // The file stores PIC 9(09)V99, including JPY (cents must be 00, checked
        // before this record is priced). Reject a value that is not whole cents.
        amount = amount.setScale(2, RoundingMode.UNNECESSARY);
        if (authCode == null || authCode.length() != 6) {
            throw new IllegalArgumentException("auth code must be 6 characters");
        }
    }

    /** Detail fields the fee needs. Date and auth are the batch's usual fillers. */
    public static SettlementRecord of(
            String merchantId,
            String cardBrand,
            TransactionType transactionType,
            String currency,
            BigDecimal amount) {
        return new SettlementRecord(merchantId, cardBrand, transactionType, currency, amount, 20260930, "A00001");
    }

    /**
     * Parse one 80-byte detail. Offsets match SETTLREC.cpy: type {@code 1},
     * merchant {@code 2:8}, brand {@code 10:2}, txn type {@code 12}, currency
     * {@code 13:3}, amount {@code 16:11} with two implied decimals, date
     * {@code 27:8}, auth {@code 35:6}.
     */
    public static SettlementRecord parseDetail(String line) {
        if (line == null || line.length() != RECORD_LENGTH) {
            throw new IllegalArgumentException("SETTLREC detail must be 80 bytes");
        }
        if (line.charAt(0) != 'D') {
            throw new IllegalArgumentException("not a detail record");
        }
        String amountDigits = line.substring(15, 26);
        if (!amountDigits.chars().allMatch(Character::isDigit)) {
            throw new IllegalArgumentException("amount not numeric");
        }
        String dateDigits = line.substring(26, 34);
        if (!dateDigits.chars().allMatch(Character::isDigit)) {
            throw new IllegalArgumentException("transaction date not numeric");
        }
        BigDecimal amount = new BigDecimal(amountDigits).movePointLeft(2);
        return new SettlementRecord(
                line.substring(1, 9),
                line.substring(9, 11),
                TransactionType.fromCode(line.charAt(11)),
                line.substring(12, 15),
                amount,
                Integer.parseInt(dateDigits),
                line.substring(34, 40));
    }

    /** FIN-98-014: the charity marker is the first character of the merchant id. */
    public boolean charity() {
        return merchantId.charAt(0) == '9';
    }
}
