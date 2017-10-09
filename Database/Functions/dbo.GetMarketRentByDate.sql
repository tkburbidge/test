SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE FUNCTION [dbo].[GetMarketRentByDate] 
(	
	-- Add the parameters for the function here
	@unitID uniqueidentifier,
	@date date,
	@includeAmenities bit
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT TOP 1 mr.ObjectID AS 'UnitID', ISNULL(mr.Amount, 0) + ISNULL(SUM(MyAmenities.Amount), 0) AS 'Amount'
		FROM MarketRent mr
			LEFT JOIN (SELECT ua.AmenityID, (SELECT TOP 1 ISNULL(ac.Amount, 0)
												FROM AmenityCharge ac
												WHERE ac.AmenityID = ua.AmenityID
													-- Make sure we take into account the last charge
													AND ac.AmenityChargeID = (SELECT TOP 1 ac2.AmenityChargeID FROM AmenityCharge ac2 WHERE ac2.AmenityID = ua.AmenityID AND ac2.DateEffective <= @date ORDER BY ac2.DateEffective DESC, ac2.DateCreated DESC)
													-- Make sure the charge increases market rent
													AND ac.LedgerItemTypeID IS NULL
												ORDER BY ac.DateEffective DESC) AS 'Amount'
									FROM UnitAmenity ua
									WHERE ua.UnitID = @unitID
									AND ((ua.DateEffective IS NULL) OR (ua.DateEffective <= @date))) AS [MyAmenities] ON @includeAmenities = 1 						
		WHERE ObjectID = @unitID		  
		   AND ((@date IS NULL) OR (DateChanged <= @date) OR ((SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitID AND DateChanged <= @date) = 0))	
		GROUP BY mr.ObjectID, mr.Amount, mr.DateChanged, mr.DateCreated
		ORDER BY
			CASE WHEN (@date IS NULL) 
					THEN DateChanged ELSE '' END DESC,
			CASE WHEN (@date IS NOT NULL AND 0 < (SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitID AND DateChanged <= @date))
					THEN DateChanged ELSE '' END DESC,
			CASE WHEN (@date IS NOT NULL AND 0 = (SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitID AND DateChanged <= @date))
					THEN DateChanged ELSE '' END,
			DateCreated DESC 	
	
)
GO
