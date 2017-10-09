SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Mar. 20, 2013
-- Description:	In line function to get the latest MarketRent value by UnitID
-- =============================================
CREATE FUNCTION [dbo].[GetLatestMarketRentByUnitTypeID] 
(	
	-- Add the parameters for the function here
	@unitTypeID uniqueidentifier, 
	@date date
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT TOP 1 DateChanged AS 'DateEntered', Amount
		FROM MarketRent
		WHERE ObjectID = @unitTypeID		  
		   AND ((@date IS NULL) OR (DateChanged <= @date) OR ((SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitTypeID AND DateChanged <= @date) = 0))			  
		ORDER BY
			CASE WHEN (@date IS NULL) 
					THEN DateChanged ELSE '' END DESC,
			CASE WHEN (@date IS NOT NULL AND 0 < (SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitTypeID AND DateChanged <= @date))
					THEN DateChanged ELSE '' END DESC,
			CASE WHEN (@date IS NOT NULL AND 0 = (SELECT COUNT(*) FROM MarketRent WHERE ObjectID = @unitTypeID AND DateChanged <= @date))
					THEN DateChanged ELSE '' END,
			DateCreated DESC 		
			
)
GO
