SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: October 30, 2013
-- Description:	Removes all non-numeric characters from a string
-- =============================================
CREATE Function [dbo].[RemoveNonNumericCharacters](@text VARCHAR(1000))
RETURNS VARCHAR(1000)
AS
BEGIN
    WHILE PATINDEX('%[^0-9]%', @text) > 0
    BEGIN
        SET @text = STUFF(@text, PATINDEX('%[^0-9]%', @text), 1, '')
    END
    RETURN @text
END
GO
