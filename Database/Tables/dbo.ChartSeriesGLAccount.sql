CREATE TABLE [dbo].[ChartSeriesGLAccount]
(
[ChartSeriesGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ChartSeriesID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChartSeriesGLAccount] ADD CONSTRAINT [PK_ChartSeriesGLAccount] PRIMARY KEY CLUSTERED  ([ChartSeriesGLAccountID], [AccountID]) ON [PRIMARY]
GO
