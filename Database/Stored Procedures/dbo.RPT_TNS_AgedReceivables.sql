SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 2, 2012
-- Description:	Generates the data for the Aged Receivables Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_AgedReceivables]
	-- Add the parameters for the stored procedure here
	@date datetime = null,
	@propertyIDs GuidCollection READONLY,
	@objectTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #LeaseStatuses (
		LeaseStatus nvarchar(50)
	)

	CREATE TABLE #ObjectTypes (
		ObjectType nvarchar(50)
	)

	IF (NOT EXISTS (SELECT Value FROM @leaseStatuses) AND NOT EXISTS(SELECT Value FROM @objectTypes))
		BEGIN
			INSERT #LeaseStatuses SELECT DISTINCT Value FROM Ordering WHERE [Type] = 'Lease'

			INSERT #ObjectTypes SELECT 'Lease'
			INSERT #ObjectTypes SELECT 'Prospect'
			INSERT #ObjectTypes SELECT 'Non-Resident Account'
			INSERT #ObjectTypes SELECT 'WOIT Account'
		END
	ELSE
		BEGIN
			INSERT #LeaseStatuses SELECT Value FROM @leaseStatuses
			INSERT #ObjectTypes SELECT Value FROM @objectTypes
		END

	IF (EXISTS(SELECT * FROM @leaseStatuses WHERE Value IN ('Current')))
	BEGIN
		INSERT #LeaseStatuses VALUES ('Renewed')
	END

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #AgedReceivables (
		PropertyID uniqueidentifier NOT NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(25) NOT NULL,
		TransactionID uniqueidentifier NULL,
		PaymentID uniqueidentifier NULL,
		TransactionType nvarchar(50) NOT NULL,
		TransactionTypeGroup nvarchar(50) NOT NULL,
		Names nvarchar(1000) NULL,
		TransactionDate datetime NOT NULL,
		LedgerItemType nvarchar(50) NULL,
		Total money NULL,
		PrepaymentsCredits money NULL,
		-- When we are recording Balance Transfers as prepayments from a deposit
		-- that was transferred from another ledger, we are using the actual Transaction.Amount
		-- instead of the Payment.Amount. In this case we don't want to update the temp table
		-- with the transferred amontn
		DoNotUpdateAmount bit)



	INSERT INTO #AgedReceivables
		SELECT DISTINCT
				t.PropertyID AS 'PropertyID',
				ulg.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				t.TransactionID AS 'TransactionID',
				NULL AS 'PaymentID',
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				NULL AS 'Names',
				t.TransactionDate AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',
				t.Amount AS 'Total',
				null AS 'PrepaymentsCredits',
				CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM UnitLeaseGroup ulg
				INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Charge')))
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
			WHERE
			   (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  AND t.TransactionDate <= @date
			  AND t.Amount > 0
			  /* START NEW */
			  -- Do not include transferred charges
			  AND t.AppliesToTransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			  /* END NEW */
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
			  AND (t.ClosedDate IS NULL OR t.ClosedDate > @date)

		UNION

		SELECT DISTINCT
				t.PropertyID AS 'PropertyID',
				ulg.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				null AS 'TransactionID',
				py.PaymentID AS 'PaymentID',
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				'' AS Name,
				py.[Date] AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',--'Prepayment' AS 'LedgerItemType',
				null AS 'Total',
				py.Amount AS 'PrepaymentsCredits',
				CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM UnitLeaseGroup ulg
				INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID AND
					-- Logic: There is an outstanding amount to be applied
					--		  or the amount that was applied was applied in the future
					--		  or the LedgerItemTypeID IS NULL which is only in the case of Balance Transfers or Deposit Applications
					--			 In these cases, the WHERE clause below will base everything off the TransactionDate not the Payment Date
					--			 which in this case, the TransationDate will be greater than the @date if the Balance Transfer or Deposit Application
					--			 is applied after the report date.
					(t.AppliesToTransactionID IS NULL OR t.TransactionDate > @date OR t.LedgerItemTypeID IS NULL)

				INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
				INNER JOIN [Payment] py ON pt.PaymentID = py.PaymentID
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Credit', 'Payment', 'Balance Transfer Payment', 'Deposit Applied to Balance')))

				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
			WHERE
			  (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  -- Added because we were picking up deposit applications
			  -- that were reversed as the reversal transaction was catching
			  AND t.ReversesTransactionID IS NULL
			  AND (py.Reversed <> 1 OR py.ReversedDate > @date)
			  AND py.Amount > 0
			  /* START NEW */
			  -- Don't get the transferred payments or credits
			  AND py.ObjectID = t.ObjectID
			  /* END NEW */
			  AND ((lit.LedgerItemTypeID IS NULL AND t.TransactionDate <= @date) OR (lit.LedgerItemTypeID IS NOT NULL AND py.[Date] <= @date))		-- Lit.LITID is null only when it's a payment or credit due to a balance transfer
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))

	UNION

		SELECT DISTINCT
				t.PropertyID AS 'PropertyID',
				ulg.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				null AS 'TransactionID',
				py.PaymentID AS 'PaymentID',
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				'' AS Name,
				py.[Date] AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',--'Prepayment' AS 'LedgerItemType',
				null AS 'Total',
				t.Amount AS 'PrepaymentsCredits',
				CAST(1 AS BIT) AS 'DoNotUpdateAmount'
			FROM UnitLeaseGroup ulg
				INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID AND
					-- Logic: There is an outstanding amount to be applied
					--		  or the amount that was applied was applied in the future
					--		  or the LedgerItemTypeID IS NULL which is only in the case of Balance Transfers or Deposit Applications
					--			 In these cases, the WHERE clause below will base everything off the TransactionDate not the Payment Date
					--			 which in this case, the TransationDate will be greater than the @date if the Balance Transfer or Deposit Application
					--			 is applied after the report date.
					(t.AppliesToTransactionID IS NULL OR t.TransactionDate > @date OR t.LedgerItemTypeID IS NULL)

				INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
				INNER JOIN [Payment] py ON pt.PaymentID = py.PaymentID
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance')))

				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
			WHERE
			  (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  -- Added because we were picking up deposit applications
			  -- that were reversed as the reversal transaction was catching
			  AND t.ReversesTransactionID IS NULL
			  AND (py.Reversed <> 1 OR py.ReversedDate > @date)
			  AND py.Amount > 0
			  /* START NEW */
			  -- Don't get the transferred payments or credits
			  AND py.ObjectID <> t.ObjectID
			  /* END NEW */
			  AND ((lit.LedgerItemTypeID IS NULL AND t.TransactionDate <= @date) OR (lit.LedgerItemTypeID IS NOT NULL AND py.[Date] <= @date))		-- Lit.LITID is null only when it's a payment or credit due to a balance transfer
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
	UNION
	-- In the case that the same payment is transferred twice, we need to lump them together and
	-- treat the amount as a single amount transferred or else we will take all applications
	-- of the transferred payment and remove them from both entries thus making both go negative

		SELECT
			 PropertyID,
			 ObjectID,
			 ObjectType,
			 TransactionID,
			 PaymentID,
			 TransactionType,
			 TransactionTypeGroup,
			 Name,
			 TransactionDate,
			 LedgerItemType,
			 Total,
			 SUM(Amount),
			 CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM
		( -- Get Transferred Payments and Credits
			SELECT
			 DISTINCT
				t.PropertyID AS 'PropertyID',
				ulg.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				null AS 'TransactionID',
				py.PaymentID AS 'PaymentID',
				'' AS Name,
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				py.[Date] AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',--'Prepayment' AS 'LedgerItemType',
				null AS 'Total',
				--CASE WHEN t.Origin = 'T' THEN t.Amount ELSE py.Amount END AS 'PrepaymentsCredits'
				t.Amount,
				CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM UnitLeaseGroup ulg
				INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
				INNER JOIN [Payment] py ON pt.PaymentID = py.PaymentID
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Over Credit', 'Prepayment')))
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
			WHERE
			   (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  AND (py.Reversed <> 1 OR py.ReversedDate > @date)
			  AND py.Amount > 0
			  -- Only get the transferred payments or credits
			  AND py.ObjectID <> t.ObjectID
			  AND t.Origin = 'T'
			  AND t.TransactionDate <= @date
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))) t

		GROUP BY PropertyID, ObjectID, ObjectType, TransactionID, PaymentID, TransactionType, TransactionTypeGroup, Name, TransactionDate, LedgerItemType, Total
	UNION


		SELECT DISTINCT
				p.PropertyID AS 'PropertyID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN woit.BillingAccountID
					ELSE t.ObjectID
				END AS 'ObjectID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN 'HAP Account'
					ELSE tt.[Group]
				END AS 'ObjectType',
				t.TransactionID AS 'TransactionID',
				NULL AS 'PaymentID',
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				CASE
					--WHEN (woit.BillingAccountID IS NOT NULL) THEN
					--	u.Number + ' - ' + STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					--	FROM Person
					--		INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
					--		INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					--		INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					--	WHERE PersonLease.LeaseID = l.LeaseID
					--		AND PersonType.[Type] = 'Resident'
					--		AND PersonLease.MainContact = 1
					--	FOR XML PATH ('')), 1, 2, '')
					WHEN (woit.BillingAccountID IS NOT NULL) THEN NULL
					WHEN (pr.PersonID IS NOT NULL) THEN pr.PreferredName + ' ' + pr.LastName
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
				END AS 'Name',
				t.TransactionDate AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',
				t.Amount AS 'Total',
				null AS 'PrepaymentsCredits',
				CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Charge')))
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup ulg ON woit.BillingAccountID = ulg.UnitLeaseGroupID
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			WHERE tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
			  AND (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  AND t.TransactionDate <= @date
			  AND t.Amount > 0
			  /* START NEW */
			  -- Do not include transferred charges
			  AND t.AppliesToTransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			  /* END NEW */
			  AND ((t.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
			  AND (t.ClosedDate IS NULL OR t.ClosedDate > @date)
			  AND (l.LeaseID IS NULL OR l.LeaseID = (SELECT TOP 1 Lease.LeaseID
													 FROM Lease
													 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													 WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													 ORDER BY Ordering.OrderBy))

	UNION


		SELECT DISTINCT
				p.PropertyID AS 'PropertyID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN woit.BillingAccountID
					ELSE t.ObjectID
				END AS 'ObjectID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN 'HAP Account'
					ELSE tt.[Group]
				END AS 'ObjectType',
				null AS 'TransactionID',
				py.PaymentID AS 'PaymentID',
				tt.Name AS 'TransactionType',
				tt.[Group] AS 'TransactionTypeGroup',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN NULL
					WHEN (pr.PersonID IS NOT NULL) THEN pr.PreferredName + ' ' + pr.LastName
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
				END AS 'Name',
				py.[Date] AS 'TransactionDate',
				lit.Name AS 'LedgerItemType',--'Prepayment' AS 'LedgerItemType',
				null AS 'Total',
				py.Amount AS 'PrepaymentsCredits',
				CAST(0 AS BIT) AS 'DoNotUpdateAmount'
			FROM  [Transaction] t
				INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
				INNER JOIN [Payment] py ON pt.PaymentID = py.PaymentID
				INNER JOIN TransactionType tt ON ((t.TransactionTypeID = tt.TransactionTypeID) AND (tt.Name IN ('Credit', 'Payment')))
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN [Person] pr ON t.ObjectID = pr.PersonID
				LEFT JOIN [WOITAccount] woit ON t.ObjectID = woit.WOITAccountID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
			WHERE -- Logic: There is an outstanding amount to be applied
					--		  or the amount that was applied was applied in the future
					--		  or the LedgerItemTypeID IS NULL which is only in the case of Balance Transfers or Deposit Applications
					--			 In these cases, the WHERE clause below will base everything off the TransactionDate not the Payment Date
					--			 which in this case, the TransationDate will be greater than the @date if the Balance Transfer or Deposit Application
					--			 is applied after the report date.
			  (t.AppliesToTransactionID IS NULL OR t.TransactionDate > @date OR t.LedgerItemTypeID IS NULL)
			  AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
			  AND (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
			  -- Added because we were picking up deposit applications
			  -- that were reversed as the reversal transaction was catching
			  AND t.ReversesTransactionID IS NULL
			  AND (py.Reversed <> 1 OR py.ReversedDate > @date)
			  AND py.Amount > 0
			   /* START NEW */
			  -- Don't get the transferred payments or credits
			  AND py.ObjectID = t.ObjectID
			  /* END NEW */
			  AND ((lit.LedgerItemTypeID IS NULL AND t.TransactionDate <= @date) OR (lit.LedgerItemTypeID IS NOT NULL AND py.[Date] <= @date))		-- Lit.LITID is null only when it's a payment or credit due to a balance transfer
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))



	-- Update all payments that are in the table due to a balance transfer or a deposit application
	-- with the amount of the actual transfer or application not the original Payment.Amount
	UPDATE #AgedReceivables SET PrepaymentsCredits = (SELECT ISNULL((SELECT	SUM(tbtp.Amount)
																FROM Payment py
																	LEFT JOIN UnitLeaseGroup ulg ON #AgedReceivables.ObjectID = ulg.UnitLeaseGroupID
																	LEFT JOIN [PaymentTransaction] ptd ON py.PaymentID = ptd.PaymentID
																	LEFT JOIN [Transaction] td ON ptd.TransactionID = td.TransactionID AND td.TransactionTypeID IN (SELECT TransactionTypeID
																																										FROM TransactionType

																																										WHERE Name IN ('Deposit')--, 'Payment', 'Balance Transfer Deposit')
																																										  AND AccountID = py.AccountID)
																	LEFT JOIN [Transaction] tbtp ON tbtp.AppliesToTransactionID = td.TransactionID AND tbtp.TransactionTypeID IN (SELECT TransactionTypeID
																																													FROM TransactionType
																																													WHERE Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance')
																																													  AND AccountID = py.AccountID)
																	LEFT JOIN [Transaction] tbtpr ON tbtp.TransactionID = tbtpr.ReversesTransactionID
																WHERE td.TransactionID IS NOT NULL
																  -- Make sure the application wasn't revsered
																  AND (tbtpr.TransactionID IS NULL OR tbtpr.TransactionDate > @date)
																  AND tbtp.TransactionDate <= @date
																   -- If someone applies or balance transfers a deposit and then
																  -- transfers that application to another unit, we don't want to
																  -- set the balance of the prepayment in the new unit to the original amount.
																  -- The way to check this is to only do the current process for payments that
																  -- are for the same ObjectID and thus not transferred.
																  AND py.ObjectID = #AgedReceivables.ObjectID
																   AND (tbtp.TransactionID iS NULL or tbtp.ObjectID = #AgedReceivables.ObjectID)
																  AND py.PaymentID = #AgedReceivables.PaymentID), PrepaymentsCredits))

--select * from #AgedReceivables

	-- Handles payments, credits that were balance transferred and then possibly applied back to their ledger
	UPDATE #AgedReceivables SET PrepaymentsCredits = PrepaymentsCredits -
								(SELECT (ISNULL((SELECT SUM(CASE WHEN ttpa.Name = 'Balance Transfer Deposit' THEN tpa.Amount ELSE -tpa.Amount END)
									FROM [Transaction] tpa
										INNER JOIN TransactionType ttpa ON tpa.TransactionTypeID = ttpa.TransactionTypeID AND ttpa.Name IN ('Balance Transfer Deposit', 'Payment Refund', 'Deposit Applied to Balance')
										LEFT JOIN [Transaction] t ON tpa.AppliesToTransactionID = t.TransactionID AND t.TransactionTypeID IN (SELECT TransactionTypeID
																																				FROM TransactionType
																																				WHERE AccountID = tpa.AccountID
																																				  AND Name IN( 'Deposit', 'Deposit Interest Payment')
																																				  AND [Group] = ttpa.[Group])
										INNER JOIN [Transaction] ta ON tpa.AppliesToTransactionID = ta.TransactionID
										INNER JOIN PaymentTransaction pt on ta.TransactionID = pt.TransactionID
										INNER JOIN Payment p on p.PaymentID = pt.PaymentID
										-- Payment Refunds can be reversed so we need to take this into account
										LEFT JOIN [Transaction] tpar ON tpar.ReversesTransactionID = tpa.TransactionID
									WHERE tpa.AppliesToTransactionID IS NOT NULL
									  AND tpa.TransactionDate <= @date
									  AND t.TransactionID IS NULL
									  AND p.PaymentID = #AgedReceivables.PaymentID
									  -- Payment Refunds can be reversed so we need to take this into account
									  AND (tpar.TransactionID IS NULL OR tpar.TransactionDate > @date)
									  AND tpa.ObjectID = #AgedReceivables.ObjectID
									  -- The Balance Transfer Deposit type is used when transferring a
									  -- payment from one unit to another in addition to from a deposit to
									  -- a payment.  We don't want to include the former in this calculation
									  AND tpa.Origin <> 'T'
									  -- Don't want to update transferred deposits except for removing the amount that
									  -- was applied to the balance and then refunded
									  AND (#AgedReceivables.DoNotUpdateAmount = 0 OR ttpa.Name = 'Payment Refund')), 0)))
--select * from #AgedReceivables

	UPDATE #AgedReceivables SET Total = (SELECT ISNULL((SELECT (#AgedReceivables.Total - ISNULL(SUM(ta.Amount), 0))
		FROM [Transaction] t
			INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
			INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name NOT IN ('Tax Charge', 'Tax Payment', 'Tax Credit')
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
		WHERE t.TransactionID = #AgedReceivables.TransactionID
		  AND (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
		  AND (tar.TransactionID IS NULL OR tar.TransactionDate > @date)
		  AND ta.TransactionDate <= @date
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		GROUP BY ta.AppliesToTransactionID), #AgedReceivables.Total))

--select * from #AgedReceivables

	UPDATE #AgedReceivables SET PrepaymentsCredits = (SELECT ISNULL((SELECT (#AgedReceivables.PrepaymentsCredits - ISNULL(SUM(payt.Amount), 0))
		FROM Payment py
			INNER JOIN PaymentTransaction pt1 ON py.PaymentID = pt1.PaymentID
			INNER JOIN [Transaction] payt ON pt1.TransactionID = payt.TransactionID
			INNER JOIN [TransactionType] tt ON payt.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Tax Payment', 'Tax Credit', 'Payment', 'Credit')
			-- Old Code: We used to pull in ALL applications whether it was a reversal or not. This worked
			-- because when we reversed a transactino we still had the reversal set with an AppliesToTransactionID.
			-- This caused issues with security deposit applications as the AppliesToTransactionID isn't set
			-- so we changed this to only pull in positive applications that are not reversals
			-- Only for deposit applications
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = payt.TransactionID --AND tar.Amount > 0
			LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
		WHERE py.PaymentID = #AgedReceivables.PaymentID
		  AND (tar.TransactionID IS NULL OR tar.TransactionDate > @date)
		  AND payt.TransactionDate <= @date
		  AND payt.AppliesToTransactionID IS NOT NULL
		  -- Application of a payment
		  AND payt.ReversesTransactionID IS NULL
		  /* START NEW */
		  AND payt.ObjectID = #AgedReceivables.ObjectID
		  /* END NEW */
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  ), #AgedReceivables.PrepaymentsCredits))

--select * from #AgedReceivables

-- Deal with Taxes


	--UPDATE #AgedReceivables SET Total = (SELECT ISNULL((SELECT (#AgedReceivables.Total + ISNULL(SUM(ta.Amount), 0))
	--	FROM [Transaction] t
	--		INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
	--		INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Tax Charge')
	--		LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	--		LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
	--	WHERE t.TransactionID = #AgedReceivables.TransactionID
	--	    AND (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
	--	   AND (tar.TransactionID IS NULL OR tar.TransactionDate > @date)
	--	GROUP BY ta.AppliesToTransactionID), #AgedReceivables.Total))



	--UPDATE #AgedReceivables SET Total = (SELECT ISNULL((SELECT #AgedReceivables.Total - ISNULL(SUM(tata.Amount), 0)
	--	FROM [Transaction] t
	--		INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
	--		INNER JOIN [Transaction] tata ON tata.AppliesToTransactionID = ta.TransactionID
	--		INNER JOIN [TransactionType] tta ON tata.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Tax Payment', 'Tax Credit')
	--		LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	--		LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
	--		LEFT JOIN [Transaction] tatar ON tatar.ReversesTransactionID = tata.TransactionID
	--	WHERE t.TransactionID = #AgedReceivables.TransactionID
	--		AND (tar.TransactionID IS NULL OR tar.TransactionDate > @date)
	--		AND (tr.TransactionID IS NULL OR tr.TransactionDate > @date)
	--		AND (tatar.TransactionID IS NULL OR tatar.TransactionDate > @date)
	--	  AND tata.TransactionDate <= @date
	--	GROUP BY ta.AppliesToTransactionID), #AgedReceivables.Total))




-- End Taxes Section


CREATE TABLE #AgedReceivablesResult (
		PropertyID uniqueidentifier NOT NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(25) NOT NULL,
		LeaseID uniqueidentifier NULL,
		Names nvarchar(1000) NULL,
		TransactionID uniqueidentifier NULL,
		PaymentID uniqueidentifier NULL,
		TransactionType nvarchar(50) NOT NULL,
		TransactionTypeGroup nvarchar(50) NOT NULL,
		TransactionDate datetime NOT NULL,
		LedgerItemType nvarchar(50) NULL,
		Total money NULL,
		PrepaymentsCredits money NULL,
		Reason nvarchar(200) NULL)



	INSERT INTO #AgedReceivablesResult
		SELECT PropertyID, ObjectID, ObjectType, null, Names, TransactionID, PaymentID, TransactionType, TransactionTypeGroup, TransactionDate, LedgerItemType,
				ISNULL(Total, 0) AS 'Total', ISNULL(SUM(PrepaymentsCredits), 0) AS 'Prepayments', NULL
			FROM #AgedReceivables
			WHERE ((Total IS NOT NULL) AND (Total > 0))
			   OR ((PrepaymentsCredits IS NOT NULL) AND (PrepaymentsCredits > 0))
			GROUP BY  PropertyID, ObjectID, ObjectType, Names, TransactionType, TransactionTypeGroup, TransactionDate, TransactionID, PaymentID, LedgerItemType, Total
--SELECT * FROM #AgedReceivablesResult
	-- Since we are including both Balance Transfer Payment in addition to Payments and Credits, there is a chance
	-- that we will get two records for the same payment.  Delete the Balance Transfer Payment if we do

	IF ((SELECT COUNT(*) FROM #AgedReceivablesResult WHERE TransactionType IN ('Balance Transfer Payment', 'Deposit Applied to Balance')) > 0)
	BEGIN

		DELETE #arr
			FROM #AgedReceivablesResult #arr
			INNER JOIN #AgedReceivablesResult #arr2 ON #arr.PaymentID = #arr2.PaymentID AND #arr2.TransactionType IN ('Payment', 'Credit')
			WHERE #arr.TransactionType IN ('Balance Transfer Payment', 'Deposit Applied to Balance')
	--SELECT * FROM #AgedReceivablesResult
		-- If we have just a Balance Transfer Payment we want to update it to either
		UPDATE #arr
			SET #arr.TransactionType = tt.Name
			FROM #AgedReceivablesResult #arr
				INNER JOIN Payment p ON p.PaymentID = #arr.PaymentID
				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
				INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
			WHERE #arr.TransactionType IN ('Balance Transfer Payment', 'Deposit Applied to Balance')
				AND tt.Name IN ('Payment', 'Credit')
	END

		UPDATE #AgedReceivablesResult SET LeaseID =  (SELECT TOP 1 LeaseID
														FROM Lease
														WHERE UnitLeaseGroupID = #AgedReceivablesResult.ObjectID
														ORDER BY LeaseEndDate DESC)
		WHERE LeaseID IS NULL
			AND ObjectType = 'Lease'

		UPDATE #AgedReceivablesResult SET LeaseID =  (SELECT TOP 1 l.LeaseID
														FROM Lease l
														WHERE l.UnitLeaseGroupID = #AgedReceivablesResult.ObjectID
														ORDER BY l.LeaseEndDate DESC)
		WHERE LeaseID IS NULL
			AND ObjectType = 'HAP Account'

		UPDATE #AgedReceivablesResult SET Names =  (SELECT TOP 1 p.PreferredName + ' ' + p.LastName
														FROM Lease l
															JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
															JOIN Person p ON pl.PersonID = p.PersonID
														WHERE l.LeaseID = #AgedReceivablesResult.LeaseID
															AND pl.HouseholdStatus = 'Head of Household'
														ORDER BY pl.MainContact)
		WHERE ObjectType = 'HAP Account'
			AND Names IS NULL

		UPDATE #AgedReceivablesResult SET Names =  (SELECT TOP 1 p.PreferredName + ' ' + p.LastName
														FROM Lease l
															JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
															JOIN Person p ON pl.PersonID = p.PersonID
														WHERE l.LeaseID = #AgedReceivablesResult.LeaseID
														ORDER BY pl.MainContact)
		WHERE ObjectType = 'HAP Account'
			AND Names IS NULL


		UPDATE #AgedReceivablesResult SET Names = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
														  FROM Person
															  INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
					 										  INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
															  INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
														  WHERE PersonLease.LeaseID = #AgedReceivablesResult.LeaseID
															AND PersonType.[Type] = 'Resident'
															AND PersonLease.MainContact = 1
														  FOR XML PATH ('')), 1, 2, '')
		WHERE LeaseID IS NOT NULL
			AND ObjectType = 'Lease'


		-- Update the Ledger Item Type Name for credits and payments
		UPDATE #AgedReceivablesResult SET LedgerItemType =  (SELECT TOP 1 lit.Name
															 FROM LedgerItemType lit
																INNER JOIN PaymentTransaction pt ON pt.PaymentID = #AgedReceivablesResult.PaymentID
																INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID
															 WHERE lit.LedgerItemTypeID = t.LedgerItemTypeID
															 ORDER BY lit.IsPayment DESC, lit.IsCredit DESC)
			WHERE LedgerItemType IS NULL
				AND TransactionType <> 'Charge'


	CREATE TABLE #Balances (
		ObjectID uniqueidentifier,
		PropertyID uniqueidentifier,
		Balance money,
		Reason nvarchar(4000)
	)

	INSERT INTO #Balances
		SELECT ObjectID,
			   PropertyID,
			   SUM(ISNULL(Total, 0) - ISNULL(PrepaymentsCredits, 0)),
			   null
		FROM #AgedReceivablesResult #arr
		GROUP BY ObjectID, PropertyID

	UPDATE #b SET Reason = CASE
								WHEN (#b.Balance < 0) THEN ulgap.PrepaidReason
								WHEN (#b.Balance > 0) THEN ulgap.DelinquentReason
								END
						FROM #Balances #b
							INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #b.PropertyID AND pap.StartDate <= @date AND pap.EndDate >= @date
							LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = #b.ObjectID AND ulgap.AccountingPeriodID = pap.AccountingPeriodID

	SELECT DISTINCT @date AS 'ReportDate',
			p.Name AS 'PropertyName',
			#arr.PropertyID,
			ISNULL(u.Number, wau.Number) AS 'Unit',
			ISNULL(u.PaddedNumber, wau.PaddedNumber) AS 'PaddedUnit',
			#arr.ObjectID,
			#arr.ObjectType,
			#arr.LeaseID,
			#arr.Names,
			#arr.TransactionID,
			#arr.PaymentID,
			#arr.TransactionType,
			#arr.TransactionDate,
			#arr.LedgerItemType,
			#arr.Total,
			#arr.PrepaymentsCredits AS 'Prepayments',
			#b.Reason
	FROM #AgedReceivablesResult #arr
		INNER JOIN Property p ON p.PropertyID = #arr.PropertyID
		LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #arr.ObjectID
		LEFT JOIN Unit u ON u.UnitID = ulg.UnitID
		LEFT JOIN #Balances #b on #b.ObjectID = #arr.ObjectID
		LEFT JOIN Lease l on #arr.LeaseID = l.LeaseID
		LEFT JOIN WOITAccount wa ON #arr.ObjectID = wa.WOITAccountID
		LEFT JOIN UnitLeaseGroup waulg ON wa.BillingAccountID = waulg.UnitLeaseGroupID
		LEFT JOIN Unit wau ON waulg.UnitID = wau.UnitID
	WHERE #arr.TransactionTypeGroup IN (SELECT ObjectType FROM #ObjectTypes)
	  AND (#arr.LeaseID IS NULL OR l.LeaseStatus IN (SELECT LeaseStatus From #LeaseStatuses))
	ORDER BY p.Name, ISNULL(u.PaddedNumber, wau.PaddedNumber), #arr.TransactionDate
END




GO
