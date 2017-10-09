CREATE TABLE [dbo].[AffordableProgramTableRow]
(
[AffordableProgramTableRowID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableProgramTableID] [uniqueidentifier] NOT NULL,
[Percent] [int] NULL,
[Value1] [money] NULL,
[Value2] [money] NULL,
[Value3] [money] NULL,
[Value4] [money] NULL,
[Value5] [money] NULL,
[Value6] [money] NULL,
[Value7] [money] NULL,
[Value8] [money] NULL,
[OrderBy] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramTableRow] ADD CONSTRAINT [PK_AffordableProgramTableRow] PRIMARY KEY CLUSTERED  ([AffordableProgramTableRowID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramTableRow] WITH NOCHECK ADD CONSTRAINT [FK_AffordableProgramTableRow_AffordableProgramTable] FOREIGN KEY ([AffordableProgramTableID], [AccountID]) REFERENCES [dbo].[AffordableProgramTable] ([AffordableProgramTableID], [AccountID])
GO
ALTER TABLE [dbo].[AffordableProgramTableRow] NOCHECK CONSTRAINT [FK_AffordableProgramTableRow_AffordableProgramTable]
GO
