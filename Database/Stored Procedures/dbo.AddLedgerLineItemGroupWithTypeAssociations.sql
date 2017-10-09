SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 11/20/2014 
-- Description:	Creates a new LedgerLineItemGroup and adds the given LedgerItemType associations
-- =============================================
CREATE PROCEDURE [dbo].[AddLedgerLineItemGroupWithTypeAssociations]
	@accountID BIGINT,
	@newGroupID UNIQUEIDENTIFIER,
	@newGroupName VARCHAR(50),
	@propertyID UNIQUEIDENTIFIER,
	@ledgerItemTypeIDs GuidCollection READONLY
AS
BEGIN
	SET NOCOUNT ON;
	
	DELETE liglit
		FROM   LedgerLineItemGroupLedgerItemType liglit
			   JOIN LedgerLineItemGroup lig
				 ON lig.LedgerLineItemGroupID = liglit.LedgerLineItemGroupID
					AND lig.PropertyID = @propertyID
					AND lig.AccountID = @accountID
		WHERE  liglit.LedgerItemTypeID IN (SELECT Value
										   FROM   @ledgerItemTypeIDs)

	INSERT INTO LedgerLineItemGroup
				(LedgerLineItemGroupID,
				 AccountID,
				 NAME,
				 PropertyID)
	VALUES      (@newGroupID,
				 @accountID,
				 @newGroupName,
				 @propertyID)

	INSERT INTO LedgerLineItemGroupLedgerItemType
				(LedgerLineItemGroupLedgerItemTypeID,
				 AccountID,
				 LedgerLineItemGroupID,
				 LedgerItemTypeID)
	SELECT NEWID(),
		   @accountID,
		   @newGroupID,
		   litIDs.Value
	FROM   @ledgerItemTypeIDs litIDs
		   INNER JOIN LedgerItemType lit
				   ON lit.LedgerItemTypeID = litIDs.Value 	
END
GO
