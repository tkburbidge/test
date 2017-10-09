SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Jordan Betteridge
-- Create date: February 13, 2014
-- Description:	Returns detailed information about all banks
--              associated with the given PropertyIDs
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_BankListings]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Create Bank Temp Tables

	-- Create LastPayment Temp table

    -- Insert statements for procedure here
	-- INSERT INTO #temp
	SELECT DISTINCT
		ba.AccountName,
		ba.AccountNumberDisplay AS 'AccountNumber',
		ba.RoutingNumber,
		ba.BankLine1,
		ba.BankLine2,
		ba.BankLine3,
		ba.BankLine4,
		ba.BankLine5,
		ba.CompanyLine1,
		ba.CompanyLine2,
		ba.CompanyLine3,
		ba.CompanyLine4,
		ba.CompanyLine5,
		ba.Phone AS 'PhoneNumber',
		gla.Number + ' - ' + gla.Name AS 'GLAccountNumberName',
		(SELECT TOP 1 p.[Date]
		 FROM Payment p					 
		 INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
		 INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID		 
		 WHERE t.AccountID = @accountID
			AND p.[Type] = 'Check'
			AND t.ObjectID = ba.BankAccountID
		ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS 'LastCheckDate',

		(SELECT TOP 1 p.ReferenceNumber
		 FROM Payment p					 
		 INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
		 INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID		 
		 WHERE t.AccountID = @accountID
			AND p.[Type] = 'Check'
			AND t.ObjectID = ba.BankAccountID
		ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS 'LastCheckNumber',

		(SELECT TOP 1 p.ReceivedFromPaidTo
		 FROM Payment p					 
		 INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
		 INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID		 
		 WHERE t.AccountID = @accountID
			AND p.[Type] = 'Check'
			AND t.ObjectID = ba.BankAccountID
		ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS 'LastCheckPayee'

		FROM BankAccount ba
			INNER JOIN BankAccountProperty bap ON ba.BankAccountID = bap.BankAccountID
			INNER JOIN GLAccount gla ON ba.GLAccountID = gla.GLAccountID
		WHERE bap.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND ba.AccountID = @accountID
				



	
END
GO
