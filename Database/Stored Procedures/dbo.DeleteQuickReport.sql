SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
CREATE PROCEDURE [dbo].[DeleteQuickReport] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@quickReportID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
    
    DECLARE @rbrIDs AS TABLE (
		rbrID uniqueidentifier
	)
	
	--Select the ReportBatchReport for the quick report and any other ReportBatchReports stemming from this quick report
	-- that were part of other report batches 
	INSERT INTO @rbrIDs
		SELECT ReportBatchReportID FROM ReportBatchReport 
		WHERE QuickReportReportBatchID = @quickReportID 
			OR ReportBatchID = @quickReportID
		
	--Delete the ReportBatch for the quick report.
	DELETE FROM ReportBatch 
	WHERE AccountID = @accountID
		AND ReportBatchID = @quickReportID
		
	--Delete the ReportBatchReports that we selected earlier
	DELETE ReportBatchReport
	FROM ReportBatchReport rbr
	WHERE rbr.AccountID = @accountID
		AND rbr.ReportBatchReportID IN (SELECT rbrID FROM @rbrIDs)
	
	--Delete the BatchReportParameters that were associated with the ReportBatchReports
    DELETE BatchReportParameter
    FROM BatchReportParameter brp
	WHERE brp.AccountID = @accountID
		AND brp.ReportBatchReportID IN (SELECT rbrID FROM @rbrIDs)
    
END
GO
