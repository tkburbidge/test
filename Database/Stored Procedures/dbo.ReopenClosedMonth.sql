SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 2, 2012
-- Description:	Reopens a closed month
-- =============================================
CREATE PROCEDURE [dbo].[ReopenClosedMonth] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier,
	@propertyAccountingPeriodID uniqueidentifier = null,
	@updateCurrentPeriod bit,
	@userAndGroupIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Reopen the period
	UPDATE PropertyAccountingPeriod SET Closed = 0 
	WHERE PropertyAccountingPeriodID = @propertyAccountingPeriodID 
		  AND AccountID = @accountID

	INSERT INTO PropertyAccountingPeriodUserSecurityRolePermission
	SELECT NEWID(), @accountID, Value, @propertyAccountingPeriodID
	FROM @userAndGroupIDs
	
	-- Set the calculated monthly totals to null
	UPDATE Budget SET NetMonthlyTotalAccrual = null, NetMonthlyTotalCash = null 
	WHERE PropertyAccountingPeriodID = @propertyAccountingPeriodID 
		  AND AccountID = @accountID
	
	-- If we need to set the current property accounting period do so	
	IF (@updateCurrentPeriod = 1)
	BEGIN
		UPDATE Property SET CurrentPropertyAccountingPeriodID = @propertyAccountingPeriodID 
		WHERE PropertyID = @propertyID 
		      AND AccountID = @accountID
	END
	
END



GO
