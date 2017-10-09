SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 30, 2012
-- Description:	Calls GetObjectBalance for just one propertyID.
-- =============================================
CREATE FUNCTION [dbo].[GetObjectBalance2] 
(
	@startDate datetime, 
	@endDate datetime,
	@objectID uniqueidentifier,
	@lateFee bit,
	@propertyID uniqueidentifier
)
RETURNS @BalanceTable TABLE
(
	ObjectID			uniqueidentifier			NOT NULL,
	Balance				money						NOT NULL
)
AS

BEGIN
	DECLARE @propertyIDs GuidCollection;

	INSERT @propertyIDs VALUES (@propertyID)
	
	INSERT INTO @BalanceTable
		SELECT * FROM GetObjectBalance(@startDate, @endDate, @objectID, @lateFee, @propertyIDs)
		
	RETURN
END
GO
