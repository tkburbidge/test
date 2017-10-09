SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 5, 2012
-- Description:	Gets the Indatus ReportIDs that should be run for this property on this given day
-- =============================================
CREATE PROCEDURE [dbo].[GetReportsToRunByPropertyID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT isqlr.IntegrationSQLReportID, ipip.IntegrationURI AS 'EmailAddress'
		FROM IntegrationSQLReport isqlr
			INNER JOIN IntegrationPartnerItemProperty ipip ON isqlr.IntegrationPartnerItemPropertyID = ipip.IntegrationPartnerItemPropertyID
		WHERE ipip.PropertyID = @propertyID
		  AND ipip.AccountID = @accountID
		  AND ((isqlr.Frequency = 'Daily')
			   OR ((isqlr.Frequency = 'Weekly') AND (isqlr.DayToRun = DATEPART(WEEKDAY, GETDATE())))
			   OR ((isqlr.Frequency = 'Monthly') AND (isqlr.DayToRun = DATEPART(DAY, GETDATE()))))
END
GO
