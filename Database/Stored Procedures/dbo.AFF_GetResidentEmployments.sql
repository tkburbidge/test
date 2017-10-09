SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetResidentEmployments] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Employments
	(
		EmploymentID uniqueidentifier not null,
		SalaryID uniqueidentifier not null,
		[Type] nvarchar(10) null,
		TaxCreditType nvarchar(100) null,
		PersonID uniqueidentifier not null,
		Resident nvarchar(81) not null,
		Employer nvarchar(100) null,
		EndDate date null,
		SalaryAmount money not null,
		HudSalaryAmount money null,
		SalaryPeriod nvarchar(100) null,
		VerificationSource nvarchar(500) null,
		VerifiedPersonName nvarchar(81) null,
		VerifiedDate date null,
		SalaryEffectiveDate date not null, 
		HasDocument bit not null,
		EmploymentEndDate date null
	)

	INSERT INTO #Employments
		SELECT
			e.EmploymentID AS 'EmploymentID',
			[effectiveSalary].SalaryID AS 'SalaryID',
			e.[Type] AS 'Type',
			e.TaxCreditType AS 'TaxCreditType',
			e.PersonID AS 'PersonID',
			p.FirstName + ' ' + p.LastName AS 'Resident',
			e.Employer AS 'Employer',
			e.EndDate AS 'EndDate',
			ISNULL([effectiveSalary].Amount, 0) AS 'SalaryAmount',
			[effectiveSalary].HUDAmount as 'HudSalaryAmount',
			[effectiveSalary].SalaryPeriod AS 'SalaryPeriod',
			[effectiveSalary].VerificationSources AS 'VerificationSource',
			[effectiveSalary].FirstName + ' ' + [effectiveSalary].LastName AS 'VerifiedPersonName',
			[effectiveSalary].DateVerified AS 'VerifiedDate',
			[effectiveSalary].EffectiveDate AS 'EffectiveDate',
			CASE WHEN (doc.DocumentID IS NOT NULL) THEN CAST(1 AS bit)
				 ELSE CAST(0 AS bit) END AS 'HasDocument',
			e.EndDate AS 'EmploymentEndDate'
		FROM Employment e
			INNER JOIN Person p ON e.PersonID = p.PersonID
			LEFT JOIN Document doc ON e.EmploymentID = doc.AltObjectID
			LEFT JOIN 
				(SELECT s.SalaryID, s.EmploymentID, s.EffectiveDate, s.Amount, s.HUDAmount, s.SalaryPeriod, s.DateVerified, s.VerificationSources, pv.FirstName, pv.LastName
					FROM Salary s
						LEFT JOIN Person pv ON s.VerifiedByPersonID = pv.PersonID) [effectiveSalary] ON e.EmploymentID = [effectiveSalary].EmploymentID
		WHERE e.AccountID = @accountID
			AND e.PersonID IN (SELECT Value FROM @personIDs)

	SELECT * FROM #Employments

END
GO
