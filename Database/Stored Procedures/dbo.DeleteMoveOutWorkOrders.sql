SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 13, 2012
-- Description:	Deletes the work orders that can be deleted on an Undo MoveOut

-- UPDATE
-- Author:		Joshua Grigg
-- Date:		7/29/2015
-- Description:	fixes to work with renaming WorkOrderInvoice table to InvoiceAssociation and new ObjectType column
-- =============================================
CREATE PROCEDURE [dbo].[DeleteMoveOutWorkOrders] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@unitID uniqueidentifier = null,
	@moveOutDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE wo 
		FROM WorkOrder wo
			LEFT JOIN InvoiceAssociation ia ON wo.WorkOrderID = ia.ObjectID AND ia.ObjectType = 'WorkOrder'
			LEFT JOIN WorkOrderTransaction wot ON wo.WorkOrderID = wot.WorkOrderID
		WHERE wo.ObjectID = @unitID
		  AND wo.ReportedPersonName = 'Move Out'
		  AND wo.ReportedDate = @moveOutDate
		  AND ia.InvoiceID IS NULL
		  AND wot.TransactionID IS NULL
END

GO
