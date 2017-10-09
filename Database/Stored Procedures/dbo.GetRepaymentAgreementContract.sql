SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetRepaymentAgreementContract] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@repaymentAgreementID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PageOne (
		PropertyName nvarchar(50),
		TotalRequestedAmount int,
		UnitNumber nvarchar(50),
		UnitStreet nvarchar(50),
		UnitCity nvarchar(50),
		UnitState nvarchar(50),
		UnitZip nvarchar(50),
		AgreementStartDate datetime,
		AgreementEndDate datetime,
		[Message] nvarchar)
	
	
	CREATE TABLE #PageThree (
		DueDate datetime,
		AmountDue int)
	

	INSERT INTO #PageOne 
	SELECT	
		p.Name,
		r.TotalRequestedAmount,
		u.Number,
		a.StreetAddress AS 'UnitStreet',
		a.City as 'UnitCity',
		a.[State] as 'UnitState',
		a.Zip as 'UnitZip',
		r.AgreementStartDate,
		r.AgreementEndDate,		
		r.CustomText

		FROM RepaymentAgreement r
		LEFT JOIN Lease l ON r.LeaseID = l.LeaseID
		LEFT JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
		LEFT JOIN [Address] a ON u.AddressID = a.AddressID
		LEFT JOIN Building b ON u.BuildingID = b.BuildingID
		LEFT JOIN Property p ON b.PropertyID = p.PropertyID
		WHERE r.RepaymentAgreementID = @repaymentAgreementID AND r.AccountID = @accountID

	INSERT INTO #PageThree
	SELECT 
		r.DueDate,
		r.Amount AS 'AmountDue'
	FROM RepaymentAgreementSchedule r
	WHERE r.RepaymentAgreementID = @repaymentAgreementID AND r.AccountID = @accountID
			
			
	SELECT * FROM #PageOne 
	SELECT * FROM #PageThree 

END
GO
