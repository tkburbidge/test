SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: June 11, 2012
-- Description:	Returns the refunds and the invoices that
--				are outstanding
-- =============================================
CREATE PROCEDURE [dbo].[RPT_DSH_APSummary]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #APSummary(
		PropertyName	nvarchar(200)		not null,
		[Type]			nvarchar(50)		not null,
		ObjectID		uniqueidentifier	not null,
		ObjectType		nvarchar(50)		not null,
		ID				uniqueidentifier	not null,
		Reference		nvarchar(500)		null,
		Name			nvarchar(500)		null,
		[Description]	nvarchar(500)		null,
		[Date]			date				not null,
		[DueDate]		date				null,
		AmountDue		money				null,
		IsCredit		bit					not null,
		IsHighPriorityPayment bit				not null,
		IsApproved		bit					not null
    )
    
    DECLARE @InvoiceForPayment TABLE (
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
			
		
	INSERT INTO @InvoiceForPayment
		EXEC [RPT_INV_UnpaidInvoices] @propertyIDs, '2999-1-1', 'AccountingDate', 1, null
	
	INSERT INTO #APSummary  SELECT 
								PropertyName,
								'Invoice',
								VendorID,
								'Vendor',
								InvoiceID,
								InvoiceNumber,
								VendorName,
								[Description],
								InvoiceDate,
								DueDate,
								(Total - AmountPaid),
								Credit,
								IsHighPriorityPayment,
								CASE WHEN InvoiceStatus IN ('Pending Approval') THEN 0 ELSE 1 END  -- If status is anything but Pending Approval then its APproved
							FROM @InvoiceForPayment
							
	 DECLARE @refunds TABLE (
		Property			nvarchar(500)			not null,
		ID					uniqueidentifier		not null,
		ObjectID			uniqueidentifier		not null,
		ObjectType			nvarchar(500)			not null,
		LeaseID				uniqueidentifier		null,
		UnitNumber			nvarchar(500)			null,
		[Description]		nvarchar(500)			not null,		
		[Date]				datetime				not null,
		[Note]				nvarchar(500)			not null,
		[PersonNames]		nvarchar(500)			not null,		
		[LeaseEndDate]		date					null,		
		Amount				money					null,		
		[Type]				nvarchar(500)			null,
		PersonID			uniqueidentifier		null,
		[Status]			nvarchar(100)			null		
		)
		
	INSERT INTO @refunds
	EXEC [GetPendingRefunds] @propertyIDs, null

	INSERT INTO #APSummary  SELECT 
								Property,
								'Refund',
								ObjectID,
								ObjectType,
								ID,
								UnitNumber,
								PersonNames,
								[Description],
								[Date],
								[LeaseEndDate],
							    Amount, 
							    0,
							    0,
								CASE 
									WHEN [Status] = 'Approved' OR [Status] IS NULL THEN 1 														
									ELSE 0 
								END
							FROM @refunds
							
	SELECT * FROM #APSummary
	ORDER BY Name, [DueDate]
END
GO
