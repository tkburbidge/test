CREATE TABLE [dbo].[AccessItem]
(
[AccessItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AccessItemPickListItemID] [uniqueidentifier] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[Number] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccessItem] ADD CONSTRAINT [PK_AccessItem] PRIMARY KEY CLUSTERED  ([AccessItemID], [AccountID]) ON [PRIMARY]
GO
