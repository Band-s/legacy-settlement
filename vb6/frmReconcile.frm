VERSION 5.00
Begin VB.Form frmReconcile 
   Caption         =   "Northwind Settlement Reconciliation"
   ClientHeight    =   5895
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   8760
   LinkTopic       =   "Form1"
   ScaleHeight     =   5895
   ScaleWidth      =   8760
   StartUpPosition =   3  'Windows Default
   Begin VB.TextBox txtReport 
      Height          =   315
      Left            =   1560
      TabIndex        =   0
      Text            =   "C:\NWSETTLE\OUT\SETTLE01.OUT"
      Top             =   120
      Width           =   5295
   End
   Begin VB.TextBox txtBank 
      Height          =   315
      Left            =   1560
      TabIndex        =   1
      Text            =   "C:\NWSETTLE\BANK\STATEMENT.CSV"
      Top             =   540
      Width           =   5295
   End
   Begin VB.CommandButton cmdReconcile 
      Caption         =   "&Reconcile"
      Default         =   -1  'True
      Height          =   375
      Left            =   7080
      TabIndex        =   2
      Top             =   120
      Width           =   1455
   End
   Begin VB.CommandButton cmdFeeCheck 
      Caption         =   "&Fee check..."
      Height          =   375
      Left            =   7080
      TabIndex        =   3
      Top             =   540
      Width           =   1455
   End
   Begin VB.ListBox lstResults 
      BeginProperty Font 
         Name            =   "Courier New"
         Size            =   9
      EndProperty
      Height          =   4740
      Left            =   120
      TabIndex        =   4
      Top             =   1020
      Width           =   8415
   End
   Begin VB.Label lblReport 
      Caption         =   "SETTLE01 report:"
      Height          =   255
      Left            =   120
      Top             =   180
      Width           =   1335
   End
   Begin VB.Label lblBank 
      Caption         =   "Bank statement:"
      Height          =   255
      Left            =   120
      Top             =   600
      Width           =   1335
   End
End
Attribute VB_Name = "frmReconcile"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' Demo code written for the Cursor Field Engineer exercise (fictional Northwind Commerce).
Option Explicit

Private Sub cmdReconcile_Click()
    Dim rows() As MerchantNet, lines() As BankLine
    Dim rowCount As Long, lineCount As Long
    Dim results As Collection, item As Variant

    On Error GoTo Failed
    lstResults.Clear
    rowCount = LoadSettlementReport(txtReport.Text, rows)
    lineCount = LoadBankStatement(txtBank.Text, lines)
    Set results = Reconcile(rows, rowCount, lines, lineCount)
    For Each item In results
        lstResults.AddItem item
    Next item
    lstResults.AddItem rowCount & " merchants, " & lineCount & " bank lines"
    Exit Sub
Failed:
    MsgBox "Reconciliation failed: " & Err.Description, vbExclamation
End Sub

Private Sub cmdFeeCheck_Click()
    Dim merchantId As String, brand As String, amountText As String
    Dim isRefund As Boolean

    merchantId = InputBox("Merchant id (8 digits):", "Fee check")
    If Len(merchantId) = 0 Then Exit Sub
    brand = InputBox("Card brand (VI, MC, AX):", "Fee check", "VI")
    amountText = InputBox("Amount:", "Fee check", "0.00")
    isRefund = (MsgBox("Is this a refund?", vbYesNo + vbQuestion, "Fee check") = vbYes)

    On Error GoTo Failed
    MsgBox "Expected fee: " & Format$(ExpectedFee(merchantId, brand, isRefund, CCur(amountText)), "0.00"), _
           vbInformation, "Fee check"
    Exit Sub
Failed:
    MsgBox "Fee check failed: " & Err.Description, vbExclamation
End Sub
