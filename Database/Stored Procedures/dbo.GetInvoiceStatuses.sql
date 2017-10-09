SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetInvoiceStatuses]
	-- Add the parameters for the stored procedure here
	@invoiceIDs GuidCollection READONLY,
	@date date = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT i.Value AS 'InvoiceID', InvoiceStatus.InvoiceStatus AS 'Status'
    FROM @invoiceIDs i
    CROSS APPLY GetInvoiceStatusByInvoiceID(i.Value, null) AS InvoiceStatus    
    
	
END
GO
