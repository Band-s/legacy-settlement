package com.northwind.settlement;

import java.math.BigDecimal;
import java.util.List;

/**
 * Card-brand fee table from {@code cobol/copybooks/MERCHFEE.cpy} (effective
 * 2024-01-01 in the copybook comment). {@code FEE-PCT} is {@code PIC 9V9999}
 * and {@code FEE-FIXED} is {@code PIC 9V99}, quoted in the transaction currency
 * except JPY, where {@code 2230-CALCULATE} rescales the fixed fee.
 */
public record FeeSchedule(String brand, BigDecimal percentage, BigDecimal fixedFee) {
    public static final FeeSchedule VISA =
            new FeeSchedule("VI", new BigDecimal("0.0180"), new BigDecimal("0.10"));
    public static final FeeSchedule MASTERCARD =
            new FeeSchedule("MC", new BigDecimal("0.0195"), new BigDecimal("0.10"));
    public static final FeeSchedule AMEX =
            new FeeSchedule("AX", new BigDecimal("0.0290"), new BigDecimal("0.15"));

    private static final List<FeeSchedule> TABLE = List.of(VISA, MASTERCARD, AMEX);

    public FeeSchedule {
        if (brand == null || brand.length() != 2) {
            throw new IllegalArgumentException("brand must be 2 characters");
        }
        if (percentage == null || fixedFee == null) {
            throw new IllegalArgumentException("percentage and fixed fee are required");
        }
    }

    /**
     * Exact match on {@code FEE-BRAND}, same as the {@code SEARCH} in
     * {@code 2200-DETAIL}. Unknown brands are rejected before
     * {@code 2230-CALCULATE} and have no fee.
     */
    public static FeeSchedule forBrand(String brand) {
        for (FeeSchedule row : TABLE) {
            if (row.brand.equals(brand)) {
                return row;
            }
        }
        throw new IllegalArgumentException("Unknown card brand " + brand);
    }
}
