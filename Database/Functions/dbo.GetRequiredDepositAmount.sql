SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 2, 2016
-- Description:	A function that determines what the Required Deposit is for a collection of Units.
-- =============================================
CREATE FUNCTION [dbo].[GetRequiredDepositAmount] 
(	
	-- Add the parameters for the function here
	@unitID uniqueidentifier, 
	@date date
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT	u.UnitID AS 'UnitID',
			CASE WHEN (ut.UseMarketRent = 0) THEN ut.RequiredDeposit
				 ELSE [MyMarkRent].Amount END AS 'Deposit'
		FROM Unit u
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			CROSS APPLY [dbo].[GetMarketRentByDate](u.UnitID, @date, 1) [MyMarkRent]
		WHERE u.UnitID = @unitID

)
GO
