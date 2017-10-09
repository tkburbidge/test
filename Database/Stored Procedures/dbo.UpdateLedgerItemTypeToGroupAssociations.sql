SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 11/20/2014
-- Description:	Takes a list of group to type associations and deletes them, then adds the specified associations, also updates group name
-- =============================================
CREATE PROCEDURE [dbo].[UpdateLedgerItemTypeToGroupAssociations] 
	@accountID BIGINT,
	@propertyID UNIQUEIDENTIFIER,
	@groupID UNIQUEIDENTIFIER,
	@groupName VARCHAR(50),
	@deleteList GuidCollection READONLY,
	@addList GuidCollection READONLY
AS
BEGIN
	SET NOCOUNT ON;
	
	UPDATE lig 
	SET    NAME = @groupName 
	FROM   LedgerLineItemGroup lig 
	WHERE  lig.LedgerLineItemGroupID = @groupID 

	DELETE liglit 
	FROM   LedgerLineItemGroupLedgerItemType liglit 
		   JOIN LedgerLineItemGroup lig 
			 ON liglit.LedgerLineItemGroupID = lig.LedgerLineItemGroupID 
				AND lig.AccountID = @accountID 
				AND lig.PropertyID = @propertyID 
	WHERE  liglit.LedgerItemTypeID IN (SELECT Value 
									   FROM   @deleteList) 

	INSERT INTO LedgerLineItemGroupLedgerItemType 
				(LedgerLineItemGroupLedgerItemTypeID, 
				 AccountID, 
				 LedgerLineItemGroupID, 
				 LedgerItemTypeID) 
	SELECT NEWID(), 
		   @accountID, 
		   @groupID, 
		   Value 
	FROM   @addList litIDs 
		   INNER JOIN LedgerItemType lit 
				   ON lit.LedgerItemTypeID = litIDs.Value
END
GO
