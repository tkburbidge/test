CREATE TABLE [dbo].[WaitListPerson]
(
[WaitListPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WaitListID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateAdded] [datetime] NOT NULL,
[AddedByPersonID] [uniqueidentifier] NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IncomeLevel] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RemovalDate] [datetime] NULL,
[RemovalNotes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RemovedByPersonID] [uniqueidentifier] NULL,
[DateMatched] [datetime] NULL,
[MatchedUnitID] [uniqueidentifier] NULL,
[RemovalReasonPickListItemID] [uniqueidentifier] NULL,
[PassOverPickListItemID] [uniqueidentifier] NULL,
[LotteryReferenceNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PassOverPersonID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListPerson] ADD CONSTRAINT [PK_WaitListPerson] PRIMARY KEY CLUSTERED  ([WaitListPersonID], [AccountID]) ON [PRIMARY]
GO
