SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: March 13, 2013
-- Description:	Gets the prospect count based on unit type interest
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_UnitTypeInterest]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN

	SELECT PropertyID, PropertyName, UnitTypeID, UnitTypeName, UnitTypeDescription, COUNT(*) AS 'Count'
	FROM 
	(SELECT  
		pro.PropertyID,
		pro.Name AS 'PropertyName',
		put.UnitTypeID,
		ut.Name AS 'UnitTypeName',
		ut.[Description] AS 'UnitTypeDescription'
	FROM Prospect p
		INNER JOIN PersonNote pn ON pn.PersonID = p.PersonID
		INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID			
		INNER JOIN Property pro ON pro.PropertyID = pps.PropertyID
		INNER JOIN ProspectUnitType put ON put.ProspectID = p.ProspectID
		INNER JOIN UnitType ut ON ut.UnitTypeID = put.UnitTypeID
		LEFT JOIN PropertyAccountingPeriod pap ON pro.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	WHERE		

		pps.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))

		  OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
		AND pn.[PersonType] = 'Prospect'
		-- Get the first contact note
		AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
								 FROM PersonNote pn2 
								 WHERE pn2.PersonID = pn.PersonID
									   AND pn2.PersonType = 'Prospect'
								 ORDER BY [Date])
								 ) Prospects
	GROUP BY PropertyID, PropertyName, UnitTypeID, UnitTypeName, UnitTypeDescription

END



GO
