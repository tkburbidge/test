SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 12, 2012
-- Description:	Updates the TaxRateGroups
-- =============================================
CREATE PROCEDURE [dbo].[UpdateTaxRateGroup] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@taxRateGroupID uniqueidentifier = null,
	@name nvarchar(50) = null,
	@description nvarchar(500) = null,
	@taxRateIDs GuidCollection READONLY,
	@propertyIDs GuidCollection READONLY,
	@type NVARCHAR(20),
	@ledgerItemTypeIDs GuidCollection READONLY
AS
DECLARE @newTaxRateGroupID				uniqueidentifier
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null)

	INSERT #Properties
		SELECT Value from @propertyIDs

	IF ((0 < (SELECT COUNT(TransactionID) 
					FROM [Transaction] 
					WHERE TaxRateGroupID = @taxRateGroupID))
			OR (0 < (SELECT COUNT(PaymentID) 
						FROM Payment
						WHERE TaxRateGroupID = @taxRateGroupID))
			OR (0 < (SELECT COUNT(InvoiceLineItemID)
						FROM InvoiceLineItem 
						WHERE TaxRateGroupID = @taxRateGroupID))
			OR (0 < (SELECT COUNT(PurchaseOrderLineItemID)
						FROM PurchaseOrderLineItem 
						WHERE TaxRateGroupID = @taxRateGroupID)))
	BEGIN
		SET @newTaxRateGroupID = NEWID()
		INSERT TaxRateGroup (TaxRateGroupID, Name, [Description], DateCreated, AccountID, IsObsolete, [Type])
			VALUES (@newTaxRateGroupID, @name, @description, GETDATE(), @accountID, 0, @type)
		INSERT TaxRateGroupTaxRate 
			SELECT @newTaxRateGroupID, Value, @accountID
				FROM @taxRateIDs
		INSERT PropertyTaxRateGroup 
			SELECT @accountID, Value, @newTaxRateGroupID, 0	
				FROM @propertyIDs
		UPDATE TaxRateGroup SET IsObsolete = 1 WHERE TaxRateGroupID = @taxRateGroupID
		UPDATE LeaseLedgerItem SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID
		UPDATE VendorProperty SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID
		--UPDATE LedgerItemTypeTaxGroup SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID

		-- updates to LedgerItemTypeProperty
		UPDATE LedgerItemTypeProperty SET TaxRateGroupID = null					-- we cannot delete the records because what if needed by InterestFormulas
			WHERE AccountID = @accountID
			  AND TaxRateGroupID = @taxRateGroupID
			  AND (LedgerItemTypeID NOT IN (SELECT Value FROM @ledgerItemTypeIDs)
				   OR PropertyID NOT IN (SELECT Value from @propertyIDs))
		UPDATE LedgerItemTypeProperty SET TaxRateGroupID = @newTaxRateGroupID
			WHERE AccountID = @accountID
			  AND (TaxRateGroupID IS NULL OR TaxRateGroupID = @taxRateGroupID)	-- this could be null if we added a record from UpdatePropertyInterestFormulaIDs.sql
			  AND PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND LedgerItemTypeID IN (SELECT Value FROM @ledgerItemTypeIDs)
		INSERT LedgerItemTypeProperty
			SELECT NEWID(), @accountID, Value, #p.PropertyID, @newTaxRateGroupID, 0
			FROM @ledgerItemTypeIDs
				INNER JOIN #Properties #p on #p.PropertyID = #p.PropertyID
			WHERE (SELECT COUNT(litp.LedgerItemTypePropertyID)
					FROM LedgerItemTypeProperty litp
					WHERE litp.AccountID = @accountID
					  AND litp.LedgerItemTypeID = Value
					  AND litp.PropertyID = #p.PropertyID) = 0
	
	END
	ELSE
	BEGIN
		UPDATE TaxRateGroup SET Name = @name, [Description] = @description, [Type] = @type
			WHERE TaxRateGroupID = @taxRateGroupID
		DELETE TaxRateGroupTaxRate WHERE TaxRateGroupID = @taxRateGroupID
		DELETE PropertyTaxRateGroup WHERE TaxRateGroupID = @taxRateGroupID
		INSERT TaxRateGroupTaxRate 
			SELECT @taxRateGroupID, Value, @accountID
				FROM @taxRateIDs
		INSERT PropertyTaxRateGroup 
			SELECT @accountID, Value, @taxRateGroupID, 0	
				FROM @propertyIDs

		-- updates to LedgerItemTypeProperty 
		UPDATE LedgerItemTypeProperty SET TaxRateGroupID = null					-- we cannot delete the records because what if needed by InterestFormulas
			WHERE AccountID = @accountID
			  AND TaxRateGroupID = @taxRateGroupID
			  AND (LedgerItemTypeID NOT IN (SELECT Value FROM @ledgerItemTypeIDs)
				   OR PropertyID NOT IN (SELECT Value from @propertyIDs))
		UPDATE LedgerItemTypeProperty SET TaxRateGroupID = @taxRateGroupID
			WHERE AccountID = @accountID
			  AND TaxRateGroupID IS NULL										-- this could be null if we added a record from UpdatePropertyInterestFormulaIDs.sql
			  AND PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND LedgerItemTypeID IN (SELECT Value FROM @ledgerItemTypeIDs)
		INSERT LedgerItemTypeProperty
			SELECT NEWID(), @accountID, Value, #p.PropertyID, @taxRateGroupID, 0, 1
			FROM @ledgerItemTypeIDs
				INNER JOIN #Properties #p on #p.PropertyID = #p.PropertyID
			WHERE (SELECT COUNT(litp.LedgerItemTypePropertyID)
					FROM LedgerItemTypeProperty litp
					WHERE litp.AccountID = @accountID
					  AND litp.LedgerItemTypeID = Value
					  AND litp.PropertyID = #p.PropertyID) = 0

	END
	
END
GO
