SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Nick Olsen
-- Create date: Aug. 21, 2012
-- Description:	Generates the data for the Purchase Order Summary Report
CREATE PROCEDURE [dbo].[RPT_PO_PurchaseOrderSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 	
	@statuses StringCollection READONLY,
	@startDate datetime = null,
	@endDate datetime = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyEndDates (
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
		
	INSERT #PropertyEndDates
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SELECT distinct 
		po.PurchaseOrderID,
		--p.Name AS 'PropertyName',
		po.Number,
		po.[Date],
		pos.InvoiceStatus AS 'Status',
		v.CompanyName AS 'Vendor',
		po.[Description],
		(select sum (poli2.Total)
			from PurchaseOrderLineItem poli2		
			where poli2.PurchaseOrderID = po.PurchaseOrderID 
				AND poli2.PropertyID IN (SELECT Value FROM @propertyIDs)) as Total,
		(CASE WHEN pos.InvoiceStatus IN ('Approved', 'Approved-R', 'Completed')
			THEN (SELECT TOP 1 per.PreferredName + ' ' + per.LastName
				  FROM POInvoiceNote pon 
				  INNER JOIN Person per ON pon.PersonID = per.PersonID
				  WHERE pon.ObjectID = po.PurchaseOrderID
					AND pon.[Status] IN ('Approved', 'Approved-R')
				  ORDER BY pon.[Date] DESC)
		 ELSE null END) AS 'ApprovedBy',
		 i.InvoiceID,
		 i.Number AS 'InvoiceNumber',
		 (SELECT SUM(t.Amount)
		  FROM InvoiceLineItem ili
			INNER JOIN [Transaction] t on t.TransactionID = ili.TransactionID
		  WHERE t.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND ili.InvoiceId = po.InvoiceID) AS 'InvoiceTotal'		 
	FROM PurchaseOrder po
	inner join PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID	
	INNER JOIN Vendor v ON po.VendorID = v.VendorID
	INNER JOIN Property p ON poli.PropertyID = p.PropertyID
	INNER JOIN #PropertyEndDates #ped ON p.PropertyID = #ped.PropertyID
	LEFT JOIN Invoice i ON po.InvoiceID = i.InvoiceID
	--CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, @endDate) pos
	CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, #ped.EndDate) pos
	WHERE poli.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND pos.InvoiceStatus IN (SELECT Value FROM @statuses)
		--AND po.[Date] >= @startDate
		--AND po.[Date] <= @endDate
		AND (((@accountingPeriodID IS NULL) AND (po.[Date] >= @startDate) AND (po.[Date] <= @endDate))
		  OR ((@accountingPeriodID IS NOT NULL) AND (po.[Date] >= #ped.StartDate) AND (po.[Date] <= #ped.EndDate)))

   
END





GO
