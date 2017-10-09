SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 24, 2016
-- Description:	Gets a list of Residents and how we contact/notify them!
-- =============================================
CREATE PROCEDURE [dbo].[GetListResidentRecipients] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@buildingIDs GuidCollection READONLY,
	@unitIDs GuidCollection READONLY,
	@floors StringCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@residencyStatuses StringCollection READONLY,
	@pets StringCollection READONLY,
	@ageMin int = null,
	@ageMax int = null,
	@balanceMin money = null,
	@balanceMax money = null,
	@leaseStartMin date = null,
	@leaseStartMax date = null,
	@leaseEndMin date = null,
	@leaseEndMax date = null,
	@moveInMin date = null,
	@moveInMax date = null,
	@moveOutMin date = null,
	@moveOutMax date = null,
	@mainContactsOnly bit = 0,
	@excludePeopleWithoutEmails bit = 0,
	@notificationTypeID int = null

AS

DECLARE @buildingCount int = 0
DECLARE @unitCount int = 0
DECLARE @floorCount int = 0
DECLARE @leaseStatusCount int = 0
DECLARE @residencyStatusCount int = 0
DECLARE @petCount int = 0
DECLARE @minBirthday date
DECLARE @maxBirthday date
DECLARE @ntv bit = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #Recipients (
		PersonID uniqueidentifier null,
		Name nvarchar(4000) null,
		[Floor] nvarchar(20) null,
		LStatus nvarchar(50) null,
		Birthdate date null,
		SSN nvarchar(100) null,
		Email nvarchar(250) null,
		Url nvarchar(250) null,
		PropertyID uniqueidentifier not null,
		PaddedNumber nvarchar(50) null,
		PersonType nvarchar(100) null,
		LeaseID uniqueidentifier not null,
		Unit nvarchar(50) null,
		FirstName nvarchar(50) null,
		LastName nvarchar(50) null,
		StreetAddress nvarchar(500) null,
		City nvarchar(50) null,
		[State] nvarchar(50) null,
		Zip nvarchar(50) null,
		Country nvarchar(50) null,
		SendEmail bit null,
		SendText bit null,
		ExcludedReason nvarchar(500) null,
		InformationType nvarchar(500) null,
		Phone1 nvarchar(50) null,
		Phone1Type nvarchar(50) null,
		Phone2 nvarchar(50) null,
		Phone2Type nvarchar(50) null,
		Phone3 nvarchar(50) null,
		Phone3Type nvarchar(50) null,
		MobilePhone nvarchar(50) null,
		[Address] nvarchar(500) null,
		UnitLeaseGroupID uniqueidentifier null,
		ReturnMe bit not null)

	CREATE TABLE #Leases (
		PropertyID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(100),
		LeaseStatus nvarchar(50) null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		PaddedNumber nvarchar(50) null,
		PersonLeaseID uniqueidentifier)

	CREATE TABLE #PersonLeases (
		PersonLeaseID uniqueidentifier,
		PropertyID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(100),
		[Floor] nvarchar(100),
		Building nvarchar(100),
		LeaseStatus nvarchar(50) null,
		ResidencyStatus nvarchar(100),
		LeaseStartDate date null,
		LeaseEndDate date null,
		PaddedNumber nvarchar(50) null,
		MoveOutDate date null)

	CREATE TABLE #ResdentBalances (
		ObjectID uniqueidentifier null,
		Balance money null)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier not null)

	CREATE TABLE #BuildingIDs (
		BuildingID uniqueidentifier null)

	CREATE TABLE #UnitIDs (
		UnitID uniqueidentifier null)

	CREATE TABLE #Floors (
		FloorNumber nvarchar(100) null)

	CREATE TABLE #LeaseStatuseses (
		LeaseStatus nvarchar(50) null)

	CREATE TABLE #ResidencyStatuses (
		ResidencyStatus nvarchar(50) null)

	CREATE TABLE #Pets (
		Pets nvarchar(50) null)

	INSERT #PropertyIDs
		SELECT Value FROM @propertyIDs

	INSERT #BuildingIDs
		SELECT Value FROM @buildingIDs

	INSERT #UnitIDs
		SELECT Value FROM @unitIDs

	INSERT #Floors
		SELECT Value FROM @floors

	INSERT #LeaseStatuseses
		SELECT Value FROM @leaseStatuses

	INSERT #ResidencyStatuses
		SELECT Value FROM @residencyStatuses

	INSERT #Pets
		SELECT Value FROM @pets

	SET @buildingCount = (SELECT COUNT(*) FROM #BuildingIDs)
	SET @unitCount = (SELECT COUNT(*) FROM #UnitIDs)
	SET @floorCount = (SELECT COUNT(*) FROM #Floors)
	SET @leaseStatusCount = (SELECT COUNT(*) FROM #LeaseStatuseses)
	SET @residencyStatusCount = (SELECT COUNT(*) FROM #ResidencyStatuses)
	SET @petCount = (SELECT COUNT(*) FROM #Pets)
	SET @ntv = (SELECT COUNT(*) FROM #ResidencyStatuses WHERE ResidencyStatus = 'Current (NTV)')

	IF (@ageMax IS NOT NULL)
	BEGIN
		SET @minBirthday = DATEADD(YEAR, -@ageMax, GETDATE())
	END
	IF (@ageMin IS NOT NULL)
	BEGIN
		SET @maxBirthday = DATEADD(YEAR, -@ageMin, GETDATE())
	END

	INSERT #PersonLeases
		SELECT  pl.PersonLeaseID, #pids.PropertyID, l.LeaseID, ulg.UnitLeaseGroupID, u.UnitID, u.Number, u.[Floor], b.Name, l.LeaseStatus, pl.ResidencyStatus, l.LeaseStartDate, l.LeaseEndDate, u.PaddedNumber, pl.MoveOutDate
			FROM PersonLease pl
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids ON ut.PropertyID = #pids.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  INNER JOIN Lease l2 ON l2.LeaseID = pl2.LeaseID
									  INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
									  WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										AND pl2.PersonID = pl.PersonID
									  ORDER BY o.OrderBy)

	IF (@ntv = 1)
	BEGIN
		UPDATE #PersonLeases
			SET ResidencyStatus = 'Current (NTV)'
		WHERE ResidencyStatus IN ('Current', 'Under Eviction')
			AND MoveOutDate IS NOT NULL
	END

	IF ((SELECT COUNT(*) FROM #LeaseStatuseses) > 0)
	BEGIN
		DELETE FROM #PersonLeases WHERE LeaseStatus NOT IN (SELECT LeaseStatus FROM #LeaseStatuseses)
	END
	IF ((SELECT COUNT(*) FROM #ResidencyStatuses) > 0)
	BEGIN
		DELETE FROM #PersonLeases WHERE ResidencyStatus NOT IN (SELECT ResidencyStatus FROM #ResidencyStatuses)
	END

	INSERT #Recipients
		SELECT	DISTINCT
				per.PersonID,
				per.PreferredName + ' ' + per.LastName,
				#l.[Floor],
				#l.LeaseStatus,
				per.Birthdate,
				per.SSN,
				per.Email,
				null AS 'Url',
				#l.PropertyID,
				#l.PaddedNumber,
				'Resident' AS 'PersonType',
				#l.LeaseID AS 'LeaseID',	
				#l.UnitNumber AS 'Unit',
				per.PreferredName AS 'FirstName',
				per.LastName AS 'LastName',
				addr.StreetAddress,
				addr.City,
				addr.[State],
				addr.Zip,
				addr.Country,
				CASE 
					WHEN (npg.IsEmailSubscribed = 0) THEN CAST(0 AS bit)
					ELSE CAST(1 AS bit) END AS 'SendEmail',
				CASE
					WHEN (npg.IsSMSSubscribed = 0) THEN CAST(0 AS bit)
					ELSE CAST(1 AS bit) END AS 'SendText',
				null AS 'ExcludedReason',
				null AS 'InformationType',
				per.Phone1,
				per.Phone1Type,
				per.Phone2,
				per.Phone2Type,
				per.Phone3,
				per.Phone3Type,
				CASE
					WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
					WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
					WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3 END AS 'MobilePhone',
				addr.StreetAddress + ', ' + addr.City + ', ' + addr.[State] + ' ' + addr.Zip AS 'Address',
				#l.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				0 AS 'ReturnMe'
			FROM Person per
				INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
				INNER JOIN #PersonLeases #l ON #l.PersonLeaseID = pl.PersonLeaseID
				LEFT JOIN [Address] addr ON (per.PersonID = addr.ObjectID AND addr.IsDefaultMailingAddress = 1) OR #l.UnitLeaseGroupID = addr.ObjectID
				LEFT JOIN NotificationPersonGroup npg ON per.PersonID = npg.ObjectID AND npg.NotificationID = @notificationTypeID
				LEFT JOIN
						(SELECT ulg1.UnitLeaseGroupID, u1.UnitID, u1.[Floor]
							FROM UnitLeaseGroup ulg1
								INNER JOIN Unit u1 ON ulg1.UnitID = u1.UnitID
								INNER JOIN #Floors #f1 ON u1.[Floor] = #f1.FloorNumber) [FloorRestriction] ON #l.UnitID = [FloorRestriction].UnitID
				LEFT JOIN 
						(SELECT ulg2.UnitLeaseGroupID, u2.UnitID, u2.BuildingID
							FROM UnitLeaseGroup ulg2
								INNER JOIN Unit u2 ON ulg2.UnitID = u2.UnitID
								INNER JOIN #BuildingIDs #b2 ON u2.BuildingID = #b2.BuildingID) [MyBuilding] ON #l.UnitID = [MyBuilding].UnitID
				LEFT JOIN 
						(SELECT ulg3.UnitLeaseGroupID, u3.UnitID, u3.BuildingID
							FROM UnitLeaseGroup ulg3
								INNER JOIN Unit u3 ON ulg3.UnitID = u3.UnitID
								INNER JOIN #UnitIDs #u3 ON u3.UnitID = #u3.UnitID) [MyUnit] ON #l.UnitID = [MyUnit].UnitID
				LEFT JOIN
						(SELECT ulg5.UnitLeaseGroupID, l5.LeaseID, pl5.PersonLeaseID, pl5.PersonID, pet5.PetID
							FROM UnitLeaseGroup ulg5
								INNER JOIN Lease l5 ON ulg5.UnitLeaseGroupID = l5.UnitLeaseGroupID
								INNER JOIN PersonLease pl5 ON l5.LeaseID = pl5.LeaseID
								INNER JOIN Pet pet5 ON pl5.PersonID = pet5.PersonID
								INNER JOIN #Pets #pet5 ON pet5.[Type] = #pet5.Pets) [MyPets] ON #l.LeaseID = [MyPets].LeaseID AND pl.PersonID = [MyPets].PersonID
			WHERE 
				((@leaseStartMin IS NULL) OR (#l.LeaseStartDate >= @leaseStartMin))
			  AND ((@leaseStartMax IS NULL) OR (#l.LeaseStartDate <= @leaseStartMax))
			  AND ((@leaseEndMin IS NULL) OR (#l.LeaseEndDate >= @leaseEndMin))
			  AND ((@leaseEndMax IS NULL) OR (#l.LeaseEndDate <= @leaseEndMax))
			  AND ((@floorCount = 0) OR ([FloorRestriction].UnitLeaseGroupID IS NOT NULL))
			  AND ((@buildingCount = 0) OR ([MyBuilding].UnitLeaseGroupID IS NOT NULL))
			  AND ((@unitCount = 0) OR ([MyUnit].UnitLeaseGroupID IS NOT NULL))
			  AND ((@petCount = 0) OR ([MyPets].UnitLeaseGroupID IS NOT NULL))
			  AND ((@mainContactsOnly = 0) OR (pl.MainContact = 1))
			  AND ((@moveInMin IS NULL) OR (pl.MoveInDate >= @moveInMin))
			  AND ((@moveInMax IS NULL) OR (pl.MoveInDate <= @moveInMax))
			  AND ((@moveOutMin IS NULL) OR (pl.MoveOutDate >= @moveOutMin))
			  AND ((@moveOutMax IS NULL) OR (pl.MoveOutDate <= @moveOutMax))
			  AND ((@ageMax IS NULL) OR (per.Birthdate >= @minBirthday))
			  AND ((@ageMin IS NULL) OR (per.Birthdate <= @maxBirthday))
			  AND ((@excludePeopleWithoutEmails = 0) OR (per.Email IS NOT NULL))
 			
	IF (@balanceMin IS NOT NULL OR @balanceMax IS NOT NULL)
	BEGIN
		INSERT #ResdentBalances
			SELECT DISTINCT #rec.UnitLeaseGroupID, [Bal].Balance
				FROM #Recipients #rec
					CROSS APPLY dbo.GetObjectBalance('1900-1-1', GETDATE(), #rec.UnitLeaseGroupID, 0, @propertyIDs) [Bal]
	END
	
	SELECT	#rec.PersonID,
			#rec.Name,
			#rec.Birthdate,
			#rec.SSN,
			#rec.Email,
			#rec.PropertyID,
			#rec.PersonType,
			#rec.LeaseID AS 'ObjectID',
			#rec.Unit,
			#rec.FirstName,
			#rec.LastName,
			#rec.StreetAddress,
			#rec.City,
			#rec.[State],
			#rec.Zip,
			#rec.Country,
			#rec.SendEmail,
			#rec.SendText,
			#rec.Phone1,
			#rec.Phone1Type,
			#rec.Phone2,
			#rec.Phone2Type,
			#rec.Phone3,
			#rec.Phone3Type,
			#rec.MobilePhone,
			#rec.[Address],
			#rec.UnitLeaseGroupID
		FROM #Recipients #rec
			LEFT JOIN #ResdentBalances #rb ON #rec.UnitLeaseGroupID = #rb.ObjectID
		WHERE (@balanceMax IS NULL OR #rb.Balance <= @balanceMax)
			AND (@balanceMin IS NULL OR #rb.Balance >= @balanceMin)
		ORDER BY PropertyID, PaddedNumber, FirstName, LastName

END
GO
