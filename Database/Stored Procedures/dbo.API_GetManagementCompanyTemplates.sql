SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[API_GetManagementCompanyTemplates]
	-- Add the parameters for the stored procedure here
	@accountID bigint
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;    

	-- Vendors
	SELECT DISTINCT
		v.CompanyName AS 'Company',
		v.Abbreviation,
		pg.PreferredName AS 'Contact',
		ag.StreetAddress AS 'GeneralAddress',
		null AS 'GeneralAddressLine2',
		ag.City AS 'GeneralCity',
		ag.[State] AS 'GeneralState',
		ag.Zip AS 'GeneralZip',
		ag.Country AS 'GeneralCountry',
		(CASE WHEN pg.Phone1Type = 'Work' THEN pg.Phone1
				WHEN pg.Phone2Type = 'Work' THEN pg.Phone2
				WHEN pg.Phone3Type = 'Work' THEN pg.Phone3
				ELSE null 
			END) AS 'GeneralWorkPhone',
		(CASE WHEN pg.Phone1Type = 'Mobile' THEN pg.Phone1
				WHEN pg.Phone2Type = 'Mobile' THEN pg.Phone2
				WHEN pg.Phone3Type = 'Mobile' THEN pg.Phone3
				ELSE null 
			END) AS 'GeneralMobilePhone',
		(CASE WHEN pg.Phone1Type = 'Fax' THEN pg.Phone1
				WHEN pg.Phone2Type = 'Fax' THEN pg.Phone2
				WHEN pg.Phone3Type = 'Fax' THEN pg.Phone3
				ELSE null 
			END) AS 'GeneralFax',
		pg.Email AS 'GeneralEmail',
		pg.Website AS 'GeneralWebsite',
		v.CustomerNumber AS 'CustomerNumber',
		v.Summary AS 'SummaryVendor',
		CONVERT(BIT, CASE WHEN ag.City = ap.City
							AND ag.Country = ap.Country
							AND ag.[State] = ap.[State]
							AND ag.StreetAddress = ap.StreetAddress
							AND ag.Zip = ap.Zip
						THEN 1
						ELSE 0
					END) AS 'PaymentSameAsGeneral',
		ap.StreetAddress AS 'PaymentAddress',
		null AS 'PaymentAddressLine2',
		ap.City AS 'PaymentCity',
		ap.[State] AS 'PaymentState',
		ap.Zip AS 'PaymentZip',
		ap.Country AS 'PaymentCountry',
		(CASE WHEN pp.Phone1Type = 'Work' THEN pp.Phone1
				WHEN pp.Phone2Type = 'Work' THEN pp.Phone2
				WHEN pp.Phone3Type = 'Work' THEN pp.Phone3
				ELSE null 
			END) AS 'PaymentWorkPhone',
		(CASE WHEN pp.Phone1Type = 'Mobile' THEN pp.Phone1
				WHEN pp.Phone2Type = 'Mobile' THEN pp.Phone2
				WHEN pp.Phone3Type = 'Mobile' THEN pp.Phone3
				ELSE null 
			END) AS 'PaymentMobilePhone',
		(CASE WHEN pp.Phone1Type = 'Fax' THEN pp.Phone1
				WHEN pp.Phone2Type = 'Fax' THEN pp.Phone2
				WHEN pp.Phone3Type = 'Fax' THEN pp.Phone3
				ELSE null 
			END) AS 'PaymentFax',
		null AS 'PaymentWorkPhone',
		null AS 'PaymentMobilePhone',
		null AS 'PaymentFax',
		pp.Email AS 'PaymentEmail',
		pp.Website AS 'PaymentWebsite',
		v.HighPriorityPayment AS 'HighPriority',
		v.PrintOnCheckAs AS 'PrintOnCheckAs',
		v.InvoiceDaysUntilDue AS 'InvoiceDaysUntilDue',
		v.Form1099Type AS 'Form1099Type',
		v.GrossProceedsPaidToAttorney AS 'GrossProceedsPaidToAttorney',
		v.SecondTINNotice AS 'SecondTINNotice',
		v.Form1099RecipientsID AS 'Form1099RecipientID',
		v.Form1099RecipientsName AS 'Form1099RecipientName',
		v.GLAccountID AS 'DefaultGLAccountID',
		v.NeedsInsurance AS 'NeedsInsurance',
		v.InsuranceExpirationDate AS 'InsuranceExpirationDate'
	FROM Vendor v
		LEFT JOIN VendorPerson vpg ON v.VendorID = vpg.VendorID
		LEFT JOIN Person pg ON vpg.PersonID = pg.PersonID
		LEFT JOIN PersonType ptg ON pg.PersonID = ptg.PersonID
		LEFT JOIN [Address] ag ON pg.PersonID = ag.ObjectID
		LEFT JOIN VendorPerson vpp ON v.VendorID = vpp.VendorID
		LEFT JOIN Person pp ON vpp.PersonID = pp.PersonID
		LEFT JOIN PersonType ptp ON pp.PersonID = ptp.PersonID
		LEFT JOIN [Address] ap ON pp.PersonID = ap.ObjectID
	WHERE v.AccountID = @accountID
		AND ptg.[Type] = 'VendorGeneral'
		AND ptp.[Type] = 'VendorPayment'
		AND v.IsActive = 1
	ORDER BY v.CompanyName

	-- Chart of Accounts
	SELECT
		g.Number AS 'Number',
		g.Name AS 'Name',
		g.[Description] AS 'Description',
		g.GLAccountType AS 'Type',
		ISNULL(p.Number, '') AS 'Parent',
		g.SummaryParent AS 'SummaryParent',
		g.IsReplacementReserve AS 'ReplacementReserve'
	FROM GLAccount g
		LEFT JOIN GLAccount p ON g.ParentGLAccountID = p.GLAccountID
	WHERE g.AccountID = @accountID
	ORDER BY g.Number

	-- Transaction Categories
	SELECT
		lit.Name AS 'Name',
		lit.Abbreviation AS 'Abbreviation',
		lit.[Description] AS 'Description',
		CASE WHEN lit.IsCharge = 1 THEN 'Charge'
			WHEN lit.IsCredit = 1 THEN 'Credit'
			WHEN lit.IsPayment = 1 THEN 'Payment'
			WHEN lit.IsDeposit = 1 THEN 'Deposit'
		END AS 'Type',
		gl.Number AS 'GLAccount',
		lit.IsRent AS 'IsRent',
		lit.IsLateFeeAssessable AS 'LateFeeAssessable',
		lit.IsRevokable AS 'LateFeeRevocable',
		'' AS 'AppliesToCategory',
		lit.OrderBy AS 'OrderBy',
		lit.IsWriteoffable AS 'WriteOfAtMOR',
		wlit.Abbreviation AS 'WriteOffCategory',
		lit.IsRecurringMonthlyRentConcession AS 'RecurringMonthlyRentConcession',
		rlit.Abbreviation AS 'RecoveryCategory'
	FROM LedgerItemType lit
		INNER JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID
		LEFT JOIN LedgerItemType wlit ON wlit.LedgerItemTypeID = lit.WriteOffLedgerItemTypeID
		LEFT JOIN LedgerItemType rlit ON lit.RecoveryLedgerItemTypeID = rlit.LedgerItemTypeID
	WHERE lit.AccountID = @accountID
		AND (lit.IsCharge = 1 OR
			 lit.IsCredit = 1 OR
			 lit.IsPayment = 1 OR
			 lit.IsDeposit = 1)
	ORDER BY lit.Name

	-- Auto Make Ready Work Orders
	SELECT
		pro.Abbreviation AS 'PropertyAbbreviation',
		amr.Abbreviation AS 'Abbreviation',
		pli.Name AS 'Category',
		amr.[Description] AS 'Description',
		p.FirstName + ' ' + p.LastName AS 'AssignedTo',
		amr.[Priority] AS 'Priority',
		amr.DaysToComplete AS 'DaysToComplete'
	FROM AutoMakeReady amr
		INNER JOIN PickListItem pli ON amr.WorkOrderCategoryID = pli.PickListItemID
		INNER JOIN Person p ON amr.AssignedToPersonID = p.PersonID
		INNER JOIN Property pro ON pro.PropertyID = amr.PropertyID
	WHERE amr.AccountID = @accountID
	ORDER BY amr.Abbreviation

END
GO
