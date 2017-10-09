CREATE TABLE [dbo].[Asset]
(
[AssetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Status] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateDivested] [date] NULL,
[Type] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EndDate] [date] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Asset] ADD CONSTRAINT [PK_Asset] PRIMARY KEY CLUSTERED  ([AssetID], [AccountID]) ON [PRIMARY]
GO
