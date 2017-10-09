CREATE TABLE [dbo].[SalaryAdditionalPay]
(
[SalaryAdditionalPayID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SalaryID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NOT NULL,
[Frequency] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SalaryAdditionalPay] ADD CONSTRAINT [PK_SalaryAdditionalPay] PRIMARY KEY CLUSTERED  ([SalaryAdditionalPayID], [AccountID]) ON [PRIMARY]
GO
