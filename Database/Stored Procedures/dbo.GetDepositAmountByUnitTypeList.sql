SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 1 2016 - National Ponytail Day
-- Description:	Gets the required deposit by UnitType
-- =============================================
CREATE PROCEDURE [dbo].[GetDepositAmountByUnitTypeList]
	-- Add the parameters for the stored procedure here
	@unitTypeIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #UnitTypeIDs (
		UnitTypeID uniqueidentifier not null)

	INSERT #UnitTypeIDs 
		SELECT Value 
			FROM @unitTypeIDs

	SELECT	#ut.UnitTypeID,
			CASE 
				WHEN (ut.UseMarketRent = 1) THEN [ArtsPonytail].Amount
				ELSE ut.RequiredDeposit END AS 'Deposit'
		FROM #UnitTypeIDs #ut
			INNER JOIN UnitType ut ON #ut.UnitTypeID = ut.UnitTypeID
			CROSS APPLY [dbo].[GetLatestMarketRentByUnitTypeID](#ut.UnitTypeID, @date) [ArtsPonytail]
		

END

GO
