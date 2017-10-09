SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: June 21, 2012
-- Description:	Imports budgets
-- =============================================
CREATE PROCEDURE [dbo].[ImportBudget]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@year int,
	@accountingBasis nvarchar(10),	
	@budgetImport BudgetImport readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @fiscalStartMonth int
	DECLARE @startDate date
	
	DECLARE @papIDs TABLE(
		Sequence int identity,
		PropertyAccountingPeriodID uniqueidentifier,		
		[Month] int
	)
	
	DECLARE @budgetImportIdentity AS TABLE(
		ID int identity,
		[GLAccountID] uniqueidentifier NOT NULL,
		[Month1Amount] money NOT NULL,
		[Month2Amount] money NOT NULL,
		[Month3Amount] money NOT NULL,
		[Month4Amount] money NOT NULL,
		[Month5Amount] money NOT NULL,
		[Month6Amount] money NOT NULL,
		[Month7Amount] money NOT NULL,
		[Month8Amount] money NOT NULL,
		[Month9Amount] money NOT NULL,
		[Month10Amount] money NOT NULL,
		[Month11Amount] money NOT NULL,
		[Month12Amount] money NOT NULL
	)	
	
	SET @fiscalStartMonth = (SELECT ISNULL(FiscalYearStartMonth, 1) FROM Property WHERE AccountID = @accountID AND PropertyID = @propertyID)

	-- If we are starting in any month but January, the start year of the start month will be
	-- in the previous year
	IF (@fiscalStartMonth > 1)
	BEGIN
		SET @year = @year - 1
	END

	SET @startDate = (SELECT DATEADD(MONTH, (ISNULL(@fiscalStartMonth, 1)-1), CAST(@year AS nvarchar(10))))
	
	--INSERT INTO @papIDs
	--	SELECT pap.PropertyAccountingPeriodID, DATEPART(month, ap.EndDate)
	--	FROM AccountingPeriod ap
	--	INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--	WHERE ap.AccountID = @accountID
	--		AND pap.PropertyID = @propertyID
	--		AND ap.Name LIKE ('%' + CONVERT(nvarchar(4), @year))
	
	INSERT INTO @papIDs
		SELECT TOP 12 pap.PropertyAccountingPeriodID, DATEPART(MONTH, ap.EndDate)
			FROM AccountingPeriod ap
				INNER JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID AND pap.PropertyID = @propertyID
			WHERE @startDate <= ap.EndDate --AND @startDate <= ap.EndDate
			ORDER BY ap.EndDate
	
	IF @accountingBasis = 'Cash' OR @accountingBasis = 'Both'
	BEGIN
		UPDATE Budget SET CashBudget = NULL
			WHERE AccountID = @accountID				  
				  AND PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID FROM @papIDs)
				  
	END
	
	IF @accountingBasis = 'Accrual' OR @accountingBasis = 'Both'
	BEGIN
		UPDATE Budget SET AccrualBudget = NULL
			WHERE AccountID = @accountID				  
				  AND PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID FROM @papIDs)
				  
	END
	
	--DECLARE @month1PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 1)		
	--DECLARE @month2PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 2)
	--DECLARE @month3PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 3)
	--DECLARE @month4PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 4)
	--DECLARE @month5PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 5)
	--DECLARE @month6PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 6)
	--DECLARE @month7PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 7)
	--DECLARE @month8PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 8)
	--DECLARE @month9PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 9)
	--DECLARE @month10PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 10)
	--DECLARE @month11PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 11)
	--DECLARE @month12PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Month] = 12)	
	
	DECLARE @month1PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 1)		
	DECLARE @month2PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 2)
	DECLARE @month3PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 3)
	DECLARE @month4PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 4)
	DECLARE @month5PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 5)
	DECLARE @month6PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 6)
	DECLARE @month7PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 7)
	DECLARE @month8PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 8)
	DECLARE @month9PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 9)
	DECLARE @month10PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 10)
	DECLARE @month11PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 11)
	DECLARE @month12PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM @papIDs WHERE [Sequence] = 12)		
	
	INSERT INTO @budgetImportIdentity
		SELECT * FROM @budgetImport		
		
	DECLARE @currentRowID int
	DECLARE @rowCount int
	SET @currentRowID = 1	
	SET @rowCount = (SELECT MAX(ID) FROM @budgetImportIdentity)				
		
	DECLARE @currentGLAccountID uniqueidentifier	
	DECLARE @currentPAPID uniqueidentifier
	DECLARE @currentBudget money
	
	WHILE (@currentRowID <= @rowCount)
	BEGIN
	
		SET @currentGLAccountID = (SELECT GLAccountID FROM @budgetImportIdentity WHERE ID = @currentRowID)			
		
		DECLARE @month int = 1
		
		WHILE (@month <= 12)
		BEGIN
			
			IF @month = 1			
			BEGIN
				SET @currentPAPID = @month1PAPID					
				SET @currentBudget = (SELECT Month1Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 2
			BEGIN
				SET @currentPAPID = @month2PAPID					
				SET @currentBudget = (SELECT Month2Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 3
			BEGIN
				SET @currentPAPID = @month3PAPID					
				SET @currentBudget = (SELECT Month3Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 4
			BEGIN
				SET @currentPAPID = @month4PAPID					
				SET @currentBudget = (SELECT Month4Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 5
			BEGIN
				SET @currentPAPID = @month5PAPID					
				SET @currentBudget = (SELECT Month5Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 6
			BEGIN
				SET @currentPAPID = @month6PAPID					
				SET @currentBudget = (SELECT Month6Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 7
			BEGIN
				SET @currentPAPID = @month7PAPID					
				SET @currentBudget = (SELECT Month7Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 8
			BEGIN
				SET @currentPAPID = @month8PAPID					
				SET @currentBudget = (SELECT Month8Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 9
			BEGIN
				SET @currentPAPID = @month9PAPID					
				SET @currentBudget = (SELECT Month9Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 10
			BEGIN
				SET @currentPAPID = @month10PAPID					
				SET @currentBudget = (SELECT Month10Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 11
			BEGIN
				SET @currentPAPID = @month11PAPID					
				SET @currentBudget = (SELECT Month11Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 12
			BEGIN
				SET @currentPAPID = @month12PAPID					
				SET @currentBudget = (SELECT Month12Amount FROM @budgetImportIdentity WHERE ID = @currentRowID)				
			END
								
			IF EXISTS(SELECT * FROM Budget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID)
			BEGIN			
				IF @accountingBasis = 'Cash' 
					UPDATE Budget SET CashBudget = @currentBudget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID					
				ELSE IF @accountingBasis = 'Accrual'
					UPDATE Budget SET AccrualBudget = @currentBudget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID			
				ELSE IF @accountingBasis = 'Both'
				UPDATE Budget SET AccrualBudget = @currentBudget, CashBudget = @currentBudget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID			
			END
			ELSE
			BEGIN
				IF @accountingBasis = 'Cash'
					INSERT INTO Budget VALUES (NEWID(), @accountID, @currentGLAccountID, @currentPAPID, null, null, @currentBudget, null, null)
				ELSE IF @accountingBasis = 'Accrual'
					INSERT INTO Budget VALUES (NEWID(), @accountID, @currentGLAccountID, @currentPAPID, null, @currentBudget, null, null, null)
				ELSE IF @accountingBasis = 'Both'
					INSERT INTO Budget VALUES (NEWID(), @accountID, @currentGLAccountID, @currentPAPID, null, @currentBudget, @currentBudget, null, null)				
			END
			
			SET @month = @month + 1
		END
		
		SET @currentRowID = @currentRowID + 1
	END
    
END
GO
