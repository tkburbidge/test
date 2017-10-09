SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: March 21, 2013
-- Description:	Gets information for a receipt of a processor payment
-- =============================================
CREATE PROCEDURE [dbo].[GetProcessorPaymentReceipt] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@processorPaymentID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	

    -- Insert statements for procedure here
	SELECT DISTINCT pp.ProcessorPaymentID AS 'PaymentID', 
					prop.Name as 'PropertyName', 
					pp.ProcessorTransactionID as 'Reference',					
					pp.DateProcessed AS 'Date',
					pp.Amount, 
					pp.Fee as 'ConvenienceFee', 
					CASE WHEN u.UnitID IS NOT NULL THEN u.Number + ' - '
						 ELSE '' END + pp.Payer AS 'Account',					
					prop.PropertyID,
					ulg.UnitID,
					pp.PaymentType,
					pp.Payer					
	FROM ProcessorPayment pp				
		INNER JOIN [Property] prop on pp.PropertyID = prop.PropertyID		
		LEFT JOIN [UnitLeaseGroup] ulg on pp.ObjectID = ulg.UnitLeaseGroupID
		LEFT JOIN [Unit] u ON u.UnitID = ulg.UnitID
	WHERE pp.AccountID = @accountID AND pp.ProcessorPaymentID = @processorPaymentID
END
GO
