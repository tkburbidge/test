SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 14, 2014
-- Description:	Sets all PricingBatch records to archived, and purges all records archived and older than 3 months plus a day.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateAndPurgePricingBatch] 
	@accountID bigint = null,
	@propertyID uniqueidentifier = null,
	@integrationPartnerID int = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--CREATE TABLE #PricingBatchesWhacked (
	--	PricingBatchID uniqueidentifier not null)

	--INSERT #PricingBatchesWhacked
	--	SELECT PricingBatchID
	--		FROM PricingBatch
	--		WHERE DatePosted < DATEADD(DAY, -1, (DATEADD(MONTH, -3, getdate())))
	--		  AND AccountID = @accountID
	--		  AND PropertyID = @propertyID
	--		  AND IntegrationPartnerID = @integrationPartnerID
			  
	--DELETE p
	--	FROM Pricing p
	--	WHERE p.PricingBatchID IN (SELECT PricingBatchID FROM #PricingBatchesWhacked)
		
	--DELETE pb
	--	FROM PricingBatch pb
	--	WHERE pb.PricingBatchID IN (SELECT PricingBatchID FROM #PricingBatchesWhacked)
		
	UPDATE PricingBatch SET IsArchived = 1
		WHERE AccountID = @accountID
			AND PropertyID = @propertyID
			AND IntegrationPartnerID = @integrationPartnerID

END
GO
