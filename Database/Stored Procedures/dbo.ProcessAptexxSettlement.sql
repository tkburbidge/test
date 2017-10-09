SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 28, 2013
-- Description:	Deals with Aptexx payment settlement
-- =============================================
CREATE PROCEDURE [dbo].[ProcessAptexxSettlement] 
	-- Add the parameters for the stored procedure here
	@aptexxPayment AptexxPaymentCollection READONLY, 
	@bankAccountID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@integrationPartnerItemID int = null,
	@accountID bigint = null,
	@settlementAmount money = null,
	@date date = null,
	@description nvarchar(500) = null
AS

DECLARE @paymentsToPost PostingBatchPaymentCollection
DECLARE @newAptexxPayments AptexxPaymentCollection 
DECLARE @postingBatchID uniqueidentifier
DECLARE @newTransactionID uniqueidentifier
DECLARE @newBatchID uniqueidentifier
DECLARE @bankDepositTransactionTypeID uniqueidentifier
DECLARE @bankDepositGLAccountID uniqueidentifier
DECLARE @bankTransactionCategoryID uniqueidentifier
DECLARE @onlinePaymentLedgerItemTypeID uniqueidentifier
DECLARE @onlineDepositLedgerItemTypeID uniqueidentifier
DECLARE @defaultLedgerItemTypeID uniqueidentifier
DECLARE @batchNumber int
DECLARE @integrationPartnerID int
DECLARE @ctr int
DECLARE @maxCtr int
DECLARE @myPropertyID uniqueidentifier
DECLARE @transSum money 

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF (@date IS NULL)
	BEGIN
		SET @date = GETDATE()
	END
	
	SELECT @integrationPartnerID = IntegrationPartnerID FROM IntegrationPartnerItem WHERE IntegrationPartnerItemID = @integrationPartnerItemID	
	SELECT @onlinePaymentLedgerItemTypeID = DefaultPortalPaymentLedgerItemTypeID, @onlineDepositLedgerItemTypeID = DefaultPortalDepositLedgerItemTypeID FROM Settings WHERE AccountID = @accountID	
	
	IF (@integrationPartnerItemID = 31 OR @integrationPartnerItemID = 32)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlinePaymentLedgerItemTypeID
	END
	ELSE IF (@integrationPartnerItemID = 33)
	BEGIN
		SET @defaultLedgerItemTypeID = @onlineDepositLedgerItemTypeID	
	END
	
	CREATE TABLE #SettlementPaymentsForProcessing (
		ReferenceNumber nvarchar(50) null,
		ExternalID nvarchar(50) null,
		PayerID uniqueidentifier null,
		[Date] datetime null,
		GAmount money null,
		NAmount money null,
		PaymentType nvarchar(50),
		LedgerItemTypeID uniqueidentifier null,
		ProcessorPaymentID uniqueidentifier null,
		PaymentID uniqueidentifier null,
		PayerPersonID uniqueidentifier null,--)--,
		AptexxPayerID nvarchar(100) null,
		Part1 uniqueidentifier null,
		Part2 uniqueidentifier null,
		PropertyID uniqueidentifier null
		)--,
		--NewAdd bit null)

	CREATE TABLE #AllMyProperties (
		Sequence int identity,
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #NewTransactions (
		TransactionID uniqueidentifier not null)
		
	-- Add all the Payments that are in the batch for processing	
	INSERT #SettlementPaymentsForProcessing 
		SELECT atPP.PaymentID, atPP.ExternalID, atPP.PayerID, atPP.[Date], atPP.GrossAmount, atPP.NetAmount, atPP.PaymentType, 
				atPP.LedgerItemTypeID, pp.ProcessorPaymentID, py.PaymentID, atPP.PayerPersonID, atPP.AptexxPayerID, null, null, pp.PropertyID
			FROM @aptexxPayment atPP
				LEFT JOIN ProcessorPayment pp ON pp.ProcessorTransactionID = atPP.PaymentID --AND pp.IntegrationPartnerItemID = @integrationPartnerItemID
				LEFT JOIN Payment py ON pp.PaymentID = py.PaymentID	
			WHERE (py.PaymentID IS NULL OR py.Reversed = 0)
				

	IF ((SELECT COUNT(p.PaymentID)
		 FROM Payment p
		 INNER JOIN #SettlementPaymentsForProcessing #pfp ON #pfp.PaymentID = p.PaymentID
		 WHERE p.BatchID IS NOT NULL) > 0)
	BEGIN
		RETURN
	END
				
	UPDATE #SettlementPaymentsForProcessing SET Part1 = CAST(SUBSTRING(AptexxPayerID, 1, 36) AS uniqueidentifier), 
												Part2 = CAST(Substring(AptexxPayerID, 38, 36) AS uniqueidentifier)
									  
	-- If the payment belongs to a UnitLeaseGroup,
	-- Part1 = UnitLeaseGroupID
	-- Part2 = PersonID									  
	UPDATE #p4p SET PropertyID = ut.PropertyID
		FROM #SettlementPaymentsForProcessing #p4p
			INNER JOIN UnitLeaseGroup ulg ON #p4p.Part1 = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	WHERE #p4p.PropertyID IS NULL
	
	-- For all the rest
	-- Part1 = PersonID/WOITAccountID
	-- Part2 = PropertyID		
	UPDATE #SettlementPaymentsForProcessing SET PropertyID = Part2, PayerPersonID = Part1	
		WHERE PropertyID IS NULL				
					
	INSERT #AllMyProperties
		SELECT DISTINCT PropertyID
			FROM #SettlementPaymentsForProcessing					
	
	-- Create the collection of new payments that need to be posted			
	--INSERT @newAptexxPayments 
	--	SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID
	--		FROM #SettlementPaymentsForProcessing
	--		WHERE PaymentID IS NULL		
	
	SELECT @bankDepositGLAccountID = GLAccountID, @bankDepositTransactionTypeID = TransactionTypeID 
		FROM TransactionType 
		WHERE AccountID = @accountID
		  AND Name = 'Deposit'
		  AND [Group] = 'Bank'
				
	SET @ctr = 1
	SET @maxCtr = (SELECT MAX(Sequence) FROM #AllMyProperties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		
		SET @myPropertyID = (SELECT PropertyID FROM #AllMyProperties WHERE Sequence = @ctr)
		-- If needed, add the ProcessorPayment records
		--IF ((SELECT COUNT(*) FROM @newAptexxPayments) > 0)
		IF ((SELECT COUNT(*) FROM #SettlementPaymentsForProcessing WHERE PaymentID IS NULL AND PropertyID = @myPropertyID) > 0)
		BEGIN			

			INSERT @newAptexxPayments 
				SELECT ReferenceNumber, ExternalID, PayerID, [Date], GAmount, NAmount, null, PaymentType, COALESCE(LedgerItemTypeID, @defaultLedgerItemTypeID), PayerPersonID, AptexxPayerID
					FROM #SettlementPaymentsForProcessing
					WHERE PaymentID IS NULL	
					  AND PropertyID = @myPropertyID		
			
			--EXEC ProcessAptexxTransactions @newAptexxPayments, @accountID, @integrationPartnerItemID, @propertyID, @date, @description	
			
			EXEC ProcessAptexxTransactions @newAptexxPayments, @accountID, @integrationPartnerItemID, @myPropertyID, @date, @description			
			
			-- Update the ProcessorPaymentID in this settlement		
			UPDATE #pp SET #pp.ProcessorPaymentID = procPay.ProcessorPaymentID
			FROM #SettlementPaymentsForProcessing #pp 
				INNER JOIN ProcessorPayment procPay ON #pp.PayerID = procPay.ObjectID AND #pp.ReferenceNumber = procPay.ProcessorTransactionID AND procPay.AccountID = @accountID
						
			---- Update the PaymentID on the temp table and the ProcessorPayment table
			UPDATE #p4p SET #p4p.PaymentID = py.PaymentID
			FROM #SettlementPaymentsForProcessing #p4p
				INNER JOIN Payment py ON #p4p.ReferenceNumber = py.ReferenceNumber AND py.AccountID = @accountID
				
			DELETE @newAptexxPayments					
		END	
		
		--UPDATE Payment SET Notes = 'Yup' WHERE ReferenceNumber IN (SELECT ProcessorPaymentID FROM #SettlementPaymentsForProcessing)
								
		SET @transSum = (SELECT SUM(pay.Amount)
							FROM #SettlementPaymentsForProcessing #sp4p
								INNER JOIN Payment pay ON #sp4p.PaymentID = pay.PaymentID
							WHERE #sp4p.PropertyID = @myPropertyID)
		
		IF (@transSum > 0)
		BEGIN
			SET @newTransactionID = NEWID()
			INSERT [Transaction] (AccountID, Amount, TransactionTypeID, TransactionDate, ObjectID, Origin, PropertyID, [Description], TransactionID, [TimeStamp], IsDeleted, NotVisible)
				VALUES (@accountID, /*@settlementAmount,*/ @transSum, @bankDepositTransactionTypeID, @date, @bankAccountID, 'X', /*@propertyID,*/ @myPropertyID, @description, @newTransactionID, GETDATE(), 0, 0)
			-- Credit Undeposited Funds		
			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
				VALUES (NEWID(), @accountID, @bankDepositGLAccountID, @newTransactionID, -1*@transSum /*@settlementAmount*/, 'Cash')
			-- Debit bank GL Account
			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
				SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, @transSum /*@settlementAmount*/, 'Cash'
					FROM BankAccount 
					WHERE BankAccountID = @bankAccountID
			-- Credit Undeposited Funds			
			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
				VALUES (NEWID(), @accountID, @bankDepositGLAccountID, @newTransactionID, -1*@transSum /*@settlementAmount*/, 'Accrual')
			-- Debit bank GL Account
			INSERT [JournalEntry] (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
				SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, @transSum /*@settlementAmount*/, 'Accrual'
					FROM BankAccount 
					WHERE BankAccountID = @bankAccountID
			INSERT #NewTransactions SELECT @newTransactionID	
		END
		
		SET @ctr = @ctr + 1		
	END			
			
	IF ((SELECT COUNT(*) FROM #NewTransactions) > 0)
	BEGIN	
		-- Deal with no batches and batches moved outside of current period			
		SET @batchNumber = (SELECT dbo.GetNextBankDepositBatch(@accountID, @bankAccountID, @date))

		DECLARE @newBankTransactionID uniqueidentifier = NEWID()	  
		
		SET @newBatchID = NEWID()
		INSERT Batch (BatchID, AccountID, PropertyAccountingPeriodID, BankTransactionID, Number, [Description], [Date], IsOpen, [Type], IntegrationPartnerID)
			VALUES (@newBatchID, @accountID, '00000000-0000-0000-0000-000000000000', @newBankTransactionID, @batchNumber, @description, @date, 0, 'Bank', 1013)

		SELECT @bankTransactionCategoryID = BankTransactionCategoryID 
			FROM BankTransactionCategory
			WHERE AccountID = @accountID
			  AND Category = 'System Deposit'
			  AND Visible = 0	
						 
		INSERT BankTransaction (BankTransactionID, AccountID, BankTransactionCategoryID, ObjectID, ObjectType, ReferenceNumber, QueuedForPrinting )
			VALUES (@newBankTransactionID, @accountID, @bankTransactionCategoryID, '00000000-0000-0000-0000-000000000000', 'BankTransactionTransaction', CAST(@batchNumber AS nvarchar(50)), 0)
		--INSERT BankTransactionTransaction (BankTransactionTransactionID, AccountID, BankTransactionID, TransactionID)
		--	VALUES (NEWID(), @accountID, @newBankTransactionID, @newTransactionID)
		
		INSERT BankTransactionTransaction
			SELECT NEWID(), @accountID, @newBankTransactionID, TransactionID
				FROM #NewTransactions
			
		UPDATE Payment SET BatchID = @newBatchID
			WHERE PaymentID IN (SELECT DISTINCT PaymentID FROM #SettlementPaymentsForProcessing)
			
		UPDATE ProcessorPayment SET DateSettled = @date
			WHERE ProcessorPaymentID IN (SELECT ProcessorPaymentID FROM #SettlementPaymentsForProcessing)		
			
	-- When we do this update, we break the link ProcessorPayment.ObjectID = Transaction.ObjectID.  If we need to get any values of relevance, we need to
	-- go through Payment (ProcessPayment.PaymentID, then to Payment, PaymentTransaction, Transaction.
		UPDATE t SET ObjectID = l.UnitLeaseGroupID, TransactionTypeID = ttNew.TransactionTypeID
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #SettlementPaymentsForProcessing #pp ON t.ObjectID = #pp.PayerID
				INNER JOIN ProcessorPayment pp ON #pp.ReferenceNumber = pp.ProcessorTransactionID
				INNER JOIN PersonLease pl ON pl.PersonID = #pp.PayerID
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID AND ut.PropertyID = #pp.PropertyID
				INNER JOIN TransactionType ttNew ON tt.Name = ttNew.Name AND ttNew.[Group] = 'Lease' AND ttNew.AccountID = @accountID
			WHERE pl.PersonLeaseID IS NOT NULL
			  AND t.ObjectID <> l.UnitLeaseGroupID 
			  AND pp.ObjectType IN ('Prospect')
			  AND t.PropertyID = #pp.PropertyID
			  -- Make sure that a prospect transferred to a new property and converted into a lease isn't
			  -- assigned a payment from the old property
			  AND t.PropertyID = b.PropertyID
			  
		-- Don't need to check property here as we don't update it above if it isn't tied to the same property
		UPDATE pay SET ObjectID = t.ObjectID, ObjectType = 'Lease'
			FROM Payment pay
				INNER JOIN #SettlementPaymentsForProcessing #pp ON pay.ObjectID = #pp.PayerID AND pay.ReferenceNumber = #pp.ReferenceNumber
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID AND t.ObjectID <> pay.ObjectID AND pay.ObjectType NOT IN ('Lease')
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = 'Lease'		
				
			
	END
		
END
GO
