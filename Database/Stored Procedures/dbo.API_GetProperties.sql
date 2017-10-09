SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: November 15, 2013
-- Description:	Gets all the Properties that are integrated with the account
-- =============================================
CREATE PROCEDURE [dbo].[API_GetProperties] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@integrationPartnerID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
		pro.PropertyID
		,pro.Name
		,a.StreetAddress
		,a.City
		,a.[State]
		,a.Zip
		,pro.PhoneNumber AS 'Phone'
		,pro.Email
		,per.PreferredName + ' ' + per.LastName AS 'Manager'
		,ap.StartDate AS 'CurrentAccountingPeriodStart'
		,ap.EndDate AS 'CurrentAccountingPeriodEnd'
	FROM Property pro
		LEFT JOIN Person per on pro.ManagerPersonID = per.PersonID
		INNER JOIN [Address] a on pro.PropertyID = a.ObjectID
		INNER JOIN IntegrationPartnerItemProperty ipip on pro.PropertyID = ipip.PropertyID
		INNER JOIN IntegrationPartnerItem ipi on ipip.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
		INNER JOIN PropertyAccountingPeriod pap on pro.CurrentPropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
		INNER JOIN AccountingPeriod ap on pap.AccountingPeriodID = ap.AccountingPeriodID
	WHERE 
		pro.AccountID = @accountID
		AND ipi.IntegrationPartnerID = @integrationPartnerID
END	
GO
