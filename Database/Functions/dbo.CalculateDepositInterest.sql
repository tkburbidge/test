SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan 2, 2014
-- Description:	Calculates the interest on Deposits
-- =============================================
CREATE FUNCTION [dbo].[CalculateDepositInterest] 
(	
	-- Add the parameters for the function here
	@propertyID uniqueidentifier, 
	@objectIDs GuidCollection READONLY,
	@date date = null,
	@balance money = null
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT	ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID', 
			--t.TransactionID, ta.TransactionID as 'tta', lit.LedgerItemTypeID, lit.Name
			CASE WHEN (@balance IS NOT NULL) 
				THEN
					ROUND((((@balance) * (ifi1.Percentage / 36500) * 
						CASE WHEN (plmi.MoveInDate > ifi1.EndDate) THEN 0
							 ELSE (DATEDIFF(day, plmi.MoveInDate, ifi2.StartDate) + 1) END) +
					 ((@balance) * (ifi2.Percentage / 36500) * 
		    				 (DATEDIFF(day, ifi1.EndDate, plmo.MoveOutDate) + 1))), 2)			
				ELSE
					ROUND((((SUM(t.Amount) - ISNULL(SUM(ta.Amount), 0) - ISNULL(SUM(tar.Amount), 0)) * (ifi1.Percentage / 36500) * 
						CASE WHEN (plmi.MoveInDate > ifi1.EndDate) THEN 0
							 ELSE (DATEDIFF(DAY, plmi.MoveInDate, ifi1.EndDate) + 1) END )) +
						((SUM(t.Amount) - ISNULL(SUM(ta.Amount), 0) - ISNULL(SUM(tar.Amount), 0)) * (ISNULL(ifi2.Percentage, 0) / 36500) *
						CASE WHEN (plmi.MoveInDate > ifi1.EndDate) THEN
								(DATEDIFF(day, plmi.MoveInDate, plmo.MoveOutDate) + 1)
							 ELSE (DATEDIFF(day, ifi2.StartDate, plmo.MoveOutDate) + 1)
							 END),  2)
				END AS 'Interest'		 
		FROM UnitLeaseGroup ulg 
			INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID
			INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsDeposit = 1
			INNER JOIN Property prop ON t.PropertyID = prop.PropertyID AND prop.PropertyID = @propertyID
			INNER JOIN LedgerItemTypeProperty litp ON lit.LedgerItemTypeID = litp.LedgerItemTypeID AND litp.PropertyID = @propertyID
																	AND litp.IsInterestable = 1
			INNER JOIN InterestFormula iform ON prop.DepositInterestFormulaID = iform.InterestFormulaID
			INNER JOIN InterestFormulaItem ifi1 ON iform.InterestFormulaID = ifi1.InterestFormulaID AND ifi1.OrderBy = 0
			LEFT JOIN InterestFormulaItem ifi2 ON iform.InterestFormulaID = ifi2.InterestFormulaID AND ifi2.OrderBy = 1
			LEFT JOIN InterestFormulaItem ifi3 ON iform.InterestFormulaID = ifi3.InterestFormulaID AND ifi3.OrderBy = 2
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Former', 'Evicted')
			INNER JOIN PersonLease plmi ON plmi.PersonLeaseID = (SELECT TOP 1 PersonLeaseID 
																	FROM PersonLease 
																	WHERE LeaseID = l.LeaseID
																	  AND MoveInDate IS NOT NULL
																	  AND ResidencyStatus IN ('Former', 'Evicted')
																	ORDER BY MoveInDate)
			INNER JOIN PersonLease plmo ON plmo.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																	FROM PersonLease
																	WHERE LeaseID = l.LeaseID
																	  AND MoveOutDate IS NOT NULL
																	  AND ResidencyStatus IN ('Former', 'Evicted')																	  
																	ORDER BY MoveOutDate DESC)
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
			LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID AND ta.TransactionTypeID IN 											
											(SELECT TransactionTypeID 
												FROM TransactionType
												WHERE Name IN ('Deposit Refund', 'Deposit Applied to Balance'))
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
		WHERE ulg.UnitLeaseGroupID IN (SELECT Value FROM @objectIDs)
		  AND tr.TransactionID IS NULL
		  --AND tar.TransactionID IS NULL
		  AND ((@date IS NULL) OR (t.TransactionDate <= @date))
		  AND ((@date IS NULL) OR ((ta.TransactionID IS NULL) OR ((ta.TransactionID IS NOT NULL) AND (ta.TransactionDate <= @date))))
		GROUP BY ulg.UnitLeaseGroupID, ifi1.Percentage, ifi2.Percentage, plmi.MoveInDate, plmo.MoveOutDate, ifi1.EndDate, ifi2.StartDate
)
GO
