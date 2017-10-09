CREATE TABLE [dbo].[Form]
(
[FormID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Form] ADD CONSTRAINT [PK_Form] PRIMARY KEY CLUSTERED  ([FormID]) ON [PRIMARY]
GO
