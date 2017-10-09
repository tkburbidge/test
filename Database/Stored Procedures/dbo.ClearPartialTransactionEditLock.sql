SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 10/16/2014
-- Description:	Removes the edit lock for a transaction, given an object id
-- =============================================
CREATE PROCEDURE [dbo].[ClearPartialTransactionEditLock]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0, 
	@objectID UNIQUEIDENTIFIER = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE pte FROM PartialTransactionEdit pte WHERE EditedID IS NULL AND OriginalID IN 
			((SELECT t.TransactionID
					FROM [Transaction] t 
					WHERE pte.OriginalID = t.TransactionID 
						AND t.ObjectID = @ObjectID
						AND pte.IsPayment = 0)
			  UNION
			  (SELECT p.PaymentID 
					FROM [Transaction] t
					INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
					INNER JOIN Payment p ON p.PaymentID = pt.PaymentID
					WHERE p.PaymentID = pte.OriginalID
						AND pte.IsPayment = 1
						AND t.ObjectID = @ObjectID))
END
GO
