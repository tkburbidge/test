CREATE TABLE [dbo].[CustomField]
(
[CustomFieldID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DataType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GroupName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL,
[IsRequired] [bit] NOT NULL,
[IsArchived] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomField] ADD CONSTRAINT [PK_CustomField] PRIMARY KEY CLUSTERED  ([CustomFieldID], [AccountID]) ON [PRIMARY]
GO
