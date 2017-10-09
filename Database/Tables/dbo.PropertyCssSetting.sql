CREATE TABLE [dbo].[PropertyCssSetting]
(
[PropertyCssSettingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CssSettingID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Value] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DocumentID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyCssSetting] ADD CONSTRAINT [PK_PropertyCssSetting] PRIMARY KEY CLUSTERED  ([PropertyCssSettingID], [AccountID]) ON [PRIMARY]
GO
