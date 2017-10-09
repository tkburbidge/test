SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 2/1/2013
-- Description:	Delete JournalEntryTemplates related to a recurringitem
-- =============================================
CREATE PROCEDURE [dbo].[DeleteJournalEntryTemplates] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@recurringItemID uniqueidentifier
AS
BEGIN
	delete from dbo.JournalEntryTemplate 
	where AccountID = @accountID and
	RecurringItemID = @recurringItemID
END
GO
