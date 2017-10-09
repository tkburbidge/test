SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[BatchUpdateUnits]
	@accountID bigint = 0, 
	@unitIDs GuidCollection readonly,
	@petsPermitted int = null,
	@availableForOnlineMarketing bit = null,
	@isHoldingUnit bit = null,
	@excludedFromOccupancy bit = null
AS
BEGIN
	SET NOCOUNT ON;

	IF (@petsPermitted IS NOT NULL)
	BEGIN
		UPDATE Unit
		SET MaxPetsPermitted = @petsPermitted, 
			PetsPermitted = CASE WHEN (@petsPermitted > 0) THEN 1 ELSE 0 END
		WHERE AccountID = @accountID AND UnitID IN (SELECT Value FROM @unitIDs) 
	END

	IF (@availableForOnlineMarketing IS NOT NULL)
	BEGIN
		UPDATE Unit
		SET AvailableForOnlineMarketing = @availableForOnlineMarketing
		WHERE AccountID = @accountID AND UnitID IN (SELECT Value FROM @unitIDs) 
	END

	IF (@isHoldingUnit IS NOT NULL)
	BEGIN
		UPDATE Unit
		SET IsHoldingUnit = @isHoldingUnit
		WHERE AccountID = @accountID AND UnitID IN (SELECT Value FROM @unitIDs) 
	END

	IF (@excludedFromOccupancy IS NOT NULL)
	BEGIN
		UPDATE Unit
		SET ExcludedFromOccupancy = @excludedFromOccupancy
		WHERE AccountID = @accountID AND UnitID IN (SELECT Value FROM @unitIDs) 
	END
END
GO
