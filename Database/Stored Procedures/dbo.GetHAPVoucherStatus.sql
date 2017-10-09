SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetHAPVoucherStatus] 
	@accountID bigint,
	@date datetime,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #Vouchers (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		ContractNumber nvarchar(20) not null,
		HAPRequests int null,
		Approved int null,
		[Status] nvarchar(50) not null,
		VoucherDate datetime null,
		VoucherCreatedDate datetime null,
		AffordableProgramAllocationID uniqueidentifier not null
	)

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.EndDate, @date)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #Vouchers
		SELECT
			p.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			ISNULL(apa.ContractNumber, apa.SubsidyType) AS 'ContractNumber',
			null AS 'HAPRequests',
			null AS 'Approved',
			'' AS 'Status',
			null AS 'VoucherDate',
			null AS 'VoucherCreatedDate',
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID'
		FROM Property p 
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
			INNER JOIN AffordableProgram ap ON p.PropertyID = ap.PropertyID
			INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
		WHERE p.AccountID = @accountID
			AND ap.IsHUD = 1

	UPDATE #v
		SET HAPRequests = a.TotalRequestAmount,
			Approved = CAST(ROUND(asp.AmountPaid + asp.OffsetAmount, 0) AS INT),
			[Status] = a.[Status],
			VoucherDate = a.StartDate,
			VoucherCreatedDate = a.DateCreated
		FROM #Vouchers #v
			INNER JOIN AffordableSubmission a ON #v.AffordableProgramAllocationID = a.AffordableProgramAllocationID
			INNER JOIN #PropertiesAndDates #pad ON #v.PropertyID = #pad.PropertyID
			LEFT JOIN AffordableSubmissionPayment asp ON a.AffordableSubmissionID = asp.AffordableSubmissionID AND asp.Code = 'VSP00'
		WHERE a.AffordableSubmissionID IN (SELECT TOP 1 a2.AffordableSubmissionID
											FROM AffordableSubmission a2
											WHERE a2.AffordableProgramAllocationID = #v.AffordableProgramAllocationID
												AND a2.StartDate < #pad.EndDate
											ORDER BY a2.StartDate DESC)

	SELECT * FROM #Vouchers

END
GO
