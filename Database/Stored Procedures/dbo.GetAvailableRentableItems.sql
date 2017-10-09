SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 3, 2011
-- Description:	Gets Rentable Items which are available, or may soon be available to rent
-- =============================================
CREATE PROCEDURE [dbo].[GetAvailableRentableItems] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@date datetime = null

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #RentableItems
	(
		PropertyName nvarchar(200),
		[Type] nvarchar(50) null,
		Name nvarchar(50),
		LedgerItemID uniqueidentifier,
		Charge money,
		LedgerItemPoolName nvarchar(100),
		Rentable bit,
		AttachedUnitNumber nvarchar(100),
		MoveInDate date null,
		DateAvailable date null,
		Applicants nvarchar(500),
		OldLeaseID uniqueidentifier null,
		OldLessorType nvarchar(100),
		NewLeaseID uniqueidentifier null,
		NewLessorType nvarchar(100),
		Unit nvarchar(100),
		LedgerItemTypePoolID uniqueidentifier null,
		LedgerItemPoolMarketingDescription nvarchar(400) null,
		IncludeInOnlineApplication bit null,
		AttachedToUnitID uniqueidentifier null
	)	
	DECLARE @propertyIDs GuidCollection
	INSERT INTO @propertyIDs VALUES (@propertyID)
	
	INSERT INTO #RentableItems
	EXEC RPT_RNTITM_AvailableRentableItems @propertyIDs, @date


	SELECT ri.LedgerItemID,
		   ri.Name,
		   ri.Charge AS 'DefaultCharge',
		   ri.LedgerItemPoolName AS 'Type',
		   ri.Unit AS 'CurrentUnit',
		   ri.DateAvailable,
		   ali.LedgerItemID AS 'ConcessionLedgerItemID',
		   ali.[Description] AS 'ConcessionLedgerItemName',
		   ri.LedgerItemTypePoolID,
		   ri.LedgerItemPoolMarketingDescription AS 'MarketingDescription',
		   ri.IncludeInOnlineApplication,
		   ri.AttachedUnitNumber,
		   ri.AttachedToUnitID
	FROM #RentableItems ri
		INNER JOIN LedgerItem li ON li.LedgerItemID = ri.LedgerItemID
		INNER JOIN LedgerItemType lit on li.LedgerItemTypeID = lit.LedgerItemTypeID
		LEFT JOIN LedgerItemType alit on alit.LedgerItemTypeID = lit.AppliesToLedgerItemTypeID
		LEFT JOIN LedgerItem ali on ali.LedgerItemTypeID = alit.LedgerItemTypeID
	WHERE ri.Rentable = 1
	  AND ri.[Type] IN ('Vacant','Notice to Vacate')

	DROP TABLE #RentableItems
	
END

GO
