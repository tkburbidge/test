SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 2, 2016
-- Description:	A function that determines what the Required Deposit is for a collection of Units.
-- =============================================
CREATE FUNCTION [dbo].[GetRequiredDepositAmountByUnitType] 
(	
	-- Add the parameters for the function here
	@unitTypeID uniqueidentifier, 
	@date date
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT	ut.UnitTypeID AS 'UnitTypeID',
			CASE WHEN (ut.UseMarketRent = 0) THEN ut.RequiredDeposit
				 ELSE [MyMarkRent].Amount END AS 'Deposit'
		FROM UnitType ut 
			CROSS APPLY [dbo].[GetLatestMarketRentByUnitTypeID](ut.UnitTypeID, @date) [MyMarkRent]
		WHERE ut.UnitTypeID = @unitTypeID
)

GO
