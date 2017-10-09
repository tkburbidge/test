SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Nick Olsen
-- Create date: Aug. 21, 2012
-- Description:	Generates the data for the Purchase Order GL Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PO_PurchaseOrderGLSummary] 
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
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
		
	INSERT #PropertiesAndDates
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SELECT gl.Number AS 'GLNumber', gl.Name AS 'GLName', gl.GLAccountID AS 'GLAccountID', Sum(poli.GLTotal) AS 'Amount'
	FROM PurchaseOrderLineItem poli
	INNER JOIN PurchaseOrder po on po.PurchaseOrderID = poli.PurchaseOrderID
	INNER JOIN GLAccount gl ON gl.GLAccountID = poli.GLAccountID
	--INNER JOIN Property p ON po.PropertyID = p.PropertyID
	INNER JOIN #PropertiesAndDates #pad ON poli.PropertyID = #pad.PropertyID
	--CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, @endDate) pos
	CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, #pad.EndDate) pos
	WHERE poli.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND pos.InvoiceStatus IN (SELECT Value FROM @statuses)
		--AND po.[Date] >= @startDate
		--AND po.[Date] <= @endDate
		AND (((@accountingPeriodID IS NULL) AND (po.[Date] >= @startDate) AND (po.[Date] <= @endDate))
		  OR ((@accountingPeriodID IS NOT NULL) AND (po.[Date] >= #pad.StartDate) AND (po.[Date] <= #pad.EndDate)))
	GROUP BY gl.GLAccountID, gl.Number, gl.Name	
    
END

GO
