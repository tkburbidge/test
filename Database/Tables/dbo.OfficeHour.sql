CREATE TABLE [dbo].[OfficeHour]
(
[OfficeHourID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Day] [int] NOT NULL,
[Start] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[End] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OfficeHour] ADD CONSTRAINT [PK_OfficeOur] PRIMARY KEY CLUSTERED  ([OfficeHourID], [AccountID]) ON [PRIMARY]
GO
