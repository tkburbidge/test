SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 5, 2012
-- Description:	Gets Completed Refunds
-- =============================================
CREATE PROCEDURE [dbo].[GetVoidedRefunds] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@startDate datetime = null,
	@endDate datetime = null,
	@sortBy nvarchar(50) = null,
	@sortOrderIsAsc bit = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
SELECT * FROM
 (
	SELECT DISTINCT p.PaymentID, p.ObjectID, /*t.TransactionID,*/ tta.[Group] AS 'ObjectType', l.LeaseID, p.ReceivedFromPaidTo AS 'PaidTo', p.Amount, 
			u.Number AS 'UnitNumber', p.ReferenceNumber, p.[Date], p.ReversedDate AS 'VoidDate', null as 'VoidNotes', u.PaddedNumber
		FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID			
			LEFT JOIN [Transaction] tr ON t.ReversesTransactionID = tr.TransactionID
			LEFT JOIN [Transaction] ta ON tr.AppliesToTransactionID = ta.TransactionID
			LEFT JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
			LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ta.ObjectID
			LEFT JOIN Unit u ON ulg.UnitID = u.UnitID	
			LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID		
		WHERE t.PropertyID = @propertyID
		  AND tt.Name = 'Refund'
		  AND tt.[Group] in ('Bank')
		  AND p.[Date] <= @endDate
		  AND p.[Date] >= @startDate
		  AND tr.TransactionID IS NOT NULL
		  AND p.Reversed = 1
		  AND ((l.LeaseID IS NULL) OR
			   (l.LeaseID = (
								SELECT TOP 1 LeaseID 
								FROM Lease 
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
								ORDER BY Lease.LeaseStartDate DESC)
							)
				)
			   ) as [MyTable]
		Order By
 			case when @sortBy = 'Date' and (@sortOrderIsAsc = 1) then [VoidDate] else '' end ASC,
			case when @sortBy = 'Date' and (@sortOrderIsAsc = 0) then [VoidDate] else '' end DESC,
 			case when @sortBy = 'Unit' and (@sortOrderIsAsc = 1) then PaddedNumber else '' end ASC,
			case when @sortBy = 'Unit' and (@sortOrderIsAsc = 0) then PaddedNumber else '' end DESC,
     		case when @sortBy = 'Type' and (@sortOrderIsAsc = 1) then ObjectType else '' end ASC,
			case when @sortBy = 'Type' and (@sortOrderIsAsc = 0) then ObjectType  else '' end DESC,
			case when @sortBy = 'PaidTo' and (@sortOrderIsAsc = 1) then PaidTo else '' end ASC,
			case when @sortBy = 'PaidTo' and (@sortOrderIsAsc = 0) then PaidTo else '' end DESC,
 			case when @sortBy = 'Reference' and (@sortOrderIsAsc = 1) then ReferenceNumber else '' end ASC,
			case when @sortBy = 'Reference' and (@sortOrderIsAsc = 0) then ReferenceNumber else '' end DESC,
 			case when @sortBy = 'Amount' and (@sortOrderIsAsc = 1) then Amount else '' end ASC,
			case when @sortBy = 'Amount' and (@sortOrderIsAsc = 0) then Amount else '' end DESC
END
GO
