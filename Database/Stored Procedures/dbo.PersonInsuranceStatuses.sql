SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Thomas Hutchins
-- Create date: June 6 2015
-- Description:	Generates the data for the PersonInsuranceStatuses
-- =============================================
CREATE PROCEDURE [dbo].[PersonInsuranceStatuses]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@accountID bigint,
	@insuranceStatus StringCollection READONLY,
	@expiringDate date = null,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Insert statements for procedure here
	CREATE TABLE #RentersInsuranceStatus
	(
		PersonID uniqueidentifier not null,
		InsuranceStatus nvarchar(10) not null
	)

	INSERT INTO #RentersInsuranceStatus		
		
		-- Select for Expired Policies 
		SELECT DISTINCT
				pl.PersonID AS 'PersonID',
				'Expired' AS 'InsuranceStatus'
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID	
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
			WHERE 				
			    ri.AccountID = @accountID
				AND b.PropertyID IN (SELECT Value FROM @propertyIDs)			
				AND 'Expired' in (SELECT Value FROM @insuranceStatus) 
				AND ri.ExpirationDate IS NOT NULL
				AND ri.ExpirationDate <= @date
		
	
	INSERT INTO #RentersInsuranceStatus		
		
		-- Select for Expiring Policies
		SELECT DISTINCT
				pl.PersonID AS 'PersonID',
				'Expiring' AS 'InsuranceStatus'
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID	
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
			WHERE 				
				ri.AccountID = @accountID
				AND b.PropertyID IN (SELECT Value FROM @propertyIDs)		
				AND 'Expiring' in (SELECT Value FROM @insuranceStatus) 
				AND ri.ExpirationDate IS NOT NULL
				AND ri.ExpirationDate >= @date
				AND ri.ExpirationDate <= @expiringDate				
		
	INSERT INTO #RentersInsuranceStatus		
		-- Select for Missing Policies
		SELECT DISTINCT
				pl.PersonID AS 'PersonID',
				'Missing' AS 'InsuranceStatus'
			FROM PersonLease pl
				INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID	
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID		
				where ulg.UnitLeaseGroupID not in (select UnitLeaseGroupID from RentersInsurance)
				AND pl.AccountID = @accountID
				AND b.PropertyID IN (SELECT Value FROM @propertyIDs)		
				AND 'Missing' in (SELECT Value FROM @insuranceStatus) 

	INSERT INTO #RentersInsuranceStatus		
		-- Select for Missing Policies
			SELECT DISTINCT
				pl.PersonID AS 'PersonID',
				'Current' AS 'InsuranceStatus'
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID	
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
			WHERE 				
			    ri.AccountID = @accountID
				AND b.PropertyID IN (SELECT Value FROM @propertyIDs)			
				AND 'Current' in (SELECT Value FROM @insuranceStatus) 
				AND (ri.ExpirationDate IS NULL
				OR ri.ExpirationDate > @date)

	SELECT * FROM #RentersInsuranceStatus
	 
END

GO
