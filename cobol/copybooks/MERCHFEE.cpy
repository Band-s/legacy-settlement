      *----------------------------------------------------------------
      * MERCHFEE.CPY - CARD BRAND FEE SCHEDULE (EFFECTIVE 2024-01-01).
      * DEMO CODE WRITTEN FOR THE CURSOR FIELD ENGINEER EXERCISE.
      *
      *   FEE-BRAND  VI = VISA, MC = MASTERCARD, AX = AMEX
      *   FEE-PCT    SHARE OF THE AMOUNT, 4 DECIMALS (0.0180 = 1.80%)
      *   FEE-FIXED  PER-TRANSACTION FEE IN THE TRANSACTION CURRENCY
      *              (SEE SETTLE01 2230-CALCULATE FOR JPY)
      *----------------------------------------------------------------
       01  FEE-TABLE-VALUES.
           05  FILLER                   PIC X(10) VALUE 'VI00180010'.
           05  FILLER                   PIC X(10) VALUE 'MC00195010'.
           05  FILLER                   PIC X(10) VALUE 'AX00290015'.
       01  FEE-TABLE REDEFINES FEE-TABLE-VALUES.
           05  FEE-ENTRY                OCCURS 3 TIMES
                                        INDEXED BY FEE-IDX.
               10  FEE-BRAND            PIC X(02).
               10  FEE-PCT              PIC 9V9999.
               10  FEE-FIXED            PIC 9V99.
