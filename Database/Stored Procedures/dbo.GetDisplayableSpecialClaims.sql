SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetDisplayableSpecialClaims] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@startDate datetime, 
	@endDate datetime, 
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs 
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #SpecialClaims (
		SpecialClaimID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Type] nvarchar (100) not null,
		Submitted bit not null
	)

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #SpecialClaims
		SELECT sc.SpecialClaimID AS 'SpecialClaimID',
			#pad.PropertyID AS 'PropertyID',
			sc.[Type] AS 'Type',
			0 AS 'Submitted'
		FROM SpecialClaim sc
			INNER JOIN #PropertiesAndDates #pad ON sc.PropertyID = #pad.PropertyID
		WHERE sc.AccountID = @accountID
			AND sc.[Date] >= #pad.StartDate
			AND sc.[Date] < #pad.EndDate

	UPDATE #sc
		SET Submitted = 1
		FROM #SpecialClaims #sc
			INNER JOIN AffordableSubmissionItem asi ON #sc.SpecialClaimID = asi.ObjectID
			INNER JOIN AffordableSubmission a ON asi.AffordableSubmissionID = a.AffordableSubmissionID
			INNER JOIN #PropertiesAndDates #pad ON #sc.PropertyID = #pad.PropertyID
		WHERE a.DateSubmitted >= #pad.StartDate
			AND a.DateSubmitted < #pad.EndDate

	SELECT 
		p.PropertyID,
		p.Name AS 'PropertyName',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.[Type] = 'Unpaid Rent') AS 'UnpaidRentCount',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.[Type] = 'Tenant Damages') AS 'TenantDamagesCount',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.[Type] = 'Regular Vacancy') AS 'RegularVacanciesCount',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.[Type] = 'Rent-Up Vacancy') AS 'RentUpVacanciesCount',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.[Type] = 'Debt Services') AS 'DebtService',
		(SELECT COUNT(*) FROM #SpecialClaims #sc WHERE #sc.PropertyID = p.PropertyID AND #sc.Submitted = 1) AS 'SubmittedCount'
	FROM Property p
		INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
	WHERE p.AccountID = @accountID
END
GO
