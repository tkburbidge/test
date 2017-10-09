SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: October 30, 2013
-- Description:	Gets prospect visits
-- =============================================
CREATE PROCEDURE [dbo].[API_GetProspectVisits] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
		p.PersonID,
		pros.ProspectID,
		pps.PropertyID AS 'PropertyID',
		--prop.Name AS 'PropertyName',		
		p.FirstName,
		p.LastName,
		p.Email AS 'Email',
		a.FirstName AS 'AgentFirstName',
		a.LastName AS 'AgentLastName',
		pn.[Date] AS 'VisitDate',
		p.Birthdate,
		COALESCE(p.IsMale, CAST(1 AS BIT)) AS 'IsMale',
		ps.Name AS 'ProspectSource'
	FROM Prospect pros
		INNER JOIN Person p ON p.PersonID = pros.PersonID
		INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
		INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
		INNER JOIN PersonNote pn ON pn.PersonID = pros.PersonID
		--INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypePropertyID = pn.CreatedByPersonTypePropertyID
		--INNER JOIN Property prop ON pn.PropertyID = prop.PropertyID
		--INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
		INNER JOIN Person a ON pn.CreatedByPersonID = a.PersonID
	WHERE
		pros.AccountID = @accountID
		AND pps.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID
							   FROM PersonNote
							   WHERE PersonID = pros.PersonID
								AND PersonType = 'Prospect'
								AND ContactType = 'Face-to-Face'
							  ORDER BY [Date])
		AND pn.[Date] >= @startDate
		AND pn.[Date] <= @endDate
		
END
GO
