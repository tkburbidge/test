SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO







-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 16, 2012
-- Description:	Inserts a batch of charge transactions
-- =============================================
CREATE PROCEDURE [dbo].[ImportChargeBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@ledgerItemTypeID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@personID uniqueidentifier = null,
	@description nvarchar(500) = null,
	@note nvarchar(500) = null,
	@taxRateGroupID uniqueidentifier = null,
	@charges PostingBatchTransactionCollection READONLY
		
AS

DECLARE @maxSequenceNum			int
DECLARE @ctr					int
DECLARE @objectID				uniqueidentifier
DECLARE @objectName				nvarchar(500)
DECLARE @amount					money
DECLARE @transactionTypeID		uniqueidentifier
DECLARE @rowCount				int
DECLARE @newTransID				uniqueidentifier
DECLARE @date					date
DECLARE @unit					nvarchar(50)
DECLARE @salesTaxLITID			uniqueidentifier
DECLARE @thisTaxRate			decimal(7, 4)
DECLARE @taxI					int
DECLARE @taxMax					int
DECLARE @taxRateID				uniqueidentifier
DECLARE @salesTaxDesc			nvarchar(500)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #NewCharges (
		SequenceNum		int identity,
		ObjectID		uniqueidentifier not null,
		ObjectName		nvarchar(100) null,
		Amount			money null,
		[Date]			date null,
		Unit			nvarchar(50) null)

	CREATE TABLE #SalesTaxes (
		[Sequence]		int identity,
		TaxRateID		uniqueidentifier null,
		Name			nvarchar(500) null,
		[Description]	nvarchar(500) null,
		Rate			decimal(7, 4) null)
		
	INSERT #NewCharges SELECT ObjectID AS 'ObjectID', ObjectName AS 'ObjectName', Amount AS 'Amount', [Date] AS 'Date', Unit AS 'Unit' FROM @charges
	SET @maxSequenceNum = (SELECT MAX(SequenceNum) FROM #NewCharges)
	SET @ctr = 1

	INSERT #SalesTaxes 
		SELECT	DISTINCT
				rate.[Name],
				rate.[Description],
				rate.Rate
			FROM TaxRate rate
				INNER JOIN TaxRateGroupTaxRate trgRate ON rate.TaxRateID = trgRate.TaxRateID
			WHERE trgRate.TaxRateGroupID = @taxRateGroupID
			  AND rate.IsObsolete = 0

	SET @taxMax = (SELECT MAX([Sequence]) FROM #SalesTaxes)
	
	--SELECT @taxRateGroupID = TaxRateGroupID 
	--	FROM LedgerItemTypeTaxGroup 
	--	WHERE PropertyID = @propertyID
	--	  AND LedgerItemTypeID = @ledgerItemTypeID
	
	WHILE (@ctr <= @maxSequenceNum)
	BEGIN
		SET @transactionTypeID = null
		SELECT @objectID = ObjectID, @objectName = ObjectName, @amount = Amount, @date = [Date], @unit = Unit
			FROM #NewCharges WHERE SequenceNum = @ctr
		SELECT @transactionTypeID = t.TransactionTypeID
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			WHERE t.ObjectID = @objectID
			  AND tt.Name = 'Charge'
		IF (@transactionTypeID IS NULL)
		BEGIN
			IF ((SELECT COUNT(*) FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @objectID) > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Charge'
					  AND [Group] = 'Lease'
			END
			ELSE IF ((SELECT COUNT(*) FROM PersonType WHERE PersonID = @objectID AND [Type] = 'Prospect') > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Charge'
					  AND [Group] = 'Prospect'
			END
			ELSE IF ((SELECT COUNT(*) FROM PersonType WHERE PersonID = @objectID AND [Type] = 'Non-Resident Account') > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Charge'
					  AND [Group] = 'Non-Resident Account'
			END
			ELSE IF ((SELECT COUNT(*) FROM WOITAccount WHERE WOITAccountID = @objectID) > 0)
			BEGIN
				SELECT @transactionTypeID = TransactionTypeID
					FROM TransactionType
					WHERE AccountID = @accountID
					  AND Name = 'Charge'
					  AND [Group] = 'WOIT Account'
			END
		END
		IF (@transactionTypeID IS NOT NULL)
		BEGIN
			SET @newTransID = NEWID()
			INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, 
									PropertyID, PersonID, TaxRateGroupID, NotVisible, Origin, Amount,
									[Description], Note, TransactionDate, PostingBatchID, IsDeleted, [TimeStamp])
					VALUES		(@newTransID, @accountID, @objectID, @transactionTypeID, @ledgerItemTypeID,
									@propertyID, @personID, @taxRateGroupID, 0, 'P', @amount,
									@description, @note, @date, @postingBatchID, 0, GETDATE())
			IF (@@ROWCOUNT < 0)
			BEGIN
				INSERT ActivityLog (ActivityLogID, AccountID, ActivityLogType, ModifiedByPersonID, ObjectName, ObjectID, PropertyID,
										Activity, [Timestamp], ExceptionName, ExceptionCaught, Exception, AltObjectID)
					VALUES			(NEWID(), @accountID, 'ImportingChargeBatch', @personID, @objectName, @objectID, @propertyID,
										'PostingBatch', GETDATE(), 'ERROR INSERTING TRANSACTION', 0, 
										'Unit #' + @unit + ', Amount $' + CAST(@amount as nvarchar) + ', Description: ' + @description + ', Note: ' + @note, @postingBatchID)			
			END
			IF ((@taxRateGroupID IS NOT NULL) AND (0 = (SELECT SalesTaxExempt FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @objectID)))
			BEGIN
				SET @taxI = 1
				WHILE (@taxI <= @taxMax)
				BEGIN
					SELECT @taxRateID = TaxRateID, @thisTaxRate = Rate, @salesTaxDesc = [Description]
						FROM #SalesTaxes
						WHERE [Sequence] = @taxI

					INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, 
											PropertyID, PersonID, TaxRateGroupID, NotVisible, Origin, Amount,
											[Description], Note, TransactionDate, PostingBatchID, IsDeleted, [TimeStamp], TaxRateID, SalesTaxForTransactionID)
						VALUES			 (NEWID(), @accountID, @objectID, @transactionTypeID, @salesTaxLITID,
											@propertyID, @personID, @taxRateGroupID, 0, 'P', @amount * @thisTaxRate,
											@salesTaxDesc + ': ' + @description, @note, @date, @postingBatchID, 0, GETDATE(), @taxRateID, @newTransID)
					SET @taxI = @taxI + 1
				END
			END
		END		
		ELSE
		BEGIN
			INSERT ActivityLog	(ActivityLogID, AccountID, ActivityLogType, ModifiedByPersonID, ObjectName, ObjectID, PropertyID,
									Activity, [Timestamp], ExceptionName, ExceptionCaught, 
									Exception, AltObjectID)
				VALUES			(NEWID(), @accountID, 'PostingBatchCharge', @personID, @objectName, @objectID, @propertyID,
									'PostingBatch', GETDATE(), 'Object not found', 0,
									'Unit #' + @unit + ', Amount $' + CAST(@amount as nvarchar) + ', Description: ' + @description + ', Note: ' + @note, @postingBatchID)
		END
		SET @ctr = @ctr + 1
	END
	
END



GO
