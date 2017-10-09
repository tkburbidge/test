CREATE TABLE [dbo].[CustomFieldValue]
(
[CustomFieldValueID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CustomFieldID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[Value] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomFieldValue] ADD CONSTRAINT [PK_CustomFieldValue] PRIMARY KEY CLUSTERED  ([CustomFieldValueID], [AccountID]) ON [PRIMARY]
GO
