CREATE TABLE [dbo].[PostedManagementFeeRule]
(
[PostedManagementFeeRuleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ManagementFeeRuleID] [uniqueidentifier] NOT NULL,
[PostedManagementFeeID] [uniqueidentifier] NOT NULL,
[ObjectBalance] [money] NULL,
[ChargedAmount] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PostedManagementFeeRule] ADD CONSTRAINT [PK_PostedManagementFeeRule] PRIMARY KEY CLUSTERED  ([PostedManagementFeeRuleID], [AccountID]) ON [PRIMARY]
GO
