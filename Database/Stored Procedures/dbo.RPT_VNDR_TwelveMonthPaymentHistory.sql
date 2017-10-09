SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

















-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Mar. 18, 2013
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_TwelveMonthPaymentHistory] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@paymentTypes StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PaymentTypes ( PaymentType nvarchar(500) )
	INSERT #PaymentTypes SELECT Value FROM @paymentTypes 

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date not null,
		WasNull bit not null)
		
	CREATE TABLE #PropsAndPeriods (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date not null)		

	-- Get the end date and the start date
	-- Start date will be the end date of the same period a year
	-- prior plus one day
	--DECLARE @endDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	--DECLARE @accountID bigint = (SELECT AccountID FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	--DECLARE @startDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE DATEPART(MONTH, EndDate) = DATEPART(MONTH, @endDate)
	--																	AND DATEPART(Year, EndDate) = DATEPART(Year, DATEADD(year, -1, @endDate))
	--																	AND AccountID = @accountID)
	
	INSERT #PropertiesAndDates
		SELECT pIDs.Value, pap.AccountingPeriodID, pap.StartDate, pap.EndDate, 0
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
		WHERE StartDate IS null	
		
	UPDATE #PropertiesAndDates SET StartDate = DATEADD(DAY, 1, StartDate)
		WHERE WasNull = 0												
		
	INSERT #PropsAndPeriods		
		SELECT pap.PropertyID, pap.AccountingPeriodID, pap.StartDate, pap.EndDate
			FROM PropertyAccountingPeriod pap
				INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID AND pap.StartDate >= #pad.StartDate AND pap.EndDate <= #pad.EndDate	

	SELECT 
			v.VendorID AS 'VendorID',
			v.CompanyName AS 'VendorName',
			--ap.EndDate AS 'EndDate',
			REALap.EndDate AS 'EndDate',
			SUM(
				CASE WHEN tt.Name = 'Vendor Credit' THEN -t.Amount
					 ELSE t.Amount
				END
			) AS 'Amount'			
		FROM Vendor v
			INNER JOIN Payment py ON v.VendorID = py.ObjectID AND py.ObjectType = 'Vendor'
			INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON tt.TransactionTypeID = t.TransactionTypeID
			--INNER JOIN AccountingPeriod ap ON ap.StartDate <= py.[Date] AND ap.EndDate >= py.[Date] AND ap.AccountID = @accountID		
			INNER JOIN #PropertiesAndDates #pad ON #pad.StartDate <= py.[Date] AND #pad.EndDate >= py.[Date] AND t.PropertyID = #pad.PropertyID
			INNER JOIN #PropsAndPeriods ap ON #pad.PropertyID = ap.PropertyID AND py.[Date] >= ap.StartDate AND py.[Date] <= ap.EndDate
			INNER JOIN AccountingPeriod REALap ON ap.AccountingPeriodID = REALap.AccountingPeriodID
			LEFT JOIN [Transaction] t1 on t1.AppliesToTransactionID = t.TransactionID
			INNER JOIN #PaymentTypes ptype ON py.[Type] = ptype.PaymentType
		WHERE 
			/*py.[Date] >= @startDate
			AND py.[Date] <= @endDate			
			AND*/
				py.[Date] >= #pad.StartDate
			AND py.[Date] <= #pad.EndDate
			AND Reversed = 0 
			AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND t1.TransactionID IS NULL
		GROUP BY REALap.EndDate, v.VendorID, v.CompanyName
		ORDER BY v.CompanyName	
		
END


GO
