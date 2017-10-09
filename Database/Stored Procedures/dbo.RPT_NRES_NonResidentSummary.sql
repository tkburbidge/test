SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_NRES_NonResidentSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@date date = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #NonResidents (
		PropertyID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		RecurringCharges money null,
		Balance money null)
		
	INSERT #PropertiesAndDates
		SELECT	Value
			FROM @propertyIDs 
		
	INSERT #NonResidents 
		SELECT #pad.PropertyID, per.PersonID, null, null
			FROM Person per 
				INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] = 'Non-Resident Account'
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID 
				INNER JOIN #PropertiesAndDates #pad ON ptp.PropertyID = #pad.PropertyID
				LEFT JOIN PersonType ptRes ON per.PersonID = ptRes.PersonID AND pt.[Type] = 'Resident'
			WHERE ptRes.PersonTypeID IS NULL

	UPDATE #NonResidents SET Balance = (SELECT [BAL].Balance
											FROM #NonResidents #nr 
												INNER JOIN #PropertiesAndDates #pad ON #nr.PropertyID = #pad.PropertyID
												CROSS APPLY GetObjectBalance(null, @date, #nr.PersonID, 0, @propertyIDs) [BAL]
											WHERE #nr.PersonID = #NonResidents.PersonID) 
											
	UPDATE #NonResidents SET RecurringCharges = (SELECT SUM(nrli.Amount)
													FROM NonResidentLedgerItem nrli
														INNER JOIN #NonResidents #nr ON nrli.PersonID = #nr.PersonID
														INNER JOIN #PropertiesAndDates #pad ON #nr.PropertyID = #pad.PropertyID
													WHERE nrli.StartDate <= @date
													  AND nrli.EndDate >= @date
													  AND #nr.PersonID = #NonResidents.PersonID
													GROUP BY #nr.PersonID)
													

	SELECT	#nr.PropertyID,
			prop.Name AS 'PropertyName',
			per.PersonID,
			per.PreferredName AS 'FirstName',
			per.LastName,
			CASE
				WHEN (per.Phone1 IS NOT NULL) THEN per.Phone1
				WHEN (per.Phone1 IS NULL AND per.Phone2 IS NOT NULL) THEN per.Phone2
				ELSE per.Phone3
				END AS 'PhoneNumber',
			per.Email,
			#nr.RecurringCharges,
			#nr.Balance
		FROM #NonResidents #nr
			INNER JOIN Property prop ON #nr.PropertyID = prop.PropertyID
			INNER JOIN Person per ON #nr.PersonID = per.PersonID 
		ORDER BY per.LastName

END


GO
