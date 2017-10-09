CREATE TABLE [dbo].[ProspectRoommate]
(
[ProspectRoommateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ProspectID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectRoommate] ADD CONSTRAINT [PK_ProspectRoommate] PRIMARY KEY CLUSTERED  ([ProspectRoommateID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectRoommate] WITH NOCHECK ADD CONSTRAINT [FK_ProspectRoommate_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[ProspectRoommate] WITH NOCHECK ADD CONSTRAINT [FK_ProspectRoommate_Prospect] FOREIGN KEY ([ProspectID], [AccountID]) REFERENCES [dbo].[Prospect] ([ProspectID], [AccountID])
GO
ALTER TABLE [dbo].[ProspectRoommate] NOCHECK CONSTRAINT [FK_ProspectRoommate_Person]
GO
ALTER TABLE [dbo].[ProspectRoommate] NOCHECK CONSTRAINT [FK_ProspectRoommate_Prospect]
GO
