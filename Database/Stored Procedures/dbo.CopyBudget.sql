SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Trevor Burbidge
-- Alter Author: Joshua Grigg
-- Create date: 7/10/2014
-- Alter Date: 7/25/2016
-- Description:	Takes a (Cash|Accrual) budget and copy all values from the cooresponding (Accrual|Cash) budget into it.
-- Alter Note: now accepts a fromYearBudgetID, if it is null then does old logic
-- =============================================
CREATE PROCEDURE [dbo].[CopyBudget] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	--@fromYearBudgetID uniqueidentifier
	@toYearBudgetID uniqueidentifier,
	@fromYearBudgetID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
    --Get the other year budget id
	
	IF (@fromYearBudgetID IS NULL)
		BEGIN
			 SET @fromYearBudgetID = (SELECT fromYB.YearBudgetID 
													FROM YearBudget fromYB
														INNER JOIN YearBudget toYB ON toYB.[Year] = fromYB.[Year] AND toYB.PropertyID = fromYB.PropertyID AND toYB.AccountingBasis <> fromYB.AccountingBasis
													WHERE toYB.YearBudgetID = @toYearBudgetID
													  AND toYB.AccountID = @accountID)
		END
    
    --We want to keep the TurnoverWorksheetEntryIDs the same for those that have BudgetNotes so they don't get lost
    -- Store info to be able to keep the IDs
    CREATE TABLE #OldTWEsWithNotes (
		TurnoverWorksheetEntryID uniqueidentifier not null,
		[Month] int not null,
		UnitTypeID uniqueidentifier not null,
		[Type] nvarchar(20) not null)
		
	INSERT #OldTWEsWithNotes 
		SELECT twe.TurnoverWorksheetEntryID, twe.[Month], twe.UnitTypeID, twe.[Type]
			FROM TurnoverWorksheetEntry twe
			WHERE twe.AccountID = @accountID
			  AND twe.YearBudgetID = @toYearBudgetID
			  AND EXISTS (SELECT bn.BudgetNoteID FROM BudgetNote bn WHERE bn.ObjectID = twe.TurnoverWorksheetEntryID AND bn.AccountID = @accountID)
    
    
    --Delete all the old turnover worksheet entries
    DELETE TurnoverWorksheetEntry WHERE YearBudgetID = @toYearBudgetID AND AccountID = @accountID
    
    --Copy the new turnover worksheet entries, use the old id if it existed
    INSERT TurnoverWorksheetEntry (AccountID, [Month], TurnoverWorksheetEntryID, [Type], UnitTypeID, Value, YearBudgetID)
		SELECT other.AccountID, other.[Month], ISNULL(#old.TurnoverWorksheetEntryID, NEWID()), other.[Type], other.UnitTypeID, other.Value, @toYearBudgetID
		FROM TurnoverWorksheetEntry other
			LEFT JOIN #OldTWEsWithNotes #old ON other.[Month] = #old.[Month] AND other.[Type] = #old.[Type] AND other.UnitTypeID = #old.UnitTypeID
		WHERE other.YearBudgetID = @fromYearBudgetID
		  AND other.AccountID = @accountID
		  
	--If any entries don't exist now but had notes we need to add them
    INSERT TurnoverWorksheetEntry (AccountID, [Month], TurnoverWorksheetEntryID, [Type], UnitTypeID, Value, YearBudgetID)
		SELECT @accountID, #old.[Month], #old.TurnoverWorksheetEntryID, #old.[Type], #old.UnitTypeID, 0, @toYearBudgetID
		FROM #OldTWEsWithNotes #old
		WHERE NOT EXISTS (SELECT *
							FROM TurnoverWorksheetEntry 
							WHERE AccountID = @accountID
							  AND TurnoverWorksheetEntryID = #old.TurnoverWorksheetEntryID)
    
    DECLARE @toAccountingBasis nvarchar(50) = (SELECT AccountingBasis FROM YearBudget WHERE YearBudgetID = @toYearBudgetID)
    DECLARE @propertyID uniqueidentifier = (SELECT PropertyID FROM YearBudget WHERE YearBudgetID = @toYearBudgetID)
    DECLARE @fiscalStartDate date = CAST(CAST((SELECT [Year] FROM YearBudget WHERE YearBudgetID = @toYearBudgetID) AS varchar) + '-' + CAST((SELECT FiscalYearStartMonth FROM Property WHERE PropertyID = @propertyID) AS varchar) + '-01' AS date)
    DECLARE @fiscalEndDate date = DATEADD(DAY, -1, DATEADD(MONTH, 12, @fiscalStartDate))
   
    
    CREATE TABLE #MyPropertyAccountingPeriods (
		PropertyAccountingPeriodID uniqueidentifier not null)
								  
	INSERT #MyPropertyAccountingPeriods 
		SELECT pap.PropertyAccountingPeriodID
			FROM PropertyAccountingPeriod pap
				INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID 
			WHERE pap.StartDate >= @fiscalStartDate
			  AND pap.EndDate <= @fiscalEndDate
			  AND pap.PropertyID = @propertyID
			ORDER BY pap.StartDate
			
	IF (@toAccountingBasis = 'Cash')
		UPDATE Budget
			SET CashBudget = AccrualBudget
			WHERE Budget.PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID FROM #MyPropertyAccountingPeriods)
			  AND Budget.AccountID = @accountID
	ELSE
		UPDATE Budget
			SET AccrualBudget = CashBudget
			WHERE Budget.PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID FROM #MyPropertyAccountingPeriods)
			  AND Budget.AccountID = @accountID
	
END


GO
