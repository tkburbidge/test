SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [dbo].[GetFormLetterRecipients] 
@accountID bigint = null,
@propertyID uniqueidentifier = null,
@parameters IntegrationSQLCollection READONLY

AS
DECLARE @SQLBase nvarchar(MAX)
DECLARE @indatusCompanyID nvarchar(50)
DECLARE @indatusPropertyID nvarchar(50)
DECLARE @indatusListCode nvarchar(50)

BEGIN

	SET @SQLBase = 'SELECT 
						l.LeaseID AS ''LeaseID'',
						u.Number AS ''Unit'',						
						STUFF((SELECT '', '' + (PreferredName + '' '' + LastName)
									 FROM Person 
										 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
										 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
										 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
									 WHERE PersonLease.LeaseID = l.LeaseID
										   AND PersonType.[Type] = ''Resident''				   
										   AND PersonLease.MainContact = 1				   
									 FOR XML PATH ('''')), 1, 2, '''') AS ''Names'',
						l.LeaseStartDate AS ''LeaseStart'',
						l.LeaseEndDate AS ''LeaseEnd''
				FROM Unit u
					INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON b.PropertyID = p.PropertyID
					INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID 
								AND l.LeaseID = (SELECT TOP 1 LeaseID
													FROM Lease l1
														INNER JOIN Ordering o ON o.[Type] = ''Lease'' AND o.Value = l1.LeaseStatus
													WHERE l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
									ORDER BY o.OrderBy)'
		
	EXEC SubstituteManualIntegrationSQLParameters @accountID, @propertyID, null, @parameters, @SQLBase OUTPUT

	SET @SQLBase = @SQLBase + ' ORDER BY u.PaddedNumber, Names '		
		
	EXECUTE sp_executesql @SQLBase

END
GO
