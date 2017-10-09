SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 17, 2012
-- Description:	Pays Invoices which have been selected
-- =============================================
CREATE PROCEDURE [dbo].[PayInvoices] 
-- Add the parameters for the stored procedure here
	@transactions TransactionCollection READONLY,
	@payments PaymentCollection READONLY,	
	@paymentTransactions PaymentTransactionCollection READONLY,
	@paymentInvoiceCreditTransactions PaymentInvoiceCreditTransactionCollection READONLY,
	@bankTransactions BankTransactionCollection READONLY,
	@poinvoiceNotes POInvoiceNoteCollection READONLY,
	@journalEntries JournalEntryCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	INSERT INTO [Transaction] ([TransactionID], [AccountID], [ObjectID], [TransactionTypeID], [LedgerItemTypeID], [AppliesToTransactionID], [ReversesTransactionID], [PropertyID], [PersonID], [TaxRateGroupID], [NotVisible], [Origin], [Amount], [Description], [Note], [TransactionDate], [TimeStamp], [IsDeleted])
		SELECT TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, AppliesToTransactionID, ReversesTransactionID, PropertyID, PersonID, TaxGroupID, NotVisible, Origin, Amount, Description, Note, TransactionDate, TimeStamp, IsDeleted
		 FROM @transactions
		
	INSERT INTO Payment (PaymentID, AccountID, ObjectID, ObjectType, [Type], BatchID, ReferenceNumber, [Date], ReceivedFromPaidTo, Amount, [Description], Notes, PaidOut, Reversed, ReversedReason, ReversedDate, [TimeStamp])
		SELECT PaymentID, AccountID, ObjectID, ObjectType, [Type], BatchID, ReferenceNumber, [Date], ReceivedFromPaidTo, Amount, [Description], Notes, PaidOut, Reversed, ReversedReason, ReversedDate, [TimeStamp] FROM @payments
		
	INSERT INTO PaymentTransaction 
		SELECT * FROM @paymentTransactions
		
	INSERT INTO PaymentInvoiceCreditTransaction 
		SELECT * FROM @paymentInvoiceCreditTransactions
		
	INSERT INTO BankTransaction (BankTransactionID, AccountID, BankTransactionCategoryID, BankReconciliationID, ObjectID, ObjectType, ClearedDate, ReferenceNumber, QueuedForPrinting, CheckPrintedDate, BankFileID)
		SELECT BankTransactionID, AccountID, BankTransactionCategoryID, BankReconciliationID, ObjectID, ObjectType, ClearedDate, ReferenceNumber, QueuedForPrinting, CheckPrintedDate, null FROM @bankTransactions
		
	INSERT INTO JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
		SELECT JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis FROM @journalEntries
		
	INSERT INTO POInvoiceNote (POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, [Timestamp], IntegrationPartnerID)
		SELECT POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, GETUTCDATE(), IntegrationPartnerID FROM @poinvoiceNotes



END




GO
