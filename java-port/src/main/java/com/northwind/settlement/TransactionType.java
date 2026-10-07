package com.northwind.settlement;

/**
 * SR-TXN-TYPE from {@code cobol/copybooks/SETTLREC.cpy}. Sale and refund are the
 * only types {@code 2230-CALCULATE} runs for; anything else is rejected earlier.
 */
public enum TransactionType {
    SALE('S'),
    REFUND('R');

    private final char code;

    TransactionType(char code) {
        this.code = code;
    }

    public char code() {
        return code;
    }

    public static TransactionType fromCode(char code) {
        for (TransactionType type : values()) {
            if (type.code == code) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown transaction type " + code);
    }
}
