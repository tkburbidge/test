SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 14, 2013
-- Description:	Computes Management fees for a given set of properties
-- =============================================
CREATE PROCEDURE [dbo].[CalculateManagementFees] 
	-- Add the parameters for the stored procedure here
	@propertyIDEAS GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
	--IF (@accountingPeriodID IS NOT NULL)
	--BEGIN
	--	SELECT @startDate = StartDate, @endDate = EndDate
	--	FROM AccountingPeriod
	--	WHERE AccountingPeriodID = @accountingPeriodID
	--END
    
	CREATE TABLE #ManagementFees (
		ManagementRuleID uniqueidentifier not null,
		ManagementFeeID uniqueidentifier not null,
		RuleType nvarchar(50) not null,
		OrderyBy tinyint not null,
		AppliesToThreshold bit not null,
		Name nvarchar(50) null,		
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		CalculationType nvarchar(20) not null,
		CalculationValue decimal(9, 4) not null,
		BasedOnAccountType nvarchar(20) null,
		BasedOnAccountID uniqueidentifier null,
		CalculationName nvarchar(100) null,
		ObjectBalance money null,
		ChargedAmount money null,
		VendorID uniqueidentifier null)
		
				
	CREATE TABLE #TempManagementFees (
		ManagementRuleID uniqueidentifier not null,
		ManagementFeeID uniqueidentifier not null,
		Name nvarchar(50) null,
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier not null)
		
	INSERT #TempManagementFees 
		SELECT mfr.ManagementFeeRuleID, mf.ManagementFeeID, mf.Name, mf.GLAccountID, mfp.PropertyID
			FROM ManagementFeeRule mfr
				INNER JOIN ManagementFee mf ON mfr.ManagementFeeID = mf.ManagementFeeID
				INNER JOIN ManagementFeeProperty mfp ON mf.ManagementFeeID = mfp.ManagementFeeID
			WHERE mfp.PropertyID IN (SELECT Value FROM @propertyIDEAS)
			  AND mfr.IsArchived = 0
		
-- Calculation based on the current balance of a GLAccount, for all account types except Income, & Expense
	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,		
				#tmf.GLAccountID,		
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				gla.Number + ' - ' + gla.Name,
				(SELECT SUM(je.Amount) 
							FROM JournalEntry je
								INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID	
								LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID							
							WHERE je.GLAccountID = gla.GLAccountID
							  AND gla.GLAccountType NOT IN ('Income', 'Expense')
							  -- Don't include closing the year entries
							  AND t.Origin NOT IN ('Y', 'E')
							  AND t.PropertyID = #tmf.PropertyID
							  AND je.AccountingBasis = mfr.Basis
							  AND je.AccountingBookID IS NULL
							  --AND t.TransactionDate >= @startDate
							  --AND t.TransactionDate <= @endDate),
							  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
							    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))),
				0,
				null
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'GLAccount'
				INNER JOIN GLAccount gla ON mfr.CalculationBasedOnAccountID = gla.GLAccountID 	
			WHERE gla.GLAccountType NOT IN ('Income', 'Expense')
				
-- Calculation based on the current balance of a GLAccount, for account types of Income, & Expense which need to be negated.
	INSERT #ManagementFees
		SELECT	DISTINCT
				#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,		
				#tmf.GLAccountID,		
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				gla.Number + ' - ' + gla.Name,
				(SELECT SUM(-je.Amount) 
							FROM JournalEntry je
								INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID	
								LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID							
							WHERE je.GLAccountID = gla.GLAccountID
							  AND t.PropertyID = #tmf.PropertyID
							  AND gla.GLAccountType IN ('Income', 'Expense')
							  -- Don't include closing the year entries
							  AND t.Origin NOT IN ('Y', 'E')
							  AND je.AccountingBasis = mfr.Basis
							  AND je.AccountingBookID IS NULL
							  --AND t.TransactionDate >= @startDate
							  --AND t.TransactionDate <= @endDate),
							  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
							    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))),
				0,
				null			
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'GLAccount'
				INNER JOIN GLAccount gla ON mfr.CalculationBasedOnAccountID = gla.GLAccountID AND gla.GLAccountType IN ('Income', 'Expense')				
			WHERE gla.GLAccountType IN ('Income', 'Expense')
			
-- Calculation based on the balance of LedgerItemType.
	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,		
				#tmf.GLAccountID,		
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				lit.Name,
				(SELECT SUM(t.Amount)
					FROM [Transaction] t 	
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID					
					WHERE t.LedgerItemTypeID = lit.LedgerItemTypeID
					  AND t.PropertyID = #tmf.PropertyID
					  --AND t.TransactionDate >= @startDate
					  --AND t.TransactionDate <= @endDate),
					  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))),
				0,
				null
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'TransactionCategory'
														AND mfr.Basis = 'Charged'
				INNER JOIN LedgerItemType lit ON mfr.CalculationBasedOnAccountID = lit.LedgerItemTypeID	AND lit.IsCharge = 1	
				
				
-- Calculation based on payments applied to a given LedgerItemType
	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,		
				#tmf.GLAccountID,		
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				'Applied to ' + lit.Name,
				ISNULL((SELECT SUM(ta.Amount)
					FROM [Transaction] t 
						INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
						INNER JOIN [TransactionType] tt on tt.transactiontypeid = ta.transactiontypeid
						--LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID	
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID					
					WHERE t.LedgerItemTypeID = lit.LedgerItemTypeID
					  AND t.PropertyID = #tmf.PropertyID
					  AND tt.Name IN ('Payment')
					  --AND ta.TransactionDate >= @startDate
					  --AND ta.TransactionDate <= @endDate
					  AND (((@accountingPeriodID IS NULL) AND (ta.TransactionDate >= @startDate) AND (ta.TransactionDate <= @endDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND (ta.TransactionDate >= pap.StartDate) AND (ta.TransactionDate <= pap.EndDate)))
					  --AND (tar.TransactionID IS NULL OR tar.TransactionDate > @endDate)
					  ), 0) +
				ISNULL((SELECT SUM(tar.Amount)
					FROM [Transaction] t 
						INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
						INNER JOIN [TransactionType] tt on tt.transactiontypeid = ta.transactiontypeid
						INNER JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID	
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID					
					WHERE t.LedgerItemTypeID = lit.LedgerItemTypeID
					  AND t.PropertyID = #tmf.PropertyID
					  AND tt.Name IN ('Payment')
					  AND tar.AppliesToTransactionID IS NULL
					  --AND tar.TransactionDate >= @startDate
					  --AND tar.TransactionDate <= @endDate	
					  AND (((@accountingPeriodID IS NULL) AND (tar.TransactionDate >= @startDate) AND (tar.TransactionDate <= @endDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate >= pap.StartDate) AND (tar.TransactionDate <= pap.EndDate)))	
					  ), 0),
				0,
				null
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'TransactionCategory'
															AND mfr.Basis = 'Collected'
				INNER JOIN LedgerItemType lit ON mfr.CalculationBasedOnAccountID = lit.LedgerItemTypeID	AND lit.IsCharge = 1	

-- Get Credits matching a given LedgerItemTypeID.		
	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,
				#tmf.GLAccountID,
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				lit.Name,
				(SELECT SUM(t.Amount)
					FROM [Transaction] t  
						INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
						INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID	
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID			
					WHERE t.LedgerItemTypeID = lit.LedgerItemTypeID
					  AND t.PropertyID = #tmf.PropertyID
					  --AND pay.[Date] >= @startDate
					  --AND pay.[Date] <= @endDate),
					  AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))),
				0,
				null
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'TransactionCategory'
														AND mfr.Basis = 'Charged'
				INNER JOIN LedgerItemType lit ON mfr.CalculationBasedOnAccountID = lit.LedgerItemTypeID	AND lit.IsCredit = 1
				
-- Get Payments matching a given LedgerItemTypeID.		
	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,		
				#tmf.GLAccountID,		
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				lit.Name,
				(SELECT SUM(t.Amount)
					FROM [Transaction] t  
						INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
						INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID		
						LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE t.LedgerItemTypeID = lit.LedgerItemTypeID
					  AND t.PropertyID = #tmf.PropertyID
					  --AND pay.[Date] >= @startDate
					  --AND pay.[Date] <= @endDate),
					  AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))),
				0,
				null			
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType = 'TransactionCategory'
														AND mfr.Basis = 'Collected'
				INNER JOIN LedgerItemType lit ON mfr.CalculationBasedOnAccountID = lit.LedgerItemTypeID	AND lit.IsPayment = 1
										
	-- Update percentages
	UPDATE #ManagementFees
		SET ChargedAmount = ObjectBalance * (CalculationValue / 100.0)
	WHERE CalculationType = 'Percent'

	UPDATE #ManagementFees
		SET ChargedAmount = CalculationValue
	WHERE CalculationType <> 'Percent'

	INSERT #ManagementFees
		SELECT	#tmf.ManagementRuleID,
				#tmf.ManagementFeeID,
				mfr.RuleType,
				mfr.OrderBy,
				mfr.AppliesToThreshold,
				#tmf.Name,				
				#tmf.GLAccountID,
				#tmf.PropertyID,
				mfr.CalculationType,
				mfr.CalculationValue,
				mfr.CalculationBasedOnAccountType,
				mfr.CalculationBasedOnAccountID,
				mfr.CalculationType,
				0.00,
				mfr.CalculationValue,
				null			
			FROM #TempManagementFees #tmf
				INNER JOIN ManagementFeeRule mfr ON #tmf.ManagementRuleID = mfr.ManagementFeeRuleID AND mfr.CalculationBasedOnAccountType IS NULL
													AND mfr.CalculationType = 'Flat Fee'

	UPDATE #mf
		SET VendorID = COALESCE(mf.VendorID, p.ManagementCompanyVendorID)
		FROM #ManagementFees #mf
			INNER JOIN ManagementFee mf on #mf.ManagementFeeID = mf.ManagementFeeID
			INNER JOIN Property p on #mf.PropertyID = p.PropertyID

	SELECT  DISTINCT
			#mf.PropertyID AS 'PropertyID',
			#mf.ManagementFeeID AS 'ManagementFeeID',
			#mf.ManagementRuleID AS 'ManagementFeeRuleID',
			#mf.RuleType AS 'RuleType',
			#mf.OrderyBy AS 'OrderBy',
			#mf.AppliesToThreshold AS 'AppliesToThreshold',
			p.Name AS 'PropertyName',
			#mf.Name AS 'ManagementFeeName',			
			#mf.GLAccountID AS 'ManagementFeeGLAccountID',
			#mf.CalculationName AS 'CategoryOrGLAccountName',
			ISNULL(#mf.ObjectBalance, 0) AS 'Balance',
			ISNULL(#mf.ChargedAmount, 0) AS 'Fee',
			#mf.VendorID AS 'VendorID',
			v.CompanyName AS 'VendorName'
			FROM #ManagementFees #mf
				INNER JOIN Property p ON #mf.PropertyID = p.PropertyID
				INNER JOIN Vendor v on #mf.VendorID = v.VendorID 
	ORDER BY p.Name, #mf.Name, #mf.CalculationName
			
  
END

/****** Object:  StoredProcedure [dbo].[ClaimPersonMessage]    Script Date: 10/08/2014 17:02:29 ******/
SET ANSI_NULLS ON
GO
