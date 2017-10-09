SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: Mar. 5, 2013
-- Description:	Gets the current status of the Unit by ID or if a date is specified, the status on that date
-- =============================================
CREATE FUNCTION [dbo].[GetUnitStatusByUnitID]
(	
	-- Add the parameters for the function here
	@unitID uniqueidentifier, 
	@date datetime
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	
	SELECT TOP 1 un.[Date], us.Name AS 'Status', un.UnitNoteID, us.UnitStatusID, 1 AS OrderBy
		FROM UnitNote un 
			INNER JOIN UnitStatus us ON un.UnitStatusID = us.UnitStatusID
		WHERE un.UnitID = @unitID
		  AND ((@date IS NULL) OR (un.[Date] <= @date) OR ((SELECT COUNT(*) FROM UnitNote WHERE UnitID = @unitID AND [Date] <= @date) = 0))			  
	ORDER BY 
		-- If no date, just get the last note
		CASE WHEN @date IS NULL THEN un.[Date] ELSE '' END DESC,
		-- If have date but there are not notes on or before the date, get the first note
		CASE WHEN @date IS NOT NULL AND ((SELECT COUNT(*) FROM UnitNote WHERE UnitID = @unitID AND [Date] <= @date) = 0) THEN un.[Date] ELSE '' END ASC,
		-- If have date and there are notes on or before the date, get the last one
		CASE WHEN @date IS NOT NULL AND ((SELECT COUNT(*) FROM UnitNote WHERE UnitID = @unitID AND [Date] <= @date) > 0) THEN un.[Date] ELSE '' END DESC,
		un.DateCreated DESC
)
GO
