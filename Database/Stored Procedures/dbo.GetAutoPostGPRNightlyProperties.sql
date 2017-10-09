SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 8/26/2016
-- Description:	Gets all properties setup to post GPR entries nightly.
-- =============================================
CREATE PROCEDURE [dbo].[GetAutoPostGPRNightlyProperties] 
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
	SELECT
		prop.AccountID,
		prop.PropertyID,
		pap.AccountingPeriodID
	FROM Property prop
		INNER JOIN PropertyAccountingPeriod pap on prop.CurrentPropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	WHERE prop.AutoPostGPRNightly = 1
	  AND prop.IsArchived = 0

END
GO
