SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: May 23, 2012
-- Description:	Gets the data needed to send to RLL
--				for nightly sync file
-- =============================================
CREATE PROCEDURE [dbo].[TSK_GetRLLEmailData]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 	
		
		prop.AccountID,
		ipip.Value3 AS 'RLLEmailAddress',
		prop.PropertyID,
		prop.Name AS 'PropertyName',
		u.UnitID,
		p.FirstName,
		p.LastName,
		b.Name AS 'BuildingName',
		u.Number AS 'UnitNumber',
		a.StreetAddress,
		a.City,
		a.[State],
		a.Zip,
	   (SELECT MIN(MoveInDate)
		FROM PersonLease
		WHERE LeaseID = l.LeaseID
		AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveInDate',
		l.LeaseEndDate,
	   (CASE WHEN (SELECT COUNT(*) FROM PersonLease WHERE LeaseID = l.LeaseID AND MoveOutDate IS NULL) = 0 
			 THEN (SELECT Max(MoveOutDate)
				   FROM PersonLease
				   WHERE LeaseID = l.LeaseID
				   AND ResidencyStatus NOT IN ('Cancelled'))
			 ELSE NULL
		END) AS 'MoveOutDate',
		CASE WHEN ri.RentersInsuranceID IS NULL THEN NULL
			 WHEN ri.IntegrationPartnerItemID = 70 THEN 'RLL' 
			 WHEN ri.IntegrationPartnerItemID = 184 THEN 'RLL-Owner' 
			 ELSE 'Private'
		END AS 'RentersInsuranceType',
		--ri.RentersInsuranceType,
		ri.ExpirationDate AS 'RentersInsuranceExpirationDate',
		ri.StartDate AS 'RentersInsuranceStartDate'
	FROM Unit u
	INNER JOIN Building b ON b.BuildingID = u.BuildingID
	INNER JOIN Property prop ON prop.PropertyID = b.PropertyID
	LEFT JOIN [Address] a ON a.AddressID = u.AddressID
	INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.AccountID = u.AccountID AND ipip.PropertyID = prop.PropertyID
	--INNER JOIN Settings s ON u.AccountID = s.AccountID
	-- Join in unit lease groups that have a current lease
	LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitID = u.UnitID AND (SELECT COUNT(*) FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Current', 'Under Eviction')) > 0
	-- Join in the current lease
	LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
	-- Join in the first main contact
	LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																				FROM PersonLease pl2
																				WHERE pl2.LeaseID = l.LeaseID
																				AND ResidencyStatus NOT IN ('Cancelled', 'Former', 'Evicted')
																				ORDER BY pl2.OrderBy)
	LEFT JOIN Person p ON pl.PersonID = p.PersonID
	LEFT JOIN RentersInsurance ri ON ri.UnitLeaseGroupID = l.UnitLeaseGroupID
	WHERE ((ri.RentersInsuranceID IS NULL) OR
		  ri.RentersInsuranceID = (SELECT TOP 1 RentersInsuranceID
								   FROM RentersInsurance
								   WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								   ORDER BY DateCreated DESC))
	AND ipip.IntegrationPartnerItemID IN (70)
	ORDER BY PaddedNumber
END
GO
