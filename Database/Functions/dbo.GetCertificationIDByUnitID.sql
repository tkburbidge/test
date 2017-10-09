SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetCertificationIDByUnitID] 
(	
	-- Add the parameters for the function here
	@unitID uniqueidentifier, 
	@effectiveDate date,
	@includeOnlyCompleted bit
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT TOP 1 certif.CertificationID, certif.LeaseID, certif.EffectiveDate
		FROM Certification certif
			JOIN UnitLeaseGroup ulg ON certif.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		WHERE ulg.UnitID = @unitID
		  AND certif.EffectiveDate <= @effectiveDate
		  AND ((@includeOnlyCompleted = 0) OR (certif.DateCompleted <= @effectiveDate))
		ORDER BY certif.EffectiveDate DESC
)
GO
