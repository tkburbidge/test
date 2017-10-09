SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: March 13, 2013
-- Description:	Gets the prospect contact count grouped by day of week
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ContactsByDayOfWeek]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN

	SELECT PropertyID, PropertyName, [DayOfWeek], ContactType, COUNT(*) AS 'Count'
	FROM 
	(SELECT  
		pro.PropertyID,
		pro.Name AS 'PropertyName',
		DATEPART(weekday, pn.[Date]) AS 'DayOfWeek',
		pn.ContactType			
	FROM Prospect p
		INNER JOIN PersonNote pn ON pn.PersonID = p.PersonID	
		INNER JOIN Property pro ON pro.PropertyID = pn.PropertyID
		--INNER JOIN PersonType pt ON pt.PersonID = pn.CreatedByPersonID --AND pt.[Type] = 'Employee'
		LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	WHERE		
		pro.PropertyID IN (SELECT Value FROM @propertyIDs)		
		AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
	    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
		AND pn.[PersonType] = 'Prospect') Contacts
	GROUP BY PropertyID, PropertyName, [DayOfWeek], ContactType

END



GO
