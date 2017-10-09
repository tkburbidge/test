SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Updated By: Trevor Burbidge
-- =============================================
CREATE PROCEDURE [dbo].[TSK_AddRentersInsuranceExpirationNotifications]
	@date date		

AS
DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @accountID bigint
DECLARE @propertyIDs GuidCollection
DECLARE @leaseStatus StringCollection
DECLARE @propertyID uniqueidentifier
DECLARE @expiringDate date

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Get a table of all accounts 
    CREATE TABLE #AccountsTemp (
		Sequence	int identity not null,
		AccountID bigint 
	)
    INSERT INTO #AccountsTemp SELECT AccountID FROM Settings   
    
	--- Has the exact same columns of the return set of the the exceptions stored procedure    
    CREATE TABLE #RentersInsuranceExceptions
	(
		PropertyName nvarchar(50) not null,
		UnitLeaseGroupID uniqueidentifier not null,		
		Residents nvarchar(500)  null,
		PolicyHolders nvarchar(200) null,
		[Type] nvarchar(50) null,			-- RentersInsuranceType
		Provider nvarchar(100) null,
		PolicyNumber nvarchar(50) null,
		ContactName nvarchar(50) null,
		PhoneNumber nvarchar(25) null,
		ExpirationDate date null,
		Coverage money null,
		Unit nvarchar (20) null,
		PaddedUnit nvarchar(50) null,
		InsuranceStatus nvarchar(10) not null,
		PropertyID uniqueidentifier not null
	)
    
    CREATE TABLE #propertyIDsTemp (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #AlertTasksTemp (
		AlertTaskID UNIQUEIDENTIFIER NOT NULL,
		AccountID BIGINT NOT NULL,
		AssignedToPersonID UNIQUEIDENTIFIER NOT NULL,
		AssignedByPersonID UNIQUEIDENTIFIER NOT NULL,
		ObjectID UNIQUEIDENTIFIER NOT NULL,
		[Subject] NVARCHAR(MAX) NOT NULL
	)
    
    -- Setup parameters
    SET @maxCtr = (SELECT MAX(Sequence) FROM #AccountsTemp)
	INSERT INTO @leaseStatus VALUES ('Current')
	SET @expiringDate = DATEADD(day, 30, @date)
    
	-- Loop for each account
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SET @accountID = (SELECT TOP 1 AccountID FROM #AccountsTemp WHERE Sequence = @ctr)
		
		-- Get all the properties with a specified ManagerPersonID
		INSERT INTO @propertyIDs SELECT PropertyID FROM Property WHERE AccountID = @accountID AND ManagerPersonID IS NOT NULL

		-- [RPT_RES_RentersInsuranceExceptions] @propertyIDs, @leaseStatus, @includeExpiringPolicies, @expiringDate, @includeMissingPolicies, @date, @includeExpiredPolicies
		INSERT INTO #RentersInsuranceExceptions EXEC [RPT_RES_RentersInsuranceExceptions] @propertyIDs, @leaseStatus, 1, @expiringDate, 0, @date, 1
		
		-- Add the alert tasks
		INSERT INTO #propertyIDsTemp SELECT DISTINCT PropertyID FROM #RentersInsuranceExceptions WHERE InsuranceStatus IN ('Expiring', 'Expired')

		INSERT INTO #AlertTasksTemp (AlertTaskID, AccountID, AssignedByPersonID, AssignedToPersonID, ObjectID, [Subject])
			SELECT 
				NEWID(),
				p.AccountID,
				p.ManagerPersonID,
				p.ManagerPersonID,
				p.PropertyID,
				'Check expiring or expired renters insurance policies for ' + p.Name
			FROM Property p
			WHERE p.PropertyID IN (SELECT PropertyID FROM #propertyIDsTemp)

		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], TaskStatus)
			SELECT
				#att.AlertTaskID,
				#att.AccountID,
				#att.AssignedByPersonID,
				#att.ObjectID,
				'Renters Insurance',
				null,
				'High',
				@date,
				@date,
				null,
				0,
				#att.[Subject],
				'Not Started'
			FROM #AlertTasksTemp #att

		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			SELECT 
				NEWID(),
				#att.AccountID,
				#att.AlertTaskID,
				#att.AssignedToPersonID,
				NULL, 
				0
			FROM #AlertTasksTemp #att

		TRUNCATE TABLE #AlertTasksTemp
		
		SET @ctr = @ctr + 1
	END
    
END

DROP TABLE #AccountsTemp
DROP TABLE #RentersInsuranceExceptions
DROP TABLE #propertyIDsTemp

GO
