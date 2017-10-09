CREATE TABLE [dbo].[CustomFieldOption]
(
[CustomFieldOptionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CustomFieldID] [uniqueidentifier] NOT NULL,
[Value] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomFieldOption] ADD CONSTRAINT [PK_CustomFieldOption] PRIMARY KEY CLUSTERED  ([CustomFieldOptionID], [AccountID]) ON [PRIMARY]
GO
