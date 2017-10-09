CREATE TABLE [dbo].[WaitListStatus]
(
[WaitListStatusID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WaitListID] [uniqueidentifier] NOT NULL,
[Status] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Date] [date] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PersonID] [uniqueidentifier] NULL,
[ReasonPickListItemID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListStatus] ADD CONSTRAINT [PK_WaitListStatus] PRIMARY KEY CLUSTERED  ([WaitListStatusID], [AccountID]) ON [PRIMARY]
GO
