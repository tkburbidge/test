CREATE TABLE [dbo].[PermissionToEnter]
(
[PermissionToEnterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[GrantingPersonID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (300) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Purpose] [nvarchar] (300) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PermissionToEnter] ADD CONSTRAINT [PK_PermissionToEnter] PRIMARY KEY CLUSTERED  ([PermissionToEnterID], [AccountID]) ON [PRIMARY]
GO
