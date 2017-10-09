SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 1/8/14
-- Description:	Updates the InterestFormulaID for each property passed in, as well as links in the transaction categories
-- =============================================
CREATE PROCEDURE [dbo].[UpdatePropertyInterestFormulaIDs] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@interestFormulaID uniqueidentifier = null,
	@propertyIDs GuidCollection READONLY,
	@interestableLedgerItemTypeIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--For all properties that WERE tied to this formula, set all ledgerItemTypeProperties
	-- of that property to be not interestable
	UPDATE LedgerItemTypeProperty 
		SET IsInterestable = null
		WHERE PropertyID IN 
			(SELECT PropertyID 
				FROM Property
				WHERE DepositInterestFormulaID = @interestFormulaID)
			OR PropertyID IN (SELECT Value FROM @propertyIDs)
				
	--For all ledgerItemTypeProperties with propertyID passed in and ledgerItemTypeID passed in
	-- set them to be interestable
	UPDATE LedgerItemTypeProperty 
		SET IsInterestable = 1
		WHERE (PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND LedgerItemTypeID IN (SELECT Value FROM @interestableLedgerItemTypeIDs))
	
	--Create new LedgerItemTypeProperties if needed and set as interestable
	INSERT INTO LedgerItemTypeProperty 
		SELECT NEWID(), @accountID, ilit.Value, pid.Value, null, 1
			FROM @propertyIDs pid
				INNER JOIN @interestableLedgerItemTypeIDs ilit ON 1 = 1
			WHERE (0 = (SELECT COUNT(LedgerItemTypePropertyID)
								  FROM LedgerItemTypeProperty
								    WHERE ilit.Value = LedgerItemTypeID
								      AND pid.Value = PropertyID))
							
	--Delete all previous ties to this interest formula ID
    UPDATE Property 
		SET DepositInterestFormulaID = null 
		WHERE DepositInterestFormulaID = @interestFormulaID
	
	--Redo all the correct ties to this interest formula ID
	UPDATE Property	
		SET DepositInterestFormulaID = @interestFormulaID
		WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
    
    
END
GO
