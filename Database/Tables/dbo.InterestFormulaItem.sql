CREATE TABLE [dbo].[InterestFormulaItem]
(
[InterestFormulaItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InterestFormulaID] [uniqueidentifier] NOT NULL,
[CompoundType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TimeFrameType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NULL,
[EndDate] [date] NULL,
[Term] [int] NULL,
[Percentage] [decimal] (4, 2) NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InterestFormulaItem] ADD CONSTRAINT [PK_InterestFormulaItem] PRIMARY KEY CLUSTERED  ([InterestFormulaItemID], [AccountID]) ON [PRIMARY]
GO
