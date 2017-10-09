SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetResidentAssets] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Assets
	(
		AssetID uniqueidentifier not null,
		AssetValueID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		[Type] nvarchar(max) null,
		EndDate date null,
		PersonName nvarchar(81) not null,
		AnnualIncome money not null,
		HUDAnnualIncome money null,
		CurrentValue money not null,
		AnnualInterestRate money not null,
		VerificationSource nvarchar(500) null,
		VerifiedByPersonName nvarchar(81) null,
		DateVerified date null,
		[Description] nvarchar(500) null,
		[Status] nvarchar(25) not null,
		EffectiveDate date not null,
		CashValue money not null, 
		HasDocument bit not null
	)

	INSERT INTO #Assets
		SELECT
			a.AssetID AS 'AssetID',
			[effectiveAssetValue].AssetValueID AS 'AssetValueID',
			a.PersonID AS 'PersonID',
			a.[Type] AS 'Type',
			a.EndDate AS 'EndDate',
			p.FirstName + ' ' + p.LastName AS 'PersonName',
			ISNULL([effectiveAssetValue].AnnualIncome, 0) AS 'AnnualIncome',
			[effectiveAssetValue].HudAnnualIncome as 'HUDAnnualIncome',
			ISNULL([effectiveAssetValue].CurrentValue, 0) AS 'CurrentValue',
			ISNULL([effectiveAssetValue].AnnualInterestRate, 0) AS 'AnnualInterestRate',
			[effectiveAssetValue].VerificationSources AS 'VerificationSource',
			[effectiveAssetValue].FirstName + ' ' + [effectiveAssetValue].LastName AS 'VerifiedByPersonName',
			[effectiveAssetValue].DateVerified AS 'DateVerified',
			a.[Description] AS 'Description',
			a.[Status] AS 'Status',
			ISNULL([effectiveAssetValue].[Date], '12-31-9999') AS 'EffectiveDate',
			ISNULL([effectiveAssetValue].CashValue, 0) AS 'CashValue',
			CASE WHEN (doc.DocumentID IS NOT NULL) THEN CAST(1 AS bit)
				 ELSE CAST(0 AS bit) END AS 'HasDocument'
		FROM Asset a
			INNER JOIN Person p ON a.PersonID = p.PersonID
			LEFT JOIN Document doc ON a.AssetID = doc.AltObjectID
			LEFT JOIN
				(SELECT av.AssetID, av.AssetValueID, av.AnnualIncome, av.HUDAnnualIncome, av.CurrentValue, av.AnnualInterestRate, av.DateVerified, pv.FirstName, pv.LastName, av.VerificationSources, av.[Date], av.CashValue
					FROM AssetValue av
						LEFT JOIN Person pv ON av.VerifiedByPersonID = pv.PersonID) [effectiveAssetValue] ON a.AssetID = [effectiveAssetValue].AssetID
		WHERE a.AccountID = @accountID
			AND a.PersonID IN (SELECT Value FROM @personIDs)
	
	SELECT * FROM #Assets

END
GO
