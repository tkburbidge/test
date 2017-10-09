SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: June 26, 2014
-- Description:	Deletes Recurring report batches tied to the ReportBatchID.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteRecurringReportBatches]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@rbid uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- delete recurring items
	DELETE ri
		FROM RecurringItem ri
		WHERE ri.AccountID = @accountID
			AND ri.RecurringItemID IN (SELECT rrbi.RecurringItemID
											FROM RecurringReportBatchItem rrbi
												JOIN RecurringReportBatch rrb on rrbi.RecurringReportBatchID = rrb.RecurringReportBatchID
											WHERE rrbi.AccountID = @accountID
												AND rrb.ReportBatchID = @rbid)

	-- delete the recurring report batch items													
	DELETE rrbi
		FROM RecurringReportBatchItem rrbi
			JOIN RecurringReportBatch rrb on rrbi.RecurringReportBatchID = rrb.RecurringReportBatchID
		WHERE rrbi.AccountID = @accountID
			AND rrb.ReportBatchID = @rbid

	-- delete the recurring report batch parameters
	DELETE rrbp
		FROM RecurringReportBatchParameter rrbp
			JOIN RecurringReportBatch rrb on rrbp.RecurringReportBatchID = rrb.RecurringReportBatchID
		WHERE rrbp.AccountID = @accountID
			AND rrb.ReportBatchID = @rbid
	
	-- delete recurring report batch
	DELETE FROM RecurringReportBatch WHERE AccountID = @accountID AND ReportBatchID = @rbid	
									
    
END
GO
