SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 12, 2016
-- Description:	Imports alternate budgets
-- =============================================
CREATE PROCEDURE [dbo].[ImportAlternateBudget]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@yearBudgetID uniqueidentifier,
	@budgetImport BudgetImport readonly
AS

DECLARE @propertyID uniqueidentifier = (SELECT PropertyID FROM YearBudget WHERE YearBudgetID = @yearBudgetID)
DECLARE @startMonth int = (SELECT StartMonth FROM YearBudget WHERE YearBudgetID = @yearBudgetID)
DECLARE @year int = (SELECT [Year] FROM YearBudget WHERE YearBudgetID = @yearBudgetID)
DECLARE @startDate date = ((SELECT DATEADD(MONTH, (ISNULL(@startMonth, 1)-1), CAST(@year AS nvarchar(10)))))

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #OurAPs (
		[Sequence] int identity,
		PropertyAccountingPeriodID uniqueidentifier,		
		[Month] int
	)
	
	CREATE TABLE #ImportedBudgets (
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

	INSERT INTO #OurAPs
		SELECT TOP 12 pap.PropertyAccountingPeriodID, DATEPART(MONTH, ap.EndDate)
			FROM AccountingPeriod ap
				INNER JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID AND pap.PropertyID = @propertyID
			WHERE @startDate <= ap.EndDate 
			ORDER BY ap.EndDate
	
	DECLARE @month1PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 1)		
	DECLARE @month2PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 2)
	DECLARE @month3PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 3)
	DECLARE @month4PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 4)
	DECLARE @month5PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 5)
	DECLARE @month6PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 6)
	DECLARE @month7PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 7)
	DECLARE @month8PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 8)
	DECLARE @month9PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 9)
	DECLARE @month10PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 10)
	DECLARE @month11PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 11)
	DECLARE @month12PAPID uniqueidentifier = (SELECT TOP 1 PropertyAccountingPeriodID FROM #OurAPs WHERE [Sequence] = 12)		
	
	INSERT INTO #ImportedBudgets
		SELECT * FROM @budgetImport	  	
		
	DECLARE @currentRowID int
	DECLARE @rowCount int
	SET @currentRowID = 1	
	SET @rowCount = (SELECT MAX(ID) FROM #ImportedBudgets)				
		
	DECLARE @currentGLAccountID uniqueidentifier	
	DECLARE @currentPAPID uniqueidentifier
	DECLARE @currentBudget money
	
	WHILE (@currentRowID <= @rowCount)
	BEGIN
	
		SET @currentGLAccountID = (SELECT GLAccountID FROM #ImportedBudgets WHERE ID = @currentRowID)			
		
		DECLARE @month int = 1
		
		WHILE (@month <= 12)
		BEGIN
			
			IF @month = 1			
			BEGIN
				SET @currentPAPID = @month1PAPID					
				SET @currentBudget = (SELECT Month1Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 2
			BEGIN
				SET @currentPAPID = @month2PAPID					
				SET @currentBudget = (SELECT Month2Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 3
			BEGIN
				SET @currentPAPID = @month3PAPID					
				SET @currentBudget = (SELECT Month3Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 4
			BEGIN
				SET @currentPAPID = @month4PAPID					
				SET @currentBudget = (SELECT Month4Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 5
			BEGIN
				SET @currentPAPID = @month5PAPID					
				SET @currentBudget = (SELECT Month5Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 6
			BEGIN
				SET @currentPAPID = @month6PAPID					
				SET @currentBudget = (SELECT Month6Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 7
			BEGIN
				SET @currentPAPID = @month7PAPID					
				SET @currentBudget = (SELECT Month7Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 8
			BEGIN
				SET @currentPAPID = @month8PAPID					
				SET @currentBudget = (SELECT Month8Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 9
			BEGIN
				SET @currentPAPID = @month9PAPID					
				SET @currentBudget = (SELECT Month9Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 10
			BEGIN
				SET @currentPAPID = @month10PAPID					
				SET @currentBudget = (SELECT Month10Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 11
			BEGIN
				SET @currentPAPID = @month11PAPID					
				SET @currentBudget = (SELECT Month11Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
			ELSE IF @month = 12
			BEGIN
				SET @currentPAPID = @month12PAPID					
				SET @currentBudget = (SELECT Month12Amount FROM #ImportedBudgets WHERE ID = @currentRowID)				
			END
								
			IF EXISTS(SELECT * FROM AlternateBudget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID)
			BEGIN			
				UPDATE AlternateBudget SET Amount = @currentBudget WHERE AccountID = @accountID AND GLAccountID = @currentGLAccountID AND PropertyAccountingPeriodID = @currentPAPID			
			END
			ELSE
			BEGIN
				INSERT INTO AlternateBudget VALUES (NEWID(), @accountID, @yearBudgetID, @currentGLAccountID, @currentPAPID, @currentBudget, null)				
			END
			
			SET @month = @month + 1
		END
		
		SET @currentRowID = @currentRowID + 1
	END
    
END
GO
