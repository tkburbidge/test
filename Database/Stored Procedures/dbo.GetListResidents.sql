SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 14, 2016
-- Description:	Gets a pages list of residents
-- =============================================
CREATE PROCEDURE [dbo].[GetListResidents]	
	@propertyIDs GuidCollection READONLY,
	@residencyStati StringCollection READONLY,
	@householdStati StringCollection READONLY,
	@letter char(1),
	@pageSize int,
	@page int,	
	@totalCount int OUTPUT,
	@sortBy nvarchar(50) = null,
	@sortOrderIsAsc bit = null,
	@waitListLotteryIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Residents
	(
		PersonID uniqueidentifier not null,
		Name nvarchar(200) null,
		ResidencyStatus nvarchar(50) null,
		PropertyAbbreviation nvarchar(20) null,
		PhoneNumber nvarchar(50) null,
		LeaseEndDate date null,
		LeaseID uniqueidentifier null,
		LeaseStartDate date null, 
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PropertyID uniqueidentifier null,
		PropertyName nvarchar(50) null,
		MoveOutDate date null,
		Email nvarchar(150) null,
		PaddedUnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		PhoneType nvarchar(50) null,
		ApplicationDate date not null,
	)

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null,
		Abbreviation nvarchar(50) null,
		Name nvarchar(100) null)

	CREATE TABLE #Stati (
		ResidencyStatus nvarchar(50) NULL)

	CREATE TABLE #HouseholdStati(
		HouseHoldStatud NVARCHAR(50) NULL)

	CREATE TABLE #LotteryIDs (
		WaitListLotteryID uniqueidentifier not null
	)

	INSERT INTO #Properties
		SELECT pIDs.Value, p.Abbreviation, p.Name
			FROM @propertyIDs pIDs
				INNER JOIN Property p ON pIDs.Value = p.PropertyID

	INSERT INTO #Stati
		SELECT Value FROM @residencyStati

	INSERT INTO #HouseholdStati
		SELECT Value FROM @householdStati

	INSERT INTO #LotteryIDs
		SELECT Value FROM @waitListLotteryIDs

	
	INSERT INTO #Residents
		SELECT	per.PersonID,
				per.LastName + ', ' + per.PreferredName AS 'Name',
				pl.ResidencyStatus,
				#props.Abbreviation,
				per.Phone1,
				l.LeaseEndDate,
				l.LeaseID,
				l.LeaseStartDate,
				u.UnitID,
				u.Number,
				#props.PropertyID,
				#props.Name,
				pl.MoveOutDate,
				per.Email,
				u.PaddedNumber,
				ulg.UnitLeaseGroupID,
				per.Phone1Type,
				pl.ApplicationDate
			FROM Person per
				INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #Properties #props ON ut.PropertyID = #props.PropertyID
				LEFT JOIN AffordablePerson ap ON per.PersonID = ap.PersonID
				LEFT JOIN WaitListLottery wll ON ap.WaitListLotteryID = wll.WaitListLotteryID
			WHERE (@letter IS NULL OR @letter = '' OR per.LastName like (@letter + '%'))
			  AND (
					(pl.ResidencyStatus IN (SELECT * FROM #Stati))
					OR (('Current (NTV)' IN (SELECT * FROM #Stati)) AND pl.MoveOutDate IS NOT NULL AND (pl.ResidencyStatus IN ('Current', 'Under Eviction'))
				  ))
			  AND l.LeaseID = (SELECT TOP 1 lSorter.LeaseID
									FROM Lease lSorter
										INNER JOIN [Ordering] ordl ON ordl.[Type] = 'Lease' AND lSorter.LeaseStatus = ordl.Value 
									WHERE lSorter.LeaseID = l.LeaseID
									ORDER BY ordl.OrderBy)
			  AND pl.PersonLeaseID = (SELECT TOP 1 plSorter.PersonLeaseID
										  FROM PersonLease plSorter
											  INNER JOIN [Ordering] ordpl ON ordpl.[Type] = 'ResidencyStatus' AND plSorter.ResidencyStatus = ordpl.Value
										  WHERE plSorter.PersonID = per.PersonID
										  ORDER BY ordpl.OrderBy)
			  AND ((pl.HouseholdStatus IN (SELECT * FROM #HouseholdStati)) OR ((SELECT COUNT(*) FROM #HouseholdStati) = 0))
			  AND (((SELECT COUNT(*) FROM #LotteryIDs) = 0) OR wll.WaitListLotteryID IN (SELECT * FROM #LotteryIDs))

				
	CREATE TABLE #Residents2
	(
		id int identity,
		PersonID uniqueidentifier not null,
		Name nvarchar(200) null,
		[Status] nvarchar(50) null,		-- Residency Status
		PropertyAbbreviation nvarchar(20) null,
		PhoneNumber nvarchar(50) null,
		LeaseEndDate date null,
		LeaseID uniqueidentifier null,
		LeaseStartDate date null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PropertyID uniqueidentifier null,
		PropertyName nvarchar(50) null,
		MoveOutDate date null,
		Email nvarchar(150) null,
		PaddedUnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		PhoneType nvarchar(50) null,
		ApplicationDate date not null,
	)
	INSERT INTO #Residents2 
		SELECT * 
		FROM #Residents
		ORDER BY
			CASE WHEN @sortBy = 'Unit' and @sortOrderIsAsc = 1  THEN [PaddedUnitNumber] END ASC,
			CASE WHEN @sortBy = 'Unit' and @sortOrderIsAsc = 0  THEN [PaddedUnitNumber] END DESC,
			CASE WHEN @sortBy = 'Abbreviation' and @sortOrderIsAsc = 1  THEN [PropertyAbbreviation] END ASC,
			CASE WHEN @sortBy = 'Abbreviation' and @sortOrderIsAsc = 0  THEN [PropertyAbbreviation] END DESC,
			CASE WHEN @sortBy = 'PhoneNumber' and @sortOrderIsAsc = 1  THEN [PhoneNumber] END ASC,
			CASE WHEN @sortBy = 'PhoneNumber' and @sortOrderIsAsc = 0  THEN [PhoneNumber] END DESC,
			CASE WHEN @sortBy = 'Email' and @sortOrderIsAsc = 1  THEN [Email] END ASC,
			CASE WHEN @sortBy = 'Email' and @sortOrderIsAsc = 0  THEN [Email] END DESC,
			CASE WHEN @sortBy = 'Status' and @sortOrderIsAsc = 1  THEN [ResidencyStatus] END ASC,
			CASE WHEN @sortBy = 'Status' and @sortOrderIsAsc = 0  THEN [ResidencyStatus] END DESC,
			CASE WHEN @sortBy = 'LeaseDates' and @sortOrderIsAsc = 1  THEN [LeaseStartDate] END ASC,
			CASE WHEN @sortBy = 'LeaseDates' and @sortOrderIsAsc = 0  THEN [LeaseStartDate] END DESC,
			CASE WHEN @sortBy = 'ApplicationDate' and @sortOrderIsAsc = 1 THEN ApplicationDate END ASC,
			CASE WHEN @sortBy = 'ApplicationDate' and @sortOrderIsAsc = 0 THEN ApplicationDate END DESC,
			CASE WHEN (@sortBy is NULL OR @sortBy = '' OR @sortBy = 'Name') and @sortOrderIsAsc = 1  THEN [Name] END ASC,
			CASE WHEN (@sortBy is NULL OR @sortBy = '' OR @sortBy = 'Name') and @sortOrderIsAsc = 0  THEN [Name] END DESC

	SET @totalCount = (SELECT COUNT(*) FROM #Residents2)

	SELECT TOP (@pageSize) * FROM 
	(SELECT *, row_number() OVER (ORDER BY id) AS [rownumber] 
	 FROM #Residents2) AS PagedProspects	 
	WHERE PagedProspects.rownumber > (((@page - 1) * @pageSize))
	
END



IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AFF_GetSetAsideCompliance]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[AFF_GetSetAsideCompliance] AS' 
END
GO
