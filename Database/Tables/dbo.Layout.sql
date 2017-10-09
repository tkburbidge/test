CREATE TABLE [dbo].[Layout]
(
[AccountID] [bigint] NOT NULL,
[LayoutID] [uniqueidentifier] NOT NULL,
[PersonType] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Layout] ADD CONSTRAINT [PK_Layout] PRIMARY KEY CLUSTERED  ([LayoutID], [AccountID]) ON [PRIMARY]
GO
