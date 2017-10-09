SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 1 2016 - National Ponytail Day
-- Description:	Gets the required deposit by UnitType
-- =============================================
CREATE PROCEDURE [dbo].[GetDepositAmountByUnitType] 
	-- Add the parameters for the stored procedure here
	@unitTypeID uniqueidentifier = null, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	CASE 
				WHEN (ut.UseMarketRent = 1) THEN [ArtsPonytail].Amount
				ELSE ut.RequiredDeposit END AS 'Deposit'
		FROM UnitType ut
			CROSS APPLY [dbo].[GetLatestMarketRentByUnitTypeID](@unitTypeID, @date) [ArtsPonytail]
		WHERE ut.UnitTypeID = @unitTypeID

END

GO
