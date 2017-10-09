SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Craig Perkins
-- Create date: July 14, 2014
-- Description:	Gets applicants and current residents
-- =============================================
CREATE PROCEDURE [dbo].[API_GetTransfers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier = null,
	@startDate date,
	@endDate date,
	@integrationPartnerID int,
	@statuses StringCollection READONLY
AS
BEGIN
	 
	CREATE TABLE #Statuses (Value nvarchar(20) not null)
	CREATE TABLE #LeaseStatuses (Value nvarchar(20) not null)

	INSERT INTO #Statuses SELECT Value FROM @statuses
	INSERT INTO #LeaseStatuses SELECT Value FROM @statuses

	IF (EXISTS(SELECT Value FROM #Statuses WHERE Value = 'Approved'))
	BEGIN
		INSERT INTO #LeaseStatuses VALUES ('Pending')
	END
	
	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier not null)

	IF (@propertyID IS NOT NULL)
	BEGIN
		INSERT INTO #PropertyIDs 
			SELECT @propertyID
	END
	ELSE
	BEGIN
		INSERT INTO #PropertyIDs
			SELECT DISTINCT PropertyID
				FROM IntegrationPartnerItemProperty ipip
				INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID
				WHERE ipip.AccountID = @accountID
				AND ipi.IntegrationPartnerID = @integrationPartnerID
	END    

	SELECT	DISTINCT	
		p.PropertyID,			
		u.Number AS 'NewUnitNumber',
		ou.Number AS 'PreviousUnitNumber',				
		l.UnitLeaseGroupID AS 'NewUnitLeaseGroupID',
		prevl.UnitLeaseGroupID AS 'PreviousUnitLeaseGroupID',
		pr.FirstName,
		pr.LastName,
		pr.Email,
		pr.PersonID,
		pl.MoveInDate AS 'MoveInDate',
		prevpl.MoveOutDate AS 'MoveOutDate',
		a.StreetAddress AS 'StreetAddress',		
		a.City AS 'City',
		a.[State] AS 'State',
		a.Zip AS 'Zip',
		pl.ResidencyStatus AS 'Status'
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
		INNER JOIN Person pr ON pr.PersonID = pl.PersonID
		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		INNER JOIN [Address] a ON u.AddressID = a.AddressID
		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		INNER JOIN Property p ON ut.PropertyID = p.PropertyID
		INNER JOIN #PropertyIDs pid ON p.PropertyID = pid.PropertyID
		LEFT JOIN UnitLeaseGroup pulg ON ulg.PreviousUnitLeaseGroupID = pulg.UnitLeaseGroupID
		LEFT JOIN Unit ou ON pulg.UnitID = ou.UnitID
		LEFT JOIN Lease prevl ON prevl.UnitLeaseGroupID = pulg.UnitLeaseGroupID			
		LEFT JOIN PersonLease prevpl ON prevpl.LeaseID = prevl.LeaseID AND prevpl.PersonID = pr.PersonID													
	WHERE
		(SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) >= @startDate
		AND (SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) <= @endDate
		AND l.LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
		AND pl.ResidencyStatus IN (SELECT Value FROM #Statuses)
		AND pl.MoveInDate >= @startDate 
		AND pl.MoveInDate <= @endDate	 
		AND pulg.UnitLeaseGroupID IS NOT NULL
		--AND p.PropertyID = @propertyID
		-- Get the first lease on the new UnitLeaseGroup		  
		AND l.LeaseID = (SELECT TOP 1 LeaseID 
						FROM Lease
						WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								AND LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
						ORDER BY LeaseStartDate)				
		-- Get the last lease on the old UnitLeaseGroup							
		AND prevl.LeaseID = (SELECT TOP 1 LeaseID
							FROM Lease
							WHERE Lease.UnitLeaseGroupID = pulg.UnitLeaseGroupID
									AND LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
							ORDER BY LeaseEndDate DESC)
END
GO
