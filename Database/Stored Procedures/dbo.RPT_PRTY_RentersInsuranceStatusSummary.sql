SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 5/7/2014
-- Description:	Gets the data for the Renters Insurance Status Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_RentersInsuranceStatusSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
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
		PendingMoveInDate date null)
    
    CREATE TABLE #InsurancePolicies (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		Provider nvarchar(50) not null,
		StartDate date null)
		
	CREATE TABLE #RentersInsurances (
		ID int identity,
		RentersInsuranceID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		ServiceProviderID uniqueidentifier null,
		IntegrationPartnerItemID int null,
		StartDate date null,
		ExpirationDate date null)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)

	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs
    
    INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, null, @propertyIDs
    
    -- Get Renters Insurances with the parameters
    INSERT #RentersInsurances
		SELECT
			ri.RentersInsuranceID,
			ri.UnitLeaseGroupID,
			ri.ServiceProviderID,
			ri.IntegrationPartnerItemID,
			ri.StartDate,
			ri.ExpirationDate
		FROM RentersInsurance ri
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ri.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = b.PropertyID
		WHERE ri.AccountID = @accountID
		  AND (ri.ExpirationDate IS NULL OR ri.ExpirationDate >= @date)
		ORDER BY ri.ExpirationDate
    
 
	-- Make renters insurances Distinct on UnitLeaseGroupID
    -- by using the insurance with the earliest StartDate.
    DELETE #ri
		FROM #RentersInsurances #ri		
		WHERE #ri.ID NOT IN
			(SELECT MIN(#ri2.ID)
				FROM #RentersInsurances #ri2
				GROUP BY #ri2.UnitLeaseGroupID)

    -- Service Providers
    INSERT #InsurancePolicies
		SELECT
			#lau.PropertyID,
			#lau.UnitID,
			#ri.UnitLeaseGroupID,
			sp.Name,
			#ri.StartDate 
		FROM #RentersInsurances #ri
			INNER JOIN #LeasesAndUnits #lau ON #ri.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
			INNER JOIN ServiceProvider sp ON #ri.ServiceProviderID = sp.ServiceProviderID
    
    -- Integration Partners
    INSERT #InsurancePolicies
		SELECT
			#lau.PropertyID,
			#lau.UnitID,
			#ri.UnitLeaseGroupID,
			ip.Name, 
			#ri.StartDate 
		FROM #RentersInsurances #ri
			INNER JOIN #LeasesAndUnits #lau ON #ri.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
			INNER JOIN IntegrationPartnerItem ipi ON #ri.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
			INNER JOIN IntegrationPartner ip ON ipi.IntegrationPartnerID = ip.IntegrationPartnerID
    
    -- Other
    INSERT #InsurancePolicies
		SELECT
			#lau.PropertyID,
			#lau.UnitID,
			#ri.UnitLeaseGroupID,
			'Other',
			#ri.StartDate 
		FROM #RentersInsurances #ri
			INNER JOIN #LeasesAndUnits #lau ON #ri.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
		WHERE #ri.ServiceProviderID IS NULL
		  AND (#ri.IntegrationPartnerItemID IS NULL OR IntegrationPartnerItemID <= 0)
    
    -- Property Info
    SELECT
		p.PropertyID,
		p.Name AS 'PropertyName',
		(SELECT COUNT(#lau.UnitID)
			FROM #LeasesAndUnits #lau
			WHERE p.PropertyID = #lau.PropertyID) AS 'UnitCount',
		(SELECT COUNT(#lau2.UnitID)
			FROM #LeasesAndUnits #lau2
			WHERE p.PropertyID = #lau2.PropertyID
			  AND #lau2.OccupiedUnitLeaseGroupID IS NOT NULL) AS 'OccupiedUnits'
	FROM Property p
	WHERE p.AccountID = @accountID
	  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
    
    -- Insurance Policies
    SELECT * FROM #InsurancePolicies
    GROUP BY PropertyID, Provider, UnitID, UnitLeaseGroupID, StartDate


    
END
GO
