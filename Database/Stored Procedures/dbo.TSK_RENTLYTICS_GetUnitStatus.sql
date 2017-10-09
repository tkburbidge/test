SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 27, 2016
-- Description:	Rentlytics Integration Unit Status Query
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GetUnitStatus]
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #UnitStatus (
		property_code nvarchar(100) null,
		unit_code nvarchar(100) null,
		[status] nvarchar(25) null,
		resident_code nvarchar(50) null,
		resident_email nvarchar(500) null,
		resident_status nvarchar(50) null,
		market_rent money null,
		market_deposit money null,
		lease_sign date null,
		lease_from date null,
		lease_to date null,
		move_in date null,
		move_out date null,
		notice_given date null,
		make_ready_status nvarchar(50) null,
		days_vacant int null,
		future_rented_status nvarchar(50) null,
		UnitID uniqueidentifier null,
		LeaseID uniqueidentifier null)

	CREATE TABLE #MarketRentAndOtherInfo (
		UnitID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		MarketRent money null,
		Deposit money null,
		UnitStatus nvarchar(50) null)

	CREATE TABLE #LeasesAndUnits (
        PropertyID uniqueidentifier,
        UnitID uniqueidentifier,
        UnitNumber nvarchar(50) null,        
        OccupiedUnitLeaseGroupID uniqueidentifier, 
        OccupiedLastLeaseID uniqueidentifier,
        OccupiedMoveInDate date,
        OccupiedNTVDate date,
        OccupiedMoveOutDate date,
        OccupiedIsMovedOut bit,
        PendingUnitLeaseGroupID uniqueidentifier,
        PendingLeaseID uniqueidentifier,
        PendingApplicationDate date,
        PendingMoveInDate date)

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
        
    INSERT #LeasesAndUnits
        EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

	INSERT #UnitStatus
		SELECT	DISTINCT
				p.Abbreviation,
				#lau.UnitNumber,
				CASE
					WHEN (#lau.OccupiedLastLeaseID IS NOT NULL AND #lau.OccupiedNTVDate IS NOT NULL) THEN 'Occupied NTV'
					WHEN (#lau.OccupiedLastLeaseID IS NOT NULL) THEN 'Occupied'
					ELSE null END AS 'status',
				null,		-- AS 'resident_code'
				null,		-- AS 'resident_email'
				'Current',	-- AS 'resident_status'
				null,		-- AS 'market_rent'
				null,		-- AS 'market_deposit
				null,		-- AS 'lease_sign'
				null,		-- AS 'lease_from'
				null,		-- AS 'lease_to'
				#lau.OccupiedMoveInDate,
				#lau.OccupiedMoveOutDate,
				#lau.OccupiedNTVDate,
				null,		-- AS 'make_ready_status'
				null,		-- AS 'days_vacant'
				CASE 
					WHEN (#lau.PendingUnitLeaseGroupID IS NULL AND #lau.OccupiedUnitLeaseGroupID IS NULL) THEN 'Unrented'
					ELSE 'Rented' END AS 'future_rented_status',
				#lau.UnitID,
				#lau.OccupiedLastLeaseID
			FROM #LeasesAndUnits #lau
				INNER JOIN Property p ON #lau.PropertyID = p.PropertyID
				INNER JOIN Unit u ON #lau.UnitID = u.UnitID

	INSERT #UnitStatus
		SELECT	#us.property_code,
				#us.unit_code,
				'Occupied',
				null,
				null,
				'Future',
				null,
				null,
				null,
				null,
				null,
				null,
				#lau.PendingMoveInDate,
				null,
				null,
				null,
				'Rented',
				#us.UnitID,
				l.LeaseID
			FROM #UnitStatus #us
				INNER JOIN UnitLeaseGroup ulg ON #us.UnitID = ulg.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending', 'Pending Transfer')
				INNER JOIN #LeasesAndUnits #lau ON #us.UnitID = #lau.UnitID
			
		
	INSERT #MarketRentAndOtherInfo
		SELECT	#lau.UnitID,
				#lau.OccupiedUnitLeaseGroupID,
				#lau.OccupiedLastLeaseID,
				[MarketRent].Amount,
				[ReqDeposit].RequiredDeposit,
				[UnitStatus].[Status]
			FROM #LeasesAndUnits #lau
				CROSS APPLY dbo.GetMarketRentByDate(#lau.UnitID, @date, 1) [MarketRent]
				CROSS APPLY dbo.GetUnitStatusByUnitID(#lau.UnitID, @date) [UnitStatus]
				CROSS APPLY dbo.GetRequiredDepositAmount(#lau.UnitID, @date) [ReqDeposit]	
	
	UPDATE #us SET market_rent = #mraoi.MarketRent, market_deposit = #mraoi.Deposit--, [status] = #mraoi.UnitStatus
		FROM #UnitStatus #us
			INNER JOIN #MarketRentAndOtherInfo #mraoi ON #us.UnitID = #mraoi.UnitID

	UPDATE #us SET lease_from = l.LeaseStartDate, lease_to = l.LeaseEndDate
		FROM #UnitStatus #us
			INNER JOIN Lease l ON #us.LeaseID = l.LeaseID

	UPDATE #us SET make_ready_status = #mraoi.UnitStatus
		FROM #UnitStatus #us
			INNER JOIN #LeasesAndUnits #lau ON #us.UnitID = #lau.UnitID
			INNER JOIN #MarketRentAndOtherInfo #mraoi ON #us.UnitID = #mraoi.UnitID





	SELECT	#us.property_code,
			#us.unit_code,
			#us.[status],
			pl.PersonID AS 'resident_code',
			per.PreferredName + ' ' + per.LastName AS 'resident_name',
			per.Email AS 'resident_email',
			pl.ResidencyStatus AS 'resident_status',
			#us.market_rent,
			#us.market_deposit,
			CONVERT(varchar(10), pl.LeaseSignedDate, 120) AS 'lease_sign',
			CONVERT(varchar(10), #us.lease_from, 120) AS 'lease_from',
			CONVERT(varchar(10), #us.lease_to, 120) AS 'lease_to',
			CONVERT(varchar(10), pl.MoveInDate, 120) AS 'move_in',
			CONVERT(varchar(10), pl.MoveOutDate, 120) AS 'move_out',
			CONVERT(varchar(10), #us.notice_given, 120) AS 'notice_given',
			#us.make_ready_status,
			ISNULL(#us.days_vacant, 0) AS 'days_vacant',
			#us.future_rented_status 
		FROM #UnitStatus #us
			LEFT JOIN PersonLease pl ON #us.LeaseID = pl.LeaseID 
											AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																		FROM PersonLease 
																		WHERE LeaseID = #us.LeaseID
																		ORDER BY OrderBy)
			LEFT JOIN Person per ON pl.PersonID = per.PersonID
		ORDER BY #us.property_code, #us.unit_code


END
GO
