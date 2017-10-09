SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[CreatePersonShortCodes] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@personIDs guidcollection readonly

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @shortCodeChars varchar(62) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

	WHILE EXISTS (SELECT * FROM Person WHERE AccountID = @accountID AND ShortCode IS NULL AND PersonID IN (SELECT VALUE FROM @personIDs))
	BEGIN
		DECLARE
			@shortCode nvarchar(4),
			@personID uniqueidentifier

		WHILE @shortCode IS NULL OR @shortCode IN (SELECT ShortCode FROM Person)
		BEGIN
			SET @shortCode = (SELECT
								RIGHT( LEFT(@shortCodeChars,ABS(BINARY_CHECKSUM(NEWID())%62) + 1 ),1) + 
								RIGHT( LEFT(@shortCodeChars,ABS(BINARY_CHECKSUM(NEWID())%62) + 1 ),1) +
								RIGHT( LEFT(@shortCodeChars,ABS(BINARY_CHECKSUM(NEWID())%62) + 1 ),1) +
								RIGHT( LEFT(@shortCodeChars,ABS(BINARY_CHECKSUM(NEWID())%62) + 1 ),1))
		END

		SET @personID = (SELECT TOP 1 PersonID FROM Person WHERE AccountID = @accountID AND ShortCode IS NULL AND PersonID IN (SELECT VALUE FROM @personIDs))

		UPDATE Person SET ShortCode = @shortCode WHERE PersonID = @personID
	END
END
GO
