SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: July 17, 2015
-- Description:	Gets all person id's associated with the phone number
-- =============================================
CREATE PROCEDURE [dbo].[GetPersonIDsByPhoneNumber] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyID uniqueidentifier,
	@phone nvarchar(15) 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		per.PersonID
	FROM Person per
		INNER JOIN PersonType pt on pt.PersonID = per.PersonID
		INNER JOIN PersonTypeProperty ptp on ptp.PersonTypeID = pt.PersonTypeID
	WHERE per.AccountID = @accountID
		AND ptp.PropertyID = @propertyID
	  AND (RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone1),10) = @phone
		OR RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone2),10) = @phone
		OR RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone3),10) = @phone)
	ORDER BY pt.[Type] DESC
	
	
END
GO
