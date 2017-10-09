SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE FUNCTION [dbo].[GetInvoiceStatusByInvoiceID]
(	
	@invoiceID uniqueidentifier,
	@asOfDate date
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT TOP 1 ObjectID AS InvoiceID, [Status] AS InvoiceStatus
		FROM POInvoiceNote
		WHERE ObjectID = @invoiceID
		  AND [Date] <= (CASE WHEN @asOfDate IS NULL THEN DATEADD(year, 25, GETDATE())
							  ELSE @asOfDate
						 END)
		--ORDER BY [Date] DESC, [Timestamp] DESC
		ORDER BY [Timestamp] DESC
)
GO
