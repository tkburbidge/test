SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 10, 2011
-- Description:	Checks to see if the account is locked due to an in-process edit of a transaction.
-- =============================================
CREATE PROCEDURE [dbo].[CheckTransactionEditLock] 
	-- Add the parameters for the stored procedure here
	@AccountID bigint = 0, 
	@ObjectID uniqueidentifier = null,
	@originalID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (EXISTS(SELECT * FROM PartialTransactionEdit pte WHERE EditedID IS NULL AND OriginalID IN 
			((SELECT t.TransactionID
					FROM [Transaction] t 
					WHERE pte.OriginalID = t.TransactionID 
						AND t.ObjectID = @ObjectID
						AND pte.IsPayment = 0
						AND t.TaxRateID IS NULL
						AND ((@originalID IS NULL) OR (@originalID <> pte.OriginalID)))
			  UNION
			  (SELECT p.PaymentID 
					FROM [Transaction] t
					INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
					INNER JOIN Payment p ON p.PaymentID = pt.PaymentID
					WHERE p.PaymentID = pte.OriginalID
						AND pte.IsPayment = 1
						AND t.ObjectID = @ObjectID
						AND ((@originalID IS NULL) OR (@originalID <> pte.OriginalID))))))
	BEGIN
		SELECT 1
	END
	ELSE
	BEGIN
		SELECT 0
	END 

END
GO
