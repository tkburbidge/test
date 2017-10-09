SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 26, 2013
-- Description:	Gets the Aptexx enrolled accounts for a given server.
-- =============================================
CREATE PROCEDURE [dbo].[GetAptexxEnrolledAccounts] 
	-- Add the parameters for the stored procedure here
  @accountID bigint = null
	  
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    SELECT	DISTINCT
			s.CompanyID AS 'CompanyID',
			s.AccountID AS 'AccountID',
			s.AptexxExternalID  AS 'AccountExternalID',
			ipip.Value1 AS 'ExternalID',
			ipip.Value2 AS 'BankAccountID',
			ipip.PropertyID AS 'PropertyID',
			ipi.IntegrationPartnerItemID AS 'IntegrationPartnerItemID',
			s.PaymentProcessorFeesGLAccountID AS 'PaymentProcessorFeesGLAccountID',
			ba.GLAccountID AS 'BankGLAccountID'
		FROM IntegrationPartnerItemProperty ipip
			INNER JOIN IntegrationPartnerItem ipi ON ipip.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
			INNER JOIN Settings s ON ipip.AccountID = s.AccountID
			LEFT JOIN BankAccount ba ON ba.BankAccountID = ipip.Value2
		WHERE ipi.IntegrationPartnerID = 1013
		  AND ((@accountID IS NULL) OR (@accountID = s.AccountID))
		  AND ipi.IntegrationPartnerItemID IN (31, 32, 33)
		
END
GO
