CREATE TABLE [dbo].[AffordableProgramTable]
(
[AffordableProgramTableID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ParentAffordableProgramTableID] [uniqueidentifier] NULL,
[EffectiveDate] [date] NOT NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AffordableProgramTableGroupID] [uniqueidentifier] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramTable] ADD CONSTRAINT [PK_AffordableProgramTable] PRIMARY KEY CLUSTERED  ([AffordableProgramTableID], [AccountID]) ON [PRIMARY]
GO
