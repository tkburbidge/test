SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 31, 2013
-- Description:	Generates the detail data for the 12 month Invoice Summary Report.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_Get12MonthInvoiceSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@accountingPeriodID uniqueidentifier = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date not null,
		WasNull bit not null)
		
	CREATE TABLE #PropsAndPeriods (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
		
	-- Get the end date and the start date
	-- Start date will be the end date of the same period a year
	-- prior plus one day
	--DECLARE @endDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID AND AccountID = @accountID)
	--DECLARE @startDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE DATEPART(MONTH, EndDate) = DATEPART(MONTH, @endDate)
	--																	AND DATEPART(Year, EndDate) = DATEPART(Year, DATEADD(year, -1, @endDate))
	--																	AND AccountID = @accountID)
																		
	INSERT #PropertiesAndDates
		SELECT pIDs.Value, pap.AccountingPeriodID, null, pap.EndDate, 0
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
				
	UPDATE #PropertiesAndDates SET StartDate = (SELECT pap.EndDate 
													FROM PropertyAccountingPeriod pap
													WHERE DATEPART(MONTH, pap.EndDate) = DATEPART(MONTH, #PropertiesAndDates.EndDate)
													  AND DATEPART(YEAR, pap.EndDate) = DATEPART(YEAR, DATEADD(year, -1, #PropertiesAndDates.EndDate))
													  AND pap.PropertyID = #PropertiesAndDates.PropertyID)																	
	
	
	-- if the start period is not defined then set the start date to the end date less one year plus one day
	--IF (@startDate IS NULL)
	--BEGIN
	--	SET @startDate = DATEADD(year, -1, (DATEADD(day, 1, @endDate)))
	--END				
	--ELSE
	--BEGIN
	--	SET @startDate = DATEADD(DAY, 1, @startDate)
	--END	
	
	UPDATE #PropertiesAndDates SET StartDate = DATEADD(YEAR, -1, (DATEADD(DAY, 1, EndDate))), WasNull = 1
		WHERE StartDate = null	
		
	UPDATE #PropertiesAndDates SET StartDate = DATEADD(DAY, 1, StartDate)
		WHERE WasNull = 0		
		
	INSERT #PropsAndPeriods		
		SELECT pap.PropertyID, pap.AccountingPeriodID, pap.StartDate, pap.EndDate
			FROM PropertyAccountingPeriod pap
				INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID AND pap.StartDate >= #pad.StartDate AND pap.EndDate <= #pad.EndDate
				
	SELECT 
			v.VendorID,
			v.CompanyName AS 'VendorName',
			--ap.EndDate AS 'EndDate', 
			REALap.EndDate AS 'EndDate',
			SUM(CASE WHEN i.Credit = 1 THEN -t.Amount ELSE t.Amount END) AS 'Amount'
		FROM Invoice i
			INNER JOIN Vendor v ON i.VendorID = v.VendorID		
			--INNER JOIN 
			--		(SELECT StartDate, EndDate
			--			FROM AccountingPeriod 
			--			WHERE StartDate >= @startDate
			--			  AND (EndDate <= @endDate)
			--			  AND AccountID = @accountID) AS ap
			--	ON 1 = 1
			--INNER JOIN 
			--		(SELECT MIN(pap.StartDate) AS 'StartDate', MAX(pap.EndDate) AS 'EndDate', pap.AccountingPeriodID
			--			FROM PropertyAccountingPeriod pap
			--				INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
			--			WHERE pap.StartDate >= #pad.StartDate
			--			  AND pap.EndDate <= #pad.EndDate
			--			  AND pap.PropertyID IN (SELECT t1.PropertyID
			--										FROM InvoiceLineItem ili1
			--											INNER JOIN [Transaction] t1 ON ili1.TransactionID = t1.TransactionID 
			--											LEFT JOIN [Transaction] tr1 ON tr1.ReversesTransactionID = t1.TransactionID 
			--										WHERE tr1.TransactionID IS NULL
			--										  AND ili1.InvoiceID = i.InvoiceID)) AS ap ON 1 = 1
			
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND i.AccountingDate >= #pad.StartDate AND i.AccountingDate <= #pad.EndDate
			INNER JOIN #PropsAndPeriods ap ON #pad.PropertyID = ap.PropertyID
			INNER JOIN AccountingPeriod REALap ON ap.AccountingPeriodID = REALap.AccountingPeriodID
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
		WHERE i.AccountingDate >= ap.StartDate
		  AND i.AccountingDate <= ap.EndDate
		  AND i.AccountID = @accountID
		  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND tr.TransactionID IS NULL
		GROUP BY REALap.EndDate, v.VendorID, v.CompanyName
		ORDER BY v.CompanyName
	
	
END



GO
