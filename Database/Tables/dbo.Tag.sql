CREATE TABLE [dbo].[Tag]
(
[TagID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Active] [bit] NOT NULL,
[TagCategoryID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tag] ADD CONSTRAINT [PK__Tag__657CFA4C1FF4508E] PRIMARY KEY CLUSTERED  ([TagID]) ON [PRIMARY]
GO
