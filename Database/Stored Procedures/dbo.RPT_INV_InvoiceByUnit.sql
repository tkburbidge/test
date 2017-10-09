SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 28, 2012
-- Description:	Generates the data for the InvoiceByUnit Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_InvoiceByUnit] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null,
	@objectIDs GuidCollection READONLY,
	@includeNullObjectID bit = 0
AS

DECLARE @objectIDCount int 

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL,
		InvoiceStatusDate [Date] NULL)
		
	CREATE TABLE #ObjectIDsCollection (
		ObjectID uniqueidentifier NOT NULL)

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN		
		INSERT #PropertyAndDates
			SELECT pids.Value, pap.StartDate, pap.EndDate, pap.EndDate
				FROM @propertyIDs pids
					INNER JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END
	ELSE
	BEGIN
		INSERT #PropertyAndDates
			SELECT pids.Value, @startDate, @endDate, @endDate
				FROM @propertyIDs pids
	END
	
	INSERT #ObjectIDsCollection
		SELECT Value FROM @objectIDs
		
	SET @objectIDCount = (SELECT COUNT(*) FROM #ObjectIDsCollection)

	SELECT	p.Name AS 'PropertyName', 
			i.InvoiceID,
			v.VendorID,
			v.CompanyName AS 'VendorName',
			CASE WHEN ili.ObjectID IS NULL THEN 'None'
				 WHEN ili.ObjectType = 'Unit' OR u.UnitID IS NOT NULL THEN ISNULL(u.Number, '')
				 WHEN ili.ObjectType = 'Rentable Item' OR ri.LedgerItemID IS NOT NULL THEN ISNULL(ri.[Description], '')
				 WHEN ili.ObjectType = 'Building' OR b.BuildingID IS NOT NULL THEN ISNULL(b.Name, '')
				 WHEN ili.ObjectType = 'WOIT Account' OR w.WOITAccountID IS NOT NULL THEN ISNULL(w.Name, '')
				 ELSE 'None'
			END AS 'ObjectName',			
			ISNULL(ili.ObjectType, '') AS 'ObjectType',
			i.Number AS 'InvoiceNumber',
			i.AccountingDate AS 'AccountingDate',
			gla.Number AS 'GLAccountNumber',
			t.[Description] AS 'Description',
			ili.Quantity AS 'Quantity',
			CASE 
				WHEN (i.Credit = 1) THEN -t.Amount 
				ELSE t.Amount END AS 'Total',
			CAST(i.Credit AS BIT) AS 'Credit'
		FROM Invoice i			
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN #PropertyAndDates #pad ON #pad.PropertyID = t.PropertyID
			INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
			INNER JOIN Vendor v ON i.VendorID = v.VendorID
			LEFT JOIN Unit u on ili.ObjectID = u.UnitID
			LEFT JOIN Building b on ili.ObjectID = b.BuildingID
			LEFT JOIN LedgerItem ri on ili.ObjectID = ri.LedgerItemID
			LEFT JOIN WOITAccount w on ili.ObjectID = w.WOITAccountID
			CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, #pad.InvoiceStatusDate) AS INVSTAT
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN #ObjectIDsCollection #objColl ON ili.ObjectID = #objColl.ObjectID
		WHERE INVSTAT.InvoiceStatus NOT IN ('Void')
		  AND i.AccountingDate >= #pad.StartDate 
		  AND i.AccountingDate <= #pad.EndDate
		  AND tr.TransactionID IS NULL
		  AND tr.ReversesTransactionID IS NULL
		  AND (((@includeNullObjectID = 1) AND (ili.ObjectID IS NULL))
		    OR ((@objectIDCount > 0) AND (#objColl.ObjectID IS NOT NULL))
		    OR ((@objectIDCount = 0) AND (ili.ObjectID IS NOT NULL)))
		ORDER BY p.Name, u.PaddedNumber
END
GO
