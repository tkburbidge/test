SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 7, 2012
-- Description:	Updates a TaxRate which ain't as easy as it sounds
-- =============================================
CREATE PROCEDURE [dbo].[UpdateTaxRate] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@taxRateID uniqueidentifier = null,
	@name nvarchar(50),
	@description nvarchar(200) =  null,
	@newRate decimal(6,4),
	@GLAccountID uniqueidentifier = null,
	@date date = null,
	@type nvarchar(20)
AS

DECLARE @ctr			int = 1
DECLARE @maxCtr			int
DECLARE @taxRateGroupID		uniqueidentifier
DECLARE @newTaxRateGroupID	uniqueidentifier
DECLARE @newTaxRateID		uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @oldRate decimal(6, 4)
	DECLARE @oldGLAccountID uniqueidentifier
	
	SELECT @oldRate = Rate,
		   @oldGLAccountID = GLAccountID
	FROM TaxRate 
	WHERE TaxRateID = @taxRateID
		AND AccountID = @accountID
	
	IF (@oldRate = @newRate AND @oldGLAccountID = @GLAccountID)
	BEGIN
		UPDATE TaxRate SET Name = @name, [Description] = @description, [Type] = @type WHERE TaxRateID = @taxRateID AND AccountID = @accountID
	END	
	ELSE IF ((0 < (SELECT COUNT(t.TransactionID) 
					FROM [Transaction] t
						INNER JOIN TaxRateGroup trg ON t.TaxRateGroupID = trg.TaxRateGroupID 
						INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
						INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
					WHERE tr.TaxRateID = @taxRateID))
			OR (0 < (SELECT COUNT(py.PaymentID) 
						FROM Payment py
							INNER JOIN TaxRateGroup trg ON py.TaxRateGroupID = trg.TaxRateGroupID 
							INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
							INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
						WHERE tr.TaxRateID = @taxRateID))
			OR (0 < (SELECT COUNT(ili.InvoiceLineItemID)
						FROM InvoiceLineItem ili
							INNER JOIN TaxRateGroup trg ON ili.TaxRateGroupID = trg.TaxRateGroupID
							INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
							INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
						WHERE tr.TaxRateID = @taxRateID))
			OR (0 < (SELECT COUNT(poli.PurchaseOrderLineItemID)
						FROM PurchaseOrderLineItem poli
							INNER JOIN TaxRateGroup trg ON poli.TaxRateGroupID = trg.TaxRateGroupID
							INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
							INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
						WHERE tr.TaxRateID = @taxRateID)))
		BEGIN
			-- If this has ever been used before, you need to recreate the entire TaxRateGroup, with the new info, and update:
			-- VendorProperty
			-- LeaseLedgerItem
			-- LedgerItemTypeTaxRateGroup
			CREATE TABLE #OldTaxGroups (
				SequenceNum			int		identity,
				TaxRateGroupID		uniqueidentifier		null)
				
			INSERT #OldTaxGroups SELECT DISTINCT trgtr.TaxRateGroupID
									FROM TaxRateGroupTaxRate trgtr
										INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
									WHERE tr.TaxRateID = @taxRateID
									
			SET @newTaxRateID = NEWID()
			INSERT TaxRate (TaxRateID, AccountID, Name, Rate, GLAccountID, [Description], IsObsolete, [Type]) 
				SELECT @newTaxRateID AS 'TaxRateID', @accountID, @name, @newRate AS 'Rate', @GLAccountID, @description, 0 AS IsObsolete, @type
				
			SET @maxCtr = (SELECT MAX(SequenceNum) FROM #OldTaxGroups)
			WHILE (@ctr <= @maxCtr)
			BEGIN
				SELECT @taxRateGroupID = TaxRateGroupID FROM #OldTaxGroups WHERE SequenceNum = @ctr
				SET @newTaxRateGroupID = NEWID()				
									
				INSERT TaxRateGroup SELECT @newTaxRateGroupID AS 'TaxRateGroupID', AccountID, Name, @date AS 'DateCreated', [Description], 0 AS IsObsolete, [Type]
									FROM TaxRateGroup
									WHERE TaxRateGroupID = @taxRateGroupID
									 AND IsObsolete = 0
				
				INSERT TaxRateGroupTaxRate VALUES (@newTaxRateGroupID, @newTaxRateID, @accountID)
				
				INSERT TaxRateGroupTaxRate SELECT @newTaxRateGroupID AS 'TaxRateGroupID', trgtr.TaxRateID, @accountID
												FROM TaxRateGroupTaxRate trgtr
												INNER JOIN TaxRate tr ON tr.TaxRateID = trgtr.TaxRateID
												INNER JOIN TaxRateGroup trg ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
												WHERE trgtr.TaxRateGroupID = @taxRateGroupID
												  AND trgtr.TaxRateID <> @taxRateID
												  AND trgtr.AccountID = @accountID
												  AND tr.IsObsolete = 0
												  AND trg.IsObsolete = 0
												  
				INSERT PropertyTaxRateGroup SELECT AccountID, PropertyID, @newTaxRateGroupID, 0 AS IsObsolete
											FROM PropertyTaxRateGroup 
											WHERE TaxRateGroupID = @taxRateGroupID
												AND AccountID = @accountID
												AND IsObsolete = 0								
	
				UPDATE PropertyTaxRateGroup SET IsObsolete = 1 WHERE TaxRateGroupID = @taxRateGroupID AND AccountID = @accountID													  
				UPDATE TaxRateGroup SET IsObsolete = 1 WHERE TaxRateGroupID = @taxRateGroupID AND AccountID = @accountID
				UPDATE TaxRate SET IsObsolete = 1 WHERE TaxRateID = @taxRateID AND AccountID = @accountID
				UPDATE LeaseLedgerItem SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID AND AccountID = @accountID
				UPDATE VendorProperty SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID AND AccountID = @accountID
				UPDATE LedgerItemTypeProperty SET TaxRateGroupID = @newTaxRateGroupID WHERE TaxRateGroupID = @taxRateGroupID AND AccountID = @accountID
				SET @ctr = @ctr + 1
			END
		END
		ELSE
		BEGIN
			UPDATE TaxRate SET Name = @name, [Description] = @description, Rate = @newRate, GLAccountID = @GLAccountID, [Type] = @type WHERE TaxRateID = @taxRateID AND AccountID = @accountID
		END													
	
END




/****** Object:  StoredProcedure [dbo].[RPT_RES_ExpiringLeases]    Script Date: 10/12/2012 14:56:30 ******/
SET ANSI_NULLS ON
GO
