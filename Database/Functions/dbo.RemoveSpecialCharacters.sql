SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: November 7, 2016
-- Description:	Removes all non-numeric characters from a string
-- =============================================
CREATE Function [dbo].[RemoveSpecialCharacters](@text VARCHAR(1000))
RETURNS VARCHAR(1000)
AS
BEGIN
    WHILE PATINDEX('%[^a-Z0-9]%', @text) > 0
    BEGIN
        SET @text = STUFF(@text, PATINDEX('%[^a-Z0-9]%', @text), 1, '')
    END
    RETURN @text
END

GO
