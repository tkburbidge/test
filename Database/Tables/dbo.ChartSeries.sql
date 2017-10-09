CREATE TABLE [dbo].[ChartSeries]
(
[ChartSeriesID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ChartType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Color] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsSystem] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChartSeries] ADD CONSTRAINT [PK_ChartSeries] PRIMARY KEY CLUSTERED  ([ChartSeriesID], [AccountID]) ON [PRIMARY]
GO
