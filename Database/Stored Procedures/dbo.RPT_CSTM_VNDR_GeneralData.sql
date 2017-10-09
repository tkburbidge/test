SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_VNDR_GeneralData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@filters StringCollection READONLY,
	@fields StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllVendors (
		VendorID uniqueidentifier not null,
        CompanyName varchar(200) not null,
        ReceivesForm1099 bit not null,
        Form1099Type nvarchar(40) null,
        Form1099RecipientsID nvarchar(75) null,
        Form1099RecipientsName nvarchar(200) null,
        CustomerNumber nvarchar(50) null,
        Notes nvarchar(4000) null,
        DefaultGLAccountNumber nvarchar(200) null,
        DefaultGLAccountName nvarchar(200) null,
        PrintChecksAs nvarchar(250) null,
        InvoiceDaysUntilDue int null,
        IsActive bit not null,
		IsApproved bit not null,
        RequirePurchaseOrder bit not null,
        HighPrioirtyPayment bit not null,
        Abbreviation nvarchar(12) null,
        AutoEmailOnApproval bit null,
        AutoEmailOnApprovalAddress nvarchar(256) null,

        GeneralContact nvarchar(200) null,
        GeneralStreetAddress nvarchar(500) null,
        GeneralCity nvarchar(50) null,
        GeneralState nvarchar(50) null,
        GeneralZip nvarchar(20) null,
        GeneralWorkPhone nvarchar(35) null,
        GeneralMobilePhone nvarchar(35) null,
        GeneralFax nvarchar(35) null,
        GeneralEmail nvarchar(150) null,
        GeneralWebsite nvarchar(150) null,

        PaymentContact nvarchar(200) null,
        PaymentStreetAddress nvarchar(500) null,
        PaymentCity nvarchar(50) null,
        PaymentState nvarchar(50) null,
        PaymentZip nvarchar(20) null,
        PaymentWorkPhone nvarchar(35) null,
        PaymentMobilePhone nvarchar(35) null,
        PaymentFax nvarchar(35) null,
        PaymentEmail nvarchar(150) null,
        PaymentWebsite nvarchar(150) null,
		RequiredInsuranceTypes int null
	)


	INSERT INTO #AllVendors
		SELECT DISTINCT
			v.VendorID AS 'VendorID',
			v.CompanyName AS 'CompanyName',
			v.Gets1099 AS 'ReceivesForm1099',
			v.Form1099Type AS 'Form1099Type',
			v.Form1099RecipientsID AS 'Form1099RecipientsID',
			v.Form1099RecipientsName AS 'Form1099RecipientsName',
			v.CustomerNumber AS 'CustomerNumber',
			v.Notes AS 'Notes',
			gla.Number AS 'DefaultGLAccountNumber',
			gla.Name AS 'DefaultGLAccountName',
			v.PrintOnCheckAs AS 'PrintChecksAs',
			v.InvoiceDaysUntilDue AS 'InvoiceDaysUntilDue',
			v.IsActive AS 'IsActive',
			v.IsApproved AS 'IsApproved',
			v.RequirePurchaseOrder AS 'RequirePurchaseOrder',
			v.HighPriorityPayment AS 'HighPrioirtyPayment',
			v.Abbreviation AS 'Abbreviation',
			ISNULL(v.AutoEmailOnApproval, 0) AS 'AutoEmailOnApproval',
			v.AutoEmailOnApprovalAddress AS 'AutoEmailOnApprovalAddress',
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			null,
			v.RequiredInsuranceTypes	  
	FROM Vendor v
		INNER JOIN VendorProperty vprop ON v.VendorID = vprop.VendorID
		LEFT JOIN GLAccount gla ON v.GLAccountID = gla.GLAccountID
	WHERE vprop.PropertyID IN (SELECT Value FROM @propertyIDs)




	-- update vendor general information
	UPDATE #av SET
		GeneralContact = per.PreferredName,
        GeneralStreetAddress = ad.StreetAddress,
        GeneralCity = ad.City,
        GeneralState = ad.[State],
        GeneralZip = ad.Zip,
        GeneralWorkPhone = CASE WHEN (per.Phone1Type = 'Work') THEN per.Phone1
							 WHEN (per.Phone2Type = 'Work') THEN per.Phone2
							 WHEN (per.Phone3Type = 'Work') THEN per.Phone3
							 ELSE null END,
        GeneralMobilePhone = CASE WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
								 WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
								 WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
								 ELSE null END,
        GeneralFax = CASE WHEN (per.Phone1Type = 'Fax') THEN per.Phone1
						WHEN (per.Phone2Type = 'Fax') THEN per.Phone2
						WHEN (per.Phone3Type = 'Fax') THEN per.Phone3
						ELSE null END,
        GeneralEmail = per.Email,
        GeneralWebsite = per.Website
	FROM #AllVendors #av
		INNER JOIN VendorPerson vper ON #av.VendorID = vper.VendorID
		INNER JOIN Person per ON vper.PersonID = per.PersonID
		INNER JOIN PersonType pty ON per.PersonID = pty.PersonID AND pty.[Type] IN ('VendorGeneral')
		INNER JOIN [Address] ad ON ad.ObjectID = per.PersonID


	-- update vendor payment information
	UPDATE #av SET
		PaymentContact = per.PreferredName,        
		PaymentStreetAddress = ad.StreetAddress,
        PaymentCity = ad.City,
        PaymentState = ad.[State],
        PaymentZip = ad.Zip,
        PaymentWorkPhone = CASE WHEN (per.Phone1Type = 'Work') THEN per.Phone1
							 WHEN (per.Phone2Type = 'Work') THEN per.Phone2
							 WHEN (per.Phone3Type = 'Work') THEN per.Phone3
							 ELSE null END,
        PaymentMobilePhone = CASE WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
								 WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
								 WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
								 ELSE null END,
        PaymentFax = CASE WHEN (per.Phone1Type = 'Fax') THEN per.Phone1
						WHEN (per.Phone2Type = 'Fax') THEN per.Phone2
						WHEN (per.Phone3Type = 'Fax') THEN per.Phone3
						ELSE null END,
        PaymentEmail = per.Email,
        PaymentWebsite = per.Website
	FROM #AllVendors #av
		INNER JOIN VendorPerson vper ON #av.VendorID = vper.VendorID
		INNER JOIN Person per ON vper.PersonID = per.PersonID
		INNER JOIN PersonType pty ON per.PersonID = pty.PersonID AND pty.[Type] IN ('VendorPayment')
		INNER JOIN [Address] ad ON ad.ObjectID = per.PersonID
	


	SELECT * FROM #AllVendors
	ORDER BY CompanyName
END
GO
