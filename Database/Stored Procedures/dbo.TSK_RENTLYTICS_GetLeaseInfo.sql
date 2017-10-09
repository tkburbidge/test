SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 16, 2017
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GetLeaseInfo] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #LeaseInfo (
		property_code nvarchar(50) not null,
		lease_code uniqueidentifier not null,
		unit_code nvarchar(50) null,
		resident_name nvarchar(100) null,
		resident_code uniqueidentifier null,
		resident_cell_phone nvarchar(20) null,
		resident_home_phone nvarchar(20) null,
		resident_email nvarchar(100) null,
		resident_status nvarchar(50) null,
		market_rent money null,
		lease_sign date null,
		lease_start date null,
		lease_end date null,
		move_in date null,
		move_out date null,
		notice_given date null,
		notice_type nvarchar(50) null,
		actual_rent money null,
		number_of_occupants int null,
		renewal_status nvarchar(50) null,
		UnitID uniqueidentifier null)

	INSERT #LeaseInfo
		SELECT	p.Abbreviation,
				l.LeaseID,
				u.Number,
				per.LastName + ', ' + per.PreferredName,
				pl.PersonID,
				null, 
				null,
				null,
				CASE	
					WHEN (pl.ResidencyStatus IN ('Former', 'Evicted')) THEN 'Former Resident'
					WHEN (pl.ResidencyStatus IN ('Pending', 'Pending Transfer')) THEN 'Future Resident'
					--WHEN (pl.ResidencyStatus IN ('Current', 'Under Eviction')) THEN 'Current Resident'
					ELSE 'Current Resident'
					END,
				null AS 'market_rent',
				pl.LeaseSignedDate,
				l.LeaseStartDate,
				l.LeaseEndDate,
				pl.MoveInDate,
				pl.MoveOutDate,
				pl.NoticeGivenDate,
				CASE 
					WHEN (pl.ResidencyStatus IN ('Evicted')) THEN 'Eviction'
					ELSE 'Regular'
					END,
				null AS 'actual_rent',
				(SELECT COUNT(*)
					FROM PersonLease
					WHERE LeaseID = l.LeaseID
					GROUP BY LeaseID),
				CASE
					WHEN (l.LeaseID = (SELECT TOP 1 LeaseID
										   FROM Lease
										   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
										   ORDER BY LeaseStartDate)) THEN 'New Tenant'
					ELSE 'Renewal'
					END,
				u.UnitID
			FROM UnitLeaseGroup ulg 
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																								FROM PersonLease
																								WHERE pl.LeaseID = l.LeaseID
																								  AND pl.MainContact = 1
																								ORDER BY OrderBy)
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				
	UPDATE #li SET market_rent = [MarkRent].Amount
		FROM #LeaseInfo #li
			CROSS APPLY dbo.GetMarketRentByDate(#li.UnitID, #li.lease_start, 1) [MarkRent]

	UPDATE #LeaseInfo SET actual_rent = (SELECT SUM(lli.Amount)
											  FROM LeaseLedgerItem lli
												  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
												  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
											  WHERE lli.LeaseID = #LeaseInfo.lease_code
											    AND lli.StartDate >= #LeaseInfo.lease_start
												AND lli.StartDate <= #LeaseInfo.lease_end)

	SELECT	property_code,
			lease_code,
			unit_code,
			resident_name,
			resident_code,
			resident_cell_phone,
			resident_home_phone,
			resident_email,
			resident_status,
			market_rent,
			CONVERT(varchar(10), lease_sign, 120) AS 'lease_sign',
			CONVERT(varchar(10), lease_start, 120) AS 'lease_start',
			CONVERT(varchar(10), lease_end, 120) AS 'lease_end',
			CONVERT(varchar(10), move_in, 120) AS 'move_in',
			CONVERT(varchar(10), move_out, 120) AS 'move_out',
			CONVERT(varchar(10), notice_given, 120) AS 'notice_given',
			notice_type,
			actual_rent,
			number_of_occupants,
			renewal_status
		FROM #LeaseInfo
		ORDER BY property_code, unit_code, lease_start

END
GO
