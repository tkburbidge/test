SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

															   
												
CREATE PROCEDURE [dbo].[GetInvoicesForPayment] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@vendorOrVendorGroupID uniqueidentifier = null,
	@selectStates bit, 
	@dueBefore datetime = null,
	@highPriorityPaymentOnly bit = 0,
	@groupByInvoice bit = 0,
	@invoiceIDs GuidCollection READONLY,
	@excludeMultiProperty bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #InvoiceForPayment (
		PropertyName			nvarchar(500)		not null,
		PropertyID				uniqueidentifier	not null,
		InvoiceID				uniqueidentifier	not null,
		VendorID				uniqueidentifier	not null,
		Vendor					nvarchar(500)		not null,
		PrintOnCheckAs			nvarchar(500)		null,
		InvoiceNumber			nvarchar(500)		not null,
		InvoiceDate				date				not null,
		AccountingDate			date				not null,
		DueDate					date				not null,
		Credit					bit					not null,
		[Description]			nvarchar(500)		not null,
		Total					money				null,
		AmountPaid				money				null,
		LastPaymentDate			datetime			null,
		SummaryVendor			bit					not null,
		PropertyAbbreviation	nvarchar(50)		null,
		DefaultBankAccountID	uniqueidentifier	null,
		OneCheckPerInvoice		bit					not null,
		IsHighPriorityPayment	bit					not null,
		HasDocuments			bit					not null,
		HoldDate				date				null,
		PostingPersonName		nvarchar(50)		null,
		BatchNumber				int					null,
		IsAchEnabled			bit					not null,
		IsEFTOnly				bit					not null
		)
		
	INSERT #InvoiceForPayment
		SELECT DISTINCT 
				p.Name, p.PropertyID, i.InvoiceID, i.VendorID, 
				(CASE WHEN i.SummaryVendorID IS NOT NULL THEN sv.Name ELSE v.CompanyName END) AS 'Vendor', 
				v.PrintOnCheckAs,
				i.Number AS 'InvoiceNumber', i.InvoiceDate, i.AccountingDate, i.DueDate, i.Credit, i.[Description],
				0.0, 0.0,
				null,
				(CASE WHEN i.SummaryVendorID IS NOT NULL THEN 1 ELSE 0 END) AS 'SummaryVendor',
				p.Abbreviation AS 'PropertyAbbreviation',
				p.DefaultAPBankAccountID AS 'DefaultBankAccountID',
				v.OneCheckPerInvoice,
				v.HighPriorityPayment,
				(CASE WHEN d.DocumentID IS NOT NULL THEN 1 ELSE 0 END) AS 'HasDocuments',
				i.HoldDate,
				per.PreferredName + ' ' + per.LastName AS 'PostingPersonName',
				0 AS 'BatchNumber',
				(CASE WHEN (v.BankRoutingNumber IS NOT NULL OR v.BankRoutingNumber <> '') AND (v.BankAccountNumber IS NOT NULL OR v.BankAccountNumber <> '') THEN 1 ELSE 0 END) as 'IsAchEnabled',
				v.EFTPaymentsOnly AS 'IsEFTOnly'
			FROM Invoice i
				LEFT JOIN Person per on i.CreatedByPersonID = per.PersonID
				INNER JOIN Vendor v on v.VendorID = i.VendorID
				LEFT JOIN VendorGroupVendor vgv on vgv.VendorID = v.VendorID
				INNER JOIN InvoiceLineItem ili on i.InvoiceID = ili.InvoiceID
				INNER JOIN [Transaction] t on ili.TransactionID = t.TransactionID
				INNER JOIN Property p on t.PropertyID = p.PropertyID		
				LEFT JOIN SummaryVendor sv on sv.SummaryVendorID = i.SummaryVendorID
				LEFT JOIN Document d on d.ObjectID = i.InvoiceID
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND ((@vendorOrVendorGroupID is null) OR (v.VendorID = @vendorOrVendorGroupID) OR (vgv.VendorGroupID = @vendorOrVendorGroupID))
			  AND ((@selectStates <> 1) OR ((select top 1 POInvoiceNote.[Status] from POInvoiceNote where ObjectID = i.InvoiceID order by [Timestamp] desc) 
						in ('Approved', 'Approved-R', 'Partially Paid', 'Partially Paid-R', 'Unapplied', 'Partially Applied')))
			  AND ((@dueBefore is null) OR (i.DueDate <= @dueBefore))
			  AND ((@highPriorityPaymentOnly = 0) OR (v.HighPriorityPayment = 1))
			  AND (((SELECT COUNT(*) FROM @invoiceIDs) = 0) OR (i.InvoiceID IN (SELECT Value FROM @invoiceIDs)))
			  AND (@excludeMultiProperty = 0 OR (SELECT COUNT(DISTINCT(p1.PropertyID)) 
													FROM Property p1
														INNER JOIN [Transaction] t on t.PropertyID = p1.PropertyID
														INNER JOIN InvoiceLineItem ili1 on ili1.TransactionID = t.TransactionID
													WHERE
														ili1.InvoiceID = i.InvoiceID) = 1)
		OPTION (RECOMPILE)

	--UPDATE #InvoiceForPayment SET 
	--	Total = ISNULL((SELECT SUM(ISNULL(t1.Amount, 0))
	--				FROM #InvoiceForPayment #IFP
	--					INNER JOIN InvoiceLineItem ilt on ilt.InvoiceID = #IFP.InvoiceID
	--					INNER JOIN [Transaction] t1 on ilt.TransactionID = t1.TransactionID
	--					INNER JOIN Property p ON t1.PropertyID = p.PropertyID AND p.Name = #IFP.PropertyName
	--				WHERE #InvoiceForPayment.InvoiceID = #IFP.InvoiceID
	--				GROUP BY #IFP.InvoiceID), 0),
	--	AmountPaid = ISNULL((SELECT SUM(ISNULL(t2.Amount, 0))
	--				FROM #InvoiceForPayment #IFP
	--					INNER JOIN InvoiceLineItem ilt on ilt.InvoiceID = #IFP.InvoiceID
	--					INNER JOIN [Transaction] t1 on ilt.TransactionID = t1.TransactionID
	--					INNER JOIN Property p ON t1.PropertyID = p.PropertyID AND p.Name = #IFP.PropertyName
	--					LEFT JOIN [Transaction] t2 on t1.TransactionID = t2.AppliesToTransactionID
	--				WHERE #InvoiceForPayment.InvoiceID = #IFP.InvoiceID
	--					  -- Exclude reversed payments
	--					AND NOT EXISTS (SELECT * 
	--									FROM [Transaction] t3
	--									WHERE t3.ReversesTransactionID = t2.TransactionID)
	--				GROUP BY #IFP.InvoiceID), 0),
	--	LastPaymentDate = (SELECT TOP 1 t2.TransactionDate
	--				FROM #InvoiceForPayment #IFP
	--					INNER JOIN InvoiceLineItem ilt on ilt.InvoiceID = #IFP.InvoiceID
	--					INNER JOIN [Transaction] t1 on ilt.TransactionID = t1.TransactionID
	--					LEFT JOIN [Transaction] t2 on t1.TransactionID = t2.AppliesToTransactionID
	--				WHERE #InvoiceForPayment.InvoiceID = #IFP.InvoiceID
	--				ORDER BY t2.TransactionDate DESC)

	UPDATE #ifp 
		SET #ifp.Total = (SELECT ISNULL(SUM(t1.Amount), 0)
								 FROM [Transaction] t1
									INNER JOIN InvoiceLineItem ili1 ON t1.TransactionID = ili1.TransactionID
									INNER JOIN Invoice i1 ON ili1.InvoiceID = i1.InvoiceID
									INNER JOIN #InvoiceForPayment #ifp1 ON i1.InvoiceID = #ifp1.InvoiceID
									INNER JOIN Property p1 ON t1.PropertyID = p1.PropertyID AND #ifp1.PropertyName = p1.Name
								 WHERE #ifp1.InvoiceID = #ifp.InvoiceID
								   AND #ifp1.PropertyName = p.Name
								 GROUP BY #ifp1.InvoiceID, #ifp1.PropertyName),
			#ifp.AmountPaid = ISNULL((SELECT ISNULL(SUM(t2.Amount), 0)
									FROM [Transaction] t2
										INNER JOIN [Transaction] t1 ON t2.AppliesToTransactionID = t1.TransactionID
										INNER JOIN InvoiceLineItem ili1 ON t1.TransactionID = ili1.TransactionID
										INNER JOIN Invoice i1 ON ili1.InvoiceID = i1.InvoiceID
										INNER JOIN #InvoiceForPayment #ifp1 ON i1.InvoiceID = #ifp1.InvoiceID
										INNER JOIN Property p1 ON t1.PropertyID = p1.PropertyID AND #ifp1.PropertyName = p1.Name
										LEFT JOIN [Transaction] tr ON t2.TransactionID = tr.ReversesTransactionID
									WHERE #ifp1.InvoiceID = #ifp.InvoiceID
									  AND #ifp1.PropertyName = p.Name
									  AND tr.TransactionID IS NULL
									GROUP BY #ifp1.InvoiceID, #ifp1.PropertyName), 0)			
			-- Not needed and messes up the result set if we are grouping by invoice and not property
			--,
			--#ifp.LastPaymentDate = (SELECT TOP 1 t3.TransactionDate
			--						FROM [Transaction] t3
			--							INNER JOIN [Transaction] t1 ON t3.AppliesToTransactionID = t1.TransactionID
			--							INNER JOIN InvoiceLineItem ili1 ON t1.TransactionID = ili1.TransactionID
			--							INNER JOIN Invoice i1 ON ili1.InvoiceID = i1.InvoiceID
			--							INNER JOIN #InvoiceForPayment #ifp1 ON i1.InvoiceID = #ifp1.InvoiceID
			--							INNER JOIN Property p1 ON t1.PropertyID = p1.PropertyID AND #ifp1.PropertyName = p1.Name
			--							LEFT JOIN [Transaction] tr ON t3.TransactionID = tr.ReversesTransactionID
			--						WHERE #ifp1.InvoiceID = #ifp.InvoiceID
			--						  AND #ifp1.PropertyName = p.Name
			--						  AND tr.TransactionID IS NULL
			--							ORDER BY t3.TransactionDate DESC)
		FROM [Transaction] t
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
			INNER JOIN #InvoiceForPayment #ifp ON i.InvoiceID = #ifp.InvoiceID
			INNER JOIN Property p ON #ifp.PropertyName = p.Name AND t.PropertyID = p.PropertyID	
	
	IF (@groupByInvoice = 0)
	BEGIN				
		UPDATE #ifp
			SET #ifp.BatchNumber = (SELECT TOP 1 b.Number
										FROM InvoiceBatch ib
											INNER JOIN Invoice i ON i.InvoiceID = ib.InvoiceID AND i.InvoiceID = #ifp.InvoiceID
											INNER JOIN Batch b ON b.BatchID = ib.BatchID
											INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID AND pap.PropertyID = #ifp.PropertyID)
		FROM #InvoiceForPayment #ifp

		SELECT * FROM #InvoiceForPayment 
		WHERE (Total - AmountPaid) <> 0
		  AND ((select top 1 POInvoiceNote.[Status] from POInvoiceNote where ObjectID = #InvoiceForPayment.InvoiceID order by [Timestamp] desc) <> 'Void')
		ORDER BY Vendor, DueDate
	END
	ELSE
	BEGIN
		SELECT	DISTINCT
				NULL AS 'PropertyName',
				cast('00000000-0000-0000-0000-000000000000' as uniqueidentifier) AS 'PropertyID',
				InvoiceID AS 'InvoiceID',
				VendorID AS 'VendorID',
				Vendor AS 'Vendor',
				PrintOnCheckAs AS 'PrintOnCheckAs',
				InvoiceNumber AS 'InvoiceNumber',
				InvoiceDate AS 'InvoiceDate',
				AccountingDate AS 'AccountingDate',
				DueDate AS 'DueDate',
				Credit AS 'Credit',
				[Description] AS 'Description',
				SUM(Total) AS 'Total',
				SUM(AmountPaid) AS 'AmountPaid',				
				NULL AS 'LastPaymentDate',
				SummaryVendor AS 'SummaryVendor',
				STUFF((SELECT ', ' + #i2.PropertyAbbreviation
						 FROM #InvoiceForPayment #i2
						 WHERE #i2.InvoiceID = #InvoiceForPayment.InvoiceID 			  
						 FOR XML PATH ('')), 1, 2, '') AS 'PropertyAbbreviation',			
				NULL AS 'DefaultBankAccountID',
				OneCheckPerInvoice AS 'OneCheckPerInvoice',
				IsHighPriorityPayment AS 'IsHighPriorityPayment',
				HasDocuments AS 'HasDocuments',
				HoldDate AS 'HoldDate',
				PostingPersonName AS 'PostingPersonName',
				IsAchEnabled as 'IsAchEnabled',
				IsEFTOnly AS 'IsEFTOnly'
			FROM #InvoiceForPayment
			WHERE ((SELECT TOP 1 POInvoiceNote.[Status] FROM POInvoiceNote WHERE ObjectID = #InvoiceForPayment.InvoiceID ORDER BY [Timestamp] DESC) <> 'Void')
			GROUP BY InvoiceID, VendorID, Vendor, PrintOnCheckAs, InvoiceNumber, InvoiceDate, AccountingDate, DueDate, Credit, [Description], 
					 SummaryVendor, OneCheckPerInvoice, IsHighPriorityPayment, HasDocuments, HoldDate, PostingPersonName, IsAchEnabled, IsEFTOnly
			HAVING (SUM(Total) - SUM(AmountPaid)) <> 0
			ORDER BY Vendor, DueDate
	END
	
END

GO
