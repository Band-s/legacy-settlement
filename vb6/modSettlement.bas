Attribute VB_Name = "modSettlement"
'------------------------------------------------------------------
' modSettlement - back-office reconciliation of SETTLE01 output
' against the bank statement. Finance Ops, rewritten 2003-02 (KAW).
'
' Demo code written for the Cursor Field Engineer exercise.
' Northwind Commerce is fictional; this is not real Northwind code.
'------------------------------------------------------------------
Option Explicit

Public Type MerchantNet
    MerchantId As String
    CurrencyCode As String
    NetAmount As Currency
    Matched As Boolean
End Type

Public Type BankLine
    ValueDate As String
    Reference As String
    Amount As Currency
    Matched As Boolean
End Type

Private Const RECON_TOLERANCE As Currency = 0.05

' Expected fee for one transaction, used by the fee check screen
' when a merchant disputes a settlement line.
Public Function ExpectedFee(ByVal MerchantId As String, ByVal Brand As String, _
                            ByVal IsRefund As Boolean, ByVal Amount As Currency) As Currency
    Dim pct As Double
    Dim fixedFee As Currency
    Dim pctFee As Currency

    Select Case UCase$(Brand)
        Case "VI": pct = 0.018: fixedFee = 0.1
        Case "MC": pct = 0.0195: fixedFee = 0.1
        Case "AX": pct = 0.029: fixedFee = 0.15
        Case Else
            Err.Raise vbObjectError + 513, "ExpectedFee", "Unknown card brand " & Brand
    End Select

    If Left$(MerchantId, 1) = "9" Then
        fixedFee = 0
    End If

    pctFee = Round(Amount * pct, 2)

    If IsRefund Then
        ExpectedFee = fixedFee - pctFee
    Else
        ExpectedFee = fixedFee + pctFee
    End If
End Function

' Reads the merchant rows of a SETTLE01 report (fixed columns).
Public Function LoadSettlementReport(ByVal Path As String, Rows() As MerchantNet) As Long
    Dim f As Integer, lineText As String, n As Long
    f = FreeFile
    Open Path For Input As #f
    Do While Not EOF(f)
        Line Input #f, lineText
        If Len(lineText) >= 77 And IsNumeric(Left$(lineText, 8)) Then
            ReDim Preserve Rows(n)
            Rows(n).MerchantId = Left$(lineText, 8)
            Rows(n).CurrencyCode = Mid$(lineText, 10, 3)
            Rows(n).NetAmount = CCur(Trim$(Mid$(lineText, 59, 19)))
            n = n + 1
        End If
    Loop
    Close #f
    LoadSettlementReport = n
End Function

' Bank statement export: ValueDate,Reference,Amount per line.
' Reference is "NW" + merchant id + currency, e.g. NW10000001USD.
Public Function LoadBankStatement(ByVal Path As String, Lines() As BankLine) As Long
    Dim f As Integer, lineText As String, parts() As String, n As Long
    f = FreeFile
    Open Path For Input As #f
    Do While Not EOF(f)
        Line Input #f, lineText
        parts = Split(lineText, ",")
        If UBound(parts) = 2 Then
            ReDim Preserve Lines(n)
            Lines(n).ValueDate = parts(0)
            Lines(n).Reference = Trim$(parts(1))
            Lines(n).Amount = CCur(parts(2))
            n = n + 1
        End If
    Loop
    Close #f
    LoadBankStatement = n
End Function

' Matches each merchant's net settlement to one bank line. Returns
' one result line per merchant and per unmatched bank line.
Public Function Reconcile(Rows() As MerchantNet, ByVal RowCount As Long, _
                          Lines() As BankLine, ByVal LineCount As Long) As Collection
    Dim results As New Collection
    Dim i As Long, j As Long, ref As String

    For i = 0 To RowCount - 1
        ref = "NW" & Rows(i).MerchantId & Rows(i).CurrencyCode
        For j = 0 To LineCount - 1
            If Not Lines(j).Matched And Lines(j).Reference = ref Then
                If Abs(Lines(j).Amount - Rows(i).NetAmount) <= RECON_TOLERANCE Then
                    Lines(j).Matched = True
                    Rows(i).Matched = True
                    results.Add "MATCHED    " & ref & "  " & Format$(Rows(i).NetAmount, "0.00")
                    Exit For
                End If
            End If
        Next j
        If Not Rows(i).Matched Then
            results.Add "NO BANK    " & ref & "  " & Format$(Rows(i).NetAmount, "0.00")
        End If
    Next i

    For j = 0 To LineCount - 1
        If Not Lines(j).Matched Then
            results.Add "NO SETTLE  " & Lines(j).Reference & "  " & Format$(Lines(j).Amount, "0.00")
        End If
    Next j
    Set Reconcile = results
End Function
