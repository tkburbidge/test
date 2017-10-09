SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[ApplyAvailableBalance] 
	-- Add the parameters for the stored procedure here
	@objectIDs GuidCollection READONLY,
	@personID uniqueidentifier,
	@date date,
	@postingBatchID uniqueidentifier = null
	
AS

DECLARE @accountID bigint
DECLARE @prepaidIncomeGLAccountID uniqueidentifier
DECLARE @accountsReceivableGLAccountID uniqueidentifier
DECLARE @undepositedFundsGLAccountID uniqueidentifier
DECLARE @creditTTypeGLAccountID uniqueidentifier 

DECLARE @taxTTypeID uniqueidentifier

DECLARE @loopCtr int = 1						-- Counter to loop through all of the accounts passed in. 
DECLARE @maxCtr int								-- Max number of Accounts
DECLARE @paymentCtr int							-- Counter to loop through all of the accounts passed in.
DECLARE @maxPaymentCtr int						-- Max number of UnApplied Payments.

DECLARE @workingBalance money					-- Sum of UnAppliedPayments
DECLARE @workingAmountDue money					-- Sum of Amount Due from Outstanding Charges
DECLARE @workingObjectID uniqueidentifier
DECLARE @propertyID uniqueidentifier
DECLARE @ttGroup nvarchar(20)
DECLARE @amountAllocated money					-- Amount we can allocate from a given payment

-- Current Charge Variables
DECLARE @curTransID uniqueidentifier
DECLARE @curAmount money
DECLARE @curUnPaidAmount money
DECLARE @curDesc nvarchar(500)
DECLARE @curTransDate date
DECLARE @curGLAccountID uniqueidentifier
DECLARE @taxRateGroupID uniqueidentifier
DECLARE @myCreditTaxRebate money
DECLARE @unpaidCharge money

-- Current Payment Variables
DECLARE @payTransID uniqueidentifier
DECLARE @payPayID uniqueidentifier
DECLARE @payTTName nvarchar(50)
DECLARE @payTTID uniqueidentifier
DECLARE @payTAmount money
DECLARE @payReference nvarchar(500)
DECLARE @payLITID uniqueidentifier
DECLARE @payDesc nvarchar(500)
DECLARE @payTOrigin nvarchar(10)
DECLARE @payPostingBatchID uniqueidentifier
DECLARE @payAllocated bit
DECLARE @payLITAppliesToLITID uniqueidentifier
DECLARE @payLITGLAccountID uniqueidentifier

DECLARE @taxSum decimal(6, 4)
DECLARE @newTransID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Available Balance Table
	CREATE TABLE #Accounts (
		ProcessNumber		int identity,
		AccountID			bigint					not null,
		PropertyID			uniqueidentifier		not null,
		ObjectID			uniqueidentifier		not null,
		TTGroup				nvarchar(25)			not null,
		AvailableBalance	money					null)
		
-- Outstanding Charges Table
    CREATE TABLE #TempTransactions (
		ID					int identity,
		ObjectID			uniqueidentifier		NOT NULL,
		TransactionID		uniqueidentifier		NOT NULL,
		Amount				money					NOT NULL,
		TaxAmount			money					NULL,
		UnPaidAmount		money					NULL,
		TaxUnpaidAmount		money					NULL,
		[Description]		nvarchar(500)			NULL,
		TranDate			datetime2				NULL,
		GLAccountID			uniqueidentifier		NULL, 
		OrderBy				smallint				NULL,
		TaxRateGroupID		uniqueidentifier		NULL,
		LedgerItemTypeID	uniqueidentifier		NULL,
		LedgerItemTypeAbbr	nvarchar(50)			NULL,
		GLNumber			nvarchar(50)			NULL,
		IsWriteOffable		bit						NULL,
		Notes				nvarchar(MAX)			NULL,
		TaxRateID			uniqueidentifier		NULL)		
		
-- Outstanding Payments Table
	CREATE TABLE #TempPayments (
		CurrentPayment		int identity,
		ObjectID			uniqueidentifier		NOT NULL,
		TransactionID		uniqueidentifier		NOT NULL,
		PaymentID			uniqueidentifier		NOT NULL,
		TTName				nvarchar(25)			NOT NULL,
		TransactionTypeID	uniqueidentifier		NOT NULL,
		Amount				money					NOT NULL,
		Reference			nvarchar(50)			NULL,
		LedgerItemTypeID	uniqueidentifier		NULL,
		[Description]		nvarchar(1000)			NULL,
		Origin				nvarchar(50)			NULL,
		PaymentDate			date					NULL,
		PostingBatchID		uniqueidentifier		NULL,
		Allocated			bit						NOT NULL,
		AppliesToLedgerItemTypeID uniqueidentifier	NULL,
		LedgerItemTypeAbbreviation	nvarchar(50)	NULL,
		GLNumber			nvarchar(50)			NULL,
		GLAccountID			uniqueidentifier		NULL,
		TaxRateID			uniqueidentifier	    NULL)
		
		
	SET @taxTTypeID = NULL
-- Get Available Balances for Each ObjectID passed in the collection.				
	INSERT INTO #Accounts
		SELECT	t.AccountID AS 'AccountID', t.PropertyID AS 'PropertyID', t.ObjectID AS 'ObjectID', tt.[Group] AS 'TTGroup',
				SUM(t.Amount) AS 'AvailableBalance'
		FROM [Transaction] t
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Credit')			
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			CROSS APPLY (SELECT Value FROM @objectIDs) OIDS
		WHERE OIDS.Value = t.ObjectID
		  AND t.AppliesToTransactionID IS NULL
		  AND t.ReversesTransactionID IS NULL
		  AND tr.TransactionID IS NULL
		  AND t.Amount > 0
		  AND (((@postingBatchID IS NULL) AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))) OR (((t.PostingBatchID = @postingBatchID) AND (pb.IsPosted = 1))))
		GROUP BY t.ObjectID, tt.[Group], t.PropertyID, t.AccountID
		
	SET @accountID = (SELECT TOP 1 AccountID FROM #Accounts)
	IF (@accountID IS NULL)
	BEGIN
		SET @accountID = (SELECT TOP 1 AccountID FROM UnitLeaseGroup WHERE UnitLeaseGroupID IN (SELECT Value FROM @objectIDs))
	END
	IF (@accountID IS NULL AND @postingBatchID IS NOT NULL)
	BEGIN
		SET @accountID = (SELECT TOP 1 AccountID FROM PostingBatch WHERE PostingBatchID = @postingBatchID)
	END
	
-- Set up GLAccountIDs that I might need later.
	SELECT @prepaidIncomeGLAccountID = GLAccountID	FROM TransactionType WHERE AccountID = @accountID AND Name = 'Prepayment' AND [Group] = 'Lease'	
	SELECT @accountsReceivableGLAccountID = GLAccountID	FROM TransactionType WHERE AccountID = @accountID AND Name = 'Charge' AND [Group] = 'Lease'
	SELECT @undepositedFundsGLAccountID = GLAccountID FROM TransactionType WHERE AccountID = @accountID AND Name = 'Deposit' AND [Group] = 'Lease'
	
-- Set up Loop to iterate over each entry in #Accounts (accounts with an available balance in our collection of accounts to check), and process each!
	SET @loopCtr = 1	
	SET @maxCtr = ISNULL((SELECT MAX(ProcessNumber) FROM #Accounts), 0)	
	
	WHILE (@loopCtr <= @maxCtr)
	BEGIN
		SELECT @workingBalance = AvailableBalance, @workingObjectID = ObjectID , @accountID = AccountID, @propertyID = PropertyID, @ttGroup = TTGroup
			FROM #Accounts WHERE ProcessNumber = @loopCtr
		IF ((@workingBalance > 0) AND (@workingObjectID IS NOT NULL))
		BEGIN
			TRUNCATE TABLE #TempTransactions 
			TRUNCATE TABLE #TempPayments	
	
			-- We now have an account, and their balance, we first need to get their unpaid charges, which we have a stored procedure already in place to do, and sum those up.
			INSERT INTO #TempTransactions EXEC GetOutstandingCharges @accountID, @propertyID, @workingObjectID, @ttGroup, 0, @date	
			SET @workingAmountDue = (SELECT SUM(UnPaidAmount) + ISNULL(SUM(TaxUnpaidAmount), 0) FROM #TempTransactions)
			
			-- Now we get the unapplied payments, one by one, ordered by type so that credits are picked up first, then on payment.date
			INSERT INTO #TempPayments EXEC GetUnappliedPayments @accountID, @propertyID, @workingObjectID, @ttGroup, @postingBatchID, @date
			SET @maxPaymentCtr = (SELECT MAX(CurrentPayment) FROM #TempPayments) 
			SET @paymentCtr = 1
			
			WHILE ((@paymentCtr <= @maxPaymentCtr) AND ((SELECT SUM(Amount) FROM #TempPayments) > 0) AND ((SELECT SUM(UnPaidAmount) FROM #TempTransactions) > 0))
			BEGIN

				-- Reset the pointer to the current charge
				SET @curTransID = null

				-- For my payment (=@paymenCtr) get me the first charge that MUST be paid by the payment
				SELECT TOP 1	@curTransID = #TT.TransactionID, @curAmount = #TT.Amount + #TT.TaxAmount, @curUnPaidAmount = #TT.UnPaidAmount, @curDesc = #TT.[Description],
								@curTransDate = #TT.TranDate, @curGLAccountID = #TT.GLAccountID, @taxRateGroupID = #TT.TaxRateGroupID, 
								@myCreditTaxRebate = #TT.TaxUnpaidAmount, @unpaidCharge = UnPaidAmount
					FROM #TempTransactions #TT
						-- Get the payment we are working with
						INNER JOIN #TempPayments #TP ON #TP.CurrentPayment = @paymentCtr
						-- Join in LedgerItemTypeApplication for the selected payment
						-- where the AppliesToLedgerItemTypeID matches the charge LedgerItemTypeID
						INNER JOIN LedgerItemTypeApplication lita ON lita.LedgerItemTypeID = #TP.LedgerItemTypeID AND lita.AppliesToLedgerItemTypeID = #TT.LedgerItemTypeID AND lita.CanBeApplied = 1
					WHERE #TT.UnPaidAmount > 0
					ORDER BY #TT.ID--lita.OrderBy, #TT.OrderBy

				-- If we didn't get a charge, try another way
				IF (@curTransID IS NULL)
				BEGIN
					-- Get any charge that we don't say can't be paid off by the selected payment
					SELECT TOP 1	@curTransID = #TT.TransactionID, @curAmount = #TT.Amount + #TT.TaxAmount, @curUnPaidAmount = #TT.UnPaidAmount, @curDesc = #TT.[Description],
									@curTransDate = #TT.TranDate, @curGLAccountID = #TT.GLAccountID, @taxRateGroupID = #TT.TaxRateGroupID, 
									@myCreditTaxRebate = #TT.TaxUnpaidAmount, @unpaidCharge = UnPaidAmount
						FROM #TempTransactions #TT
						INNER JOIN #TempPayments #TP ON #TP.CurrentPayment = @paymentCtr
						-- Join in a LedgerItemTypeApplicatoin record for the payment where the AppliesToLedgerItemTypeID
						-- matches the charge and we say that combination can't exist
						LEFT JOIN LedgerItemTypeApplication lita ON lita.LedgerItemTypeID = #TP.LedgerItemTypeID AND lita.AppliesToLedgerItemTypeID = #TT.LedgerItemTypeID AND lita.CanBeApplied = 0
						-- Join in any LedgerItemTypeApplication where we have defined that the payment
						-- can only pay off that type of charge
						LEFT JOIN LedgerItemTypeApplication litaNADA ON litaNADA.LedgerItemTypeID = #TP.LedgerItemTypeID AND litaNADA.CanBeApplied = 1 						
					WHERE #TT.UnPaidAmount > 0
						-- There doesn't exist a record saying that I can't use this payment to pay off this charge
						AND lita.LedgerItemTypeApplicationID IS NULL
						-- There doesn't exist a record saying that this payment can only be applied to a specific set of charges
						AND litaNADA.LedgerItemTypeApplicationID IS NULL
						-- We are applying a credit, its NOT the case that the credit is NOT a sales tax credit AND the charge IS a sales tax charge
						-- Basically we don't want to apply regular concessions to sales tax charges automatically. Force them to do this manually
						AND NOT (#TP.TTName IN ('Credit', 'Overcredit') AND #TP.TaxRateID IS NULL AND #TT.TaxRateID IS NOT NULL)
					ORDER BY #TT.ID--#TT.OrderBy	

				END
				
				IF (@curTransID IS NOT NULL)			-- We have a payment and a charge we can apply it to, so do it!
				BEGIN
					-- Since we have a charge, that this payment can be applied to, let's get the payment information
					SELECT TOP 1	@payTransID = #TP.TransactionID, @payPayID = #TP.PaymentID, @payTTName = #TP.TTName, @payTTID = #TP.TransactionTypeID, @payTAmount = #TP.Amount, 
									@payReference = #TP.Reference, @payLITID = #TP.LedgerItemTypeID, @payDesc = #TP.[Description], @payTOrigin = #TP.Origin,
									@payPostingBatchID = #TP.PostingBatchID, @payAllocated = #TP.Allocated,	@payLITAppliesToLITID = #TP.AppliesToLedgerItemTypeID,
									@payLITGLAccountID = #TP.GLAccountID
						FROM #TempPayments #TP							
						WHERE CurrentPayment = @paymentCtr
			
					-- If we don't have a GLAccountID for this payment or credit, its most likely due to 
					-- the fact that this is a credit available from a balance transfer (Scenario: Credit or payment
					-- on ledger, Balance Transferred up to a deposit then now being applied back down to the
					-- ledger).  In this case, get the last Transaction tied to the payment that has a LedgerItemTypeID
					-- and use that.
					IF (@payLITGLAccountID IS NULL)
					BEGIN
						SET @payLITGLAccountID = (SELECT TOP 1 lit.GLAccountID
												  FROM Payment p
														INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
														INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
														INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
												  WHERE p.PaymentID = @payPayID
													AND t.ObjectID = @workingObjectID
													AND t.PropertyID = @propertyID
												ORDER BY t.TimeStamp DESC)
					END

					---- If this is a Credit, give the tax back via the credit which we'll do later!
					--IF (@payTTName = 'Credit')
					--BEGIN
					--	SET @workingAmountDue = @workingAmountDue - @myCreditTaxRebate
					--END
					
					-- Find amount that we can apply first.  It's the less of the two possibilities.  Note, @payTAmount is the amount of the Transaction of type 'Payment', it was set in the select above.
					IF (@curUnPaidAmount >= @payTAmount)
					BEGIN
						SET @amountAllocated = @payTAmount
					END
					ELSE
					BEGIN
						SET @amountAllocated = @curUnPaidAmount
					END

					-- We have money to apply, let's get busy!!!!
					IF (ISNULL(@amountAllocated, 0) > 0)
					BEGIN
						-- Actually apply the Transaction of type 'Payment' or 'Credit' to the charge.  
						-- Change the amount to what we have available, if it's a payment, fix the Journal Entries.
						UPDATE [Transaction] 
							SET AppliesToTransactionID = @curTransID,
								Amount = @amountAllocated,
								[Description] = LEFT(@payDesc + ': ' + @curDesc, 50),
								[TransactionDate] = @date
							WHERE TransactionID = @payTransID
						IF (@payTTName = 'Payment')
						BEGIN
							IF (@postingBatchID IS NULL)
							BEGIN
								INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @prepaidIncomeGLAccountID, @payTransID, @amountAllocated, 'Cash');
								INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @prepaidIncomeGLAccountID, @payTransID, @amountAllocated, 'Accrual');
							END
							ELSE
							BEGIN
								INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @undepositedFundsGLAccountID, @payTransID, @amountAllocated, 'Cash');
								INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @undepositedFundsGLAccountID, @payTransID, @amountAllocated, 'Accrual');						
							END
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @curGLAccountID, @payTransID, -1 * @amountAllocated, 'Cash');
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @accountsReceivableGLAccountID, @payTransID, -1 * @amountAllocated, 'Accrual');
						END
						ELSE IF ((@payTTName = 'Credit') AND (@accountID IN (1, 502, 1000, 1047) AND @date >= '2015-1-1'))
						BEGIN
						-- Make new Cash journal entries.
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @curGLAccountID, @payTransID, -1 * @amountAllocated, 'Cash');
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @payLITGLAccountID, @payTransID, @amountAllocated, 'Cash');
						END
						-- Only do this when we are posting credit posting batches
						-- In this case journal entries haven't been posted for this transaction and
						-- we need to account for them.  Otherwise, if not a posting batch, journal entries
						-- for the credit have already been posted to Accounts Receivable
						ELSE IF (@payTTName = 'Credit' AND @postingBatchID IS NOT NULL)
						BEGIN
							-- Debit the LedgerItemType GL AccountID
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @payLITGLAccountID, @payTransID, @amountAllocated, 'Accrual');						
							
							-- Credit Accounts Receivable
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @accountsReceivableGLAccountID, @payTransID, -1 * @amountAllocated, 'Accrual');
						END
						
						-- 2016-09-06: Decided to do taxes differently
						-- Check if we need to pay taxes on this charge.
						--IF (@taxRateGroupID IS NOT NULL)
						--BEGIN
						--	EXEC PayTaxesOnPayment /*@payTransID,*/ @curTransID, @payTTName, 'Before', @taxRateGroupID, @ttGroup, @accountID,
						--		@workingObjectID, @payTOrigin, @payTransID, @propertyID, @personID, @payPayID,
						--		@date, @prepaidIncomeGLAccountID, @accountsReceivableGLAccountID, null, @curUnPaidAmount, @amountAllocated, @unpaidCharge,
						--		@taxSum OUTPUT
						--END					

						-- Update our temporary tables, and our working variables.
						UPDATE #TempPayments SET Amount = Amount - @amountAllocated WHERE TransactionID = @payTransID
						UPDATE #TempTransactions SET UnPaidAmount = UnPaidAmount - @amountAllocated WHERE TransactionID = @curTransID
						SET @payTAmount = @payTAmount - @amountAllocated
						SET @workingAmountDue = @workingAmountDue - ISNULL(@amountAllocated, 0)
						SET @workingBalance = @workingBalance - ISNULL(@amountAllocated, 0)	
						
						
						-- Add a new Transaction of type Payment and a new PaymentTransaction Record if there is still money to spend.	
						IF (@payTAmount > 0)
						BEGIN
							SET @newTransID = NEWID()
							INSERT [Transaction] (TransactionID, ObjectID, TransactionDate, TransactionTypeID, LedgerItemTypeID, [Description], Amount,
													AccountID, PropertyID, PersonID, NotVisible, Origin, IsDeleted, TimeStamp) VALUES
												 (@newTransID, @workingObjectID, @date, @payTTID, @payLITID, LEFT(@payDesc, 50), @payTAmount,
													@accountID, @propertyID, @personID, CAST(0 AS BIT), @payTOrigin, 0, GETDATE())
							INSERT PaymentTransaction (AccountID, PaymentID, TransactionID) VALUES (@accountID, @payPayID, @newTransID)					
							
							-- Since there is still money to spend, we won't get a new Transaction of type 'Payment' or 'Credit', instead, we'll add another Record or either 'Payment' or 'Credit'
							-- We've added it, if we don't need it, fine it should be there, if we do consume it or part of it next time in the loop, we need to update that record
							-- Which we do with line below.			
							UPDATE #TempPayments SET TransactionID = @newTransID WHERE TransactionID = @payTransID			
							SET @payTransID = @newTransID
						END  -- End @payTAmount > 0					
										
					END  -- We have money to apply, @amountAllocated > 0
				
				END  -- End We have a Charge to process, @curTransID IS NOT NULL
			
				-- Either we don't have money left on this Payment, or we can't apply what's left to any charges!
				-- This should move us on to the next payment, or kick us out of the loop!
				IF (((SELECT Amount FROM #TempPayments WHERE CurrentPayment = @paymentCtr) = 0) OR (@curTransID IS NULL))
				BEGIN
					SET @paymentCtr = @paymentCtr + 1
				END
			END  -- End Payment Loop
			
			IF ((@postingBatchID IS NOT NULL) AND (@workingBalance > 0.00))
			BEGIN
				DECLARE @payCtr int = 1
				DECLARE @maxPayCtr int = (SELECT MAX(CurrentPayment) FROM #TempPayments)
				DECLARE @payAmountLeft money
				DECLARE @curPaymentID uniqueidentifier
				DECLARE @reference nvarchar(100)
				DECLARE @transactionTypeName nvarchar(25)
				DECLARE @ledgerItemTypeGLAccountID uniqueidentifier
				DECLARE @tranDescription nvarchar(1000)
				DECLARE @paymentDate date
				WHILE (@payCtr <= @maxPayCtr)
				BEGIN
					SELECT @payAmountLeft = #TempPayments.Amount, @curPaymentID = PaymentID, @reference = Reference, @payTOrigin = Origin, @transactionTypeName = TTName, 
							@ledgerItemTypeGLAccountID = lit.GLAccountID, @tranDescription = #TempPayments.[Description], @paymentDate = #TempPayments.PaymentDate
						FROM #TempPayments
							LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = #TempPayments.LedgerItemTypeID
						WHERE CurrentPayment = @payCtr	
					IF (@payAmountLeft > 0)
					BEGIN

						IF (@transactionTypeName = 'Payment') 
						BEGIN
							SET @newTransID = NEWID()
							SET @payTTID = (SELECT TransactionTypeID FROM TransactionType WHERE Name = 'Prepayment' AND [Group] = @ttGroup AND AccountID = @accountID)
							SET @payDesc = 'Payment ' + @reference
							INSERT [Transaction] (TransactionID, ObjectID, TransactionDate, TransactionTypeID, LedgerItemTypeID, [Description], Amount,
													AccountID, PropertyID, PersonID, NotVisible, Origin, IsDeleted, PostingBatchID, TimeStamp) VALUES
												 (@newTransID, @workingObjectID, @paymentDate, @payTTID, null, LEFT(@payDesc, 50), /*@workingBalance*/ @payAmountLeft,
													@accountID, @propertyID, @personID, CAST(0 AS BIT), @payTOrigin, 0, @postingBatchID, GETDATE())
							INSERT PaymentTransaction (AccountID, PaymentID, TransactionID) VALUES (@accountID, /*@payPayID*/ @curPaymentID, @newTransID)	
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @undepositedFundsGLAccountID, @newTransID, @payAmountLeft, 'Cash');
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @undepositedFundsGLAccountID, @newTransID, @payAmountLeft, 'Accrual');	
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @prepaidIncomeGLAccountID, @newTransID, -1*@payAmountLeft, 'Cash');
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @prepaidIncomeGLAccountID, @newTransID, -1*@payAmountLeft, 'Accrual');
						END
						ELSE IF (@transactionTypeName = 'Credit')
						BEGIN
							SET @newTransID = NEWID()
							SET @payTTID = (SELECT TransactionTypeID FROM TransactionType WHERE Name = 'Over Credit' AND [Group] = @ttGroup AND AccountID = @accountID)
							SET @payDesc = @tranDescription
							INSERT [Transaction] (TransactionID, ObjectID, TransactionDate, TransactionTypeID, LedgerItemTypeID, [Description], Amount,
													AccountID, PropertyID, PersonID, NotVisible, Origin, IsDeleted, PostingBatchID, TimeStamp) VALUES
												 (@newTransID, @workingObjectID, @paymentDate, @payTTID, null, LEFT(@payDesc, 50), /*@workingBalance*/ @payAmountLeft,
													@accountID, @propertyID, @personID, CAST(0 AS BIT), @payTOrigin, 0, @postingBatchID, GETDATE())
							INSERT PaymentTransaction (AccountID, PaymentID, TransactionID) VALUES (@accountID, /*@payPayID*/ @curPaymentID, @newTransID)							
							-- Debit the LedgerItemType GL Account
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @ledgerItemTypeGLAccountID, @newTransID, @payAmountLeft, 'Accrual');								
							-- Credit Accounts Receivable
							INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
												VALUES (NEWID(), @accountID, @accountsReceivableGLAccountID, @newTransID, -1*@payAmountLeft, 'Accrual');
						END
					END
					SET @payCtr = @payCtr + 1				
				END  -- End While @payCtr <= @maxPayCtr
			END  -- End IF @payPostingBatchID IS NOT NULL			
	
		END  -- End if we have an object that has charges to pay off
		
		SET @loopCtr = @loopCtr + 1
	
	END  -- Main loop on each ObjectID (Account)
	
	
END  -- End Stored Procedure	
GO
