SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 8, 2013
-- Description:	Gets a given posting batch prior to posting it
-- =============================================
CREATE PROCEDURE [dbo].[GetPostingBatchTransactions] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@postingBatchID uniqueidentifier = null 
AS
DECLARE @isPaymentBatch bit
DECLARE @isPosted bit
DECLARE @datePosted date = null
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PostedTransactions (
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null,
		PropertyID uniqueidentifier null,
		Unit nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		Names nvarchar(300) null,
		LedgerItemTypeName nvarchar(50) null,
		[Description] nvarchar(500) null,
		Notes nvarchar(500) null,
		Reference nvarchar(50) null,
		Amount money null,
		ID uniqueidentifier null,
		TransactionTypeName nvarchar(50),
		LITID uniqueidentifier null)
 
	SET @isPaymentBatch = (SELECT IsPaymentBatch FROM PostingBatch WHERE PostingBatchID = @postingBatchID AND AccountID = @accountID)
	SET @isPosted = (SELECT IsPosted FROM PostingBatch WHERE PostingBatchID = @postingBatchID AND AccountID = @accountID)
	SET @datePosted = (SELECT PostedDate FROM PostingBatch WHERE PostingBatchID = @postingBatchID AND AccountID = @accountID)
	
	IF (@isPaymentBatch = 0)
	BEGIN	
		INSERT #PostedTransactions
			SELECT	DISTINCT
					t.ObjectID,
					tt.[Group] AS 'ObjectType',
					t.PropertyID,
					null AS 'Unit',
					null AS 'PaddedNumber',
					null AS 'Names',
					null AS 'LedgerItemTypeName',
					t.[Description],
					t.Note AS 'Notes',
					null AS 'Reference',
					t.Amount,
					t.TransactionID AS 'ID',
					tt.Name AS 'TransactionTypeName',
					t.LedgerItemTypeID AS 'LITID'
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				WHERE t.PostingBatchID = @postingBatchID
	END
	ELSE
	BEGIN
		INSERT #PostedTransactions
			SELECT	DISTINCT
					pay.ObjectID,
					pay.ObjectType AS 'ObjectType',
					pb.PropertyID,
					null AS 'Unit',
					null AS 'PaddedNumber',
					null AS 'Names',
					null AS 'LedgerItemTypeName',
					pay.[Description],
					pay.Notes, 
					pay.ReferenceNumber AS 'Reference',
					pay.Amount,
					pay.PaymentID AS 'ID',
					'Payment' AS 'TransactionTypeName',
					t.LedgerItemTypeID AS 'LITID'					
				FROM Payment pay
					INNER JOIN PostingBatch pb ON pay.PostingBatchID = pb.PostingBatchID
					INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
					INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				WHERE pay.PostingBatchID = @postingBatchID
				  AND t.TransactionID = (SELECT TOP 1 t1.TransactionID
											FROM [Transaction] t1
												INNER JOIN TransactionType tt1 ON t1.TransactionTypeID = tt1.TransactionTypeID AND tt1.Name IN ('Payment')
												INNER JOIN PaymentTransaction pt1 ON pt1.TransactionID = t1.TransactionID
											WHERE pt1.PaymentID = pay.PaymentID
											  AND t1.ObjectID = t.ObjectID
											ORDER BY t1.TimeStamp)
	END
	
	(SELECT	#pt.ObjectID,
			#pt.ObjectType,
			#pt.PropertyID,
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedNumber',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'Names',
			--CASE
			--	WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
			--	ELSE #pt.TransactionTypeName END AS 'LedgerItemTypeName',
			lit.Name AS 'LedgerItemTypeName',
			#pt.[Description] AS 'Description',
			#pt.Notes AS 'Notes',
			#pt.Reference AS 'Reference',
			#pt.Amount,
			#pt.ID,
			#pt.TransactionTypeName,
			@isPosted AS IsPosted,
			@datePosted AS DatePosted		
		FROM #PostedTransactions #pt
			INNER JOIN UnitLeaseGroup ulg ON #pt.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			LEFT JOIN LedgerItemType lit ON #pt.LITID = lit.LedgerItemTypeID
		WHERE #pt.ObjectType = 'Lease'
		  AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
						   FROM Lease  
						   INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
						   WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
						   ORDER BY Ordering.OrderBy)
	
	UNION
	
	SELECT	#pt.ObjectID,
			#pt.ObjectType,
			#pt.PropertyID,
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedNumber',
			per.PreferredName + ' ' + per.LastName AS 'Names',
			--CASE
			--	WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
			--	ELSE #pt.TransactionTypeName END AS 'LedgerItemTypeName',
			lit.Name AS 'LedgerItemTypeName',
			#pt.[Description] AS 'Description',
			#pt.Notes AS 'Notes',
			#pt.Reference AS 'Reference',
			#pt.Amount,
			#pt.ID,
			#pt.TransactionTypeName,
			@isPosted AS IsPosted,
			@datePosted AS DatePosted			
		FROM #PostedTransactions #pt
			LEFT JOIN UnitLeaseGroup ulg ON #pt.ObjectID = ulg.UnitLeaseGroupID
			LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
			LEFT JOIN Person per ON #pt.ObjectID = per.PersonID
			LEFT JOIN LedgerItemType lit ON #pt.LITID = lit.LedgerItemTypeID
		WHERE #pt.ObjectType <> 'Lease')
	ORDER BY LedgerItemTypeName, PaddedNumber
	
END
GO
