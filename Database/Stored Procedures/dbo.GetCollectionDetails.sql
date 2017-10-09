SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 3, 2012
-- Description:	Gets a collection of collection accounts and the money due
-- =============================================
CREATE PROCEDURE [dbo].[GetCollectionDetails] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY,
	@objectID uniqueidentifier = null,
	@requireAgreement bit,
	@returnAllCharges bit,
	@agreementType nvarchar(100),
	@includeClosed bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		CREATE TABLE #Collections (
		PropertyName nvarchar(250) not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(25) null,
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
		IsClosed bit not null)

	INSERT INTO #Collections
		SELECT	CASE	
					WHEN pp.PropertyID IS NOT NULL THEN pp.Name
					WHEN lp.PropertyID IS NOT NULL THEN lp.Name
				END AS 'PropertyName',
				cd.ObjectID AS 'ObjectID', ca.ObjectType AS 'ObjectType', ISNULL(ca.Amount, 0) AS 'TotalMonthlyAmount', 
				cd.CollectionDetailID AS 'CollectionDetailID', cd.Amount AS 'Amount', cd.LedgerItemTypeID AS 'LedgerItemTypeID', 
				lit.GLAccountID AS 'LedgerItemTypeGLAccountID', cd.OrderBy AS 'OrderBy', cd.[Description] AS 'Description',	cd.[Notes] AS 'Notes',
				null AS 'AmountBilled', null AS 'AmountPaid', 
				CASE WHEN ca.CollectionAgreementID IS NULL THEN 0 ELSE ca.IsClosed END AS 'IsClosed'
			FROM CollectionDetail cd
				LEFT JOIN [CollectionAgreement] ca ON cd.ObjectID = ca.ObjectID
				LEFT JOIN [LedgerItemType] lit ON cd.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Person] p ON cd.ObjectID = p.PersonID
				LEFT JOIN [PersonType] pt ON p.PersonID = pt.PersonID
				LEFT JOIN [PersonTypeProperty] ptp ON pt.PersonTypeID = ptp.PersonTypeID
				LEFT JOIN [Property] pp ON pp.PropertyID = ptp.PropertyID
				LEFT JOIN [UnitLeaseGroup] ulg ON cd.ObjectID = ulg.UnitLeaseGroupID
				LEFT JOIN [Unit] u ON ulg.UnitID = u.UnitID
				LEFT JOIN [UnitType] ut ON u.UnitTypeID = ut.UnitTypeID
				LEFT JOIN [Property] lp ON lp.PropertyID = ut.PropertyID			
			WHERE cd.AccountID = @accountID
			  AND ((ca.CollectionAgreementID IS NULL AND @requireAgreement = 0) OR (ca.IsClosed = 0 OR @includeClosed = 1))
			  AND ((ut.PropertyID IN (SELECT Value FROM @propertyIDs)) OR (ptp.PropertyID IN (SELECT Value FROM @propertyIDs)))
			  AND ((@objectID IS NULL) OR (@objectID = cd.ObjectID))
			  -- There is no collection agreement and one isn't required or
			  -- join in the last collection agreement
			  AND ((ca.CollectionAgreementID IS NULL AND @requireAgreement = 0) OR (ca.CollectionAgreementID = (SELECT TOP 1 CollectionAgreementID 
																														FROM CollectionAgreement
																														WHERE ObjectID = ca.ObjectID																															
																														ORDER BY DateCreated DESC)))
		      -- There is no collection agreement and one isn't required or 
		      -- the last agreement is of type In House																														
			  AND ((ca.CollectionAgreementID IS NULL AND @requireAgreement = 0) OR (ca.CollectionType = @agreementType) OR (@agreementType IS NULL))
		  
	UPDATE #co SET AmountCharged = ISNULL((SELECT SUM(ts.Amount) 
				FROM [Transaction] ts 
					INNER JOIN CollectionDetailTransaction cdts ON ts.TransactionID = cdts.TransactionID
					INNER JOIN CollectionDetail cd ON cdts.CollectionDetailID = cd.CollectionDetailID AND ts.ObjectID = cd.ObjectID
					INNER JOIN #Collections #c ON #c.CollectionDetailID = cd.CollectionDetailID AND #c.CollectionDetailID = #co.CollectionDetailID AND #c.ObjectID = cd.ObjectID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ts.TransactionID
				WHERE ts.ObjectID = #c.ObjectID 
				  AND tr.TransactionID IS NULL
				GROUP BY cdts.CollectionDetailID), 0)
			FROM #Collections #co
				
	UPDATE #co SET AmountPaid = ISNULL((SELECT SUM(ta.Amount) 
				FROM [Transaction] ts 
					INNER JOIN CollectionDetailTransaction cdts ON ts.TransactionID = cdts.TransactionID
					INNER JOIN CollectionDetail cd ON cdts.CollectionDetailID = cd.CollectionDetailID AND ts.ObjectID = cd.ObjectID
					INNER JOIN #Collections #c ON #c.CollectionDetailID = cd.CollectionDetailID AND #c.CollectionDetailID = #co.CollectionDetailID AND #c.ObjectID = cd.ObjectID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ts.TransactionID
					LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = ts.TransactionID
					LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
				WHERE ts.ObjectID = #c.ObjectID 
				  AND tr.TransactionID IS NULL
				  AND tar.TransactionID IS NULL
				GROUP BY cdts.CollectionDetailID), 0)
			FROM #Collections #co
	
	IF (@returnAllCharges = 1)
	BEGIN
		SELECT * FROM #Collections
	END 
	ELSE
	BEGIN
		SELECT * FROM #Collections 
		WHERE Amount > AmountCharged
	END
END




GO
