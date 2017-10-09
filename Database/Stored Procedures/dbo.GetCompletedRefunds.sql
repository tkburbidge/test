SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		 Rick Bertelsen
-- Create date: Jan. 5, 2012
-- Description:	 Gets Completed Refunds
-- =============================================

CREATE PROCEDURE [dbo].[GetCompletedRefunds] 
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
 (SELECT DISTINCT p.PaymentID, p.ObjectID, tta.[Group] AS 'ObjectType', l.LeaseID, p.ReceivedFromPaidTo AS 'PaidTo', p.Amount, 
 			u.Number AS 'UnitNumber', p.ReferenceNumber, p.[Date] AS 'Date', null AS 'VoidDate', null as 'VoidNotes', u.PaddedNumber
		 FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
 			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
 			LEFT JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
			LEFT JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
 			LEFT JOIN [Transaction] tr ON t.ReversesTransactionID = tr.TransactionID
			LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ta.ObjectID
 			LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
			LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		WHERE t.PropertyID = @propertyID
		  AND tt.Name = 'Refund'
		  AND tt.[Group] in ('Bank')
  		  AND p.[Date] <= @endDate
		  AND p.[Date] >= @startDate
		  AND tr.TransactionID IS NULL
		  AND p.Reversed = 0
		  AND ((l.LeaseID IS NULL) OR 
				 (l.LeaseID = (SELECT TOP 1 LeaseID 
 									FROM Lease 
									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
 									ORDER BY Lease.LeaseStartDate DESC)
								 ))
) AS [MyTable]
		 Order By
 			case when @sortBy = 'Date' and (@sortOrderIsAsc = 1) then 'Date' else '' end ASC,
			case when @sortBy = 'Date' and (@sortOrderIsAsc = 0) then 'Date' else '' end DESC,
 			case when @sortBy = 'Unit' and (@sortOrderIsAsc = 1) then 'UnitNumber' else '' end ASC,
			case when @sortBy = 'Unit' and (@sortOrderIsAsc = 0) then 'UnitNumber' else '' end DESC,
     		case when @sortBy = 'Type' and (@sortOrderIsAsc = 1) then 'Group' else '' end ASC,
			case when @sortBy = 'Type' and (@sortOrderIsAsc = 0) then 'Group' else '' end DESC,
			case when @sortBy = 'PaidTo' and (@sortOrderIsAsc = 1) then 'ReceivedFromPaidTo' else '' end ASC,
			case when @sortBy = 'PaidTo' and (@sortOrderIsAsc = 0) then 'ReceivedFromPaidTo' else '' end DESC,
 			case when @sortBy = 'Reference' and (@sortOrderIsAsc = 1) then 'ReferenceNumber' else '' end ASC,
			case when @sortBy = 'Reference' and (@sortOrderIsAsc = 0) then'ReferenceNumber' else '' end DESC,
 			case when @sortBy = 'Amount' and (@sortOrderIsAsc = 1) then 'Amount' else '' end ASC,
			case when @sortBy = 'Amount' and (@sortOrderIsAsc = 0) then 'Amount' else '' end DESC
 

END
GO
