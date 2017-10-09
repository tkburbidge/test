SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: May 18, 2012
-- Description:	Gets the data needed to display 
--				collections accounts on the rent 
--				roll report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_CollectionsAutobillAccounts]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY		
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
		DECLARE @collections TABLE (
			PropertyName nvarchar(250) not null,
			ObjectID uniqueidentifier not null,
			ObjectType nvarchar(25) not null,
			TotalMonthlyAmount money null, 
			CollectionDetailID uniqueidentifier not null,
			Amount money null,
			LedgerItemTypeID uniqueidentifier null,
			LedgerItemTypeGLAccountID uniqueidentifier null,
			OrderBy tinyint null,
			[Description] nvarchar(500) null,
			Notes nvarchar(1000) null,
			AmountCharged money null,
			AmountPaid money null,
			IsClosed bit not null
			)
		
		INSERT INTO @collections
		EXEC [GetCollectionDetails] @accountID, @propertyIDs, null, 1, 1, 'In House', 0
	
		DECLARE @collectionsAutobill TABLE (
			PropertyName nvarchar(250) not null,
			Account nvarchar(500) null,
			ObjectID uniqueidentifier not null,
			ObjectType nvarchar(25) not null,
			CollectionsTotal money null,
			AgreementAmount money null, 
			AmountCharged money null,  
			AmountPaid money null
		)	
		
		INSERT INTO @collectionsAutobill
		SELECT PropertyName,
			   null,
			   ObjectID,
			   ObjectType,
			   SUM(Amount) AS 'CollectionsTotal',
			   TotalMonthlyAmount AS 'AgreementAmount',
			   SUM(AmountCharged) AS 'AmountCharged',
			   SUM(AmountPaid) AS 'AmountPaid'			   
		FROM @collections
		GROUP BY ObjectID, ObjectType, TotalMonthlyAmount, PropertyName
		
		UPDATE ca
		SET ca.Account = (SELECT PreferredName + ' ' + LastName	
						   FROM Person
						   WHERE PersonID = ca.ObjectID)
		FROM @collectionsAutobill ca
		WHERE ca.ObjectType <> 'Lease'
		
		UPDATE ca
		SET ca.Account = (SELECT (u.Number + ' - ' + 
								STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
										 FROM Person
										 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
										 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
										 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
										 WHERE PersonLease.LeaseID = l.LeaseID
											   AND PersonType.[Type] = 'Resident'				   
											   AND PersonLease.MainContact = 1	
										 ORDER BY PersonLease.OrderBy, Person.PreferredName			   
										 FOR XML PATH ('')), 1, 2, ''))
							FROM UnitLeaseGroup ulg							
							INNER JOIN Unit u on u.UnitID = ulg.UnitID
							INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							WHERE ulg.UnitLeaseGroupID = ca.ObjectID
								AND l.LeaseID = (SELECT TOP 1 LeaseID
												 FROM Lease 
												 INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
												 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
												 ORDER BY o.OrderBy))
							
		FROM @collectionsAutobill ca
		WHERE ca.ObjectType = 'Lease'
				
		SELECT * FROM @collectionsAutobill
		WHERE CollectionsTotal > AmountCharged
END
GO
