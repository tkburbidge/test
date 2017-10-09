SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Apr. 9, 2015
-- Description:	Gets the list of owners
-- =============================================
CREATE PROCEDURE [dbo].[RPT_OWN_OwnershipInformation] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @defaultAccountingBasis nvarchar(10) = (SELECT DefaultAccountingBasis FROM Settings WHERE AccountID = @accountID)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #WhoOwnsMe (
		PropertyID uniqueidentifier not null,
		DistributionGLAccountID uniqueidentifier null,
		EquityGLAccountID uniqueidentifier null,
		PropertyName nvarchar(500) null,
		VendorID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		OwnerName nvarchar(500) null,
		StreetAddress nvarchar(500) null,
		City nvarchar(1000) null,
		[State] nvarchar(300) null,
		Zip nvarchar(200) null,
		Form1099RecipientsID nvarchar(1000) null,
		EquityPercentage decimal(7, 4) null,
		EquityContribution money null,
		DistributionAmount money null,
		IsActive bit null)
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)
		
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #WhoOwnsMe
		SELECT	DISTINCT
				vp.PropertyID,
				op.DistributionGLAccountID AS 'DistributionGLAccountID',
				op.EquityGLAccountID AS 'EquityGLAccountID',
				p.Name AS 'PropertyName',
				v.VendorID,
				vPer.PersonID,
				v.CompanyName AS 'OwnerName',
				[add].StreetAddress,
				[add].City,
				[add].[State],
				[add].Zip,
				v.Form1099RecipientsID,
				(SELECT opp1.Percentage
					FROM OwnerPropertyPercentage opp1
						INNER JOIN OwnerPropertyPercentageGroup oppg1 ON opp1.OwnerPropertyPercentageGroupID = oppg1.OwnerPropertyPercentageGroupID
					WHERE opp1.OwnerPropertyID = op.OwnerPropertyID
					  AND oppg1.OwnerPropertyPercentageGroupID = (SELECT TOP 1 oppg.OwnerPropertyPercentageGroupID		
																	  FROM OwnerPropertyPercentageGroup oppg
																		  INNER JOIN #PropertiesAndDates #pad ON oppg.PropertyID = #pad.PropertyID
																		  INNER JOIN OwnerPropertyPercentage opp ON oppg.OwnerPropertyPercentageGroupID = opp.OwnerPropertyPercentageGroupID
																		  INNER JOIN OwnerProperty op1 ON opp.OwnerPropertyID = op1.OwnerPropertyID 
																	  WHERE oppg.[Date] <= #pad.EndDate
																		AND op1.VendorPropertyID = vp.VendorPropertyID
																	  ORDER BY oppg.[Date] DESC, oppg.DateCreated DESC)) AS 'EquityPercentage',
				null AS 'EquityContribution',
				null AS 'DistributionAmount',
				CASE 
					WHEN ((op.DateInactive IS NULL) OR (op.DateInactive > #pad.EndDate)) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END AS 'IsActive'
			FROM OwnerProperty op
				INNER JOIN VendorProperty vp ON op.VendorPropertyID = vp.VendorPropertyID
				INNER JOIN Vendor v ON vp.VendorID = v.VendorID
				INNER JOIN VendorPerson vPer ON v.VendorID = vPer.VendorID
				INNER JOIN [Address] [add] ON vPer.PersonID = [add].ObjectID AND [add].AddressType = 'VendorPayment'

				INNER JOIN Property p ON vp.PropertyID = p.PropertyID 
				INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID

	UPDATE #WhoOwnsMe SET DistributionAmount = (SELECT -SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
													WHERE je.GLAccountID = #WhoOwnsMe.DistributionGLAccountID
													  AND t.PropertyID = #WhoOwnsMe.PropertyID
													  AND t.TransactionDate >= #pad.StartDate 
													  AND t.TransactionDate <= #pad.EndDate
													  AND je.AccountingBookID IS NULL
													  AND AccountingBasis = @defaultAccountingBasis)

	UPDATE #WhoOwnsMe SET EquityContribution = (SELECT -SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID															
														WHERE je.GLAccountID = #WhoOwnsMe.EquityGLAccountID
														  AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
														  AND je.AccountingBookID IS NULL
														  AND AccountingBasis = @defaultAccountingBasis)
			
	SELECT * FROM #WhoOwnsMe	
		ORDER BY PropertyName, OwnerName										

END
GO
