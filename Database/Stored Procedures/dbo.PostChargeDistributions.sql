SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 24, 2013
-- Description:	Posts distributed charges
-- =============================================
CREATE PROCEDURE [dbo].[PostChargeDistributions] 
	-- Add the parameters for the stored procedure here
	@chargeDistributionDetails GuidCollection READONLY,
	@chargeDistributionEdits ChargeDistributionEditsCollection READONLY, 
	@personID uniqueidentifier = null,
	@date date = null,
	@buildingIDs GuidCollection READONLY
AS

DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @propertyID uniqueidentifier
DECLARE @ledgerItemTypeID uniqueidentifier
DECLARE @postingBatchID uniqueidentifier
DECLARE @chargeDistributionID uniqueidentifier
DECLARE @accountID bigint
DECLARE @description nvarchar(500)
DECLARE @charges PostingBatchTransactionCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #DistributedCharges (
		ChargeDistributionDetailID uniqueidentifier NOT NULL,
		UnitLeaseGroupID uniqueidentifier NOT NULL,
		Amount money NULL,
		ChargeName nvarchar(500) NOT NULL,
		LedgerItemTypeID uniqueidentifier NOT NULL,
		DistributionChargeName nvarchar(1000) NOT NULL,
		TotalFootage int NULL,
		TotalOccupants int NULL,
		TotalAmount money NULL,
		OccupancyWeight tinyint NULL,
		SquareFootageWeight tinyint NULL,
		BillingPercentage tinyint NULL,
		AdditionalFee money NULL,
		OccupancyCount int NULL,
		UnitArea int NULL,
		MoveInDate date NULL)
		
	CREATE TABLE #DistributedChargeTypesToPost (
		Sequence int identity,
		ChargeDistributionDetailID uniqueidentifier NOT NULL,
		PostingBatchID uniqueidentifier NULL)
		
	INSERT #DistributedCharges
		EXEC GetChargeDistributions @chargeDistributionDetails, @date, 1, @buildingIDs
	
	IF (0 < (SELECT COUNT(*) FROM @chargeDistributionEdits))
	BEGIN	
		UPDATE #dc SET Amount = cde.Amount
			FROM #DistributedCharges #dc
				INNER JOIN @chargeDistributionEdits cde ON #dc.ChargeDistributionDetailID = cde.ChargeDistributionDetailID AND #dc.UnitLeaseGroupID = cde.UnitLeaseGroupID
	END
		
	INSERT #DistributedChargeTypesToPost
		SELECT Value, NEWID() 
			FROM @chargeDistributionDetails
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #DistributedChargeTypesToPost)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		DELETE @charges
		INSERT @charges
			SELECT	ulg.UnitLeaseGroupID,
					LEFT(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, ''), 100) AS 'ObjectName',
					#dc.Amount,
					@date,
					u.Number
				FROM #DistributedCharges #dc
					INNER JOIN Lease l ON #dc.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN UnitLeaseGroup ulg ON #dc.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID					
				WHERE #dc.Amount > 0
				  AND #dc.ChargeDistributionDetailID = (SELECT ChargeDistributionDetailID FROM #DistributedChargeTypesToPost WHERE Sequence = @ctr)
				  AND l.LeaseID = (SELECT TOP 1 l2.LeaseID	
								   FROM Lease l2 
									INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'
								  WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
								   ORDER BY o.OrderBy)
	
		SELECT	@propertyID = cd.PropertyID, @ledgerItemTypeID = cdd.LedgerItemTypeID, @postingBatchID = #dctp.PostingBatchID, 
				@accountID = cd.AccountID, @description = cdd.[Description], @chargeDistributionID = cd.ChargeDistributionID
			FROM ChargeDistribution cd
				INNER JOIN ChargeDistributionDetail cdd ON cd.ChargeDistributionID = cdd.ChargeDistributionID
				INNER JOIN #DistributedChargeTypesToPost #dctp ON cdd.ChargeDistributionDetailID = #dctp.ChargeDistributionDetailID
			WHERE #dctp.Sequence = @ctr
			
		INSERT PostingBatch (PostingBatchID, AccountID, PropertyID, PostingPersonID, PostedDate, IsPaymentBatch, IsPosted)
			VALUES (@postingBatchID, @accountID, @propertyID, @personID, @date, 0, 1)
			
		EXEC ImportChargeBatch @accountID, @postingBatchID, @ledgerItemTypeID, @propertyID, @personID, @description, null, null, @charges
		
		EXEC PostChargeBatch @accountID, @postingBatchID, @personID, @date
		
		UPDATE ChargeDistributionDetail SET PostingBatchID = @postingBatchID
			WHERE ChargeDistributionDetailID = (SELECT ChargeDistributionDetailID FROM #DistributedChargeTypesToPost WHERE Sequence = @ctr)
			
		SET @ctr = @ctr + 1
	END
	
	EXEC GetPostedChargeDistributionInfo @chargeDistributionID
END
GO
