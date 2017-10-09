CREATE TABLE [dbo].[InterestFormula]
(
[InterestFormulaID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FirstMonthProrate] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastMonthProrate] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InterestFormula] ADD CONSTRAINT [PK_InterestFormula] PRIMARY KEY CLUSTERED  ([InterestFormulaID], [AccountID]) ON [PRIMARY]
GO
