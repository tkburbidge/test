SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: Dec. 20, 2012
-- Description:	Gets the needed data to run integration partner
--				sql reports
-- =============================================
CREATE PROCEDURE [dbo].[GetIntegrationPartnerSQLReportsToRun]		
	@integrationPartnerItemID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT ipip.AccountID, ipip.PropertyID, isqlr.IntegrationSQLReportID, ipip.IntegrationURI
		FROM IntegrationSQLReport isqlr
			INNER JOIN IntegrationPartnerItemProperty ipip ON isqlr.IntegrationPartnerItemPropertyID = ipip.IntegrationPartnerItemPropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID
		WHERE ipi.IntegrationPartnerItemID = @integrationPartnerItemID
		  AND isqlr.Frequency IS NOT NULL
		  AND (isqlr.Frequency = 'Daily' OR isqlr.DayToRun IS NOT NULL)
		  AND ((isqlr.Frequency = 'Daily')
			   OR ((isqlr.Frequency = 'Weekly') AND (isqlr.DayToRun = DATEPART(WEEKDAY, GETDATE())))
			   OR ((isqlr.Frequency = 'Monthly') AND (isqlr.DayToRun = DATEPART(DAY, GETDATE()))))
END
GO
