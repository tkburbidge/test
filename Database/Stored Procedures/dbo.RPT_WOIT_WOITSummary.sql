SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 19, 2015
-- Description:	Gets the data for the Non-Resident Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_WOIT_WOITSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null, 
	@endDate date = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)
		
		
--PropertyID
--PropertyName
--Name
--WorkOrders - Count of the work orders posted during the range
--Invoices - Total of the invoice line items posted during the range
--Balance - Balance at the end of the report range		
		
		
	CREATE TABLE #MyWOITs (
		PropertyID uniqueidentifier not null,
		WOITAccountID uniqueidentifier not null,
		Name nvarchar(250) null,
		WorkOrders int null,
		InvoiceTotals money null,
		Balance money null)
		
	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	INSERT #MyWOITs
		SELECT #pad.PropertyID, woit.WOITAccountID, woit.Name, null, null, null
			FROM WOITAccount woit
				INNER JOIN #PropertiesAndDates #pad ON woit.PropertyID = #pad.PropertyID
			WHERE BillingAccountID IS NULL
				
	UPDATE #MyWOITs SET WorkOrders = (SELECT COUNT(*)
										  FROM WorkOrder wo
											  INNER JOIN #MyWOITs #mw ON wo.ObjectID = #mw.WOITAccountID
											  INNER JOIN #PropertiesAndDates #pad ON #mw.PropertyID = #pad.PropertyID
										  WHERE #mw.WOITAccountID = #MyWOITs.WOITAccountID
										    AND wo.ReportedDate >= #pad.StartDate 
										    AND wo.ReportedDate <= #pad.EndDate
										  GROUP BY #mw.WOITAccountID)
										  
	UPDATE #MyWOITs SET InvoiceTotals = (SELECT SUM(t.Amount)
											FROM #MyWOITs #mw
												INNER JOIN InvoiceLineItem ili ON #mw.WOITAccountID = ili.ObjectID
												INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
												INNER JOIN #PropertiesAndDates #pad ON #mw.PropertyID = #pad.PropertyID
											WHERE t.TransactionDate >= #pad.StartDate
											  AND t.TransactionDate <= #pad.EndDate
											  AND #mw.WOITAccountID = #MyWOITs.WOITAccountID
											GROUP BY #mw.WOITAccountID)
											
	UPDATE #MyWOITs SET Balance = ISNULL((SELECT [BAL].Balance
											  FROM #MyWOITs #mw
												  INNER JOIN #PropertiesAndDates #pad ON #mw.PropertyID = #pad.PropertyID
												  CROSS APPLY GetObjectBalance(null, #pad.EndDate, #mw.WOITAccountID, 0, @propertyIDs) [BAL]
											  WHERE #mw.WOITAccountID = #MyWOITs.WOITAccountID), 0.00)
											
	SELECT	#mw.PropertyID,
			prop.Name AS 'PropertyName',
			#mw.WOITAccountID,
			#mw.Name,
			#mw.WorkOrders,
			#mw.InvoiceTotals AS 'Invoices',
			#mw.Balance
		FROM #MyWOITs #mw
			INNER JOIN Property prop ON #mw.PropertyID = prop.PropertyID


END
GO
