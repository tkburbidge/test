CREATE TABLE [dbo].[SearchAllTiming]
(
[ID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Query] [varchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartTime] [datetime2] NOT NULL,
[EndTime] [datetime2] NOT NULL,
[Term] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SearchAllTiming] ADD CONSTRAINT [PK_SearchAllTiming] PRIMARY KEY CLUSTERED  ([ID], [AccountID]) ON [PRIMARY]
GO
