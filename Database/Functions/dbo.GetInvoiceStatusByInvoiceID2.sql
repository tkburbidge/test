SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
CREATE FUNCTION [dbo].[GetInvoiceStatusByInvoiceID2]
(	
	-- Add the parameters for the function here
	@invoiceID uniqueidentifier,
	@asOfDate date
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT TOP 1 ObjectID AS 'InvoiceID', [Status] AS 'InvoiceStatus'
		FROM POInvoiceNote
		WHERE ObjectID = @invoiceID
		  AND [Date] <= (CASE WHEN @asOfDate IS NULL THEN DATEADD(year,25, getdate())
							  ELSE @asOfDate END)
		--ORDER BY [Date] DESC, [TimeStamp] DESC
		ORDER BY [TimeStamp] DESC
)
GO
