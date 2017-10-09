SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[TSK_PostEventTasks]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@date date,
	@event nvarchar(20),
	@propertyID uniqueidentifier,
	@objectID uniqueidentifier,
	@objectType nvarchar(25), 
	@objectDescription nvarchar(250)
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @taskTemplateID uniqueidentifier
	
	CREATE TABLE #EventTaskTemplates (
		Sequence int identity,
		TaskTemplateID uniqueidentifier not null)

	INSERT INTO #EventTaskTemplates
		SELECT tt.TaskTemplateID
			FROM TaskTemplate tt
				INNER JOIN TaskTemplateProperty ttp ON ttp.TaskTemplateID = tt.TaskTemplateID
			WHERE tt.AccountID = @accountID
			  AND tt.[Type] = @event
			  AND ttp.PropertyID = @propertyID
			  AND ttp.IsCarbonCopy = 0

	DECLARE @currentSequence int = (SELECT TOP 1 Sequence FROM #EventTaskTemplates ORDER BY Sequence DESC)
	
	WHILE @currentSequence > 0
	BEGIN
		SET @taskTemplateID = (SELECT TOP 1 TaskTemplateID FROM #EventTaskTemplates WHERE Sequence = @currentSequence)

		EXEC dbo.TSK_CreateTaskFromTemplate @accountID, @date, @taskTemplateID, @objectID, @objectType, @objectDescription
		
		SET @currentSequence = @currentSequence - 1 
	END


END





GO
