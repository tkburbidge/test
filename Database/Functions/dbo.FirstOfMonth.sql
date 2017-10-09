SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[FirstOfMonth]
(
	-- Add the parameters for the function here
	@date datetime
)
RETURNS datetime
AS
BEGIN

	RETURN DATEADD(MONTH, DATEDIFF(MONTH, 0, @date), 0)

END
GO
