SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Trevor Burbidge
-- Create date: Mar. 24, 2015
-- Description:	Gets the current market rentable price factoring in term length, and if they're integrated with LRO.
-- =============================================
CREATE PROCEDURE [dbo].[GetLatestUnitTypePrice] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyID uniqueidentifier = null, 
	@unitTypeIDs GuidCollection READONLY,
	@leaseTerm int = null,
	@date date
AS

DECLARE @isLROIntegrated bit = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Final results set
	CREATE TABLE #PricingToReturn (
		ObjectID uniqueidentifier not null,
		LeaseTerm int null,
		PricingID uniqueidentifier null,
		BaseRent money null,
		Concession money null,
		ExtraAmenitiesAmount money null,
		EffectiveRent money null,
		StartDate date null,
		EndDate date null,
		IsFixed bit null,
		LeaseTermName nvarchar(50) null)

	CREATE TABLE #UnitTypeMarketRent (
		UnitTypeID uniqueidentifier not null,
		MarketRent money null)
		
	CREATE TABLE #UnitTypeIDs (
		UnitTypeID uniqueidentifier not null)
		
	--If no unit types were passed in then we will return all of them
	IF ((SELECT COUNT(*) FROM @unitTypeIDs) = 0)
		INSERT #UnitTypeIDs
			SELECT UnitTypeID 
				FROM UnitType 
				WHERE AccountID = @accountID 
				  AND PropertyID = @propertyID
	ELSE
		INSERT #UnitTypeIDs
			SELECT Value
				FROM @unitTypeIDs
	END

	SET @isLROIntegrated = 
		CASE 
			WHEN EXISTS (SELECT ipip.IntegrationPartnerItemPropertyID
							FROM IntegrationPartnerItemProperty ipip
							WHERE ipip.AccountID = @accountID
							  AND ipip.PropertyID = @propertyID
							  AND ipip.IntegrationPartnerItemID = 72) --LRO Revenue Management
			THEN 1
			ELSE 0
		END

	INSERT INTO #UnitTypeMarketRent
			SELECT #ut.UnitTypeID, ISNULL(mr.Amount, 0)
				FROM #UnitTypeIDs #ut
					CROSS APPLY GetLatestMarketRentByUnitTypeID(#ut.UnitTypeID, @date) mr
	
	
	-- ADD a row for MarketRent & Fixed Lease Terms ALWAYS to be returned.
	INSERT #PricingToReturn
		SELECT #umr.UnitTypeID, null, null, #umr.MarketRent, 0.00, 0.00, #umr.MarketRent, null, null, 0, 'MarketRent'
			FROM #UnitTypeMarketRent #umr

	IF (@isLROIntegrated = 1)
	BEGIN
		INSERT #PricingToReturn
			SELECT p.ObjectID, p.LeaseTerm, p.PricingID, p.BaseRent, p.Concession, null, p.EffectiveRent, p.StartDate, p.EndDate, 0, COALESCE(p.Name, CAST(p.LeaseTerm AS nvarchar(100)) + ' Month')
				FROM Pricing p
					INNER JOIN PricingBatch pb ON p.PricingBatchID = pb.PricingBatchID AND pb.IsArchived = 0
					INNER JOIN #UnitTypeIDs #ut ON #ut.UnitTypeID = p.ObjectID
				WHERE p.ObjectType = 'UnitType'	
				  AND @date >= p.StartDate AND @date <= p.EndDate	
	END
	ELSE-- Property is NOT integrated with LRO, use ResMan pricing!
	BEGIN	


		INSERT #PricingToReturn
			SELECT	#umr.UnitTypeID,
					lt.Months,
					null,
					CASE
						WHEN (utlt.[Round] = 1)
							THEN ROUND((#umr.MarketRent +
											CASE						-- Factor in the Concession value
												WHEN (utlt.IsPercentage = 1) THEN
													#umr.MarketRent * (utlt.Amount/100.0)
												ELSE
													utlt.Amount
												END), 0)
						ELSE (#umr.MarketRent +
											CASE						-- Factor in the Concession value
												WHEN (utlt.IsPercentage = 1) THEN
													#umr.MarketRent * (utlt.Amount/100.0)
												ELSE
													utlt.Amount
												END)
						END AS 'BaseRent',
					0 AS 'Concession',
					0 AS 'ExtraAmenitiesAmount',
					0 AS 'EffectiveRent',
					NULL,
					NULL,
					0 AS 'IsFixed',
					lt.Name											
				FROM #UnitTypeMarketRent #umr
					INNER JOIN UnitTypeLeaseTerm utlt ON #umr.UnitTypeID = utlt.UnitTypeID
					INNER JOIN LeaseTerm lt ON utlt.LeaseTermID = lt.LeaseTermID AND lt.IsFixed = 0
								

					
		INSERT #PricingToReturn
			SELECT	#umr.UnitTypeID, lt.Months, null, #umr.MarketRent, 0.00, 0.00, #umr.MarketRent, lt.StartDate, lt.EndDate, ISNULL(lt.IsFixed, CAST(0 AS bit)), lt.Name
				FROM #UnitTypeMarketRent #umr
					INNER JOIN PropertyLeaseTerm plt ON plt.PropertyID = @propertyID
					INNER JOIN LeaseTerm lt ON lt.LeaseTermID = plt.LeaseTermID AND lt.IsFixed = 1 
				WHERE lt.StartDate >= CAST(GETDATE() AS date)

		UPDATE #PricingToReturn SET EffectiveRent = BaseRent
									
	END			
	
	SELECT 
		ObjectID,
		LeaseTerm,
		PricingID,
		ISNULL(BaseRent, 0) AS BaseRent,
		ISNULL(Concession, 0) AS Concession,
		ISNULL(ExtraAmenitiesAmount, 0) AS ExtraAmenitiesAmount,
		ISNULL(EffectiveRent, 0) AS EffectiveRent,
		StartDate,
		EndDate,
		IsFixed,
		LeaseTermName
		FROM #PricingToReturn
		ORDER BY ObjectID, IsFixed, LeaseTerm
GO
