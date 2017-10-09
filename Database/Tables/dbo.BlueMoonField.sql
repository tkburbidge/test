CREATE TABLE [dbo].[BlueMoonField]
(
[BlueMoonFieldID] [bigint] NOT NULL,
[Name] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayableName] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Group] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MergeField] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BlueMoonField] ADD CONSTRAINT [PK_BlueMoonField] PRIMARY KEY CLUSTERED  ([BlueMoonFieldID]) ON [PRIMARY]
GO
