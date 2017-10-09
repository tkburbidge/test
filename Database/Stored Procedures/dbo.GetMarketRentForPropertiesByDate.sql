SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 18, 2014
-- Description:	Gets all of the MarketRents for a set of properties on a given date.
-- =============================================
CREATE PROCEDURE [dbo].[GetMarketRentForPropertiesByDate] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #MyMarketRents (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		MarketRent money null)
		
	INSERT #MyMarketRents
		SELECT prop.PropertyID, u.UnitID, null
			FROM Property prop 
				INNER JOIN UnitType ut ON prop.PropertyID = ut.PropertyID
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
			WHERE prop.PropertyID IN (SELECT Value FROM @propertyIDs)

	UPDATE #mmr SET MarketRent = MarketRent.Amount
		FROM #MyMarketRents #mmr
			CROSS APPLY GetMarketRentByDate(#mmr.UnitID, @date, 1) AS [MarketRent]
			
				
	SELECT *
		FROM #MyMarketRents
		ORDER BY PropertyID, UnitID
		
END
GO
