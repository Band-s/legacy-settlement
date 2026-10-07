       IDENTIFICATION DIVISION.
       PROGRAM-ID. SETTLE01.
      *----------------------------------------------------------------
      * SETTLE01 - DAILY CARD SETTLEMENT: MERCHANT FEES AND NET.
      *
      * DEMO CODE WRITTEN FOR THE CURSOR FIELD ENGINEER EXERCISE.
      * NORTHWIND COMMERCE IS FICTIONAL. THIS IS NOT REAL NORTHWIND
      * CODE AND NOT A REAL CARD SCHEME FEE SCHEDULE.
      *
      * READS ONE SETTLEMENT BATCH (LAYOUT SETTLREC) FROM THE FILE
      * NAMED BY ENV VAR SETTLE_IN AND WRITES A MERCHANT FEE REPORT
      * TO THE FILE NAMED BY SETTLE_OUT. DETAILS ARRIVE SORTED BY
      * MERCHANT AND CURRENCY (UPSTREAM SORT STEP).
      *
      * RETURN CODES   0 IN BALANCE, NOTHING REJECTED
      *                4 IN BALANCE, SOME RECORDS REJECTED
      *                8 TRAILER MISSING OR OUT OF BALANCE
      *               16 SETTLE_IN/SETTLE_OUT NOT SET OR NOT OPENABLE
      *
      * CHANGE LOG     1994-06-01 DPK  ORIGINAL VERSION (USD ONLY)
      *                1998-03-12 RJH  CHARITY MERCHANTS
      *                2001-11-20 MLT  EUR AND GBP
      *                2009-04-02 MLT  JPY (ZERO MINOR UNITS)
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SETTLE-IN ASSIGN TO WS-IN-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-IN-STATUS.
           SELECT REPORT-OUT ASSIGN TO WS-OUT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-OUT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD  SETTLE-IN.
           COPY SETTLREC.
       FD  REPORT-OUT.
       01  REPORT-LINE                  PIC X(100).
       WORKING-STORAGE SECTION.
       01  WS-IN-PATH                   PIC X(256) VALUE SPACES.
       01  WS-OUT-PATH                  PIC X(256) VALUE SPACES.
       01  WS-IN-STATUS                 PIC XX.
       01  WS-OUT-STATUS                PIC XX.
       01  WS-FLAGS.
           05  WS-EOF-FLAG              PIC X VALUE 'N'.
               88  WS-EOF                          VALUE 'Y'.
           05  WS-TRAILER-FLAG          PIC X VALUE 'N'.
               88  WS-TRAILER-SEEN                 VALUE 'Y'.
           05  WS-GROUP-FLAG            PIC X VALUE 'N'.
               88  WS-GROUP-OPEN                   VALUE 'Y'.
           05  WS-VALID-FLAG            PIC X VALUE 'Y'.
               88  WS-VALID                        VALUE 'Y'.
           COPY MERCHFEE.
       01  WS-COUNTERS.
           05  WS-REC-NO                PIC 9(07) VALUE 0.
           05  WS-DETAIL-COUNT          PIC 9(07) VALUE 0.
           05  WS-ACCEPT-COUNT          PIC 9(07) VALUE 0.
           05  WS-REJECT-COUNT          PIC 9(07) VALUE 0.
           05  WS-HASH-TOTAL            PIC 9(13)V99 VALUE 0.
       01  WS-RETURN-CODE               PIC 99 VALUE 0.
       01  WS-PREV-MERCHANT             PIC X(08) VALUE SPACES.
       01  WS-PREV-CURRENCY             PIC X(03) VALUE SPACES.
       01  WS-GROUP-TOTALS.
           05  WS-GRP-COUNT             PIC 9(07).
           05  WS-GRP-GROSS             PIC S9(11)V99.
           05  WS-GRP-FEES              PIC S9(11)V99.
       01  WS-CALC.
           05  WS-PCT-FEE               PIC 9(09)V99.
           05  WS-PCT-FEE-WHOLE         PIC 9(09).
           05  WS-FIXED-FEE             PIC 9(07)V99.
       01  WS-SUM-LINE.
           05  WS-SUM-MERCHANT          PIC X(09).
           05  WS-SUM-CURRENCY          PIC X(04).
           05  WS-SUM-COUNT             PIC ZZZZZZ9.
           05  WS-SUM-GROSS             PIC -ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  WS-SUM-FEES              PIC -ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  WS-SUM-NET               PIC -ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-REJ-LINE.
           05  FILLER                   PIC X(11) VALUE 'REJECT REC '.
           05  WS-REJ-NO                PIC 9(07).
           05  FILLER                   PIC X VALUE SPACE.
           05  WS-REJ-MERCHANT          PIC X(09).
           05  WS-REJ-REASON            PIC X(30).
       01  WS-OOB-LINE.
           05  FILLER                   PIC X(16) VALUE
               'OUT OF BALANCE: '.
           05  WS-OOB-WHAT              PIC X(13).
           05  WS-OOB-ACTUAL            PIC Z(12)9.99.
           05  FILLER                   PIC X(10) VALUE ' EXPECTED '.
           05  WS-OOB-EXPECTED          PIC Z(12)9.99.
       01  WS-TOT-LINE.
           05  FILLER                   PIC X(15) VALUE
               'DETAIL RECORDS '.
           05  WS-TOT-DETAIL            PIC ZZZZZZ9.
           05  FILLER                   PIC X(11) VALUE '  ACCEPTED '.
           05  WS-TOT-ACCEPT            PIC ZZZZZZ9.
           05  FILLER                   PIC X(11) VALUE '  REJECTED '.
           05  WS-TOT-REJECT            PIC ZZZZZZ9.
           05  FILLER                   PIC X(15) VALUE
               '  RETURN CODE '.
           05  WS-TOT-RC                PIC 99.

       PROCEDURE DIVISION.
       0000-MAIN.
           ACCEPT WS-IN-PATH FROM ENVIRONMENT 'SETTLE_IN'
           ACCEPT WS-OUT-PATH FROM ENVIRONMENT 'SETTLE_OUT'
           OPEN INPUT SETTLE-IN
           OPEN OUTPUT REPORT-OUT
           IF WS-IN-STATUS NOT = '00' OR WS-OUT-STATUS NOT = '00'
               DISPLAY 'SETTLE01: CANNOT OPEN SETTLE_IN/SETTLE_OUT, '
                   'STATUS ' WS-IN-STATUS '/' WS-OUT-STATUS
                   UPON SYSERR
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 8000-READ
           PERFORM UNTIL WS-EOF
               ADD 1 TO WS-REC-NO
               EVALUATE TRUE
                   WHEN SR-HEADER  PERFORM 2100-HEADER
                   WHEN SR-DETAIL  PERFORM 2200-DETAIL
                   WHEN SR-TRAILER PERFORM 2300-TRAILER
                   WHEN OTHER
                       MOVE 'UNKNOWN RECORD TYPE' TO WS-REJ-REASON
                       PERFORM 2900-REJECT
               END-EVALUATE
               PERFORM 8000-READ
           END-PERFORM
           PERFORM 3000-CLOSE-GROUP
           PERFORM 4000-FINISH
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

       2100-HEADER.
           MOVE SPACES TO REPORT-LINE
           STRING 'SETTLE01 SETTLEMENT REPORT  BATCH ' SR-BATCH-ID
                  '  DATE ' SR-BATCH-DATE
                  DELIMITED BY SIZE INTO REPORT-LINE
           WRITE REPORT-LINE
           MOVE 'MERCHANT CUR     CNT              GROSS           '
             & '    FEES                NET' TO REPORT-LINE
           WRITE REPORT-LINE.

       2200-DETAIL.
           ADD 1 TO WS-DETAIL-COUNT
           IF SR-AMOUNT IS NUMERIC
               ADD SR-AMOUNT TO WS-HASH-TOTAL
           END-IF
           MOVE 'Y' TO WS-VALID-FLAG
           SET FEE-IDX TO 1
           SEARCH FEE-ENTRY
               AT END
                   MOVE 'UNKNOWN CARD BRAND' TO WS-REJ-REASON
                   MOVE 'N' TO WS-VALID-FLAG
               WHEN FEE-BRAND (FEE-IDX) = SR-CARD-BRAND
                   CONTINUE
           END-SEARCH
           IF WS-VALID AND NOT (SR-SALE OR SR-REFUND)
               MOVE 'UNKNOWN TRANSACTION TYPE' TO WS-REJ-REASON
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-VALID AND SR-AMOUNT IS NOT NUMERIC
               MOVE 'AMOUNT NOT NUMERIC' TO WS-REJ-REASON
               MOVE 'N' TO WS-VALID-FLAG
           END-IF
           IF WS-VALID
               EVALUATE SR-CURRENCY
                   WHEN 'USD' WHEN 'EUR' WHEN 'GBP'
                       CONTINUE
                   WHEN 'JPY'
                       IF SR-AMOUNT-CENTS NOT = 0
                           MOVE 'JPY AMOUNT HAS MINOR UNITS'
                               TO WS-REJ-REASON
                           MOVE 'N' TO WS-VALID-FLAG
                       END-IF
                   WHEN OTHER
                       MOVE 'UNSUPPORTED CURRENCY' TO WS-REJ-REASON
                       MOVE 'N' TO WS-VALID-FLAG
               END-EVALUATE
           END-IF
           IF WS-VALID
               IF WS-GROUP-OPEN AND (SR-MERCHANT-ID NOT =
                  WS-PREV-MERCHANT OR SR-CURRENCY NOT =
                  WS-PREV-CURRENCY)
                   PERFORM 3000-CLOSE-GROUP
               END-IF
               IF NOT WS-GROUP-OPEN
                   MOVE SR-MERCHANT-ID TO WS-PREV-MERCHANT
                   MOVE SR-CURRENCY TO WS-PREV-CURRENCY
                   INITIALIZE WS-GROUP-TOTALS
                   MOVE 'Y' TO WS-GROUP-FLAG
               END-IF
               PERFORM 2230-CALCULATE
               ADD 1 TO WS-ACCEPT-COUNT
           ELSE
               PERFORM 2900-REJECT
           END-IF.

       2230-CALCULATE.
      *    PERCENTAGE FEE ROUNDED HALF-UP TO THE CENT. JPY HAS NO
      *    MINOR UNIT: ROUND TO THE WHOLE YEN, AND THE FIXED FEE
      *    (QUOTED IN CENTS) BECOMES YEN 1:1, SO 0.10 -> 10 YEN.
           IF SR-CURRENCY = 'JPY'
               COMPUTE WS-PCT-FEE-WHOLE ROUNDED =
                   SR-AMOUNT * FEE-PCT (FEE-IDX)
               MOVE WS-PCT-FEE-WHOLE TO WS-PCT-FEE
               COMPUTE WS-FIXED-FEE = FEE-FIXED (FEE-IDX) * 100
           ELSE
               COMPUTE WS-PCT-FEE ROUNDED =
                   SR-AMOUNT * FEE-PCT (FEE-IDX)
               MOVE FEE-FIXED (FEE-IDX) TO WS-FIXED-FEE
           END-IF
      *    1998-03-12 RJH  BOARD MEMO FIN-98-014. MERCHANT IDS THAT
      *    START WITH '9' ARE REGISTERED CHARITIES: NO FIXED FEE, AND
      *    THE PERCENTAGE FEE IS TRUNCATED, NOT ROUNDED, SO ROUNDING
      *    NEVER GOES AGAINST THE CHARITY. CONTRACTUAL - DO NOT
      *    "FIX". THE PREFIX IS THE ONLY MARKER; THE MERCHANT MASTER
      *    HAS NO CHARITY FLAG.
           IF SR-MERCHANT-ID (1:1) = '9'
               MOVE 0 TO WS-FIXED-FEE
               IF SR-CURRENCY = 'JPY'
                   COMPUTE WS-PCT-FEE-WHOLE =
                       SR-AMOUNT * FEE-PCT (FEE-IDX)
                   MOVE WS-PCT-FEE-WHOLE TO WS-PCT-FEE
               ELSE
                   COMPUTE WS-PCT-FEE = SR-AMOUNT * FEE-PCT (FEE-IDX)
               END-IF
           END-IF
      *    REFUNDS: THE PERCENTAGE FEE IS GIVEN BACK, THE FIXED FEE
      *    IS STILL CHARGED.
           ADD 1 TO WS-GRP-COUNT
           IF SR-REFUND
               SUBTRACT SR-AMOUNT FROM WS-GRP-GROSS
               COMPUTE WS-GRP-FEES = WS-GRP-FEES + WS-FIXED-FEE
                   - WS-PCT-FEE
           ELSE
               ADD SR-AMOUNT TO WS-GRP-GROSS
               COMPUTE WS-GRP-FEES = WS-GRP-FEES + WS-FIXED-FEE
                   + WS-PCT-FEE
           END-IF.

       2300-TRAILER.
           MOVE 'Y' TO WS-TRAILER-FLAG
           PERFORM 3000-CLOSE-GROUP
           IF SR-RECORD-COUNT NOT = WS-DETAIL-COUNT
               MOVE 'DETAIL COUNT' TO WS-OOB-WHAT
               MOVE WS-DETAIL-COUNT TO WS-OOB-ACTUAL
               MOVE SR-RECORD-COUNT TO WS-OOB-EXPECTED
               WRITE REPORT-LINE FROM WS-OOB-LINE
               MOVE 8 TO WS-RETURN-CODE
           END-IF
           IF SR-HASH-TOTAL NOT = WS-HASH-TOTAL
               MOVE 'HASH TOTAL' TO WS-OOB-WHAT
               MOVE WS-HASH-TOTAL TO WS-OOB-ACTUAL
               MOVE SR-HASH-TOTAL TO WS-OOB-EXPECTED
               WRITE REPORT-LINE FROM WS-OOB-LINE
               MOVE 8 TO WS-RETURN-CODE
           END-IF
           IF WS-RETURN-CODE = 0
               MOVE 'TRAILER CHECK OK' TO REPORT-LINE
               WRITE REPORT-LINE
           END-IF.

       2900-REJECT.
           ADD 1 TO WS-REJECT-COUNT
           MOVE WS-REC-NO TO WS-REJ-NO
           MOVE SR-MERCHANT-ID TO WS-REJ-MERCHANT
           WRITE REPORT-LINE FROM WS-REJ-LINE.

       3000-CLOSE-GROUP.
           IF WS-GROUP-OPEN
               MOVE WS-PREV-MERCHANT TO WS-SUM-MERCHANT
               MOVE WS-PREV-CURRENCY TO WS-SUM-CURRENCY
               MOVE WS-GRP-COUNT TO WS-SUM-COUNT
               MOVE WS-GRP-GROSS TO WS-SUM-GROSS
               MOVE WS-GRP-FEES TO WS-SUM-FEES
               COMPUTE WS-SUM-NET = WS-GRP-GROSS - WS-GRP-FEES
               WRITE REPORT-LINE FROM WS-SUM-LINE
               MOVE 'N' TO WS-GROUP-FLAG
           END-IF.

       4000-FINISH.
           IF NOT WS-TRAILER-SEEN
               MOVE 'OUT OF BALANCE: TRAILER MISSING' TO REPORT-LINE
               WRITE REPORT-LINE
               MOVE 8 TO WS-RETURN-CODE
           END-IF
           IF WS-RETURN-CODE = 0 AND WS-REJECT-COUNT > 0
               MOVE 4 TO WS-RETURN-CODE
           END-IF
           MOVE WS-DETAIL-COUNT TO WS-TOT-DETAIL
           MOVE WS-ACCEPT-COUNT TO WS-TOT-ACCEPT
           MOVE WS-REJECT-COUNT TO WS-TOT-REJECT
           MOVE WS-RETURN-CODE TO WS-TOT-RC
           WRITE REPORT-LINE FROM WS-TOT-LINE
           CLOSE SETTLE-IN REPORT-OUT.

       8000-READ.
           READ SETTLE-IN
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.
