SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Craig Perkins
-- Create date: November 17, 2014
-- Description:	Generates the data for the Controlled Access Information Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_ControlledAccessInformation]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@leaseStatuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		p.Name AS 'PropertyName',
		p.PropertyID,
		u.Number AS 'UnitNumber',
		u.PaddedNumber AS 'PaddedUnitNumber',
		l.LeaseStatus,
		l.LeaseID,
		STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				FROM Person
					INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
					INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				WHERE PersonLease.LeaseID = l.LeaseID
					AND PersonType.[Type] = 'Resident'
					AND PersonLease.MainContact = 1
				FOR XML PATH ('')), 1, 2, '') AS 'Residents',
		pli.Name AS 'Type',
		ai.Number,
		ai.Notes
	FROM AccessItem ai
		INNER JOIN UnitLeaseGroup ulg ON ai.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN PickListItem pli ON ai.AccessItemPickListItemID = pli.PickListItemID
		INNER JOIN Building b ON u.BuildingID = b.BuildingID
		INNER JOIN Property p ON b.PropertyID = p.PropertyID
	WHERE l.LeaseStatus in (SELECT Value FROM @leaseStatuses)
		AND p.PropertyID in (SELECT Value FROM @propertyIDs)
		AND l.LeaseID = (SELECT TOP 1 LeaseID
							FROM Lease
								INNER JOIN Ordering o1 ON o1.[Type] = 'Lease' and LeaseStatus = o1.Value
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
							ORDER BY o1.OrderBy)
	ORDER BY u.PaddedNumber
END
GO
