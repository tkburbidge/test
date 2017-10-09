SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 28, 2011
-- Description:	Updates all Transactions associated to a Person of Type Prospect to an Object of the Lease and also updates the TransactionTypeID.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateNewResidentTransactions] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null,
	@newObjectID uniqueidentifier = null, 
	@oldObjectID uniqueidentifier = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE [Transaction] 
		SET ObjectID = @newObjectID,
			TransactionTypeID = tt2.TransactionTypeID
		FROM [Transaction] t
			INNER JOIN TransactionType tt1 ON t.TransactionTypeID = tt1.TransactionTypeID 
			INNER JOIN TransactionType tt2 ON tt1.Name = tt2.Name AND tt1.[Group] = 'Prospect' AND tt2.[Group] = 'Lease'
															AND tt2.AccountID = t.AccountID
		WHERE t.ObjectID = @oldObjectID
			AND t.PropertyID = @propertyID

	UPDATE Payment
		SET ObjectID = @newObjectID,
			ObjectType = 'Lease'			
		FROM Payment p			
			INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
			INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID
		WHERE p.ObjectID = @oldObjectID
			AND p.ObjectType = 'Prospect'
			AND t.PropertyID = @propertyID
END

GO
