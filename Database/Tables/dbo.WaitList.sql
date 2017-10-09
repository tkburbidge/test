CREATE TABLE [dbo].[WaitList]
(
[WaitListID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EnableLottery] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitList] ADD CONSTRAINT [PK_WaitList] PRIMARY KEY CLUSTERED  ([WaitListID], [AccountID]) ON [PRIMARY]
GO
