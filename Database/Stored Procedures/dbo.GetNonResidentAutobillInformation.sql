SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 13, 2014
-- Description:	Gets all of the info needed to do the NonResident autobilling
-- =============================================
CREATE PROCEDURE [dbo].[GetNonResidentAutobillInformation] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  per.PersonID AS 'PersonID', 
			li.[Description] AS 'Description', 
			nrli.Amount AS 'Amount', 
			li.LedgerItemTypeID AS 'LedgerItemTypeID', 
			nrli.NonResidentLedgerItemID AS 'NonResidentLedgerItemID', 
			li.LedgerItemID AS 'LedgerItemID', 
			litp.TaxRateGroupID AS 'TaxRateGroupID',
			CASE
				WHEN (lit.IsCharge = 1) THEN CAST(1 AS Bit)
				ELSE CAST(0 AS Bit) END AS 'IsCharge',
			nrli.PostingDay,
			per.FirstName + ' ' + per.LastName AS 'NonResidentName'
		FROM NonResidentLedgerItem nrli
			INNER JOIN LedgerItem li ON nrli.LedgerItemID = li.LedgerItemID
			INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
			INNER JOIN Person per ON nrli.PersonID = per.PersonID
			INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] = 'Non-Resident Account'
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID = @propertyID
			LEFT JOIN LedgerItemTypeProperty litp ON litp.LedgerItemTypeID = lit.LedgerItemTypeID AND litp.PropertyID = @propertyID
		WHERE nrli.StartDate <= @date AND nrli.EndDate >= @date
	
END
GO
