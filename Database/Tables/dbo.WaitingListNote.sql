CREATE TABLE [dbo].[WaitingListNote]
(
[WaitingListNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WaitingListID] [uniqueidentifier] NOT NULL,
[PersonNoteID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitingListNote] ADD CONSTRAINT [PK_WaitingListNote] PRIMARY KEY CLUSTERED  ([WaitingListNoteID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitingListNote] WITH NOCHECK ADD CONSTRAINT [FK_WaitingListNote_WaitingList] FOREIGN KEY ([WaitingListID], [AccountID]) REFERENCES [dbo].[WaitingList] ([WaitingListID], [AccountID])
GO
ALTER TABLE [dbo].[WaitingListNote] NOCHECK CONSTRAINT [FK_WaitingListNote_WaitingList]
GO
