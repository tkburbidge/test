SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Tony Morgan
-- Create date: 12/9/2014
-- Description:	Checks to see if a building can be deleted
-- =============================================
CREATE PROCEDURE [dbo].[CanDeleteBuilding] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT,
	@buildingID UNIQUEIDENTIFIER
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	IF EXISTS(SELECT * FROM Unit WHERE BuildingID = @buildingID)
	BEGIN
		SELECT 0
	END
    ELSE IF EXISTS(SELECT * FROM WorkOrder WHERE ObjectID = @buildingID AND ObjectType = 'Building')
    BEGIN
		SELECT 0
    END
    ELSE IF EXISTS(SELECT * FROM InvoiceLineItem WHERE ObjectID = @buildingID AND ObjectType = 'Building')
    BEGIN
		SELECT 0
    END
    ELSE IF EXISTS(SELECT * FROM PurchaseOrderLineItem WHERE ObjectID = @buildingID AND ObjectType = 'Building')
    BEGIN
		SELECT 0
    END
    ELSE IF EXISTS(SELECT * FROM InventoryItemLocation WHERE ObjectID = @buildingID AND ObjectType = 'Building')
    BEGIN
		SELECT 0
	END
	ELSE IF EXISTS(SELECT * FROM RepairAndUpgrade WHERE ObjectID = @buildingID AND ObjectType = 'Building')
	BEGIN
		SELECT 0
	END
	ELSE
	BEGIN
		SELECT 1
	END
END

GO
