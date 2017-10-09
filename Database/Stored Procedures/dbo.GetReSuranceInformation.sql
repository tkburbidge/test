SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 5/31/2017
-- Description:	Gets ReSurance insurance information needed for auto enrolling
-- =============================================
CREATE PROCEDURE [dbo].[GetReSuranceInformation] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@propertyID uniqueidentifier,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #UnitLeaseGroups (
		UnitLeaseGroupID uniqueidentifier not null,
		ReSuranceConsent bit not null
	)

	INSERT INTO #UnitLeaseGroups
		SELECT DISTINCT
			ulg.UnitLeaseGroupID,
			0
		FROM UnitLeaseGroup ulg
			INNER JOIN Lease l on ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on ulg.UnitID = u.UnitID
			INNER JOIN Building b on u.BuildingID = b.BuildingID
		WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			AND b.PropertyID = @propertyID

	-- Get all ActionPreRequisites for ResidentAgreesToReSurance tied to this UnitLeaseGroup and get the last one
	-- If they gave consent (giving consent is determined by not overriding the consent) then mark it so
	UPDATE #UnitLeaseGroups SET ReSuranceConsent = ISNULL((SELECT TOP 1 CASE WHEN (aps.IsOverridden = 0) THEN CAST(1 AS bit)
																	   ELSE CAST(0 AS bit) END
														FROM #UnitLeaseGroups #ulgs 
															INNER JOIN Lease l on l.UnitLeaseGroupID = #ulgs.UnitLeaseGroupID
															INNER JOIN ActionPrerequisiteStatus aps on l.LeaseID = aps.ObjectID
															INNER JOIN ActionPrerequisiteItem api on aps.ActionPrerequisiteItemID = api.ActionPrerequisiteItemID
														WHERE api.Name = 'ResidentAgreesToReSurance'
														  AND aps.DateCompleted IS NOT NULL
														  AND #ulgs.UnitLeaseGroupID = #UnitLeaseGroups.UnitLeaseGroupID
														ORDER BY aps.DateCompleted DESC), 0)
	
		
	
	-- list of unit lease groups and consent for ReSurance
	SELECT * FROM #UnitLeaseGroups


	-- list of leases and dates that need ReSurance
	SELECT
		l.UnitLeaseGroupID,
		l.LeaseID,
		l.LeaseStartDate,
		l.LeaseEndDate,
		l.LeaseStatus
	FROM Lease l
		INNER JOIN #UnitLeaseGroups #ulg on l.UnitLeaseGroupID = #ulg.UnitLeaseGroupID
	WHERE #ulg.ReSuranceConsent = 1
	  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Pending Renewal')



	-- renters insurance policies for onges that consent for ReSurance
	SELECT
		ri.UnitLeaseGroupID,
		ri.RentersInsuranceID,
		ri.IntegrationPartnerItemID,
		ri.OtherProvider,
		ri.PolicyType,
		ri.PolicyNumber,
		ri.Coverage,
		ri.StartDate,
		ri.ExpirationDate,
		ri.CancelDate
	FROM RentersInsurance ri
		INNER JOIN #UnitLeaseGroups #ulg on ri.UnitLeaseGroupID = #ulg.UnitLeaseGroupID
	WHERE #ulg.ReSuranceConsent = 1

END
GO
