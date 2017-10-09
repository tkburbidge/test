SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 1, 2014; So it might work and it might not, you fool!
-- Description:	Gets some custom data to add to the AvailableUnits Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_WeeklyReportAvailableUnits] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@availableUnitInfo AvailableUnitInfoCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #AvailableUnits (
		UnitID uniqueidentifier not null,
		OldLeaseID uniqueidentifier null,
		NewLeaseID uniqueidentifier null,
		[Type] nvarchar(50) null)
		
	CREATE TABLE #RentsAndStuff (
		UnitID uniqueidentifier not null,
		PreviousRent money null,
		NextRent money null,
		ReasonForNotice nvarchar(500) null,
		MoveOutDate date null)
		
	INSERT #AvailableUnits
		SELECT UnitID, OldLeaseID, NewLeaseID, [Type]
			FROM @availableUnitInfo

	UPDATE #au SET OldLeaseID = l.LeaseID
		FROM #AvailableUnits #au
			INNER JOIN UnitLeaseGroup ulg ON #au.UnitID = ulg.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID
																								FROM Lease
																								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																								  AND LeaseStatus IN ('Former', 'Evicted')
																								ORDER BY DateCreated DESC)
		WHERE #au.OldLeaseID IS NULL
		
	INSERT #RentsAndStuff 
		SELECT UnitID, null, null, null, null
			FROM #AvailableUnits
			
	UPDATE #RentsAndStuff SET PreviousRent = (SELECT ISNULL(SUM(lli.Amount), 0)
			FROM #RentsAndStuff #ras
				INNER JOIN #AvailableUnits #au ON #ras.UnitID = #au.UnitID
				INNER JOIN Lease l ON #au.OldLeaseID = l.LeaseID
				INNER JOIN LeaseLedgerItem lli ON #au.OldLeaseID = lli.LeaseID AND lli.StartDate <= l.LeaseEndDate
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
			WHERE #RentsAndStuff.UnitID = #ras.UnitID)
			
	UPDATE #RentsAndStuff SET NextRent = (SELECT ISNULL(SUM(lli.Amount), 0)
			FROM #RentsAndStuff #ras
				INNER JOIN #AvailableUnits #au ON #ras.UnitID = #au.UnitID
				INNER JOIN Lease l ON #au.NewLeaseID = l.LeaseID
				INNER JOIN LeaseLedgerItem lli ON #au.NewLeaseID = lli.LeaseID AND lli.StartDate <= l.LeaseEndDate
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
			WHERE #RentsAndStuff.UnitID = #ras.UnitID)
			
	UPDATE #RentsAndStuff SET ReasonForNotice = (SELECT TOP 1 pl.ReasonForLeaving
													FROM PersonLease pl
														INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
														INNER JOIN #AvailableUnits #au ON l.LeaseID = #au.OldLeaseID
														INNER JOIN #RentsAndStuff #ras ON #au.UnitID = #ras.UnitID
													WHERE pl.ReasonForLeaving IS NOT NULL
													  AND pl.NoticeGivenDate IS NOT NULL
													  AND #RentsAndStuff.UnitID = #ras.UnitID
													  AND #au.[Type] IN ('Notice to Vacate Pre-Leased', 'Notice to Vacate')
													ORDER BY pl.NoticeGivenDate)
													
	UPDATE #RentsAndStuff SET MoveOutDate = (SELECT TOP 1 pl.MoveOutDate
												FROM PersonLease pl
													INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
													INNER JOIN #AvailableUnits #au ON l.LeaseID = #au.OldLeaseID
													INNER JOIN #RentsAndStuff #ras ON #au.UnitID = #ras.UnitID
												WHERE pl.ResidencyStatus IN ('Former', 'Evicted')
												  AND pl.MoveOutDate IS NOT NULL
												  AND #RentsAndStuff.UnitID = #ras.UnitID
												  AND #au.[Type] IN ('Vacant Pre-Leased', 'Vacant')
												ORDER BY pl.MoveOutDate DESC)
				
	SELECT * FROM #RentsAndStuff
			
		
END
GO
