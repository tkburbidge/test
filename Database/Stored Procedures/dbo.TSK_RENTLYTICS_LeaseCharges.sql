SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 17, 2017
-- Description:	Gets the data for the Rentlytics Lease Charges data dump
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_LeaseCharges] 
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
	CREATE TABLE #LeaseCharges (
		property_code nvarchar(100) null,
		unit_code nvarchar(50) null,
		resident_code nvarchar(250) null,
		resident_status nvarchar(250) null,
		charge_type nvarchar(50) null,
		charge_amount money null,
		UnitLeaseGroupID uniqueidentifier not null)

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

	INSERT #LeaseCharges
		SELECT	DISTINCT
				p.Abbreviation,
				#lau.UnitNumber,
				l.LeaseID,
				'Current',
				lli.[Description],
				lli.Amount,
				#lau.OccupiedUnitLeaseGroupID
			FROM #LeasesAndUnits #lau
				INNER JOIN Property p ON #lau.PropertyID = p.PropertyID
				INNER JOIN Lease l ON #lau.OccupiedLastLeaseID = l.LeaseID
				INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID 
										AND lli.StartDate >= @date AND lli.EndDate <= @date
				
	INSERT #LeaseCharges
		SELECT	DISTINCT
				p.Name,
				#lau.UnitNumber,
				l.LeaseID,
				'Future',
				lli.[Description],
				lli.Amount,
				#lau.PendingUnitLeaseGroupID
			FROM #LeasesAndUnits #lau
				INNER JOIN Property p ON #lau.PropertyID = p.PropertyID
				INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
				INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID 
										--AND lli.StartDate >= @date AND lli.EndDate <= @date
			WHERE #lau.PendingUnitLeaseGroupID NOT IN (SELECT UnitLeaseGroupID FROM #LeaseCharges)



END
GO
