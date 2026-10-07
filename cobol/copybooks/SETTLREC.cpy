      *----------------------------------------------------------------
      * SETTLREC.CPY - CARD SETTLEMENT INPUT RECORD, 80 BYTES, FIXED.
      * DEMO CODE WRITTEN FOR THE CURSOR FIELD ENGINEER EXERCISE.
      * NORTHWIND COMMERCE IS FICTIONAL.
      *
      * ONE BATCH = ONE 'H' HEADER, N 'D' DETAILS, ONE 'T' TRAILER.
      * AMOUNTS ARE UNSIGNED WITH 2 IMPLIED DECIMALS IN EVERY
      * CURRENCY, INCLUDING JPY (WHERE THE DECIMALS MUST BE 00).
      *----------------------------------------------------------------
       01  SETTLE-REC.
           05  SR-REC-TYPE              PIC X(01).
               88  SR-HEADER                       VALUE 'H'.
               88  SR-DETAIL                       VALUE 'D'.
               88  SR-TRAILER                      VALUE 'T'.
           05  SR-BODY                  PIC X(79).
           05  SR-DETAIL-BODY REDEFINES SR-BODY.
               10  SR-MERCHANT-ID       PIC X(08).
               10  SR-CARD-BRAND        PIC X(02).
               10  SR-TXN-TYPE          PIC X(01).
                   88  SR-SALE                     VALUE 'S'.
                   88  SR-REFUND                   VALUE 'R'.
               10  SR-CURRENCY          PIC X(03).
               10  SR-AMOUNT            PIC 9(09)V99.
               10  SR-AMOUNT-PARTS REDEFINES SR-AMOUNT.
                   15  SR-AMOUNT-UNITS  PIC 9(09).
                   15  SR-AMOUNT-CENTS  PIC 9(02).
               10  SR-TXN-DATE          PIC 9(08).
               10  SR-AUTH-CODE         PIC X(06).
               10  FILLER               PIC X(40).
           05  SR-HEADER-BODY REDEFINES SR-BODY.
               10  SR-BATCH-ID          PIC X(10).
               10  SR-BATCH-DATE        PIC 9(08).
               10  FILLER               PIC X(61).
           05  SR-TRAILER-BODY REDEFINES SR-BODY.
               10  SR-RECORD-COUNT      PIC 9(07).
               10  SR-HASH-TOTAL        PIC 9(13)V99.
               10  FILLER               PIC X(57).
