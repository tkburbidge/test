CREATE TABLE [dbo].[Ad]
(
[AdID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Location] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [datetime] NULL,
[EndDate] [datetime] NULL,
[Html] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Url] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Weight] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Ad] ADD CONSTRAINT [PK_Ad] PRIMARY KEY CLUSTERED  ([AdID]) ON [PRIMARY]
GO
