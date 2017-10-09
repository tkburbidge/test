SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 26, 2013
-- Description:	Adds a UnitType MarketRent record and all associated Unit records
-- =============================================
CREATE PROCEDURE [dbo].[AddUnitTypeUnitMarketRent] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@unitTypeID uniqueidentifier = null,
	@dateChanged date = null,
	@amount money = 0,
	@notes nvarchar(500) = null,
	@updateUnitMarketRents bit = 1,
	@updateUnitType bit = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	INSERT MarketRent (MarketRentID, AccountID, ObjectID, DateChanged, Amount, Notes, ObjectType, DateCreated)
			 VALUES (NEWID(), @accountID, @unitTypeID, @dateChanged, @amount, @notes, 'UnitType', GETUTCDATE())
	
	IF @updateUnitMarketRents = 1
	BEGIN
		INSERT MarketRent (MarketRentID, AccountID, ObjectID, DateChanged, Amount, Notes, ObjectType, DateCreated)
			SELECT NEWID(), @accountID, u.UnitID, @dateChanged, @amount, @notes, 'Unit', GETUTCDATE()
				FROM Unit u
				WHERE u.UnitTypeID = @unitTypeID
	END
	
	IF @updateUnitType = 1
	BEGIN
		UPDATE UnitType SET MarketRent = @amount WHERE UnitTypeID = @unitTypeID
	END
END

GO
