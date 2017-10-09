SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 27, 2012
-- Description:	Gets the data for the APAgingSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_GetAPAgingSummaries] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #APAgingSummary (		
		VendorID uniqueidentifier not null,
		VendorName nvarchar(200) not null,		
		Total money null,
		ZeroToThirty money null,
		ThirtyOneToSixty money null,
		SixtyOneToNinety money null,
		OverNinety money null)
		
	CREATE TABLE #UnpaidInvoices2 (
			PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyAbbreviation nvarchar(50) not null,
		VendorID uniqueidentifier not null,
		VendorName nvarchar(500) not null,
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(500) not null,
		InvoiceDate date null,
		AccountingDate date null,
		DueDate date null,
		[Description] nvarchar(500) null,
		Total money null,
		AmountPaid money null,
		Credit bit null,
		InvoiceStatus nvarchar(20) null,
		IsHighPriorityPayment bit null,
		ApproverPersonID uniqueidentifier null,
		ApproverLastName nvarchar(500) null,
		HoldDate date null)

	INSERT INTO #UnpaidInvoices2 EXEC RPT_INV_UnpaidInvoices @propertyIDs, @reportDate, null, null, null, 1, 1
	
	-- Negate credit invoices
	UPDATE #Unpaidinvoices2 SET Total = -Total, AmountPaid = -AmountPaid WHERE Credit = 1
	
	INSERT INTO #APAgingSummary
		SELECT	#UI.VendorID AS 'VendorID',
				#UI.VendorName AS 'VendorName',				
				SUM(#UI.Total - #UI.AmountPaid) AS 'Total',
				0,
				0,
				0,
				0
			FROM #UnpaidInvoices2 #UI			
			GROUP BY VendorID, VendorName
			ORDER BY VendorName		
									 
	UPDATE #APAgingSummary SET ZeroToThirty = (SELECT ISNULL(SUM(#UI1.Total - #UI1.AmountPaid) , 0)
													FROM #UnpaidInvoices2 #UI1
													WHERE #UI1.VendorID = #APAgingSummary.VendorID
													  AND #UI1.AccountingDate <= @reportDate
													  AND #UI1.AccountingDate >= DATEADD(day, -30, @reportDate))
													  
	UPDATE #APAgingSummary SET ThirtyOneToSixty = (SELECT ISNULL(SUM(#UI1.Total - #UI1.AmountPaid) , 0)
													FROM #UnpaidInvoices2 #UI1
													WHERE #UI1.VendorID = #APAgingSummary.VendorID
													  AND #UI1.AccountingDate <= @reportDate
													  AND #UI1.AccountingDate <= DATEADD(day, -31, @reportDate)
													  AND #UI1.AccountingDate >= DATEADD(day, -60, @reportDate))
													  
	UPDATE #APAgingSummary SET SixtyOneToNinety = (SELECT ISNULL(SUM(#UI1.Total - #UI1.AmountPaid) , 0)
													FROM #UnpaidInvoices2 #UI1
													WHERE #UI1.VendorID = #APAgingSummary.VendorID
													  AND #UI1.AccountingDate <= @reportDate
													  AND #UI1.AccountingDate <= DATEADD(day, -61, @reportDate)
													  AND #UI1.AccountingDate >= DATEADD(day, -90, @reportDate))
													  
	UPDATE #APAgingSummary SET OverNinety = (SELECT ISNULL(SUM(#UI1.Total - #UI1.AmountPaid) , 0)
											FROM #UnpaidInvoices2 #UI1
											WHERE #UI1.VendorID = #APAgingSummary.VendorID
											  AND #UI1.AccountingDate <= @reportDate
											  AND #UI1.AccountingDate <= DATEADD(day, -91, @reportDate))
		SELECT
			VendorID,
			VendorName,
			Total,
			ZeroToThirty,
			ThirtyOneToSixty,
			SixtyOneToNinety,
			OverNinety			
		FROM #APAgingSummary
		ORDER BY VendorName						

END
GO
