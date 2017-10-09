SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Thomas Hutchins
-- Create date: Sep 20, 2017
-- Description:	Gets the annual amount
-- =============================================
CREATE FUNCTION [dbo].[CalculateAnnual]
(
	@salary DECIMAL,
	@salaryPeriod VARCHAR(10)
)
RETURNS MONEY
AS
BEGIN
	RETURN CASE WHEN (@salaryPeriod = 'Monthly') 
			 	THEN @salary * 12.0
			 WHEN (@salaryPeriod = 'Biweekly')
			 	THEN @salary * 26.0
			 WHEN (@salaryPeriod = 'Weekly')
			 	THEN @salary * 52.0
			 ELSE @salary END
END



GO
