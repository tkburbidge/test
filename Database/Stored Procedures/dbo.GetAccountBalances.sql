SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 3, 2012
-- Description:	Generates the data for Delinquency report
-- =============================================
CREATE PROCEDURE [dbo].[GetAccountBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@accountingPeriodID uniqueidentifier = null, 
	@propertyIDs GuidCollection READONLY
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertiesAndDates (
		Sequence int identity,
		PropertyID uniqueidentifier NOT NULL,
		StartDate date NOT NULL,
		EndDate date NOT NULL,
		DayBeforeStartDate date NOT NULL)
		
	INSERT #PropertiesAndDates 
		SELECT pIDs.Value, pap.StartDate, pap.EndDate, DATEADD(day, -1, pap.StartDate)
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	
	CREATE TABLE #Accounts (				
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null)

	CREATE TABLE #AccountsAndBalance (				
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null,
		Balance money null)
	
	INSERT INTO #Accounts
		SELECT DISTINCT p.PropertyID,
			   ulg.UnitLeaseGroupID,
			   'Lease'
			FROM UnitLeaseGroup ulg				
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = ulg.UnitLeaseGroupID AND ulgap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID						
			  									 
		UNION

		SELECT DISTINCT p.PropertyID,
				t.ObjectID,
				tt.[Group]
			FROM [Transaction] t				
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID				
			WHERE tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
	
	SELECT 
		#a.*,
		Balance.Balance
	FROM #Accounts #a
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #a.PropertyID
	CROSS APPLY GetObjectBalance(null, #pad.EndDate, #a.ObjectID, 0, @propertyIDs) AS Balance
	
	 
END



GO
