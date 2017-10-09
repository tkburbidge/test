CREATE TABLE [dbo].[TurnoverWorksheetEntry]
(
[TurnoverWorksheetEntryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[YearBudgetID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[Month] [int] NOT NULL,
[Value] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TurnoverWorksheetEntry] ADD CONSTRAINT [PK_TurnoverWorksheetEntry] PRIMARY KEY CLUSTERED  ([TurnoverWorksheetEntryID], [AccountID]) ON [PRIMARY]
GO
