SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: March 21, 2012
-- Description:	Lists invoice line items for a given set of GL Accounts
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_PurchasesByGL]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@glAccountIDs GuidCollection readonly,	
	@glAccountTypes StringCollection readonly,
	@startDate datetime,
	@endDate datetime,
	@accountingPeriodID uniqueidentifier 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @reportGLAccountIDs GuidCollection
	
	-- If we are passed in types, get all GL Accounts
	-- based on the types passed in
	IF ((SELECT COUNT(*) FROM @glAccountTypes) > 0)
	BEGIN
		INSERT INTO @reportGLACcountIDs
			SELECT GLAccountID
			FROM GLAccount 
			WHERE AccountID = @accountID
				AND GLAccountType IN (SELECT Value FROM @glAccountTypes)
	END
	ELSE
	BEGIN
		INSERT INTO @reportGLAccountIDs SELECT Value FROM @glAccountIDs
	END


    -- Insert statements for procedure here
	SELECT 
		p.Name AS 'PropertyName',
		i.InvoiceDate,
		i.InvoiceID,
		i.AccountingDate,
		i.Number AS 'InvoiceNumber',
		CASE WHEN i.Credit = 1 THEN -t.Amount
			 ELSE t.Amount END AS 'Amount',
		CASE WHEN v.Summary = 1 THEN sv.Name
			 ELSE v.CompanyName
		END AS 'Vendor',
		t.[Description],
		gl.GLAccountID,
		gl.Number AS 'GLNumber',
		gl.Name AS 'GLName',
		CASE WHEN ili.ObjectID IS NULL THEN NULL
			 WHEN ili.ObjectType = 'Unit' THEN u.Number
			 WHEN ili.ObjectType = 'Rentable Item' THEN ri.[Description]
			 WHEN ili.ObjectType = 'Building' THEN b.Name
			 WHEN ili.ObjectType = 'WOIT Account' THEN w.Name
		END AS 'Location',
		ili.ObjectType AS 'LocationType',
		InvoiceStatus.InvoiceStatus
	FROM InvoiceLineItem ili
	INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
	INNER JOIN Vendor v ON i.VendorID = v.VendorID
	INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
	INNER JOIN [GLAccount] gl ON gl.GLAccountID = ili.GLAccountID
	INNER JOIN Property p ON t.PropertyID = p.PropertyID
	LEFT JOIN SummaryVendor sv ON i.SummaryVendorID = sv.SummaryVendorID
	LEFT JOIN Unit u on ili.ObjectID = u.UnitID
	LEFT JOIN Building b on ili.ObjectID = b.BuildingID
	LEFT JOIN LedgerItem ri on ili.ObjectID = ri.LedgerItemID
	LEFT JOIN WOITAccount w on ili.ObjectID = w.WOITAccountID
	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, COALESCE(pap.EndDate, @endDate)) InvoiceStatus
	WHERE ili.GLAccountID IN (SELECT Value FROM @reportGLAccountIDs)
		  --AND i.AccountingDate >= @startDate
		  --AND i.AccountingDate <= @endDate

		  AND (((@accountingPeriodID IS NULL) AND (i.AccountingDate >= @startDate) AND (i.AccountingDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (i.AccountingDate >= pap.StartDate) AND (i.AccountingDate <= pap.EndDate)))
		  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND InvoiceStatus.InvoiceStatus <> 'Void'
		  AND tr.TransactionID IS NULL
		  AND t.ReversesTransactionID IS NULL
END






GO
