CREATE TABLE [dbo].[BudgetNote]
(
[BudgetNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Note] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AltObjectID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetNote] ADD CONSTRAINT [PK_BudgetNote] PRIMARY KEY CLUSTERED  ([BudgetNoteID], [AccountID]) ON [PRIMARY]
GO
