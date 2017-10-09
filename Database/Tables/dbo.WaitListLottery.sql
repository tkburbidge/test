CREATE TABLE [dbo].[WaitListLottery]
(
[WaitListLotteryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WaitListID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListLottery] ADD CONSTRAINT [PK_WaitListLottery] PRIMARY KEY CLUSTERED  ([WaitListLotteryID], [AccountID]) ON [PRIMARY]
GO
