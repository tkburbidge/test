SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_PRTY_GetPhysicalOccupancyHelper] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@byUnitType bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ResidentOccupancy (
		UnitLeaseGroupID uniqueidentifier null,
		Property nvarchar(50) null,
		Unit nvarchar(50) null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null,
		TransferredToNewUnit bit null,
		TransferredFromUnit bit null,
		UnitTypeName nvarchar(50) null,
		UnitTypeID uniqueidentifier null)

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null)

	INSERT #Properties
		SELECT Value FROM @propertyIDs

	INSERT #ResidentOccupancy
		SELECT	DISTINCT
				ulg.UnitLeaseGroupID,
				prop.Abbreviation,
				u.Number,
				[FirstLease].MoveInDate,  
				[LastLease].MoveOutDate,
				[FirstLease].LeaseID,
				CASE
					WHEN ([TransferredToUnit].LeaseID IS NOT NULL) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END AS 'TransferredToUnit',
				CASE
					WHEN (ulg.PreviousUnitLeaseGroupID IS NOT NULL) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END AS 'TransferredFromUnit',
				CASE
					WHEN (@byUnitType = 1) THEN ut.Name
					ELSE 'NoType' END AS 'UnitTypeName',
				CASE
					WHEN (@byUnitType = 1) THEN ut.UnitTypeID
					ELSE null END AS 'UnitTypeID'
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #Properties #pads ON ut.PropertyID = #pads.PropertyID
				INNER JOIN Property prop ON #pads.PropertyID = prop.PropertyID
				LEFT JOIN 
						(SELECT prevULG.UnitLeaseGroupID, prevL.LeaseID, prevULG.PreviousUnitLeaseGroupID
							FROM UnitLeaseGroup prevULG
								INNER JOIN Lease prevL ON prevULG.UnitLeaseGroupID = prevL.UnitLeaseGroupID
							WHERE prevL.LeaseStatus NOT IN ('Cancelled')) [TransferredToUnit] ON ulg.UnitLeaseGroupID = [TransferredToUnit].PreviousUnitLeaseGroupID
				LEFT JOIN
						(SELECT DISTINCT fl.UnitLeaseGroupID, fl.LeaseID, fl.LeaseStartDate, fl.LeaseEndDate,
								(SELECT MIN(MoveInDate)
									FROM PersonLease
									WHERE LeaseID = fl.LeaseID
									  AND ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Pending Renewal', 'Pending Transfer', 'Renewed')) AS 'MoveInDate'
							FROM Lease fl
								INNER JOIN UnitLeaseGroup flULG ON fl.UnitLeaseGroupID = flULG.UnitLeaseGroupID
							WHERE fl.LeaseID = (SELECT TOP 1 LeaseID
													FROM Lease
													WHERE UnitLeaseGroupID = flULG.UnitLeaseGroupID
													  AND LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
													ORDER BY LeaseStartDate, DateCreated)) [FirstLease] ON ulg.UnitLeaseGroupID = [FirstLease].UnitLeaseGroupID
				LEFT JOIN
						(SELECT DISTINCT ll.UnitLeaseGroupID, ll.LeaseStartDate, ll.LeaseEndDate,
								(SELECT MAX(pl.MoveOutDate)
									FROM PersonLease pl
									WHERE pl.LeaseID = ll.LeaseID
									  AND ll.LeaseStatus IN ('Former', 'Evicted')
									  AND pl.ResidencyStatus IN ('Former', 'Evicted')) AS 'MoveOutDate'									   
							FROM Lease ll
								INNER JOIN UnitLeaseGroup flULG ON ll.UnitLeaseGroupID = flULG.UnitLeaseGroupID
							WHERE ll.LeaseID = (SELECT TOP 1 LeaseID
													FROM Lease
													WHERE UnitLeaseGroupID = flULG.UnitLeaseGroupID
													  AND LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
													ORDER BY LeaseStartDate DESC, DateCreated DESC)) [LastLease] ON ulg.UnitLeaseGroupID = [LastLease].UnitLeaseGroupID

			WHERE u.ExcludedFromOccupancy = 0
			  AND u.IsHoldingUnit = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > @endDate)
			  AND [FirstLease].MoveInDate <= @endDate
			  AND ([LastLease].MoveOutDate IS NULL OR [LastLease].MoveOutDate >= @startDate)

	SELECT * FROM #ResidentOccupancy
		ORDER BY Property, Unit

END
GO
