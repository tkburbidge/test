CREATE TABLE [dbo].[CssSetting]
(
[CssSettingID] [uniqueidentifier] NOT NULL,
[CssSelector] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Style] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CssCategoryID] [uniqueidentifier] NOT NULL,
[OrderBy] [int] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DefaultValue] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CssSetting] ADD CONSTRAINT [PK__CssSetti__FF8AA0971ED50383] PRIMARY KEY CLUSTERED  ([CssSettingID]) ON [PRIMARY]
GO
