SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 10, 2013
-- Description:	Adds a ProcessorPayment record and determines what type it is.
-- =============================================
CREATE PROCEDURE [dbo].[AddProcessorPaymentRecords] 
	-- Add the parameters for the stored procedure here
	@aptexxPayments AptexxPaymentCollection READONLY, 
	@accountID bigint = 0,
	@integrationPartnerItemID int = 0,
	@propertyID uniqueidentifier = null,
	@date datetime = null,
	@description nvarchar(200) = null
AS

DECLARE @TTGLAccountID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PaymentsAndTransactions (
		TransactionID uniqueidentifier null,
		PayerID uniqueidentifier null,
		PaymentID uniqueidentifier null)

	DECLARE @integrationPartnerID int = (SELECT IntegrationPartnerID FROM IntegrationPartnerItem WHERE IntegrationPartnerItemID = @integrationPartnerItemID)

	INSERT ProcessorPayment (ProcessorPaymentID, AccountID, IntegrationPartnerItemID, ProcessorTransactionID, WalletItemID, PaymentID, PropertyID, ObjectID, ObjectType,
							 Amount, Fee, DateCreated, PaymentType, Payer, RefundDate, DateProcessed, DateSettled, LedgerItemTypeID, IntegrationPartnerID)
		SELECT 	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, 'Lease', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
				GETUTCDATE(), aptx.PaymentType, 
				LEFT(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, ''), 50) AS 'Payer',
				null, aptx.[Date], null, aptx.LedgerItemTypeID, @integrationPartnerID
			FROM @aptexxPayments aptx
				INNER JOIN UnitLeaseGroup ulg ON aptx.PayerID = ulg.UnitLeaseGroupID AND ulg.AccountID = @accountID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID 
																									FROM Lease
																									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																									ORDER BY LeaseStartDate DESC)
				--INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
				--													AND ipip.Value1 = aptx.ExternalID
		
		UNION
		
		SELECT	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, 'Prospect', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
				GETUTCDATE(), aptx.PaymentType, 
				per.PreferredName + ' ' + per.LastName, 
				null, aptx.[Date], null, aptx.LedgerItemTypeID, @integrationPartnerID
			FROM @aptexxPayments aptx
				INNER JOIN Person per ON aptx.PayerID = per.PersonID AND per.AccountID = @accountID
				INNER JOIN PersonType perType ON perType.PersonID = per.PersonID  AND perType.[Type] = 'Prospect'
				--INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
				--												AND ipip.Value1 = aptx.ExternalID
			
		UNION
		
		SELECT	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, 'Non-Resident Account', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
				GETUTCDATE(), aptx.PaymentType, 
				per.PreferredName + ' ' + per.LastName, 
				null, aptx.[Date], null, aptx.LedgerItemTypeID, @integrationPartnerID
			FROM @aptexxPayments aptx
				INNER JOIN Person per ON aptx.PayerID = per.PersonID AND per.AccountID = @accountID
				INNER JOIN PersonType perType ON perType.PersonID = per.PersonID  AND perType.[Type] = 'Non-Resident Account'
				--INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = @integrationPartnerItemID
				--												AND ipip.Value1 = aptx.ExternalID		

		UNION
		
		SELECT	NEWID(), @accountID, @integrationPartnerItemID, aptx.PaymentID, null, null, @propertyID, aptx.PayerID, 'WOIT Account', aptx.NetAmount, (aptx.GrossAmount-aptx.NetAmount),
				GETUTCDATE(), aptx.PaymentType, 
				woit.Name, 
				null, aptx.[Date], null, aptx.LedgerItemTypeID, @integrationPartnerID
			FROM @aptexxPayments aptx
				INNER JOIN WOITAccount woit ON aptx.PayerID = woit.WOITAccountID AND woit.AccountID = @accountID AND woit.PropertyID = @propertyID
				
END
GO
