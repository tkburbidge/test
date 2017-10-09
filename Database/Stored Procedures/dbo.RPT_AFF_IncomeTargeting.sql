SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_AFF_IncomeTargeting]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@effectiveDate datetime,
	@propertyIDs GuidCollection READONLY
AS

BEGIN

	DECLARE @types StringCollection

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #CertificationInformation (
		CertificationID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(20) not null,
		PaddedUnitNumber nvarchar(20) not null,
		BuildingID uniqueidentifier not null,
		BuildingName nvarchar(15) not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		CertificationType nvarchar(50) not null,
	)

	INSERT #Properties
		SELECT Value FROM @propertyIDs

	INSERT #CertificationInformation
		SELECT c.CertificationID AS 'CertificationID',
			c.LeaseID AS 'LeaseID',
			u.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			b.BuildingID AS 'BuildingID',
			b.[Name] AS 'BuildingName',
			b.PropertyID AS 'PropertyID',
			pr.[Name] AS 'PropertyName',
			c.[Type] AS 'CertificationType'
		FROM Certification c
			JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Unit u ON ulg.UnitID = u.UnitID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN Property pr ON b.PropertyID = pr.PropertyID
			JOIN CertificationGroup cg ON c.CertificationGroupID = cg.CertificationGroupID
			JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE c.AccountID = @accountID
			AND pr.PropertyID IN (SELECT PropertyID FROM #Properties)
			AND c.CertificationID = (SELECT dbo.GetPreviousCertificationID(@accountID, @effectiveDate, NULL, @types, 1, 0, cg.CertificationGroupID))
			AND NOT EXISTS (SELECT *
								FROM Certification c3
								WHERE c3.CertificationGroupID = cg.CertificationGroupID
									AND c3.[Type] IN ('Termination', 'Move-out'))
			AND ap.IsHUD = 1


	SELECT *
		FROM #CertificationInformation
		ORDER BY PaddedUnitNumber
END
GO
