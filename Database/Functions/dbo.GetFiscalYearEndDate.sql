SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 28, 2015
-- Description:	Gets the EndDate of the last day of the Fiscal Year.
-- =============================================
CREATE FUNCTION [dbo].[GetFiscalYearEndDate] 
(
	-- Add the parameters for the function here
	@propertyID uniqueidentifier,
	@accountingPeriodID uniqueidentifier
)
RETURNS date
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result date

	-- Add the T-SQL statements to compute the return value here
	SET @Result = (SELECT pap.EndDate
						FROM PropertyAccountingPeriod pap
						WHERE DATEPART(MONTH, pap.EndDate) = (SELECT CASE WHEN (FiscalYearStartMonth = 1) THEN 12 ELSE FiscalYearStartMonth - 1 END
																FROM Property 
																WHERE PropertyID = pap.PropertyID)
						  AND DATEPART(YEAR, pap.EndDate) = (SELECT CASE WHEN (DATEPART(MONTH, papCur.EndDate) <= (SELECT CASE WHEN (FiscalYearStartMonth = 1) THEN 12 ELSE FiscalYearStartMonth - 1 END
																													FROM Property 
																													WHERE PropertyID = pap.PropertyID)) 
																		 THEN DATEPART(YEAR, papCur.EndDate)
																		 ELSE DATEPART(YEAR, papCur.EndDate) + 1
																		 END																								
																FROM PropertyAccountingPeriod papCur
																WHERE papCur.PropertyID = pap.PropertyID
																  AND papCur.AccountingPeriodID = @accountingPeriodID)
						  AND pap.PropertyID = @propertyID)
	
	
	
	
	-- Return the result of the function
	RETURN @Result

END
GO
