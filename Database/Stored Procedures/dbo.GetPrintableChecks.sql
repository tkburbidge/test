SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: March 21, 2012
-- Description:	Gets the information needed to print checks
-- =============================================
CREATE PROCEDURE [dbo].[GetPrintableChecks]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@bankTransactionIDs GuidCollection readonly,
	@checkPrintingProfileID uniqueidentifier,
	@userID uniqueidentifier	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT DISTINCT
		   p.PaymentID,
		   p.ReferenceNumber AS 'CheckNumber',
		   p.[Date],
		   p.Amount,
		   p.ReceivedFromPaidTo AS 'PayTo',
		   p.Notes,
		   p.[Description] AS 'Memo',		   
		   CASE WHEN p.ObjectType = 'Vendor' THEN va.StreetAddress
			    WHEN p.ObjectType = 'SummaryVendor' THEN sva.StreetAddress
			    WHEN p.ObjectType = 'Resident Person' THEN rfa.StreetAddress
			    WHEN p.ObjectType = 'Prospect' THEN pa.StreetAddress
			    WHEN p.ObjectType = 'Non-Resident Account' THEN nraa.StreetAddress
		   END AS 'StreetAddress',
		   CASE WHEN p.ObjectType = 'Vendor' THEN va.City
			    WHEN p.ObjectType = 'SummaryVendor' THEN sva.City
			    WHEN p.ObjectType = 'Resident Person' THEN rfa.City
			    WHEN p.ObjectType = 'Prospect' THEN pa.City
			    WHEN p.ObjectType = 'Non-Resident Account' THEN nraa.City
		   END AS 'City',
		   CASE WHEN p.ObjectType = 'Vendor' THEN va.State
			    WHEN p.ObjectType = 'SummaryVendor' THEN sva.State
			    WHEN p.ObjectType = 'Resident Person' THEN rfa.State
			    WHEN p.ObjectType = 'Prospect' THEN pa.State
			    WHEN p.ObjectType = 'Non-Resident Account' THEN nraa.State
		   END AS 'State',
		    CASE WHEN p.ObjectType = 'Vendor' THEN va.Zip
			    WHEN p.ObjectType = 'SummaryVendor' THEN sva.Zip
			    WHEN p.ObjectType = 'Resident Person' THEN rfa.Zip
			    WHEN p.ObjectType = 'Prospect' THEN pa.Zip
			    WHEN p.ObjectType = 'Non-Resident Account' THEN nraa.Zip
		   END AS 'Zip',
		    CASE WHEN p.ObjectType = 'Vendor' THEN va.Country
			    WHEN p.ObjectType = 'SummaryVendor' THEN sva.Country
			    WHEN p.ObjectType = 'Resident Person' THEN rfa.Country
			    WHEN p.ObjectType = 'Prospect' THEN pa.Country
			    WHEN p.ObjectType = 'Non-Resident Account' THEN nraa.Country
		   END AS 'Country',
		   tt.Name AS 'TransactionType',
		   p.[TimeStamp],
		   basr.SignedCheckThreshold,
		   ba.BankLine1,
		   ba.BankLine2,
		   ba.BankLine3,
		   ba.BankLine4,
		   ba.BankLine5,
		   ba.CompanyLine1 AS 'PropertyLine1',
		   ba.CompanyLine2 AS 'PropertyLine2',
		   ba.CompanyLine3 AS 'PropertyLine3',
		   ba.CompanyLine4 AS 'PropertyLine4',
		   ba.CompanyLine5 AS 'PropertyLine5',
		   ba.AccountNumber,
		   ba.AccountOpenDate,
		   ba.FractionalNumber AS 'BankFractionalNumber',
		   ba.RoutingNumber,
		   ba.VoucherCompanyLine,
		   cpp.SignatureLineText,
		   cpp.VoucherLine2,		   
		   --ISNULL(vprop.CustomerNumber, v.CustomerNumber) as VendorCustomerNumber,
		   -- Get the vendor level customer number 
		   v.CustomerNumber AS 'VendorCustomerNumber',		   
		   -- If there are multiple properties on this payment
		   -- there might be multiple customer numbers.  Join them here
		   -- and return them
		   STUFF((SELECT ', ' + CustomerNumber
			FROM 
			  (SELECT DISTINCT vp2.CustomerNumber
			   FROM PaymentTransaction pt2 
			   INNER JOIN [Transaction] t2 ON t2.TransactionID = pt2.TransactionID
			   INNER JOIN VendorProperty vp2 ON vp2.PropertyID = t2.PropertyID AND vp2.VendorID = p.ObjectID
			   WHERE pt2.PaymentID = p.PaymentID
				AND vp2.CustomerNumber IS NOT NULL
				AND vp2.CustomerNumber <> '') cns
			   FOR XML PATH ('')), 1, 2, '') AS JoinedVendorCustomerNumber,		   
		   ISNULL(cpp.PrintBankInfo, 0) AS PrintBankInfo,
		   ISNULL(cpp.PrintCheckNumber, 0) AS PrintCheckNumber,
		   ISNULL(cpp.PrintCompanyInfo, 0) AS PrintCompanyInfo,
		   ISNULL(cpp.PrintDateLine, 0) AS PrintDateLine,
		   ISNULL(cpp.PrintPayToLabel, 0) AS PrintPayToLabel,
		   ISNULL(cpp.PrintPayToLine, 0) AS PrintPayToLine,
		   ISNULL(cpp.PrintAmountLabel, 0) AS PrintAmountLabel,
		   ISNULL(cpp.PrintAmountLine, 0) AS PrintAmountLine,
		   ISNULL(cpp.PrintTextAmountLine, 0) AS PrintTextAmountLine,
		   ISNULL(cpp.PrintMemoLabel, 0) AS PrintMemoLabel,
		   ISNULL(cpp.PrintMemoLine, 0) AS PrintMemoLine,
		   ISNULL(cpp.PrintMICRLine, 0) AS PrintMICRLine,
		   ISNULL(cpp.PrintCompanyInfo, 0) AS 'PrintPropertyInfo',
		   ISNULL(cpp.PrintVendorCustomerNumber, 0) AS 'PrintVendorCustomerNumber',		  
		   (CASE WHEN ISNULL(cpp.SignatureLines, 0) > 0 THEN CAST (1 AS BIT) ELSE CAST(0 AS BIT) END) AS 'PrintSignatureLine1',
		   (CASE WHEN ISNULL(cpp.SignatureLines, 0) > 1 THEN CAST (1 AS BIT) ELSE CAST(0 AS BIT) END) AS 'PrintSignatureLine2',		   
		   ISNULL(cpp.BankInfoLeftOffset, 0) AS BankInfoLeftOffset,
		   ISNULL(cpp.BankInfoTopOffset, 0) AS BankInfoTopOffset,
		   ISNULL(cpp.CheckNumberLeftOffset, 0) AS CheckNumberLeftOffset,
		   ISNULL(cpp.CheckNumberTopOffset, 0) AS CheckNumberTopOffset,
		   ISNULL(cpp.CompanyInfoLeftOffset, 0) AS PropertyInfoLeftOffset,
		   ISNULL(cpp.CompanyInfoTopOffset, 0) AS PropertyInfoTopOffset,
		   ISNULL(cpp.DateLeftOffset, 0) AS DateLeftOffset,
		   ISNULL(cpp.DateTopOffset, 0) AS DateTopOffset,
		   ISNULL(cpp.MICRLeftOffset, 0) AS MICRLeftOffset,
		   ISNULL(cpp.MICRTopOffset, 0) AS MICRTopOffset,
		   ISNULL(cpp.MemoLeftOffset, 0) AS MemoLeftOffset,
		   ISNULL(cpp.MemoTopOffset, 0) AS MemoTopOffset,
		   ISNULL(cpp.PayToAddressLeftOffset, 0) AS AddressLeftOffset,
		   ISNULL(cpp.PayToAddressTopOffset, 0) AS AddressTopOffset,
		   ISNULL(cpp.PayToLeftOffset, 0) AS PayToLeftOffset,
		   ISNULL(cpp.PayToTopOffset, 0) AS PayToTopOffset,		  
		   ISNULL(cpp.SignatureLeftOffset, 0) AS SignatureLeftOffset,
		   ISNULL(cpp.SignatureTopOffset, 0) AS SignatureTopOffset,		   		   
		   ISNULL(cpp.Voucher1LeftOffset, 0) AS Voucher1LeftOffset,
		   ISNULL(cpp.Voucher1TopOffset, 0) AS Voucher1TopOffset,
		   ISNULL(cpp.Voucher2LeftOffset, 0) AS Voucher2LeftOffset,
		   ISNULL(cpp.Voucher2TopOffset, 0) AS Voucher2TopOffset,		   
		   ISNULL(cpp.WrittenAmountLeftOffset, 0) AS WrittenAmountLeftOffset,
		   ISNULL(cpp.WrittenAmountTopOffset, 0) AS WrittenAmountTopOffset,
		   ISNULL(cpp.AmountLeftOffset,0) AS AmountLeftOffset,
		   ISNULL(cpp.AmountTopOffset,0) AS AmountTopOffset,
		   ISNULL(cpp.Signature1LeftOffset,0) AS Signature1LeftOffset,
		   ISNULL(cpp.Signature1TopOffset,0) AS Signature1TopOffset,
		   ISNULL(cpp.Signature2LeftOffset,0) AS Signature2LeftOffset,
		   ISNULL(cpp.Signature2TopOffset,0) AS Signature2TopOffset,
		   ISNULL(cpp.VendorCustomerNumberTopOffset, 0) AS VendorCustomerNumberTopOffset,
		   ISNULL(cpp.VendorCustomerNumberLeftOffset, 0) AS VendorCustomerNumberLeftOffset,
		   ISNULL(cpp.SecondSignatureThreshold, 0) AS SecondSignatureThreshold,
		   ba.AccountName
		   --pro.Name
	FROM BankTransaction bt
	INNER JOIN Payment p on bt.ObjectID = p.PaymentID
	INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
	INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID	
	INNER JOIN TransactionType tt on t.TransactionTypeID = tt.TransactionTypeID AND tt.Name  IN ('Payment', 'Refund', 'Check')
	INNER JOIN BankAccount ba on ba.BankAccountID = t.ObjectID		
	LEFT JOIN CheckPrintingProfile cpp ON cpp.CheckPrintingProfileID = COALESCE(@checkPrintingProfileID ,ba.CheckPrintingProfileID)
	--INNER JOIN Property pro ON pro.PropertyID = t.PropertyID	
	--INNER JOIN BankAccountProperty bapro ON ba.BankAccountID = bapro.BankAccountID AND pro.PropertyID = bapro.PropertyID
	-- Deal with vendor payment address
	LEFT JOIN [Vendor] v ON v.VendorID = p.ObjectID
	--LEFT JOIN VendorProperty vprop ON vprop.VendorID = v.VendorID AND vprop.PropertyID = pro.PropertyID
	LEFT JOIN [VendorPerson] vp ON vp.VendorID = v.VendorID
	LEFT JOIN [Person] per ON per.PersonID = vp.PersonID
	LEFT JOIN [PersonType] pert ON pert.PersonID = per.PersonID
	LEFT JOIN [Address] va ON va.ObjectID = per.PersonID AND va.AddressType = 'VendorPayment'
	-- End deal with vendor payment address
	LEFT JOIN [Address] sva ON sva.ObjectID = p.ObjectID AND sva.AddressType = 'Summary Vendor'
	LEFT JOIN [Address] rfa ON rfa.ObjectID = p.ObjectID AND rfa.AddressType = 'Forwarding'
	LEFT JOIN [Address] pa ON pa.ObjectID = p.ObjectID AND pa.AddressType = 'Prospect'
	LEFT JOIN [Address] nraa ON nraa.ObjectID = p.ObjectID AND pa.AddressType = 'Non-Resident Account'
	-- SecurityRoleThreshold
	LEFT JOIN BankAccountSecurityRole basr on ba.BankAccountID = basr.BankAccountID
	LEFT JOIN SecurityRole sr on basr.SecurityRoleID = sr.SecurityRoleID
	LEFT JOIN [User] u on sr.SecurityRoleID = u.SecurityRoleID
	WHERE bt.BankTransactionID IN (SELECT Value FROM @bankTransactionIDs)		
		  AND (v.VendorID IS NULL OR pert.[Type] = 'VendorPayment')
		  and (u.UserID IS NULL OR u.UserID = @userID)
		  AND (basr.BankAccountSecurityRoleID IS NULL OR basr.SecurityRoleID = sr.SecurityRoleID)
		  AND (sr.SecurityRoleID IS NULL OR sr.SecurityRoleID = u.SecurityRoleID)
	ORDER BY ba.AccountName, p.[Timestamp], p.ReceivedFromPaidTo
END
GO
