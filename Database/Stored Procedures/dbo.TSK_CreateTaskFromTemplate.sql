SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[TSK_CreateTaskFromTemplate]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@date date,
	@taskTemplateID uniqueidentifier,
	@objectID uniqueidentifier,
	@objectType nvarchar(25),
	@objectDescription nvarchar(250)
AS

DECLARE @ctrAssignedToPersonIDs int = 1
DECLARE @maxCtrAssignedToPersonIDs int
DECLARE @assignedByPersonID uniqueIdentifier
DECLARE @importance nvarchar(10)
DECLARE @subject nvarchar(250)
DECLARE @message nvarchar(2000)
DECLARE @daysUntilDue int
DECLARE @isAssignedtoPeople bit
DECLARE @isCopiedToPeople bit
DECLARE @isGroupTask bit
DECLARE @newAlertTaskID UNIQUEIDENTIFIER
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
	-- print @maxCtrRecurringItems
	CREATE TABLE #AssignedToPersonIDs (
		Sequence	int identity not null,
		AssignedToPersonID uniqueidentifier not null)

	CREATE TABLE #CopyToPersonIDs (
		Sequence INT IDENTITY NOT NULL,
		PersonID UNIQUEIDENTIFIER NOT NULL)
		

	--  get the TaskTemplate
	SELECT @assignedByPersonID = tt.AssignedByPersonID, @importance = tt.Importance, @subject = tt.[Subject], @daysUntildue = tt.DaysUntilDue, @isAssignedtoPeople = tt.IsAssignedtoPeople, @isCopiedToPeople = tt.IsCopiedToPeople, @message = tt.Message,  @isGroupTask = tt.IsGroupTask
		FROM TaskTemplate tt
		WHERE tt.TaskTemplateID = @taskTemplateID

	IF(@objectDescription IS NOT NULL AND @objectDescription <> '')
	BEGIN
		SET @subject = @subject + ': ' + @objectDescription
	END

	IF (@isAssignedToPeople = 1)
	BEGIN
		INSERT INTO #AssignedToPersonIDs
			SELECT ttp.PersonID
				FROM TaskTemplatePerson ttp
				WHERE ttp.TaskTemplateID = @taskTemplateID
					AND ttp.IsCarbonCopy = 0
	END
	ELSE
	BEGIN
		INSERT INTO #AssignedToPersonIDs
			SELECT DISTINCT u.PersonID
				FROM TaskTemplate tt
					INNER JOIN TaskTemplateProperty ttp ON ttp.TaskTemplateID = tt.TaskTemplateID
					INNER JOIN TaskTemplateSecurityRole ttsr ON ttsr.TaskTemplateID = tt.TaskTemplateID
					INNER JOIN [User] u ON u.SecurityRoleID = ttsr.SecurityRoleID
					INNER JOIN PersonType pt ON pt.PersonID = u.PersonID
					INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID AND ptp.PropertyID = ttp.PropertyID AND ptp.HasAccess = 1
				WHERE tt.TaskTemplateID = @taskTemplateID
					AND ttp.IsCarbonCopy = 0
					AND ttsr.IsCarbonCopy = 0
	END

	IF (@isCopiedToPeople = 1)
	BEGIN
		INSERT INTO #CopyToPersonIDs
			SELECT ttp.PersonID
				FROM TaskTemplatePerson ttp
				WHERE ttp.TaskTemplateID = @taskTemplateID
					AND ttp.IsCarbonCopy = 1
	END
	ELSE
	BEGIN
		INSERT INTO #CopyToPersonIDs
			SELECT DISTINCT u.PersonID
				FROM TaskTemplate tt
					INNER JOIN TaskTemplateProperty ttp ON ttp.TaskTemplateID = tt.TaskTemplateID
					INNER JOIN TaskTemplateSecurityRole ttsr ON ttsr.TaskTemplateID = tt.TaskTemplateID
					INNER JOIN [User] u ON u.SecurityRoleID = ttsr.SecurityRoleID
					INNER JOIN PersonType pt ON pt.PersonID = u.PersonID
					INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID AND ptp.PropertyID = ttp.PropertyID AND ptp.HasAccess = 1
				WHERE tt.TaskTemplateID = @taskTemplateID
					AND ttp.IsCarbonCopy = 1
					AND ttsr.IsCarbonCopy = 1
	END
					
	SET @maxCtrAssignedToPersonIDs = (SELECT MAX(Sequence) FROM #AssignedToPersonIDs)

	-- add a task for each user that needs it
	IF (@isGroupTask = 1)
	BEGIN
		--For group tasks we will create ONE AlertTask and MANY TaskAssignments pointing to it
		SET @newAlertTaskID = NEWID()	
		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], [Message], TaskStatus, PercentComplete)
			VALUES (@newAlertTaskID, @accountID, @assignedByPersonID, @objectID, @objectType, 'Task', @importance, @date, DATEADD(DAY, @daysUntilDue, @date) , null, 0, @subject, @message,  'Not Started', 0)

		--Add the assignments
		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			SELECT NEWID(), @accountID, @newAlertTaskID, #atp.AssignedToPersonID, NULL, 0
				FROM #AssignedToPersonIDs #atp
					
		--Add all the CCs to each task
		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			SELECT NEWID(), @accountID, @newAlertTaskID, #ctp.PersonID, NULL, 1
				FROM #CopyToPersonIDs #ctp
	END
	ELSE
	BEGIN
		--If not group task then we will create MANY AlertTasks with ONE TaskAssignment each.
		WHILE (@ctrAssignedToPersonIDs <= @maxCtrAssignedToPersonIDs)
		BEGIN	
			-- Add a task for the user to update the needed values
			SET @newAlertTaskID = NEWID()
			INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], [Message], TaskStatus, PercentComplete)
				VALUES (@newAlertTaskID, @accountID, @assignedByPersonID, @objectID, @objectType, 'Task', @importance, @date, DATEADD(DAY, @daysUntilDue, @date) , null, 0, @subject, @message,  'Not Started', 0)

			--Add the assigned people
			INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
				VALUES (NEWID(), @accountID, @newAlertTaskID, (SELECT AssignedToPersonID FROM #AssignedToPersonIDs WHERE Sequence = @ctrAssignedToPersonIDs), NULL, 0)
					
			--Add ALL the CCs to each task
			INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
				SELECT NEWID(), @accountID, @newAlertTaskID, #ctp.PersonID, NULL, 1
					FROM #CopyToPersonIDs #ctp

			SET @ctrAssignedToPersonIDs = @ctrAssignedToPersonIDs + 1
		END
	END
	
END





GO
