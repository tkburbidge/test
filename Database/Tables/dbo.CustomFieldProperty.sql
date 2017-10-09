CREATE TABLE [dbo].[CustomFieldProperty]
(
[CustomFieldID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomFieldProperty] ADD CONSTRAINT [PK_CustomFieldProperty] PRIMARY KEY CLUSTERED  ([CustomFieldID], [PropertyID], [AccountID]) ON [PRIMARY]
GO
