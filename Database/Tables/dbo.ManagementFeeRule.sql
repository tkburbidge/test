CREATE TABLE [dbo].[ManagementFeeRule]
(
[ManagementFeeRuleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ManagementFeeID] [uniqueidentifier] NOT NULL,
[RuleType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CalculationType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CalculationValue] [decimal] (9, 3) NOT NULL,
[CalculationBasedOnAccountType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CalculationBasedOnAccountID] [uniqueidentifier] NULL,
[Basis] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AppliesToThreshold] [bit] NOT NULL,
[IsArchived] [bit] NOT NULL,
[OrderBy] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ManagementFeeRule] ADD CONSTRAINT [PK_ManagementFeeRule] PRIMARY KEY CLUSTERED  ([ManagementFeeRuleID], [AccountID]) ON [PRIMARY]
GO
