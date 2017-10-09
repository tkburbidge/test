SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 22, 2014
-- Description:	Gets the current time in the timezone of the property
-- =============================================
CREATE FUNCTION [dbo].[GetTimeZoneTime] 
(
	-- Add the parameters for the function here
	@propertyID uniqueidentifier
)
RETURNS datetime
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result datetime
	DECLARE @year int

	-- Add the T-SQL statements to compute the return value here
	SET @year = DATEPART(year, GETUTCDATE())
	SELECT @Result = (SELECT CASE 
								WHEN (dst.StartDate <= GETUTCDATE() AND dst.EndDate >= GETUTCDATE()) THEN DATEADD(hour, DaylightGMTOffset, GETUTCDATE())
								ELSE DATEADD(hour, StandardGMTOffset,  GETUTCDATE()) END
						  FROM Property p
							  INNER JOIN TimeZone tz ON p.TimeZoneID = tz.Name
							  INNER JOIN DaylightSavingsTime dst ON dst.[Year] = @year
						  WHERE p.PropertyID = @propertyID)

	-- Return the result of the function
	RETURN @Result

END
GO
