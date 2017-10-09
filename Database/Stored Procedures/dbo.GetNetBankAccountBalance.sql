SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: Jan 16, 2012
-- Description:	Gets the sum of the Bank GL Account
--				for a given date
-- =============================================
CREATE PROCEDURE [dbo].[GetNetBankAccountBalance]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@accountingBasis nvarchar(50),
	@date date,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #BankBalances (		
		PropertyID uniqueidentifier NULL,
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 
		[Description] nvarchar(500) NULL,
		GLAccountType nvarchar(50) NOT NULL,
		ParentGLAccountID uniqueidentifier NULL,
		Depth int NOT NULL,
		IsLeaf bit NOT NULL,
		SummaryParent bit NOT NULL,
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,
		SummaryParentPath nvarchar(max) NOT NULL,
		Balance money null	
		)
		
		DECLARE @bankGLAccountTypes StringCollection
		INSERT INTO @bankGLAccountTypes VALUES ('Bank')
		
		DECLARE @accountingBookIDs GuidCollection
		INSERT INTO @accountingBookIDs VALUES ('55555555-5555-5555-5555-555555555555')

		INSERT INTO #BankBalances EXEC RPT_ACTG_BalanceSheet @propertyIDs, '', @accountingBasis, @date, @bankGLAccountTypes, null, 0, @accountingPeriodID, @accountingBookIDs
		
		SELECT ISNULL(SUM(Balance), 0) AS Balance FROM #BankBalances		
				
END
GO
