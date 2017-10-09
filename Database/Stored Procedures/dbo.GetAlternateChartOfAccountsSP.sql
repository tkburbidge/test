SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 14, 2013
-- Description:	Lies on top of same table valued
--				function
-- =============================================
CREATE PROCEDURE [dbo].[GetAlternateChartOfAccountsSP]
	@accountID bigint,
	@alternateChartOfAccountsID uniqueidentifier,
	@glAccountTypes StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT * FROM GetAlternateChartOfAccounts(@accountID, @glAccountTypes, @alternateChartOfAccountsID) ORDER BY [OrderByPath]
END
GO
