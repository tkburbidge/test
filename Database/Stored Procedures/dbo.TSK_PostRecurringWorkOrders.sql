SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Art Olsen
-- Create date: Dec 3, 2013
-- Description:	Adds recurring work orders from the work order template table.
-- =============================================
CREATE PROCEDURE [dbo].[TSK_PostRecurringWorkOrders]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@recurringItemIDs GuidCollection READONLY,
	@postingPersonID uniqueIdentifier = null,
	@locationID uniqueidentifier = null,
	@locationType nvarchar(25) = null,
	@locationName nvarchar(50) = null
AS

DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @newWorkOrderID uniqueidentifier
DECLARE @recurringItemID uniqueidentifier
DECLARE @workOrderTemplateID uniqueidentifier
DECLARE @personID uniqueidentifier
DECLARE @recurringItemName nvarchar(600)
DECLARE @assignedToPersonID uniqueidentifier
DECLARE @nextWorkOrderNumber int
DECLARE @useGlobalWorkOrderNumbering bit
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
		AssignedToPersonID uniqueidentifier not null)
		
	
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
			SELECT RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID
				FROM RecurringItem
				WHERE RecurringItemID IN (SELECT Value FROM @recurringItemIDs)
	END
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #RecurringItems)		
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		-- Get the RecurringItem info
		SELECT @recurringItemID = RecurringItemID, @accountID = #RecurringItems.AccountID, @personID = PersonID, @recurringItemName = Name, @assignedToPersonID = AssignedToPersonID,
				@useGlobalWorkOrderNumbering = s.UseGlobalWorkOrderNumbering
			FROM #RecurringItems 
			INNER JOIN Settings s ON s.AccountID = #RecurringItems.AccountID
			WHERE Sequence = @ctr
			
		SET @newWorkOrderID = NEWID()			
		
		-- Add the work order
		INSERT WorkOrder (WorkOrderID, AccountID, PropertyID, ReceivedPersonID, WorkOrderCategoryID, VendorID, ReportedPersonID, ObjectID, 
		ObjectType, ObjectName, [Description], [Priority], [Status], ReportedPersonName, ReportedDate, ReportedNotes, DueDate, AssignedPersonID, Appointment, 
		ContactPhone, Pets, InventoryItemID, Number, ReportedDateTime, LastModified)
			SELECT @newWorkOrderID, wt.AccountID, wt.PropertyID, wt.ReceivedPersonID, wt.WorkOrderCategoryID, wt.VendorID, wt.ReportedPersonID,
				 COALESCE(@locationID, wt.LocationID), COALESCE(@locationType, wt.LocationType), COALESCE(@locationName, wt.LocationName), wt.[Description],
				  wt.[Priority], 'Not Started', rp.PreferredName + ' ' + rp.LastName, @date, wt.Notes, DATEADD(day, wt.DaysUntilDue ,@date),
					wt.AssignedPersonID, wt.Appointment, wt.ContactPhone, wt.Pets,wt.InventoryItemID, 
					(CASE WHEN @useGlobalWorkOrderNumbering = 1 THEN s.NextWorkOrderNumber
						  ELSE p.NextWorkOrderNumber
					END), 
					@date, @date
			FROM WorkOrderTemplate wt 
				LEFT JOIN Person rp on wt.ReportedPersonID = rp.PersonID
				INNER JOIN Settings s ON s.AccountID = wt.AccountID
				INNER JOIN Property p on wt.PropertyID = p.PropertyID				
			WHERE RecurringItemID = @recurringItemID
				
		IF (@useGlobalWorkOrderNumbering = 1)
		BEGIN
			UPDATE Settings SET NextWorkOrderNumber = NextWorkOrderNumber + 1
		END
		ELSE
		BEGIN
			update Property set NextWorkOrderNumber = p.NextWorkOrderNumber + 1
			from Property p
			join WorkOrderTemplate wt on p.PropertyID = wt.PropertyID
			where wt.RecurringItemID = @recurringItemID
		END
		
		
		SET @ctr = @ctr + 1
			
		IF (@postingPersonID is null)
		BEGIN
			update dbo.RecurringItem SET LastRecurringPostDate = @date
			where RecurringItemID = @recurringItemID
		END
		ELSE
		BEGIN
			update dbo.RecurringItem
			SET LastManualPostDate = @date, LastManualPostPersonID = @postingPersonID
			where RecurringItemID = @recurringItemID
		END		
	END
END




GO
