CREATE TABLE [dbo].[CustomRequiredField]
(
[CustomRequiredFieldID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Action] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PropertyName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomRequiredField] ADD CONSTRAINT [PK_CustomRequiredField] PRIMARY KEY CLUSTERED  ([CustomRequiredFieldID], [AccountID]) ON [PRIMARY]
GO
