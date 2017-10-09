SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: April 16, 2012
-- Description:	Gets the fiscal year start date for a given
--			    accounting period 
-- =============================================
CREATE FUNCTION [dbo].[GetFiscalYearStartDate] 
(
	-- Add the parameters for the function here
	@accountID bigint,
	@accountingPeriodID uniqueidentifier,
	@propertyID uniqueidentifier
)
RETURNS datetime
AS
BEGIN
	DECLARE @fiscalYearBegin int = 1
	DECLARE @apEndDate datetime
	DECLARE @fiscalYearStartDate datetime

	-- Get the start month
	--SELECT @fiscalYearBegin = ISNULL(s.FiscalYearStartMonth, 1)	   
	--FROM Settings s		
	--WHERE s.AccountID = @accountID
	
	-- Get the start month, this is now in the Property table.
	-- We currently assume that if this function is called from a sproc, ALL properties which were passed into that sproc have the same start date.
	SELECT @fiscalYearBegin = ISNULL(p.FiscalYearStartMonth, 1)
		FROM Property p
		WHERE p.PropertyID = @propertyID
		

	--SET @apEndDate = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	SET @apEndDate = (SELECT EndDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID AND PropertyID = @propertyID)
			
	-- Try and get the fiscal year start date by matching
	-- on the month from the settings and the year of the 
	-- passed in accounting period		
	SET @fiscalYearStartDate = (SELECT pap.StartDate
								--FROM AccountingPeriod ap
								FROM PropertyAccountingPeriod pap
								WHERE pap.AccountID = @accountID
									  AND pap.PropertyID = @propertyID
									  AND DATEPART(month, pap.EndDate) = @fiscalYearBegin
									  AND ((DATEPART(year, pap.EndDate) = DATEPART(year, @apEndDate))))
									  
	-- If there is no defined period for the given start date
	-- set the fiscal year start date to the first of the month for
	-- the @fiscalYearBegin value
	IF (@fiscalYearStartDate IS NULL)
	BEGIN
		SET @fiscalYearStartDate = (CONVERT(nvarchar(4), DATEPART(year, @apEndDate)) + '-' + CONVERT(nvarchar(2), @fiscalYearBegin) + '-1')
	END	  
		 	 
	-- If the start date is greater than the end date for the period
	-- in which we are running the report then set it to the previous
	-- year period start date	 	 
	IF (@fiscalYearStartDate > @apEndDate)
	BEGIN	
		SET @fiscalYearStartDate  = (SELECT ap.StartDate
									--FROM AccountingPeriod ap	
									FROM PropertyAccountingPeriod ap
									WHERE ap.AccountID = @accountID
									      AND ap.PropertyID = @propertyID
										  AND DATEPART(month, ap.EndDate) = @fiscalYearBegin
										  AND DATEPART(year, ap.EndDate) = (DATEPART(year, @apEndDate) - 1))
	END

	-- If the start date is null then set the fiscal year start 
	-- date to the first of the month for the @fiscalYearBegin value
	IF (@fiscalYearStartDate IS NULL)
	BEGIN
		SET @fiscalYearStartDate = (CONVERT(nvarchar(4), DATEPART(year, @apEndDate) - 1) + '-' + CONVERT(nvarchar(2), @fiscalYearBegin) + '-1')
	END	  

	RETURN @fiscalYearStartDate

END


GO
