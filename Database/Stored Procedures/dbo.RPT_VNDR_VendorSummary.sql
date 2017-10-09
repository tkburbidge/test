SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 28, 2012
-- Description:	Generates the data for the VendorSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_VendorSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * 
	FROM 
		(SELECT	v.CompanyName AS 'VendorName',
				ad.StreetAddress AS 'VendorAddress',
				ad.City AS 'VendorCity',
				ad.State AS 'VendorState',
				ad.Zip As 'VendorZip',
				pr.Phone1 AS 'VendorPhone',
				(CASE WHEN v.RequiredInsuranceTypes > 0 THEN CAST (1 AS BIT)
					  ELSE CAST (0 AS BIT)
			     END) AS 'NeedsInsurance',
				v.Gets1099 AS 'Gets1099',
				v.IsApproved AS 'IsApproved',		
				(SELECT COUNT(distinct po.PurchaseOrderID)
					FROM PurchaseOrder po
						INNER JOIN PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID 
						CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, @endDate) AS POSTAT2
						LEFT JOIN PropertyAccountingPeriod pap ON poli.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE po.VendorID = v.VendorID
					  --AND po.[Date] >= @startDate
					  --AND po.[Date] <= @endDate
					  AND (((@accountingPeriodID IS NULL) AND (po.[Date] >= @startDate) AND (po.[Date] <= @endDate))
						OR ((@accountingPeriodID IS NOT NULL) AND (po.[Date] >= pap.StartDate) AND (po.[Date] <= pap.EndDate)))
					  AND poli.PropertyID IN (SELECT Value FROM @propertyIDs)
					  AND POSTAT2.InvoiceStatus NOT IN ('Void')) AS 'POCount',
				(SELECT ISNULL(SUM(poli.GLTotal), 0)
					FROM PurchaseOrder po
						inner join PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID 
						CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, @endDate) AS POSTAT2
						LEFT JOIN PropertyAccountingPeriod pap ON poli.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE po.VendorID = v.VendorID
					  --AND po.[Date] >= @startDate
					  --AND po.[Date] <= @endDate
					  AND (((@accountingPeriodID IS NULL) AND (po.[Date] >= @startDate) AND (po.[Date] <= @endDate))
						OR ((@accountingPeriodID IS NOT NULL) AND (po.[Date] >= pap.StartDate) AND (po.[Date] <= pap.EndDate)))				  
					  AND poli.PropertyID IN (SELECT Value FROM @propertyIDs)
					  AND POSTAT2.InvoiceStatus NOT IN ('Void')) AS 'POTotal',
				(SELECT COUNT(DISTINCT i2.InvoiceID) 
					FROM Invoice i2 
						INNER JOIN InvoiceLineItem ili ON i2.InvoiceID = ili.InvoiceID
						INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
						CROSS APPLY GetInvoiceStatusByInvoiceID(i2.InvoiceID, @endDate) AS INVSTAT2
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE i2.VendorID = v.VendorID
					  --AND i2.AccountingDate >= @startDate
					  --AND i2.AccountingDate <= @endDate
					  AND (((@accountingPeriodID IS NULL) AND (i2.AccountingDate >= @startDate) AND (i2.AccountingDate <= @endDate))
						OR ((@accountingPeriodID IS NOT NULL) AND (i2.AccountingDate >= pap.StartDate) AND (i2.AccountingDate <= pap.EndDate)))
					  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
					  AND INVSTAT2.InvoiceStatus NOT IN ('Void')) AS 'InvoiceCount',
				(SELECT ISNULL(SUM(CASE
								WHEN i3.Credit = 1 THEN -t.Amount
								ELSE t.Amount END), 0)
					FROM InvoiceLineItem ili					
						INNER JOIN Invoice i3 ON i3.InvoiceID = ili.InvoiceID
						INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID				
						CROSS APPLY GetInvoiceStatusByInvoiceID(i3.InvoiceID, @endDate) AS INVSTAT3
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE i3.VendorID = v.VendorID
					  --AND i3.AccountingDate >= @startDate
					  --AND i3.AccountingDate <= @endDate
					  AND (((@accountingPeriodID IS NULL) AND (i3.AccountingDate >= @startDate) AND (i3.AccountingDate <= @endDate))
						OR ((@accountingPeriodID IS NOT NULL) AND (i3.AccountingDate >= pap.StartDate) AND (i3.AccountingDate <= pap.EndDate)))				  
					  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)				  				  
					  AND INVSTAT3.InvoiceStatus NOT IN ('Void')) AS 'InvoiceTotal',
				v.Form1099RecipientsID AS 'TaxID',
				v.IsActive

			FROM Vendor v
				INNER JOIN VendorPerson vp ON v.VendorID = vp.VendorID
				INNER JOIN Person pr ON vp.PersonID = pr.PersonID
				INNER JOIN PersonType pty ON pr.PersonID = pty.PersonID AND pty.Type IN ('VendorGeneral')
				INNER JOIN [Address] ad ON ad.ObjectID = pr.PersonID
				--INNER JOIN VendorProperty vprop ON vprop.VendorID = v.VendorID
			WHERE --vprop.PropertyID IN (SELECT Value FROM @propertyIDs)		  
				EXISTS (SELECT * FROM VendorProperty vp
						WHERE vp.PropertyID IN (SELECT Value FROM @propertyIDs)
							AND vp.VendorID = v.VendorID)) Vendors
		WHERE IsActive = 1
			OR InvoiceCount > 0
			OR POCount > 0
		ORDER BY VendorName
END
GO
