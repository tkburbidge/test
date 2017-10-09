CREATE TABLE [dbo].[WaitingList]
(
[WaitingListID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[AddedByPersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NOT NULL,
[DateNeeded] [date] NULL,
[DateRemoved] [date] NULL,
[DateSatisfied] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitingList] ADD CONSTRAINT [PK_WaitingList] PRIMARY KEY CLUSTERED  ([WaitingListID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitingList] WITH NOCHECK ADD CONSTRAINT [FK_WaitingList_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[WaitingList] NOCHECK CONSTRAINT [FK_WaitingList_Person]
GO
