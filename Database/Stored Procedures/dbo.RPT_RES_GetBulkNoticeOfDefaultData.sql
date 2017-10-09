SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Josh Grigg (w/some help from Rick)
-- Create date: June 14, 2016
-- Description:	Gets data needed to run bulk notice of default report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_GetBulkNoticeOfDefaultData] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@startBalance money = null,
	@endBalance money = null,
	@endDate Date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #UnitLeaseGroups(
		PropertyID			uniqueidentifier NOT NULL,
		UnitID				uniqueidentifier NOT NULL,
		UnitLeaseGroupID	uniqueidentifier NOT NULL
	)


	CREATE TABLE #OutstandingCharges(
		PropertyID			uniqueidentifier		NOT NULL,
		UnitID				uniqueidentifier		NOT NULL,
		ObjectID			uniqueidentifier		NOT NULL,
		TransactionID		uniqueidentifier		NOT NULL,
		Amount				money					NOT NULL,
		UnpaidAmount		money					NULL,
		[Description]		nvarchar(200)			NULL,
		TranDate			datetime2				NULL
	)

	INSERT #UnitLeaseGroups
		SELECT DISTINCT
			p.Value,
			u.UnitID,
			ulg.UnitLeaseGroupID
		FROM @propertyIDs p
			INNER JOIN UnitType ut on p.Value = ut.PropertyID
			INNER JOIN Unit u on ut.UnitTypeID = u.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg on u.UnitID = ulg.UnitID
			INNER JOIN Lease l on ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			OUTER APPLY GetObjectBalance2(null, @endDate, ulg.UnitLeaseGroupID, 0, p.Value) as balance
		WHERE ((@startBalance IS NULL) OR (@startBalance <= balance))
			AND ((@endBalance IS NULL) OR (balance <= @endBalance))
			AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)

	INSERT #OutstandingCharges
		SELECT
			#ulg.PropertyID,
			#ulg.UnitID,
			t.ObjectID,
			t.[TransactionID],
			t.Amount,
			0, 
			t.[Description], 
			t.TransactionDate
		FROM #UnitLeaseGroups #ulg	
					INNER JOIN [Transaction] t ON #ulg.UnitLeaseGroupID = t.[ObjectID]
					INNER JOIN [TransactionType]  ON t.[TransactionTypeID] = [TransactionType].[TransactionTypeID]
					LEFT JOIN [PostingBatch] pb ON t.PostingBatchID = pb.PostingBatchID	
					LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID			
				WHERE t.AccountID = @accountID
					AND t.PropertyID = #ulg.PropertyID
					AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
					AND (([TransactionType].[Group] = 'Lease') OR ([TransactionType].[Group] = 'Tax'))
					AND (([TransactionType].[Name] = 'Charge') AND (t.AppliesToTransactionID IS NULL))
					AND t.ReversesTransactionID IS NULL
					-- Ensure that the Charge Transaction has not been reversed
					AND tr.TransactionID IS NULL

	UPDATE #OutstandingCharges SET UnpaidAmount = (SELECT #OutstandingCharges.Amount - ISNULL(SUM(t.Amount), 0) 
			FROM [Transaction] t
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			WHERE t.AppliesToTransactionID = #OutstandingCharges.TransactionID 
				  AND tt.Name NOT IN ('Tax Charge')
				  -- Ensure that the Payment Transaction has not been reversed
				  AND tr.TransactionID IS NULL)

	--outstanding charges
	SELECT DISTINCT
			ObjectID AS 'UnitLeaseGroupID',
			RIGHT(REPLACE(convert(varchar, TranDate, 106), '-', ' '), 8) + ' ' + [Description] AS 'ChargeDateAndName',
			UnpaidAmount AS 'ChargeAmount'
		FROM #OutstandingCharges
		WHERE UnpaidAmount > 0

	--resident names
	SELECT DISTINCT
			#ulg.UnitLeaseGroupID,
			p.PreferredName + ' ' + p.LastName AS 'ResidentName',
			p.SSN
		FROM #UnitLeaseGroups #ulg
			INNER JOIN Lease l ON #ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			INNER JOIN Person p ON pl.PersonID = p.PersonID
		WHERE l.AccountID = @accountID
		  AND pl.MainContact = 1
	
	--unit addresses
	SELECT DISTINCT
			#ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			CASE WHEN (u.AddressIncludesUnitNumber = 1) THEN a.StreetAddress 
				 ELSE a.StreetAddress + ' ' + u.Number END AS 'StreetAddress',
			a.City,
			a.Country,
			a.[State],
			a.Zip
		FROM #UnitLeaseGroups #ulg
			INNER JOIN Unit u ON #ulg.UnitID = u.UnitID
			LEFT JOIN [Address] a ON u.AddressID = a.AddressID
		WHERE a.AccountID = @accountID
	
	--property addresses
	SELECT DISTINCT
			#ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			p.PropertyID AS 'PropertyID',
			p.Name,
			p.LegalName,
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			a.Country
		FROM Property p
			INNER JOIN #UnitLeaseGroups #ulg ON #ulg.PropertyID = p.PropertyID
			LEFT JOIN [Address] a ON p.PropertyID = a.ObjectID
		WHERE p.AccountID = @accountID
END
GO
