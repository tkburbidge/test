SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 8, 2016,
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRTY_UnitType]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@date date null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	ut.UnitTypeID,
			ut.PropertyID,
			ut.Name,
			ut.MarketingName,
			ut.Bedrooms,
			ut.Bathrooms,
			ut.[Description],
			ut.MarketRent,
			CASE WHEN (ut.UseMarketRent = 0) THEN ut.RequiredDeposit
				 ELSE [Deposit].[Deposit] END AS 'Deposit',
			ut.MarketingDescription,
			ut.Notes
		FROM UnitType ut
			INNER JOIN @propertyIDs pIDs ON ut.PropertyID = pIDs.Value
			CROSS APPLY dbo.[GetRequiredDepositAmountByUnitType](ut.UnitTypeID, GETDATE()) [Deposit]
END
GO
