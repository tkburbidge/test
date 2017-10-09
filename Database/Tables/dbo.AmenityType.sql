CREATE TABLE [dbo].[AmenityType]
(
[AmenityTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DefaultGLAccountID] [uniqueidentifier] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AmenityType] ADD CONSTRAINT [PK_AmenityType] PRIMARY KEY CLUSTERED  ([AmenityTypeID], [AccountID]) ON [PRIMARY]
GO
