SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: June 6, 2014
-- Description:	Deletes recurring items, recurring report batch items,
--				and parameters tied to a recurring report batch.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteRecurringReportBatchItems]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@rrbid uniqueidentifier = null,
	@includeBatch bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- delete recurring items tied to the recurring report batch items
    DELETE FROM RecurringItem WHERE RecurringItemID IN (SELECT RecurringItemID
															FROM RecurringReportBatchItem
															WHERE AccountID = @accountID AND RecurringReportBatchID = @rrbid)
	
	-- delete the recurring items													
	DELETE FROM RecurringReportBatchItem WHERE AccountID = @accountID AND RecurringReportBatchID = @rrbid									
	
	-- delete the recurring report batch parameters
	DELETE FROM RecurringReportBatchParameter WHERE AccountID = @accountID AND RecurringReportBatchID = @rrbid
	
	-- delete recurring report batch if needed
	DELETE FROM RecurringReportBatch WHERE AccountID = @accountID
										AND RecurringReportBatchID = @rrbid
										AND @includeBatch = 1 		
									
    
END
GO
