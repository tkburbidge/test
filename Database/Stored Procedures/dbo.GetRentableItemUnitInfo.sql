SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 9/28/2016
-- Description:	Gets Rentable Item info
-- =============================================
CREATE PROCEDURE [dbo].[GetRentableItemUnitInfo] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@onlyAttached bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	

	CREATE TABLE #RIPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #RIPropertyIDs SELECT Value FROM @propertyIDs
	
		SELECT
			--b.PropertyID,
			li.AttachedToUnitID AS 'UnitID',
			li.LedgerItemID,
			li.[Description] AS 'Name',
			lip.Amount,
			lip.Name AS 'Type'
		FROM LedgerItem li
			INNER JOIN LedgerItemPool lip on li.LedgerItemPoolID = lip.LedgerItemPoolID
			INNER JOIN #RIPropertyIDs #pids ON #pids.PropertyID = lip.PropertyID
		where li.AccountID = @accountID
		  AND (@onlyAttached = 0 OR (@onlyAttached = 1 AND li.AttachedToUnitID IS NOT NULL))

END




GO
