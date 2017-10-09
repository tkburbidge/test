SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetAutoPostRecurringChargesProperties]	
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT p.AccountID, p.PropertyID, p.Name AS 'PropertyName'
	FROM Property p 
	WHERE p.AutoPostRecurringChargesDayOfMonth IS NOT NULL
		AND ((p.AutoPostRecurringChargesDayOfMonth = DATEPART(DAY, @date))
					  -- Post on last day of month if day to run happens to be greater than last day of month (we save 32 if 'last day' is chosen)
			OR (p.AutoPostRecurringChargesDayOfMonth >= DATEPART(day,EOMONTH(@date)) AND DATEPART(day,EOMONTH(@date)) = DATEPART(day, @date)))
END
GO
