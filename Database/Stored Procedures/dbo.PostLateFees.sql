SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO








-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 20, 2012
-- Description:	Posts Late Fees to a list of accounts
-- =============================================
CREATE PROCEDURE [dbo].[PostLateFees] 
	-- Add the parameters for the stored procedure here
	@ULGInfo LateFeeCollection READONLY, 
	@accountID bigint = null,
	@propertyID uniqueidentifier = null,
	@accountingPeriodID uniqueidentifier = null,
	@personID uniqueidentifier = null,
	@date date = null,
	@description nvarchar(500) = null,
	@revokeCredits bit = 0
AS
DECLARE @i		int
DECLARE @iMax	int
DECLARE @j		int
DECLARE @jMax	int
DECLARE @chargeTTID uniqueidentifier
DECLARE @chargeGLAID uniqueidentifier
DECLARE @lateFeeLITID uniqueidentifier
DECLARE @lateFeeGLAID uniqueidentifier
DECLARE @transactionID uniqueidentifier
DECLARE @objectID uniqueidentifier
DECLARE @lateFee money
DECLARE @retCode int
DECLARE @baseTimeStamp datetime
DECLARE @transactionToReverse uniqueidentifier
DECLARE @paymentToReverse uniqueidentifier
DECLARE @newPaymentID uniqueidentifier
DECLARE @lastPaymentID uniqueidentifier
DECLARE @newTransactionID uniqueidentifier
DECLARE @amount money
DECLARE @tamount money
DECLARE @creditGLAccountID uniqueidentifier
DECLARE @debitGLAccountID uniqueidentifier
DECLARE @JECount int
DECLARE @payObjectID uniqueidentifier
DECLARE @payObjectType nvarchar(50)
DECLARE @salesTaxLedgerItemTypeID uniqueidentifier
DECLARE @salesTaxGLAccountID uniqueidentifier
DECLARE @salesTaxFee money
DECLARE @salesTaxRate decimal(6, 4)
DECLARE @salesTaxI int = 1
DECLARE @maxSalesTaxers int = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #LateFees (
		ULGID uniqueidentifier not null,
		LateFee money null,
		FeeLedgerItemTypeID uniqueidentifier null,
		SequenceNumber int identity not null)
		
	CREATE TABLE #PaymentIDsToReverse (
		PaymentID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		Amount money not null,
		TransAmount money not null,
		TTGLAID uniqueidentifier null,
		LITGLAID uniqueidentifier null,
		JECount int not null,
		ObjectID uniqueidentifier null,
		ObjectType nvarchar(50),
		PaymentNumber int identity not null)

	CREATE TABLE #LedgerItemsToAddSalesTax (
		[Sequence] int identity,
		LedgerItemTypeID uniqueidentifier not null,
		TaxRateGroupID uniqueidentifier null,
		TaxRateID uniqueidentifier null,
		TaxRate decimal(6, 4) null,
		TaxRateGLAccountID uniqueidentifier null)

	CREATE TABLE #SalesTaxesToApply (
		LedgerItemTypeID uniqueidentifier not null,
		TaxRate decimal(6,4) null,
		TaxRateGLAccountID uniqueidentifier null)		

	CREATE TABLE #ULGIDsThatGetTaxed (
		UnitLeaseGroupID uniqueidentifier not null)

	CREATE TABLE #PaymentIDsThatWereTaxed (
		PaymentID uniqueidentifier not null)
		
	SELECT @chargeTTID = TransactionTypeID, @chargeGLAID = GLAccountID
		FROM TransactionType 
		WHERE Name = 'Charge'
		  AND [Group] = 'Lease'
		  AND AccountID = @accountID

	--SELECT @lateFeeLITID = LateFeeLedgerItemTypeID FROM Settings WHERE AccountID = @accountID
	--SELECT @lateFeeGLAID = GLAccountID FROM LedgerItemType WHERE LedgerItemTypeID = @lateFeeLITID	
	
	INSERT #LateFees SELECT * FROM @ULGInfo

	INSERT #LedgerItemsToAddSalesTax
		SELECT litp.LedgerItemTypeID, litp.TaxRateGroupID, tr.TaxRateID, tr.Rate, tr.GLAccountID
			FROM LedgerItemTypeProperty litp
				INNER JOIN TaxRateGroupTaxRate trgtr ON litp.TaxRateGroupID = trgtr.TaxRateGroupID
				INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
			WHERE litp.TaxRateGroupID IS NOT NULL
			  AND PropertyID = @propertyID
			  AND tr.IsObsolete = 0

	SET @maxSalesTaxers = (SELECT MAX([Sequence]) FROM #LedgerItemsToAddSalesTax)

	INSERT #ULGIDsThatGetTaxed
		SELECT	ulg.UnitLeaseGroupID
			FROM #LateFees #lfees
				INNER JOIN UnitLeaseGroup ulg ON #lfees.ULGID = ulg.UnitLeaseGroupID
			WHERE SalesTaxExempt = 0



	SET @salesTaxLedgerItemTypeID = (SELECT TOP 1 LedgerItemTypeID FROM LedgerItemType WHERE AccountID = @accountID AND IsSalesTax = 1)
	SET @i = 1
	SET @iMax = (SELECT MAX(SequenceNumber) FROM #LateFees)
	SET @baseTimeStamp = GETDATE()
	SET @lastPaymentID = NEWID()
	
	WHILE (@i <= @iMax)
	BEGIN
		SELECT @objectID = ULGID, @lateFee = LateFee, @lateFeeLITID = FeeLedgerItemTypeID
			FROM #LateFees 
			WHERE SequenceNumber = @i
		EXEC @retCode = CheckTransactionEditLock @accountID, @objectID, null
		IF (0 = @retCode)
		BEGIN
		
-- Add Late Fee Charge & Journal Entries
			SELECT @lateFeeGLAID = GLAccountID FROM LedgerItemType WHERE LedgerItemTypeID = @lateFeeLITID
			SET @transactionID = NEWID()
			INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, PropertyID, PersonID, Origin, Amount,
									[Description], TransactionDate, NotVisible, [TimeStamp], IsDeleted)
				VALUES (@transactionID, @accountID, @objectID, @chargeTTID, @lateFeeLITID, @propertyID, @personID, 'L', @lateFee,
						  @description, @date, 0, @baseTimeStamp, 0)
			INSERT JournalEntry (JournalEntryID, TransactionID, AccountingBasis, Amount, GLAccountID, AccountID)
				VALUES (NEWID(), @transactionID, 'Accrual', @lateFee, @chargeGLAID, @accountID)
			INSERT JournalEntry (JournalEntryID, TransactionID, AccountingBasis, Amount, GLAccountID, AccountID)
				VALUES (NEWID(), @transactionID, 'Accrual', -1 * @lateFee, @lateFeeGLAID, @accountID)
			SET @baseTimeStamp = DATEADD(MS, 1, @baseTimeStamp)

-- Add Sales Taxes if applicable.
			IF ((0 < (SELECT COUNT(*) FROM #ULGIDsThatGetTaxed WHERE UnitLeaseGroupID = @objectID))	AND (@maxSalesTaxers > 0))
			BEGIN
				SET @salesTaxI = 1
				
				WHILE (@salesTaxI <= @maxSalesTaxers)
				BEGIN			

					SET @transactionID = NEWID()
					SELECT @salesTaxRate = TaxRate, @salesTaxGLAccountID = TaxRateGLAccountID
						FROM #LedgerItemsToAddSalesTax
						WHERE [Sequence] = @salesTaxI

					SET @salesTaxFee = CAST((@lateFee * @salesTaxRate) AS money)
					INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, PropertyID, PersonID, Origin, Amount,
											[Description], TransactionDate, NotVisible, [TimeStamp], IsDeleted)
						VALUES (@transactionID, @accountID, @objectID, @chargeTTID, @salesTaxLedgerItemTypeID, @propertyID, @personID, 'L', @salesTaxFee,
								  'Sales Tax:' + @description, @date, 0, @baseTimeStamp, 0)

					INSERT JournalEntry (JournalEntryID, TransactionID, AccountingBasis, Amount, GLAccountID, AccountID)
						VALUES (NEWID(), @transactionID, 'Accrual', @salesTaxFee, @chargeGLAID, @accountID)
					INSERT JournalEntry (JournalEntryID, TransactionID, AccountingBasis, Amount, GLAccountID, AccountID)
						VALUES (NEWID(), @transactionID, 'Accrual', -1 * @salesTaxFee, @lateFeeGLAID, @accountID)
					SET @baseTimeStamp = DATEADD(MS, 1, @baseTimeStamp)	
					SET @salesTaxI = @salesTaxI + 1

				END
			END	
			
			IF (@revokeCredits = 1)
			BEGIN

				INSERT #PaymentIDsToReverse 
					SELECT py.PaymentID, t.TransactionID, py.Amount, t.Amount, tt.GLAccountID, lit.GLAccountID,
							(SELECT COUNT(*) FROM JournalEntry WHERE TransactionID = t.TransactionID AND AccountingBasis = 'Accrual') AS 'JECount',
							py.ObjectID, py.ObjectType
						FROM Payment py
							INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
							INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
							INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Credit')
							LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
							INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
							LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
						WHERE t.ObjectID = @objectID
						  AND py.[Date] >= pap.StartDate
						  AND py.[Date] <= pap.EndDate
						  AND lit.IsRevokable = 1
						  AND t.ReversesTransactionID IS NULL
						  AND tr.TransactionID IS NULL
						  AND t.Origin = 'A'
						ORDER BY py.PaymentID, t.[TimeStamp] 

				-- Deal with SalesTax Reversals if necessary.
				INSERT #PaymentIDsThatWereTaxed
					SELECT salesTaxPayment.PaymentID
						FROM #PaymentIDsToReverse #pay2Rev
							INNER JOIN Payment salesTaxPayment ON #pay2Rev.PaymentID = salesTaxPayment.PaymentID AND salesTaxPayment.TaxRateGroupID IS NOT NULL

				-- Continue dealing with SaleTax Reversals if necessary.
				INSERT #PaymentIDsToReverse
					SELECT	py.PaymentID, t.TransactionID, py.Amount, t.Amount, tt.GLAccountID, tRate.GLAccountID,
							(SELECT COUNT(*) FROM JournalEntry WHERE TransactionID = t.TransactionID AND AccountingBasis = 'Accrual') AS 'JECount',
							py.ObjectID, py.ObjectType
						FROM #PaymentIDsThatWereTaxed #paydTaxes
							INNER JOIN Payment paymentThatWasTaxed ON #paydTaxes.PaymentID = paymentThatWasTaxed.PaymentID
							INNER JOIN Payment py ON paymentThatWasTaxed.SalesTaxForPaymentID = py.PaymentID
							INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
							INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
							INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Credit')
							INNER JOIN TaxRate tRate ON py.TaxRateID = tRate.TaxRateID
							LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
							INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
							LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
						WHERE t.ObjectID = @objectID
						  AND py.[Date] >= pap.StartDate
						  AND py.[Date] <= pap.EndDate
						  --AND lit.IsRevokable = 1
						  AND t.ReversesTransactionID IS NULL
						  AND tr.TransactionID IS NULL
						  AND t.Origin = 'A'
						ORDER BY py.PaymentID, t.[TimeStamp] 
						
				SET @j = 1
				SET @jMax = (SELECT MAX(PaymentNumber) FROM #PaymentIDsToReverse)
				WHILE (@j <= @jMax)
				BEGIN
					SELECT	@paymentToReverse = PaymentID, @transactionID = TransactionID, @amount = Amount, @tamount = TransAmount,
							@creditGLAccountID = LITGLAID, @debitGLAccountID = TTGLAID, @JECount = JECount, @payObjectID = ObjectID, @payObjectType = ObjectType
						FROM #PaymentIDsToReverse
						WHERE PaymentNumber = @j

						
					IF (@lastPaymentID <> @paymentToReverse)
					BEGIN
						-- Insert the new credit that will reverse the original credit
						SET @newPaymentID = NEWID();
						INSERT Payment (PaymentID, AccountID, [Type], [Date], ReceivedFromPaidTo,
										Amount, [Description], PaidOut, Reversed, ObjectID, ObjectType, [TimeStamp])
							VALUES (@newPaymentID, @accountID, 'Late Payment', @date, (SELECT ReceivedFromPaidTo FROM Payment WHERE PaymentID = @paymentToReverse),
										-@amount, (SELECT 'Reversed ' + [Description] FROM Payment WHERE PaymentID = @paymentToReverse), CAST(0 AS Bit), CAST(0 AS Bit),
										@payObjectID, @payObjectType, @baseTimeStamp)
						SET @baseTimeStamp = DATEADD(MS, 1, @baseTimeStamp)

							
						-- Indicate that the original credit was reversed
						UPDATE Payment SET Reversed = 1, ReversedReason = 'Late Payment', ReversedDate = @date WHERE PaymentID = @paymentToReverse
						SET @lastPaymentID = @paymentToReverse
					END

						
					SET @newTransactionID = NEWID()
					INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID,
											LedgerItemTypeID, ReversesTransactionID, PropertyID, PersonID,
											Origin, Amount,
											[Description], TransactionDate, [TimeStamp],
											NotVisible, IsDeleted)
						VALUES (@newTransactionID, @accountID, @objectID, (SELECT TransactionTypeID FROM [Transaction] WHERE TransactionID = @transactionID),
									(SELECT LedgerItemTypeID FROM [Transaction] WHERE TransactionID = @transactionID), 
										@transactionID,
										@propertyID, @personID,
									(SELECT Origin FROM [Transaction] WHERE TransactionID = @transactionID), -@tamount,
									(SELECT 'Reversed ' + [Description] FROM [Transaction] WHERE TransactionID = @transactionID), @date, @baseTimeStamp,
									(SELECT NotVisible FROM [Transaction] WHERE TransactionID = @transactionID), 0)
					SET @baseTimeStamp = DATEADD(MS, 1, @baseTimeStamp)

					-- Deal with cash entries if we are supposed to
					IF (@accountID IN (1, 502, 1000, 1047) AND @date >= '2015-1-1')
					BEGIN
						INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)	 
								SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, -1 * Amount, AccountingBasis 
									FROM JournalEntry
									WHERE TransactionID = @transactionID
									AND AccountingBasis = 'Cash'
					END

					-- Deal with accrual entries
					IF (@JECount > 0)  -- Note this is only accrual entry count
					BEGIN

						INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)	 
							SELECT NEWID(), @accountID, GLAccountID, @newTransactionID, -1 * Amount, AccountingBasis 
								FROM JournalEntry
								WHERE TransactionID = @transactionID
								AND AccountingBasis = 'Accrual'
					END
					ELSE
					BEGIN

						INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)				
							VALUES (NEWID(), @accountID, @debitGLAccountID, @newTransactionID, @tamount, 'Accrual')

						INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)				
							VALUES (NEWID(), @accountID, @creditGLAccountID, @newTransactionID, -1 * @tamount, 'Accrual')
					END
					INSERT PaymentTransaction VALUES (@newTransactionID, @newPaymentID, @accountID)
					SET @j = @j + 1
				END
				TRUNCATE TABLE #PaymentIDsToReverse
				TRUNCATE TABLE #PaymentIDsThatWereTaxed
			END
-- Add (if necessary) a row in the APULGInformation table.
			IF (0 = (SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = @objectID AND AccountingPeriodID = @accountingPeriodID))
			BEGIN
				INSERT ULGAPInformation (ULGAPInformationID, AccountID, ObjectID, AccountingPeriodID, Late)
					VALUES (NEWID(), @accountID, @objectID, @accountingPeriodID, CAST(1 AS Bit))
			END
			ELSE
			BEGIN
				UPDATE ULGAPInformation SET Late = 1 WHERE ObjectID = @objectID AND AccountingPeriodID = @accountingPeriodID
			END

		END
	
		SET @i = @i + 1
	END
	
	UPDATE PropertyAccountingPeriod 
	SET LateFeesAccessed = 1 
	WHERE PropertyID = @propertyID 
		AND AccountingPeriodID = @accountingPeriodID 
		AND AccountID = @accountID

END






GO
