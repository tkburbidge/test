CREATE TABLE [dbo].[Batch]
(
[BatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyAccountingPeriodID] [uniqueidentifier] NOT NULL,
[BankTransactionID] [uniqueidentifier] NULL,
[Number] [int] NOT NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NOT NULL,
[IsOpen] [bit] NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IntegrationPartnerID] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Batch] ADD CONSTRAINT [PK_Batch] PRIMARY KEY CLUSTERED  ([BatchID], [AccountID]) ON [PRIMARY]
GO
