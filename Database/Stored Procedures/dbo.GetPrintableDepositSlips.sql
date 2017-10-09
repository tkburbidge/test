SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 10, 2014
-- Description:	Gets printable deposit slips
-- Update Date: Oct. 5, 2015
-- Update Description: added Payment.ObjectID & Payment.ObjectType to the selection
-- =============================================
CREATE PROCEDURE [dbo].[GetPrintableDepositSlips] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankTransactionIDs GuidCollection READONLY,
	@userID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
			bt.BankTransactionID AS 'BankTransactionID',
			bat.[Date] AS 'Date',
			(SELECT SUM(t.Amount)
				FROM BankTransactionTransaction btt
					INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
				WHERE btt.BankTransactionID = bt.BankTransactionID) AS 'Amount', 
			pay.PaymentID AS 'PaymentID',
			pay.ReferenceNumber AS 'Reference',
			pay.[Date] AS 'PaymentDate',
			pay.ReceivedFromPaidTo AS 'Residents',
			pay.ObjectID AS 'PaymentObjectID',
			pay.ObjectType AS 'PaymentObjectType',
			--STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
			--	 FROM Person 
			--		 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
			--		 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
			--		 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
			--	 WHERE PersonLease.LeaseID = l.LeaseID
			--		   AND PersonType.[Type] = 'Resident'				   
			--		   AND PersonLease.MainContact = 1				   
			--	 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
			pay.[Description] AS 'Description',
			pay.[Type] AS 'PaymentMethod',
			pay.Amount As 'PaymentAmount',
			
			ba.CompanyLine1 AS 'CompanyLine1',
			ba.CompanyLine2 AS 'CompanyLine2',
			ba.CompanyLine3 AS 'CompanyLine3',
			ba.CompanyLine4 AS 'CompanyLine4',
			ba.CompanyLine5 AS 'CompanyLine5',
			
			ba.AccountName + ' - ' + ba.AccountNumberDisplay AS 'BankAccountName',
			ba.BankLine1 AS 'BankLine1',
			ba.BankLine2 AS 'BankLine2',
			ba.BankLine3 AS 'BankLine3',
			ba.BankLine4 AS 'BankLine4',
			ba.BankLine5 AS 'BankLine5',
			ba.FractionalNumber AS 'BankFractionalNumber',
			ba.AccountNumber AS 'AccountNumber',
			ba.DepositSlipRoutingNumber AS 'RoutingNumber',
			
			dpp.PrintCompanyInfo,
			dpp.PrintSignature,
			dpp.PrintBankInfo,
			dpp.PrintMICRLine,
			dpp.PrintFractionalNumber,
			dpp.PrintTotalNumberDeposits,
			dpp.PrintGrandTotal,
			
			dpp.CompanyInfoTopOffset,
			dpp.CompanyInfoLeftOffset,
			dpp.DateTopOffset,
			dpp.DateLeftOffset,
			dpp.SignatureTopOffset,
			dpp.SignatureLeftOffset,
			dpp.BankInfoTopOffset,
			dpp.BankInfoLeftOffset,
			dpp.MICRTopOffset,
			dpp.MICRLeftOffset,
			dpp.FractionalNumberTopOffset,
			dpp.FractionalNumberLeftOffset,
			dpp.FirstCheckColumnTopOffset,
			dpp.FirstCheckColumnLeftOffset,
			dpp.SecondCheckColumnTopOffset,
			dpp.SecondCheckColumnLeftOffset,
			dpp.ThirdCheckColumnTopOffset,
			dpp.ThirdCheckColumnLeftOffset,
			dpp.TotalNumberDepositsTopOffset,
			dpp.TotalNumberDepositsLeftOffset,
			dpp.GrandTotalTopOffset,
			dpp.GrandTotalLeftOffset
		FROM BankTransaction bt
			INNER JOIN BankTransactionTransaction bttForBA ON bt.BankTransactionID = bttForBA.BankTransactionID
			INNER JOIN [Transaction] tForBA ON bttForBA.TransactionID = tForBA.TransactionID
			INNER JOIN BankAccount ba ON tForBA.ObjectID = ba.BankAccountID
			INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
			INNER JOIN Payment pay ON bat.BatchID = pay.BatchID
			--INNER JOIN Person per ON pay.PayerPersonID = per.PersonID
			--INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
			--INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			--INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			LEFT JOIN DepositPrintingProfile dpp ON ba.DepositPrintingProfileID = dpp.DepositPrintingProfileID
		WHERE bt.BankTransactionID IN (SELECT Value FROM @bankTransactionIDs)



END

GO
