SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 4/20/2015
-- Description:	Get Resident Utility information for the Utilities Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_Utilities] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyIDs GuidCollection READONLY,
	@utilityTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT
		p.PropertyID,
		p.Name AS 'PropertyName',
		u.Number AS 'UnitNumber',
		u.PaddedNumber AS 'PaddedUnitNumber',
		l.LeaseID,
		STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'Residents',
		l.LeaseStartDate,
		l.LeaseEndDate,
		util.UtilityType AS 'UtilityType',
		sp.Name AS 'Company',
		util.AccountNumber AS 'AccountNumber',
		util.Notes AS 'Notes',
		util.StartDate AS 'StartDate'
	FROM Utility util
		INNER JOIN UnitLeaseGroup ulg ON util.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN Lease l on ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u on ulg.UnitID = u.UnitID
		INNER JOIN Building b on u.BuildingID = b.BuildingID
		INNER JOIN Property p on b.PropertyID = p.PropertyID
		LEFT JOIN ServiceProvider sp on util.ServiceProviderID = sp.ServiceProviderID
	WHERE util.AccountID = @accountID
	  AND b.PropertyID IN (SELECT Value FROM @propertyIDs)
	  AND util.UtilityType IN (SELECT Value FROM @utilityTypes)
	  AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
	  --AND sp.[Type] = 'Utility'
	ORDER BY u.PaddedNumber
    
END
GO
