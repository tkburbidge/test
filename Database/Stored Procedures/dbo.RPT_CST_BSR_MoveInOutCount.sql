SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 19, 2015
-- Description:	Gets the data for move ins and outs
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_MoveInOutCount]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date null,
		EndDate date null)
	
	
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	CREATE TABLE #ResidentActivity (
		[Type] nvarchar(100),
		PropertyID uniqueidentifier,
		PropertyName nvarchar(50),
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		UnitID uniqueidentifier,
		Unit nvarchar(50),
		PaddedUnitNumber nvarchar(50),
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,
		Residents nvarchar(1000),
		MarketRent money,
		EffectiveRent money,
		MoveInDate date,
		MoveOutReason nvarchar(100),
		NoticeGiven date,
		MoveOutDate date,
		LeaseEndDate date,
		RequiredDeposit money,
		DepositsPaidIn money,
		DepositsPaidOut money,
		DepositsHeld money,
		ProspectSource nvarchar(100)
	)

	INSERT INTO #ResidentActivity
		SELECT DISTINCT 
				'MoveOut',
				p.PropertyID,	
				p.Name AS 'PropertyName',	
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				0 AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.MoveInDate,
				pl.ReasonForLeaving,
				pl.NoticeGivenDate,
				pl.MoveOutDate,
				l.LeaseEndDate,
				0 AS 'RequiredDeposit',
				0 AS 'DepositsPaidIn',
				0 AS 'DepositsPaidOut',
				0 AS 'DepositHeld',
				null AS 'ProspectSource'				
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
				--Join in PickListItem for the category
				LEFT JOIN PickListItem pli on pli.Name = pl.ReasonForLeaving AND pli.[Type] = 'ReasonForLeaving' AND pli.AccountID = @accountID									
				INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  WHERE pl2.LeaseID = l.LeaseID
										AND pl2.ResidencyStatus IN ('Former', 'Evicted')
									  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)		
			  AND pl.MoveOutDate >= #pad.StartDate
			  AND pl.MoveOutDate <= #pad.EndDate
			  AND pl.ResidencyStatus IN ('Former', 'Evicted')
			  AND l.LeaseStatus IN ('Former', 'Evicted')
			
	

	INSERT INTO #ResidentActivity
		SELECT DISTINCT 	
				'MoveIn' AS 'Type',					
				p.PropertyID,
				p.Name AS 'PropertyName',	
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,			
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				mr.Amount AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.MoveInDate,
				'' AS 'MoveOutReason',
				null AS 'NoticeGiven',
				null AS 'MoveOutDate',
				l.LeaseEndDate,			
				0,
				0 AS 'DepositsPaidIn',
				0 AS 'DepositsPaidOut',
				0,
				null AS 'ProspectSource'				
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																		
				INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
				CROSS APPLY GetMarketRentByDate(u.UnitID, #pad.EndDate, 1) mr
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  WHERE pl2.LeaseID = l.LeaseID
										AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
									  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
			  AND pl.MoveInDate >= #pad.StartDate
			  AND pl.MoveInDate <= #pad.EndDate
			  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
							   ORDER BY LeaseStartDate, DateCreated)

	CREATE TABLE #Occupancy (
		PropertyID uniqueidentifier,
		PropertyName nvarchar(50),
		MoveIns int,
		MoveOuts int,
	)

	INSERT INTO #Occupancy
		SELECT
			p.PropertyID,
			p.Name,
			0 AS 'MoveIns',
			0 AS 'MoveOuts'
		FROM Property p
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE p.AccountID = @accountID

	UPDATE #Occupancy SET MoveIns = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyID = #Occupancy.PropertyID
										AND #ra.[Type] = 'MoveIn')

	UPDATE #Occupancy SET MoveOuts = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyID = #Occupancy.PropertyID
										AND #ra.[Type] = 'MoveOut')

	SELECT * FROM #Occupancy
	
END
GO
