SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetEmailTemplateRecipients] 
	@accountID bigint = null,
	@propertyID uniqueidentifier = null,
	@parameters IntegrationSQLCollection READONLY
AS
--DECLARE @propertyID uniqueidentifier
DECLARE @SQLBase nvarchar(MAX)

BEGIN
	
	SET @SQLBase = 'SELECT DISTINCT			
			u.Number AS ''Unit'',
			l.LeaseID,
			ulg.UnitLeaseGroupID AS ''UnitLeaseGroupID'',
			per.FirstName AS ''FirstName'',
			per.LastName AS ''LastName'',
			per.Email AS ''Email'',
			l.LeaseEndDate,
			l.LeaseStartDate,
			per.PersonID
	FROM Unit u
		INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON u.BuildingID = b.BuildingID
		INNER JOIN Property p ON b.PropertyID = p.PropertyID
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID  AND l.LeaseID = (SELECT TOP 1 LeaseID
																							FROM Lease l1
																								INNER JOIN Ordering o ON o.[Type] = ''Lease'' AND o.Value = l1.LeaseStatus
																							WHERE l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																							ORDER BY o.OrderBy)
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MainContact = 1 AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
																											  FROM PersonLease pl2
																											  INNER JOIN Ordering o ON o.[Type] = ''ResidencyStatus'' AND Value = pl2.ResidencyStatus
																											  WHERE pl2.PersonID = pl.PersonID
																											  ORDER BY o.OrderBy)
		INNER JOIN Person per ON pl.PersonID = per.PersonID AND per.Email <> '''' AND per.Email IS NOT NULL'
		
	EXEC SubstituteManualIntegrationSQLParameters @accountID, @propertyID, NULL, @parameters, @SQLBase OUTPUT
	
	--SELECT @SQLBase
		
	EXECUTE sp_executesql @SQLBase

END
GO
