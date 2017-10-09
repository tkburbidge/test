CREATE TABLE [dbo].[AssetValue]
(
[AssetValueID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AssetID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[CashValue] [money] NOT NULL,
[AnnualInterestRate] [decimal] (18, 4) NOT NULL,
[AnnualIncome] [money] NOT NULL,
[DateVerified] [date] NULL,
[VerifiedByPersonID] [uniqueidentifier] NULL,
[VerificationSources] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CurrentValue] [money] NOT NULL,
[HUDAnnualIncome] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AssetValue] ADD CONSTRAINT [PK_AssetValue] PRIMARY KEY CLUSTERED  ([AssetValueID], [AccountID]) ON [PRIMARY]
GO
