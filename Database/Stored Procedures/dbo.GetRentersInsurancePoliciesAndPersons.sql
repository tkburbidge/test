SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: August 5, 2014
-- Description:	Gets renters insurance details and mapped people
-- =============================================
CREATE PROCEDURE [dbo].[GetRentersInsurancePoliciesAndPersons] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@unitLeaseGroupID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT DISTINCT
		ri.RentersInsuranceID,
		ri.UnitLeaseGroupID,
		ri.OtherProvider,
		ri.PolicyNumber,
		ri.StartDate,
		ri.ExpirationDate,
		ri.CancelDate,
		ri.Coverage,
		ri.RentersInsuranceType,
		ri.Notes,
		p.PersonID,
		p.Birthdate,
		p.FirstName,
		p.MiddleName,
		p.LastName
	FROM RentersInsurance ri
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ri.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		LEFT JOIN RentersInsurancePerson rip ON ri.RentersInsuranceID = rip.RentersInsuranceID
		LEFT JOIN Person p ON rip.PersonID = p.PersonID
	WHERE 
		ri.AccountID = @accountID
		AND (@unitLeaseGroupID IS NULL OR ri.UnitLeaseGroupID = @unitLeaseGroupID)
		AND b.PropertyID = @propertyID
	END
GO
