SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 4, 2012
-- Description:	Updates a given TaxRateGroup
-- =============================================
CREATE PROCEDURE [dbo].[UpdateTaxRateGroupOld] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@taxRateGroupID uniqueidentifier = null,
	@taxRates TaxRateCollection READONLY
AS

DECLARE @cTaxRateID		uniqueidentifier
DECLARE @cName			nvarchar(100)
DECLARE @cRate			decimal(6,4)
DECLARE @cGLAccountID	uniqueidentifier
DECLARE @cDescription	nvarchar(500)
DECLARE @sTaxRateID		uniqueidentifier
DECLARE @sName			nvarchar(100)
DECLARE @sRate			decimal(6,4)
DECLARE @sGLAccountID	uniqueidentifier
DECLARE @sDescription	nvarchar(500)
DECLARE @ctr			int
DECLARE @maxCtr			int

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #TempTaxRates (
		SequenceNum		int identity,
		TaxRateID		uniqueidentifier		null,
		Name			nvarchar(100)			null,
		Rate			decimal(6,4)			null,
		GLAccountID		uniqueidentifier		null,
		[Description]	nvarchar(500)			null)
		
	CREATE TABLE #TempOldTaxRates (
		SequenceNum		int identity,
		TaxRateID		uniqueidentifier		null,
		Name			nvarchar(100)			null,
		Rate			decimal(6,4)			null,
		GLAccountID		uniqueidentifier		null,
		[Description]	nvarchar(500)			null)
		
	INSERT #TempTaxRates SELECT TaxRateID, Name, Rate, GLAccountID, [Description] FROM @taxRates ORDER BY Rate, Name
	
	INSERT #TempOldTaxRates
		SELECT tr.TaxRateID, tr.Name, tr.Rate, tr.GLAccountID, tr.[Description] 
		FROM TaxRate tr
			INNER JOIN TaxRateGroupTaxRate trgtr ON tr.TaxRateID = trgtr.TaxRateID
		WHERE trgtr.TaxRateGroupID = @taxRateGroupID
		  AND tr.IsObsolete = 0
		  
	SET @ctr = 1
	
	SELECT @cTaxRateID = TaxRateID, @cName = Name, @cRate = Rate, @cGLAccountID = GLAccountID, @cDescription = [Description]
		FROM #TempTaxRates 
		WHERE SequenceNum = @ctr
		
	WHILE (@cTaxRateID IS NOT NULL)
	BEGIN
		SELECT @sTaxRateID = TaxRateID
			FROM TaxRate
			WHERE TaxRateID = @cTaxRateID
		IF (@sTaxRateID IS NULL)
		BEGIN
			INSERT TaxRate (TaxRateID, AccountID, Name, Rate, GLAccountID, [Description], IsObsolete)
				VALUES (@cTaxRateID, @accountID, @cName, @cRate, @cGLAccountID, @cDescription, 0)
			INSERT TaxRateGroupTaxRate (TaxRateGroupID, TaxRateID, AccountID)
				VALUES (@taxRateGroupID, @cTaxRateID, @accountID)
		END
		ELSE
		BEGIN
			UPDATE TaxRate SET Rate = @cRate, Name = @cName, GLAccountID = @cGLAccountID, [Description] = @cDescription
				WHERE TaxRateID = @cTaxRateID
			DELETE #TempOldTaxRates WHERE TaxRateID = @cTaxRateID
		END
		SET @ctr = @ctr + 1
	END
	
	SET @ctr = 1
	SET @maxCtr = (SELECT MAX(SequenceNum) FROM #TempOldTaxRates)
	WHILE ((@maxCtr IS NOT NULL) AND (@ctr < @maxCtr))
	BEGIN
		SELECT @sTaxRateID = TaxRateID FROM #TempOldTaxRates
		IF ((0 < (SELECT COUNT(t.TransactionID) 
					FROM [Transaction] t
						INNER JOIN TaxRateGroup trg ON t.TaxRateGroupID = trg.TaxRateGroupID 
						INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
						INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
					WHERE tr.TaxRateID = @sTaxRateID))
				AND (0 < (SELECT COUNT(py.PaymentID) 
					FROM Payment py
						INNER JOIN TaxRateGroup trg ON py.TaxRateGroupID = trg.TaxRateGroupID 
						INNER JOIN TaxRateGroupTaxRate trgtr ON trg.TaxRateGroupID = trgtr.TaxRateGroupID
						INNER JOIN TaxRate tr ON trgtr.TaxRateID = tr.TaxRateID
					WHERE tr.TaxRateID = @sTaxRateID)))
		BEGIN
		DELETE TaxRate WHERE TaxRateID = @sTaxRateID
		END
		SET @ctr = @ctr + 1
	END
END
GO
