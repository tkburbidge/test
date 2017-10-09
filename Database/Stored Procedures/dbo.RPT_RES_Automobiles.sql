SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Jordan Betteridge
-- Create date: April 6, 2015
-- Description:	Generates the data for the Automobiles Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_Automobiles] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,  
	@propertyIDs GuidCollection READONLY, 
	@residentStatus StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Automobiles (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PersonID uniqueidentifier not null,
		Resident nvarchar(210) not null,
		PersonType nvarchar(20) not null,
		LeaseID uniqueidentifier null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		[Status] nvarchar(25) null,
		Unit nvarchar(20) null,
		PaddedUnit nvarchar(20) null,
		Building nvarchar(15) null,
		LicensePlate nvarchar(12) null,
		PermitNumber nvarchar(25) null,
		Model nvarchar(50) null,
		Make nvarchar(50) null,
		Notes nvarchar(4000) null)
	
	INSERT #Automobiles
		SELECT DISTINCT
			prop.PropertyID,	
			prop.Name AS 'PropertyName',
			p.PersonID,
			p.PreferredName + ' ' + p.LastName AS 'Resident',
			pt.[Type] as 'PersonType',
			l.LeaseID,
			l.LeaseStartDate AS 'LeaseStartDate',
			l.LeaseEndDate AS 'LeaseEndDate',
			pl.ResidencyStatus AS 'Status',
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedUnit',
			b.Name AS 'Building',
			a.LicensePlateNumber AS 'LicensePlate',
			a.PermitNumber AS 'PermitNumber',
			a.Model AS 'Model',
			a.Make AS 'Make',
			a.Notes AS 'Notes'
		FROM Automobile a
			INNER JOIN person p ON a.PersonID = p.PersonID
			INNER JOIN PersonType pt on p.PersonID = pt.PersonID
			INNER JOIN PersonTypeProperty ptp on pt.PersonTypeID = ptp.PersonTypeID
			INNER JOIN Property prop on ptp.PropertyID = prop.PropertyID			
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
		WHERE a.AccountID = @accountID
		  AND prop.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND pl.ResidencyStatus IN (SELECT Value FROM @residentStatus)
		  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								FROM Lease
									INNER JOIN Ordering o1 ON o1.[Type] = 'Lease' and LeaseStatus = o1.Value
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								ORDER BY o1.OrderBy)
		  AND pt.[Type] = 'Resident'	
		
		UNION
		
		SELECT DISTINCT
			prop.PropertyID,	
			prop.Name AS 'PropertyName',
			p.PersonID,
			p.PreferredName + ' ' + p.LastName AS 'Resident',
			pt.[Type] as 'PersonType',
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			a.LicensePlateNumber AS 'LicensePlate',
			a.PermitNumber AS 'PermitNumber',
			a.Model AS 'Model',
			a.Make AS 'Make',
			a.Notes AS 'Notes'
		FROM Automobile a
			INNER JOIN person p ON a.PersonID = p.PersonID
			INNER JOIN PersonType pt on p.PersonID = pt.PersonID
			INNER JOIN PersonTypeProperty ptp on pt.PersonTypeID = ptp.PersonTypeID
			INNER JOIN Property prop on ptp.PropertyID = prop.PropertyID			
		WHERE a.AccountID = @accountID
		  AND prop.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND pt.[Type] = 'Non-Resident Account'
		  AND p.PersonID NOT IN (SELECT PersonID FROM #Automobiles)
		
	SELECT * FROM #Automobiles ORDER BY PaddedUnit, Resident	  
END

GO
