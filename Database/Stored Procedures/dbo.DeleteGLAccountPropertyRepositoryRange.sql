SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:	Tony Morgan
-- Create date: 10/22/2014
-- Description:	Deletes all GLAccountPropertyRecords that 
--	are in both the property and GL Account Lists
-- =============================================
CREATE PROCEDURE [dbo].[DeleteGLAccountPropertyRepositoryRange]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0, 
	@glAccountIDs GuidCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
SET NOCOUNT ON;

   -- Insert statements for procedure here
	DELETE 
		glAP 
	FROM 
		GLAccountPropertyRestriction AS glAP 
	WHERE 
		glAP.AccountID = @accountID
		AND glAP.GLAccountID IN (SELECT Value FROM @glAccountIDs)
		AND glAP.PropertyID IN (SELECT Value FROM @propertyIDs)
END
GO
