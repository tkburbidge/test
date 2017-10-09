SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 27, 2013
-- Description:	Gets the list of Properties and Names for possible intercompanyInvoice Payers
-- =============================================
CREATE PROCEDURE [dbo].[GetIntercompanyPaymentOptions] 
	-- Add the parameters for the stored procedure here
	@magicGuid uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #InvoiceProperties (
		PropertyID uniqueidentifier null)

	CREATE TABLE #PossiblePayers (
		Sequence int identity,
		PropertyID uniqueidentifier null)

	CREATE TABLE #PropertiesCanPay (
		PropertyID uniqueidentifier null)

	CREATE TABLE #IntercompSettings (
		SourcePropertyID uniqueidentifier null,
		DestinationPropertyID uniqueidentifier null)
		
	INSERT #InvoiceProperties
		SELECT PropertyID FROM Property WHERE PropertyID = @magicGuid 
		
	INSERT #InvoiceProperties 
		SELECT PropertyID FROM PropertyGroupProperty WHERE PropertyGroupID = @magicGuid	
		
	INSERT #PossiblePayers 
		SELECT PropertyID FROM Property WHERE PropertyID = @magicGuid
		UNION
		SELECT PropertyID FROM PropertyGroupProperty WHERE PropertyGroupID = @magicGuid
		UNION
		SELECT SourcePropertyID FROM IntercompanySetting WHERE DestinationPropertyID IN (SELECT PropertyID FROM #InvoiceProperties)
		
	INSERT #IntercompSettings 
		SELECT SourcePropertyID, DestinationPropertyID
			FROM IntercompanySetting
			WHERE DestinationPropertyID IN (SELECT PropertyID FROM #InvoiceProperties)
			
	INSERT #IntercompSettings
		SELECT PropertyID, PropertyID 
			FROM #InvoiceProperties

	DECLARE @maxCtr int = (SELECT MAX(Sequence) FROM #PossiblePayers)
	DECLARE @ctr int = 1
	DECLARE @thisPropertyID uniqueidentifier

	WHILE (@ctr <= @maxCtr)
	BEGIN
		SET @thisPropertyID = (SELECT PropertyID FROM #PossiblePayers WHERE Sequence = @ctr)
		INSERT #PropertiesCanPay 
			SELECT @thisPropertyID
				WHERE (NOT EXISTS (
						SELECT PropertyID FROM #InvoiceProperties
						EXCEPT
						SELECT DestinationPropertyID FROM #IntercompSettings WHERE SourcePropertyID = @thisPropertyID))
		SET @ctr = @ctr + 1
	END

	SELECT p.PropertyID, p.Name, p.Abbreviation
		FROM #PropertiesCanPay #pcp
			INNER JOIN Property p ON #pcp.PropertyID = p.PropertyID

END
GO
