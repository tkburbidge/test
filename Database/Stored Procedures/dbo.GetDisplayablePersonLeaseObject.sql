SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetDisplayablePersonLeaseObject] 
	-- Add the parameters for the stored procedure here
	@personLeaseID uniqueidentifier = null,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT	pl.ApplicationDate,
			pl.ApprovalStatus,
			pl.HouseholdStatus,
			CASE
				WHEN (u.IsHoldingUnit = 1) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'IsWaitingListLease',
			CASE
				WHEN (pendLease.LeaseID IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'IsOnPendingLeaseRenewal',
			l.LeaseID,
			l.LeaseStartDate,
			l.LeaseEndDate,
			l.LeaseStatus,
			CASE
				WHEN (leaseAgent.PersonID IS NOT NULL) THEN leaseAgent.PreferredName + ' ' + leaseAgent.LastName
				ELSE null END AS 'LeasingAgentPerson',
			leaseAgent.PersonID AS 'LeasingAgentPersonID',
			pl.MainContact,
			pl.MoveInDate,
			pl.MoveOutDate,
			pl.NoticeGivenDate,
			pl.PersonLeaseID,
			p.Name AS 'Property',
			p.PropertyID,
			p.PropertyType,
			pl.ReasonForLeaving,
			pl.ResidencyStatus,
			CASE
				WHEN (at.ApplicantTypeID IS NOT NULL) THEN at.Name
				ELSE null END AS 'ApplicantType',
			u.UnitID,
			ut.UnitTypeID,
			ulg.UnitLeaseGroupID,
			ulg.SalesTaxExempt,
			CASE
				WHEN (litp.LedgerItemTypePropertyID IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'ShowSalesTaxExempt',
			u.Number AS 'UnitNumber',
			ut.Name AS 'UnitType',
			[TransferringToUnit].LeaseID AS 'TransferringLeaseID',
			[TransferringToUnit].Number AS 'TransferringUnit',
			[TransferringToUnit].LeaseStatus AS 'TransferringLeaseStatus',
			[RenewedLease].LeaseID AS 'RenewedLeaseID',
			[RenewedLease].LeaseStatus AS 'RenewedLeaseStatus',
			[RenewedLease].LeaseStartDate AS 'RenewedLeaseStartDate',
			[RenewedLease].LeaseEndDate AS 'RenewedLeaseEndDate',
			CASE
				WHEN (cd.CollectionDetailID IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'OnCollections',
			forwardAdd.AddressID AS 'ForwardingAddressID',
			forwardAdd.AccountID AS 'ForwardingAccountID',
			forwardAdd.AddressType AS 'ForwardingAddressType',
			forwardAdd.City AS 'ForwardingCity',
			forwardAdd.Country AS 'ForwardingCountry',
			forwardAdd.IsDefaultMailingAddress AS 'ForwardingIsDefaultMailingAddress',
			forwardAdd.ObjectID AS 'ForwardingObjectID',
			forwardAdd.[State] AS 'ForwardingState',
			forwardAdd.StreetAddress AS 'ForwardingStreetAddress',
			forwardAdd.Zip AS 'ForwardingZip',
			CASE 
				WHEN (plSigned.PersonLeaseID IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'LeaseSigned',
			ulg.OnlinePaymentsDisabled,
			CASE
				WHEN (appScr.ApplicantScreeningID IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'ApplicantsScreeened',
			CASE
				WHEN (ulg.MoveOutReconciliationDate IS NOT NULL) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'MoveOutReconciliation',
			CASE
				WHEN (ulg.EndingBalancesTransferred IS NOT NULL) THEN ulg.EndingBalancesTransferred
				ELSE CAST(0 AS bit) END AS 'EndingBalancesTransferred',
			CASE
				WHEN ((l.LeaseStatus IN (N'Pending',N'Pending Transfer',N'Pending Renewal')) AND (llio.LeaseLedgerItemID IS NOT NULL)) 
					THEN
						ISNULL((SELECT SUM(lli.Amount)
									FROM LeaseLedgerItem lli
										INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
										INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
									WHERE lli.LeaseID = l.LeaseID
									  AND lli.StartDate <= l.LeaseEndDate
									  AND lli.EndDate >= l.LeaseEndDate), 0.00)
					ELSE 0.00 END AS 'PendingRent',
			CASE
				WHEN ((l.LeaseStatus IN (N'Current',N'Under Eviction')) AND (llio.LeaseLedgerItemID IS NOT NULL))
					THEN
						ISNULL((SELECT SUM(lli.Amount)
									FROM LeaseLedgerItem lli
										INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
										INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
									WHERE lli.LeaseID = l.LeaseID
									  AND lli.StartDate <= l.LeaseEndDate
									  AND lli.EndDate >= l.LeaseEndDate), 0.00)
					ELSE 0.00 END AS 'CurrentRent',
			ISNULL((SELECT SUM(lli.Amount)
						FROM LeaseLedgerItem lli
							INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
						WHERE lli.LeaseID = formerLease.LeaseID
						  AND lli.StartDate <= formerLease.LeaseEndDate
						  AND lli.EndDate >= formerLease.LeaseEndDate), 0.00) AS 'FormerRent',
			HAPWOIT.WOITAccountID AS 'HAPLedgerID'
		FROM PersonLease pl
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID
			LEFT JOIN Lease pendLease ON ulg.UnitLeaseGroupID = pendLease.UnitLeaseGroupID AND pendLease.LeaseStatus IN (N'Pending', N'Pending Transfer', N'Pending Renewal')
									AND pendLease.LeaseStartDate > l.LeaseStartDate AND l.LeaseID <> pendLease.LeaseID
			LEFT JOIN Lease formerLease ON ulg.UnitLeaseGroupID = formerLease.UnitLeaseGroupID AND formerLease.LeaseStatus IN (N'Denied', N'Former', N'Evicted', N'Renewed')
									AND formerLease.LeaseID = (SELECT TOP 1 LeaseID
																   FROM Lease
																   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																     AND LeaseStatus IN (N'Denied', N'Former', N'Evicted', N'Renewed')
																	 AND DateCreated < l.DateCreated
																	 AND LeaseStartDate < l.LeaseStartDate
																   ORDER BY LeaseEndDate DESC)
			LEFT JOIN LeaseLedgerItem llio ON l.LeaseID = llio.LeaseID AND llio.StartDate <= l.LeaseStartDate AND llio.EndDate >= l.LeaseEndDate
											AND llio.LeaseLedgerItemID = (SELECT TOP 1 LeaseLedgerItemID
																			 FROM LeaseLedgerItem
																			 WHERE LeaseID = l.LeaseID
																			 ORDER BY Amount DESC)
			LEFT JOIN Person leaseAgent ON l.LeasingAgentPersonID = leaseAgent.PersonID
			LEFT JOIN ApplicantType at ON pl.ApplicantTypeID = at.ApplicantTypeID
			LEFT JOIN LedgerItemTypeProperty litp ON p.PropertyID = litp.PropertyID AND litp.TaxRateGroupID IS NOT NULL
			LEFT JOIN CollectionDetail cd ON ulg.UnitLeaseGroupID = cd.ObjectID
			LEFT JOIN [Address] forwardAdd ON pl.PersonID = forwardAdd.ObjectID AND forwardAdd.AddressType = 'Forwarding'
			LEFT JOIN PersonLease plSigned ON l.LeaseID = plSigned.LeaseID AND plSigned.LeaseSignedDate IS NOT NULL
			LEFT JOIN ApplicantScreening appScr ON ulg.UnitLeaseGroupID = appScr.UnitLeaseGroupID
			LEFT JOIN WOITAccount HAPWOIT ON ulg.UnitLeaseGroupID = HAPWOIT.BillingAccountID AND HAPWOIT.[Type] = 'HAP'
			LEFT JOIN 
					(SELECT newULG.PreviousUnitLeaseGroupID, newL.LeaseID, newU.Number, newL.LeaseStatus
						FROM Lease newL
							INNER JOIN UnitLeaseGroup newULG ON newL.UnitLeaseGroupID = newULG.UnitLeaseGroupID
							INNER JOIN Unit newU ON newULG.UnitID = newU.UnitID) [TransferringToUnit] ON ulg.UnitLeaseGroupID = [TransferringToUnit].PreviousUnitLeaseGroupID
			LEFT JOIN
					(SELECT renewedL.UnitLeaseGroupID, renewedL.LeaseID, renewedL.LeaseStatus, renewedL.LeaseStartDate, renewedL.LeaseEndDate, renewedL.DateCreated
						FROM Lease renewedL
						WHERE renewedL.LeaseStatus NOT IN (N'Cancelled', N'Denied')) [RenewedLease] ON ulg.UnitLeaseGroupID = [RenewedLease].UnitLeaseGroupID 
																AND l.LeaseStartDate < [RenewedLease].LeaseStartDate AND l.DateCreated < [RenewedLease].DateCreated

		WHERE pl.PersonLeaseID = @personLeaseID






END
GO
