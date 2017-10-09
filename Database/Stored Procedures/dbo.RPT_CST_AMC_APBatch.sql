SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_CST_AMC_APBatch] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier, 
	@batchID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #InvoicesToExport (
		GLAccount nvarchar(50) null,							-- Invoice.GLAccount.Number
		Unit nvarchar(50) null,									-- Invoice line item location name
		[Description] nvarchar(MAX) null,						-- line item description
		VendorID nvarchar(50) null,								-- Vendor Abbreviation
		VendorName nvarchar(100) null,							-- Name
		DrawDate date null,										-- Batch Date
		InvoiceNumber nvarchar(50) null,						-- InvoiceNumber
		InvoiceDate date null,									-- InvoiceDate
		Amount money null										-- Line Item Amount
		)

	INSERT #InvoicesToExport
		SELECT	gla.Number,
				u.Number,
				t.[Description],
				vend.Abbreviation,
				vend.CompanyName,
				b.[Date],
				i.Number,
				i.InvoiceDate,
				t.Amount
			FROM Invoice i 
				INNER JOIN InvoiceBatch ib on ib.BatchID = @batchID AND ib.InvoiceID = i.InvoiceID
				INNER JOIN Batch b on ib.BatchID = b.BatchID
				INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
				INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
				INNER JOIN Vendor vend ON i.VendorID = vend.VendorID
				CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, GETDATE()) [InvStat]
				LEFT JOIN Unit u ON ili.ObjectID = u.UnitID
				LEFT JOIN ExportDetail ed ON i.InvoiceID = ed.ObjectID
			WHERE [InvStat].InvoiceStatus NOT IN ('Void')
			  AND ed.ExportDetailID IS NULL
			  AND t.PropertyID = @propertyID

	SELECT * FROM #InvoicesToExport
			  
END
GO
