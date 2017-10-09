CREATE TABLE [dbo].[Project]
(
[ProjectID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Label] [nvarchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[ProjectManagerPersonID] [uniqueidentifier] NOT NULL,
[StatusPickListItemID] [uniqueidentifier] NOT NULL,
[Budget] [money] NOT NULL,
[ShowLabelOnReports] [bit] NOT NULL CONSTRAINT [DF__Project__ShowLab__64D7DFA6] DEFAULT ((1)),
[IsCompleted] [bit] NOT NULL,
[Number] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Project] ADD CONSTRAINT [PK_Project] PRIMARY KEY CLUSTERED  ([ProjectID], [AccountID]) ON [PRIMARY]
GO
