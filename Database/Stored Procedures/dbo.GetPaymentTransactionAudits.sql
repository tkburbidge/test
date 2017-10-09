SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: June 10, 2016
-- Description:	Generates the data for the SPN Payment Transaction Audit Report/Export
-- =============================================
CREATE PROCEDURE [dbo].[GetPaymentTransactionAudits] 
	-- Add the parameters for the stored procedure here
	@startDate datetime,
	@endDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--DECLARE @startDate date = '2016-5-1'
	--DECLARE @endDate DATE = '2016-5-31'

	CREATE TABLE #Properties (
		AccountID bigint,
		CompanyName nvarchar(500),
		PropertyID uniqueidentifier,
		PropertyName nvarchar(500),
		TotalUnits int,
		IntegrationPartnerID int,
		IntegrationPartner nvarchar(100)	
	)

	CREATE TABLE #Payments
	(
		PropertyID uniqueidentifier,
		IntegrationPartnerID int,
		PaymentMethod nvarchar(100),	
		PaymentCount int,
		PaymentTotal money	
	)

	INSERT INTO #Properties
		SELECT DISTINCT
			s.AccountID,
			s.CompanyName,
			p.PropertyID,
			p.Name,
			0,
			ip.IntegrationPartnerID,
			ip.Name
		FROM Property p
		INNER JOIN Settings s ON s.AccountID = p.AccountID
		INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = p.PropertyID
		INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID
		INNER JOIN IntegrationPartner ip ON ip.IntegrationPartnerID = ipi.IntegrationPartnerID
		WHERE ip.Category = 'PaymentProcessing'


	UPDATE #Properties SET TotalUnits = (SELECT COUNT(u.UnitID) 
											FROM Unit u
											INNER JOIN Building b on b.BuildingID = u.BuildingID											
											where u.ExcludedFromOccupancy = 0
												AND (u.DateRemoved IS NULL OR u.DateRemoved > @endDate)
												AND #Properties.PropertyID = b.PropertyID)

	-- Integrated Payments
	INSERT INTO #Payments
		SELECT 
			pp.PropertyID,
			ip.IntegrationPartnerID,
			pp.PaymentType,
			COUNT(pp.ProcessorPaymentID),
			SUM(pp.Amount)
		FROM ProcessorPayment pp
		INNER JOIN #Properties #p ON #p.PropertyID = pp.PropertyID
		--INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = pp.IntegrationPartnerItemID
		INNER JOIN IntegrationPartner ip ON ip.IntegrationPartnerID = pp.IntegrationPartnerID
		INNER JOIN Payment p ON p.PaymentID = pp.PaymentID
		WHERE p.[Date] >= @startDate
			AND p.[Date] <= @endDate
			AND p.Amount > 0
			AND p.Reversed = 0
		GROUP BY pp.PropertyID, pp.PaymentType, ip.IntegrationPartnerID

	-- ALL Payments
	INSERT INTO #Payments		
		SELECT
			PropertyID,
			null,
			[Type],
			COUNT(PaymentID),
			SUM(Amount)
		FROM 
			(SELECT DISTINCT
				#p.PropertyID,				
				p.[Type],
				p.PaymentID,
				p.Amount
			FROM Payment p			
			INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
			INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
			INNER JOIN #Properties #p ON #p.PropertyID = t.PropertyID		
			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID AND tt.Name IN ('Payment', 'Deposit')
																					    AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
			WHERE p.[Date] >= @startDate
				AND p.[Date] <= @endDate
				AND p.Amount > 0
				AND p.Reversed = 0) AS Payments 
		GROUP BY PropertyID, [Type]


		
	SELECT
		#p.AccountID, 
		#p.CompanyName,
		#p.PropertyID,
		#p.PropertyName,
		#p.TotalUnits,
		#p.IntegrationPartnerID,
		#p.IntegrationPartner,
		Methods.PaymentMethod,
		ISNULL(#ip.PaymentCount, 0) AS IntegratedPaymentCount,
		ISNULL(#ip.PaymentTotal, 0) AS IntegratedPaymentTotal,
		ISNULL(#nip.PaymentCount, 0) AS AllPaymentCount,
		ISNULL(#nip.PaymentTotal, 0) AS AllPaymentTotal
	FROM #Properties #p
		INNER JOIN (SELECT DISTINCT PaymentMethod FROM #Payments) Methods ON 1 = 1 
		LEFT JOIN #Payments #ip ON #ip.PropertyID = #p.PropertyID AND #ip.IntegrationPartnerID = #p.IntegrationPartnerID AND #ip.PaymentMethod = Methods.PaymentMethod
		LEFT JOIN #Payments #nip ON #nip.PropertyID = #p.PropertyID AND #nip.IntegrationPartnerID IS NULL AND #nip.PaymentMethod = Methods.PaymentMethod
	WHERE ISNULL(#ip.PaymentCount, 0) <> 0 OR
		  ISNULL(#ip.PaymentTotal, 0) <> 0 OR
		  ISNULL(#nip.PaymentCount, 0) <> 0 OR
		  ISNULL(#nip.PaymentTotal, 0) <> 0
	ORDER BY AccountID, CompanyName, PropertyName, IntegrationPartnerID

	--DROP TABLE #Properties
	--DROP TABLE #Payments
    
END
GO
