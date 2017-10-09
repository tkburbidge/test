SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_TLC_GetRentersInsuranceInfo] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @accountID bigint
DECLARE @accountingPeriodID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #DataSetToReturn1 (
		PropertyID uniqueidentifier not null,
		PropertyAbbreviation nvarchar(50) null,
		UnitID uniqueidentifier null,
		PaddedUnitNumber nvarchar(50) null,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		Resident nvarchar(100) null,							-- (if multiple residents wil only be MainContact1)
		PersonID uniqueidentifier null,
		Email nvarchar(150) null,
		MobilePhone nvarchar(35) null,
		LeaseStatus nvarchar(50) null,
		MoveInDate date null,
		MoveOutDate date null
		)

	CREATE TABLE #DataSetToReturn2 (
		UnitLeaseGroupID uniqueidentifier null,
		RentersInsuranceID uniqueidentifier null,
		[Provider] nvarchar(500) null,
		[Type] nvarchar(100) null,      
		PolicyNumber nvarchar(200) null,
		StartDate date null,
		ExpirationDate date null,
		HasDocument bit null,									-- (bit is there a document with Document.ObjectID = ulgID and .AltObjectID = rentersInsuranceID
		CancelDate date null
		)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier not null
		)

	CREATE TABLE #AllMyUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		IsHoldingUnit bit not null
		)
		
	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null
		)

	INSERT #PropertyIDs
		SELECT Value FROM @propertyIDs

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertyIDs))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs

	INSERT #DataSetToReturn1
		SELECT	#lau.PropertyID,
				null,
				#lau.UnitID,
				null,
				#lau.UnitNumber,
				#lau.OccupiedUnitLeaseGroupID,
				#lau.OccupiedLastLeaseID,
				null,
				null,
				null,
				null,
				l.LeaseStatus,
				#lau.OccupiedMoveInDate,
				#lau.OccupiedMoveOutDate				
			FROM #LeasesAndUnits #lau
				INNER JOIN Lease l ON #lau.OccupiedLastLeaseID = l.LeaseID
			WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
			  AND #lau.OccupiedIsMovedOut = 0

	INSERT #DataSetToReturn1
		SELECT	#lau.PropertyID,
				null,
				#lau.UnitID,
				null,
				#lau.UnitNumber,
				#lau.PendingUnitLeaseGroupID,
				#lau.PendingLeaseID,
				null,
				null,
				null,
				null,
				l.LeaseStatus,
				#lau.PendingMoveInDate,
				null
			FROM #LeasesAndUnits #lau
				INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
			WHERE #lau.PendingUnitLeaseGroupID IS NULL

	INSERT #AllMyUnits
		SELECT #pIDs.PropertyID, u.UnitID, u.IsHoldingUnit
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertyIDs #pIDs ON ut.PropertyID = #pIDs.PropertyID
			WHERE u.ExcludedFromOccupancy = 0
			  AND ((u.DateRemoved IS NULL) OR (u.DateRemoved > @date))

	INSERT #DataSetToReturn1
		SELECT	#a.PropertyID,
				null,
				#a.UnitID,
				null,
				u.Number,
				null,
				null,
				'Vacant',
				null,
				null,
				null,
				null,
				null,
				null
			FROM #AllMyUnits #a
				INNER JOIN Unit u ON #a.UnitID = u.UnitID
			WHERE #a.UnitID NOT IN (SELECT DISTINCT UnitID FROM #DataSetToReturn1)
	
	INSERT #DataSetToReturn2
		SELECT	#ds1.UnitLeaseGroupID,
				ri.RentersInsuranceID,
				CASE WHEN (ri.ServiceProviderID IS NOT NULL) THEN sp.Name
					 ELSE ri.OtherProvider END,
				CASE WHEN (ri.ServiceProviderID IS NOT NULL) THEN sp.[Type]
					 ELSE ri.RentersInsuranceType END,
				ri.PolicyNumber,
				ri.StartDate,
				ri.ExpirationDate,
				CASE
					WHEN (doc.DocumentID IS NOT NULL) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END,
				ri.CancelDate
			FROM #DataSetToReturn1 #ds1
				INNER JOIN RentersInsurance ri ON #ds1.UnitLeaseGroupID = ri.UnitLeaseGroupID
				LEFT JOIN ServiceProvider sp ON ri.ServiceProviderID = sp.ServiceProviderID
				LEFT JOIN [Document] doc ON #ds1.UnitLeaseGroupID = doc.ObjectID AND ri.RentersInsuranceID = doc.AltObjectID

	UPDATE #ds1 SET
		Resident = per.PreferredName + ' ' + per.LastName,
		PersonID = per.PersonID,
		Email = per.Email,
		MobilePhone = CASE WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
						   WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
						   WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
						   ELSE null END
		FROM #DataSetToReturn1 #ds1
			INNER JOIN PersonLease pl ON #ds1.LeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
		WHERE #ds1.Resident IS NULL
		  AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID 
									  FROM PersonLease
									  WHERE LeaseID = #ds1.LeaseID
									  ORDER BY OrderBy)

	SELECT	#ds1.PropertyID,
			p.Abbreviation AS 'PropertyAbbreviation',
			#ds1.UnitID,
			u.PaddedNumber AS 'PaddedUnitNumber',
			#ds1.UnitNumber,
			#ds1.UnitLeaseGroupID,
			#ds1.LeaseID,
			#ds1.Resident,
			#ds1.PersonID,
			#ds1.Email,
			#ds1.MobilePhone,
			#ds1.LeaseStatus,
			#ds1.MoveInDate,
			#ds1.MoveOutDate
		FROM #DataSetToReturn1 #ds1
			INNER JOIN Property p ON #ds1.PropertyID = p.PropertyID
			INNER JOIN Unit u ON #ds1.UnitID = u.UnitID

	SELECT DISTINCT * 
		FROM #DataSetToReturn2

END
GO
