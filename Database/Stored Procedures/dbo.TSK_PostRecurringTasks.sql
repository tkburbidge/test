SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[TSK_PostRecurringTasks]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@recurringItemIDs GuidCollection READONLY,
	@postingPersonID uniqueIdentifier = null
AS

DECLARE @ctrRecurringItems int = 1
DECLARE @maxCtrRecurringItems int
DECLARE @recurringItemID uniqueidentifier
DECLARE @taskTemplateID uniqueidentifier
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #RecurringItems (
		Sequence	int identity not null,
		RecurringItemID uniqueidentifier not null,
		AccountID bigint not null,
		PersonID uniqueidentifier not null,
		Name nvarchar(500) null,
		AssignedToPersonID uniqueidentifier not null)	--not used		
	
	-- If we aren't posting a particular set of RecurringItems then get all
	-- RecurringItems for the given date.  Otherwise, just post get 
	-- the recurring items of the IDs passed in
	IF (0 = (SELECT COUNT(*) FROM @recurringItemIDs))
	BEGIN
		INSERT INTO #RecurringItems EXEC GetRecurringItemsByType @accountID, @itemType, @date
	END
	ELSE
	BEGIN
		INSERT INTO #RecurringItems
			SELECT ri.RecurringItemID, ri.AccountID, ri.PersonID, '', NEWID()
				FROM RecurringItem ri
				WHERE ri.RecurringItemID IN (SELECT Value FROM @recurringItemIDs)
	END
	
	SET @maxCtrRecurringItems = (SELECT MAX(Sequence) FROM #RecurringItems)		

	WHILE (@ctrRecurringItems <= @maxCtrRecurringItems)
	BEGIN
		-- Get the RecurringItem info
		SELECT 
			@recurringItemID = RecurringItemID,
			@accountID = AccountID
			--@assignedByPersonID = PersonID
			FROM #RecurringItems 
			WHERE Sequence = @ctrRecurringItems
		

		--  get the recurringTaskTemplate
		SELECT @taskTemplateID = tt.TaskTemplateID
			FROM TaskTemplate tt
			WHERE tt.RecurringItemId = @recurringItemID		

		EXEC TSK_CreateTaskFromTemplate @accountID, @date, @taskTemplateID, null, null, null

		SET @ctrRecurringItems = @ctrRecurringItems + 1
		
		IF (@postingPersonID is null)
		BEGIN
			UPDATE dbo.RecurringItem 
				SET LastRecurringPostDate = @date
				WHERE RecurringItemID = @recurringItemID
		END
		ELSE
		BEGIN
			UPDATE dbo.RecurringItem
				SET LastManualPostDate = @date, 
					LastManualPostPersonID = @postingPersonID
				WHERE RecurringItemID = @recurringItemID
		END		
	END
END





GO
