SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

--Edited by Trevor Burbidge
--Fixes issue where updating a group for template A could affect template B
CREATE PROCEDURE [dbo].[AddUpdateDeleteBudgetTemplateGroup] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@budgetTemplateGroupID uniqueidentifier,
	@budgetTemplateID uniqueidentifier,
	@name nvarchar(200),
	@type nvarchar(25),
	@delete bit,
	@glAccountIDs GuidCollection READONLY, -- these are the gl accounts that we are putting into this budget template group
	@localDate datetime,
	@personID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    IF (@budgetTemplateGroupID IS NULL)
		BEGIN
			SET @budgetTemplateGroupID = NEWID()
			--Create a the budget template group
			INSERT INTO BudgetTemplateGroup (AccountID, BudgetTemplateGroupID, BudgetTemplateID, IsSystem, Name, [Type], OrderBy)
				VALUES (@accountID, @budgetTemplateGroupID, @budgetTemplateID, 0, @name, @type, 0)
		END
	ELSE
		BEGIN
			SET @budgetTemplateID = (SELECT TOP 1 BudgetTemplateID FROM BudgetTemplateGroup WHERE BudgetTemplateGroupID = @budgetTemplateGroupID)

			IF (@delete = 1)
				DELETE BudgetTemplateGroup
					WHERE BudgetTemplateGroupID = @budgetTemplateGroupID
			ELSE
				UPDATE BudgetTemplateGroup 
					SET Name = @name, [Type] = @type
					WHERE BudgetTemplateGroupID = @budgetTemplateGroupID
		END
    
    --Delete old ones (both old ones that are in a different group right now and old ones that are in this group)
    DELETE btggla 
		FROM BudgetTemplateGroupGLAccount btggla
			INNER JOIN BudgetTemplateGroup btg ON btg.BudgetTemplateGroupID = btggla.BudgetTemplateGroupID
		WHERE btg.BudgetTemplateID = @budgetTemplateID -- only want to mess with this budget template
		  AND btggla.IsEditable = 1 --don't change ones that aren't editable
		  --Here we are including any gls that we passed in (no matter what group they are in) and all gls already in this group
		  AND (btggla.GLAccountID IN (SELECT Value FROM @glAccountIDs) OR btggla.BudgetTemplateGroupID = @budgetTemplateGroupID)
    
    --Add new ones
    INSERT BudgetTemplateGroupGLAccount (AccountID, BudgetTemplateGroupGLAccountID, BudgetTemplateGroupID, GLAccountID, IsEditable)
		SELECT @accountID, NEWID(), @budgetTemplateGroupID, Value, 1 
			FROM @glAccountIDs
				LEFT JOIN BudgetTemplateGroupGLAccount btggl ON btggl.GLAccountID = Value AND btggl.BudgetTemplateGroupID = @budgetTemplateGroupID
				LEFT JOIN BudgetTemplateGroup btg ON btg.BudgetTemplateGroupID = btggl.BudgetTemplateGroupID
			WHERE (btg.BudgetTemplateID IS NULL OR btg.BudgetTemplateID = @budgetTemplateID)
			  AND (btggl.BudgetTemplateGroupGLAccountID IS NULL OR btggl.IsEditable = 1) --don't change ones that aren't editable
		

	--Update the budget template
	UPDATE BudgetTemplate
		SET LastModified = @localDate, LastModifiedByPersonID = @personID
		WHERE BudgetTemplateID = @budgetTemplateID

				
	SELECT * FROM BudgetTemplateGroup WHERE BudgetTemplateGroupID = @budgetTemplateGroupID
END
GO
