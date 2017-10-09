SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 21, 2012
-- Description:	Gets the age of a person
-- =============================================
CREATE FUNCTION [dbo].[GetPersonAge] 
(
	-- Add the parameters for the function here
	@personID uniqueidentifier, 
	@date date
)
RETURNS 
@Age TABLE 
(
	-- Add the column definitions for the TABLE variable here
	PersonID uniqueidentifier, 
	Age int
)
AS

BEGIN
	-- Fill the table variable with the rows for your result set
	DECLARE @birthday date
	DECLARE @birthdayOfYear int
	DECLARE @thisDayOfYear int
	DECLARE @currentAge int
	
	INSERT @Age VALUES (@personID, 0)
	IF (@date IS NULL)
	BEGIN
		SET @date = GETDATE()
	END
	
	SET @birthday = (SELECT Birthdate
						FROM Person
						WHERE PersonID = @personID)
	IF (@birthday IS NULL)
	BEGIN
		UPDATE @Age SET Age = 0
	END
	ELSE
	BEGIN
		SET @currentAge = DATEDIFF(YEAR, @birthday, @date)
		SET @birthdayOfYear = DATEPART(DayOfYear, @birthday)
		SET @thisDayOfYear = DATEPART(DayOfYear, @date)
		IF (@thisDayOfYear < @birthdayOfYear)
		BEGIN
			SET @currentAge = @currentAge - 1
		END
		
		UPDATE @Age SET Age = @currentAge
	END
	
	RETURN 
END
GO
