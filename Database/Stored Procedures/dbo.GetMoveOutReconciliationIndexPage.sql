SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 6, 2014
-- Description:	Populates a Move Out Reconciliation Index Page
-- =============================================
CREATE PROCEDURE [dbo].[GetMoveOutReconciliationIndexPage] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    CREATE TABLE #MORIndex (
		PropertyID uniqueidentifier NOT NULL,
		PropertyName nvarchar(50) NULL,
		PropertyAbbreviation nvarchar(50) NULL,
		Unit nvarchar(50) NULL,
		LeaseID uniqueidentifier NULL,
		UnitLeaseGroupID uniqueidentifier NULL,
		ResidentNames nvarchar(500) NULL,
		MoveOutDate date NULL,
		LeaseStartDate date NULL,
		LeaseEndDate date NULL,
		DepositsHeld money NULL,
		Balance money NULL)
		
	INSERT #MORIndex
		SELECT	DISTINCT
				ut.PropertyID,
				p.Name,
				p.Abbreviation,
				u.Number,
				l.LeaseID,
				l.UnitLeaseGroupID,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',	
				(SELECT TOP 1 MoveOutDate
					FROM PersonLease 
					WHERE LeaseID = l.LeaseID
					ORDER BY MoveOutDate DESC) AS 'MoveOutDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				null,
				null			
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
			WHERE ulg.AccountID = @accountID
			  AND ulg.MoveOutReconciliationNotes IS NULL
			  AND l.LeaseStatus IN ('Evicted', 'Former')
			  AND ut.PropertyID IN (SELECT Value FROM @propertyIDs)
    
    UPDATE #MORIndex SET DepositsHeld = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t 
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment')
		WHERE t.ObjectID = #MORIndex.UnitLeaseGroupID)
		
	UPDATE #MORIndex SET DepositsHeld = DepositsHeld - (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t 
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
		WHERE t.ObjectID = #MORIndex.UnitLeaseGroupID)
		
	UPDATE #MORIndex SET Balance = BAL.Balance
		FROM #MORIndex
			CROSS APPLY GetObjectBalance('2000-01-01', '2099-12-31', #MORIndex.UnitLeaseGroupID, 0, @propertyIDs) AS [BAL]
		WHERE #MORIndex.UnitLeaseGroupID = BAL.ObjectID
    
    SELECT * FROM #MORIndex
    
END
GO
