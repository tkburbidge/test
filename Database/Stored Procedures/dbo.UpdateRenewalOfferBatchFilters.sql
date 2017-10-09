SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 7/21/2016
-- Description:	Updates the filters for a renewal offer batch, adds renewal offers for leases that now match the filters, deletes renewal offers that no longer match the filters.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateRenewalOfferBatchFilters] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@renewalOfferBatchID uniqueidentifier,
	@minExpirationDate date,
	@maxExpirationDate date,
	@includeLeasesOnNotice bit,
	@includeLeasesWithExpiredOffers bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--update the filters
	UPDATE RenewalOfferBatch 
		SET MinExpirationDate = @minExpirationDate, 
			MaxExpirationDate = @maxExpirationDate,
			IncludeLeasesOnNotice = @includeLeasesOnNotice,
			IncludeLeasesWithExpiredOffers = @includeLeasesWithExpiredOffers
		WHERE AccountID = @accountID 
		  AND RenewalOfferBatchID = @renewalOfferBatchID

	DECLARE @propertyID uniqueidentifier = (SELECT PropertyID FROM RenewalOfferBatch WHERE RenewalOfferBatchID = @renewalOfferBatchID)

	--Find leases that meet the criteria 
	CREATE TABLE #Leases (
		LeaseID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		CurrentRent money null,
		CurrentRentConcessions money null,
		MarketRent money null,
		HasOfferInBatch bit not null
	)
		
	INSERT INTO #Leases
		SELECT l.LeaseID, 
			   ut.UnitTypeID, 
			   (SELECT SUM(lli.Amount) 
					FROM LeaseLedgerItem lli 
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 1), 
				(SELECT SUM(lli.Amount) 
					FROM LeaseLedgerItem lli 
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRecurringMonthlyRentConcession = 1),
				mr.Amount,
			   CASE WHEN ro.RenewalOfferID IS NULL THEN 0 ELSE 1 END
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				LEFT JOIN RenewalOffer ro ON ro.LeaseID = l.LeaseID AND ro.RenewalOfferBatchID = @renewalOfferBatchID
				CROSS APPLY GetLatestMarketRentByUnitID(u.UnitID, GETDATE()) mr
			WHERE l.AccountID = @accountID
			  AND ut.PropertyID = @propertyID
			  AND (@minExpirationDate IS NULL OR l.LeaseEndDate >= @minExpirationDate)
			  AND l.LeaseEndDate <= @maxExpirationDate
			  AND ulg.DoNotRenewPersonNoteID IS NULL
			  AND l.LeaseStatus = 'Current' --purposely don't care about 'under eviction'. Why would we want to renew them????
			  --This will find any other offer if we aren't including leases with expired offers, or just active offers if we are including them.
			  AND NOT EXISTS (SELECT * 
								FROM RenewalOffer activeRO
									INNER JOIN RenewalOfferBatch activeROB ON activeROB.RenewalOfferBatchID = activeRO.RenewalOfferBatchID
								WHERE activeRO.LeaseID = l.LeaseID
								  AND activeROB.RenewalOfferBatchID <> @renewalOfferBatchID
								  AND (@includeLeasesWithExpiredOffers = 0
									  OR ((/*activeROB.ValidRangeFixedStart <= GETDATE() AND*/ activeROB.ValidRangeFixedEnd >= GETDATE()) 
											OR (/*activeROB.ValidRangeRelativeStart IS NOT NULL AND*/ activeROB.ValidRangeRelativeEnd IS NOT NULL AND (/*DATEADD(DAY, -activeROB.ValidRangeRelativeStart, l.LeaseEndDate) <= GETDATE() AND*/ DATEADD(DAY, -activeROB.ValidRangeRelativeEnd, l.LeaseEndDate) >= GETDATE())))))
			  AND (@includeLeasesOnNotice = 1 OR EXISTS (SELECT * FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID AND pl.MoveOutDate IS NULL))

	UPDATE #Leases SET CurrentRent = 0 WHERE CurrentRent IS NULL
	UPDATE #Leases SET CurrentRentConcessions = 0 WHERE CurrentRentConcessions IS NULL




	--Add offers for leases that don't already have one
	
	--add one offer for each lease
	INSERT INTO RenewalOffer (AcceptedRenewalOfferOptionID, AccountID, LeaseID, RenewalOfferBatchID, RenewalOfferID, [Status], CurrentRent, CurrentRentConcessions)
		SELECT NULL, @accountID, #l.LeaseID, @renewalOfferBatchID, NEWID(), 'Created', #l.CurrentRent, #l.CurrentRentConcessions
			FROM #Leases #l
			WHERE #l.HasOfferInBatch = 0

	-- this table is just to map new RenewalOfferOptionIDs to the DefaultRenewalOfferOptionID that created it so that we can add the correct default specials later
	CREATE TABLE #OptionsToAdd (
		LeaseID uniqueidentifier not null,
		RenewalOfferID uniqueidentifier not null,
		RenewalOfferOptionID uniqueidentifier not null,
		DefaultRenewalOfferOptionID uniqueidentifier not null,
		CurrentRent money not null,
		MarketRent money not null
	)

	INSERT INTO #OptionsToAdd
		SELECT #l.LeaseID, ro.RenewalOfferID, NEWID(), droo.DefaultRenewalOfferOptionID, #l.CurrentRent, #l.MarketRent
			FROM DefaultRenewalOfferOption droo
				INNER JOIN #Leases #l ON 1 = 1
				LEFT JOIN UnitTypeLeaseTerm utlt ON utlt.UnitTypeID = #l.UnitTypeID AND utlt.LeaseTermID = droo.LeaseTermID
				INNER JOIN RenewalOffer ro ON ro.LeaseID = #l.LeaseID AND ro.RenewalOfferBatchID = @renewalOfferBatchID
			WHERE #l.HasOfferInBatch = 0
			  AND (droo.LeaseTermID IS NULL OR utlt.UnitTypeLeaseTermID IS NOT NULL)

	INSERT INTO RenewalOfferOption (AccountID, LeaseTermDuration, LeaseTermID, RenewalOfferID, RenewalOfferOptionID, Rent, IsBaseOption)
		SELECT @accountID, 
			   droo.LeaseTermDuration, 
			   droo.LeaseTermID, 
			   #ota.RenewalOfferID, 
			   #ota.RenewalOfferOptionID, 
			   CASE WHEN droo.AdjustmentStartValue = 'CurrentRent' THEN #ota.CurrentRent + CASE WHEN droo.AdjustmentType = 'Amount' THEN droo.AdjustmentAmount
																								WHEN droo.AdjustmentType = 'Percentage' THEN (#ota.CurrentRent * (droo.AdjustmentAmount / 100))
																							END
					WHEN droo.AdjustmentStartValue = 'MarketRent' THEN #ota.MarketRent + CASE WHEN droo.AdjustmentType = 'Amount' THEN droo.AdjustmentAmount
																								WHEN droo.AdjustmentType = 'Percentage' THEN (#ota.MarketRent * (droo.AdjustmentAmount / 100))
																							END
					ELSE -1 --These guys are calculated off of the base offer. We'll do that in an UPDATE
				END,
				droo.IsBaseOption
			FROM #OptionsToAdd #ota
				INNER JOIN DefaultRenewalOfferOption droo ON droo.DefaultRenewalOfferOptionID = #ota.DefaultRenewalOfferOptionID

	--Have to do this here to get the base rents all set
	UPDATE roo SET roo.Rent = CASE WHEN roo.Rent > droo.MaximumRent THEN droo.MaximumRent
								   WHEN roo.Rent < droo.MinimumRent THEN droo.MinimumRent
								   ELSE roo.Rent
							  END
		FROM RenewalOfferOption roo
			INNER JOIN #OptionsToAdd #ota ON #ota.RenewalOfferOptionID = roo.RenewalOfferOptionID
			INNER JOIN DefaultRenewalOfferOption droo ON droo.DefaultRenewalOfferOptionID = #ota.DefaultRenewalOfferOptionID


	--For the options that are not the base option, we need to calculate the rent amount based on the base.
	UPDATE roo SET roo.Rent = baseRoo.Rent + CASE WHEN droo.AdjustmentType = 'Amount' THEN droo.AdjustmentAmount
												  WHEN droo.AdjustmentType = 'Percentage' THEN (baseRoo.Rent * (droo.AdjustmentAmount / 100))
											 END
		FROM RenewalOfferOption roo
			INNER JOIN #OptionsToAdd #ota ON #ota.RenewalOfferOptionID = roo.RenewalOfferOptionID
			INNER JOIN DefaultRenewalOfferOption droo ON droo.DefaultRenewalOfferOptionID = #ota.DefaultRenewalOfferOptionID AND droo.IsBaseOption = 0
			INNER JOIN DefaultRenewalOfferOption baseDroo ON baseDroo.RenewalOfferBatchID = droo.RenewalOfferBatchID AND baseDroo.IsBaseOption = 1 AND baseDroo.DefaultRenewalOfferOptionID <> #ota.DefaultRenewalOfferOptionID
			INNER JOIN #OptionsToAdd #baseOption ON #baseOption.DefaultRenewalOfferOptionID = baseDroo.DefaultRenewalOfferOptionID
			INNER JOIN RenewalOfferOption baseRoo ON baseRoo.RenewalOfferOptionID = #baseOption.RenewalOfferOptionID AND baseRoo.RenewalOfferID = roo.RenewalOfferID
		

	--Have to do this again to make sure the other options are correct.
	UPDATE roo SET roo.Rent = CASE WHEN roo.Rent > droo.MaximumRent THEN droo.MaximumRent
								   WHEN roo.Rent < droo.MinimumRent THEN droo.MinimumRent
								   ELSE roo.Rent
							  END
		FROM RenewalOfferOption roo
			INNER JOIN #OptionsToAdd #ota ON #ota.RenewalOfferOptionID = roo.RenewalOfferOptionID
			INNER JOIN DefaultRenewalOfferOption droo ON droo.DefaultRenewalOfferOptionID = #ota.DefaultRenewalOfferOptionID
		

	--add specials to each offer option matching on default renewal offer option id
	INSERT INTO RenewalOfferOptionSpecial (AccountID, RenewalOfferOptionID, SpecialID)
		SELECT @accountID, #ota.RenewalOfferOptionID, droos.SpecialID
			FROM DefaultRenewalOfferOptionSpecial droos
				INNER JOIN #OptionsToAdd #ota ON #ota.DefaultRenewalOfferOptionID = droos.DefaultRenewalOfferOptionID


	--Delete offers where the lease no longer meets the criteria
	DELETE ro 
		FROM RenewalOffer ro
			LEFT JOIN #Leases #l ON #l.LeaseID = ro.LeaseID
		WHERE ro.RenewalOfferBatchID = @renewalOfferBatchID
		  AND #l.LeaseID IS NULL
		  AND ro.[Status] IN ('Created', 'Approved') -- don't want offers that have already been sent to be deleted

	DELETE roo	
		FROM RenewalOfferOption roo
			LEFT JOIN RenewalOffer ro ON ro.RenewalOfferID = roo.RenewalOfferID
		WHERE ro.RenewalOfferID IS NULL

	DELETE roos 
		FROM RenewalOfferOptionSpecial roos
			LEFT JOIN RenewalOfferOption roo ON roo.RenewalOfferOptionID = roos.RenewalOfferOptionID
		WHERE roo.RenewalOfferOptionID IS NULL


	--Make sure that if an offer has options, it has a base
	UPDATE RenewalOfferOption SET IsBaseOption = 1
			--Check that the offer does not have a base option
		WHERE NOT EXISTS (SELECT *
							FROM RenewalOfferOption roo2
							WHERE roo2.RenewalOfferID = RenewalOfferOption.RenewalOfferID
							  AND roo2.IsBaseOption = 1)
			-- Make sure this is the first option in the offer and set it to be the base option
		  AND RenewalOfferOptionID = (SELECT TOP 1 RenewalOfferOptionID
										FROM RenewalOfferOption roo3
										WHERE roo3.RenewalOfferID = RenewalOfferOption.RenewalOfferID
										ORDER BY roo3.RenewalOfferOptionID)



	--Make sure all offers have an option
	INSERT RenewalOfferOption (AccountID, IsBaseOption, LeaseTermDuration, LeaseTermID, RenewalOfferID, RenewalOfferOptionID, Rent)
		SELECT ro.AccountID, 1, 12, null, ro.RenewalOfferID, NEWID(), CASE WHEN #l.MarketRent > ro.CurrentRent THEN #l.MarketRent ELSE ro.CurrentRent END
			FROM RenewalOffer ro
				LEFT JOIN RenewalOfferOption roo ON roo.RenewalOfferID = ro.RenewalOfferID
				INNER JOIN #Leases #l ON #l.LeaseID = ro.LeaseID
			WHERE ro.RenewalOfferBatchID = @renewalOfferBatchID
			  AND roo.RenewalOfferOptionID IS NULL
END
GO
