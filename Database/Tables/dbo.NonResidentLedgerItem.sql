CREATE TABLE [dbo].[NonResidentLedgerItem]
(
[NonResidentLedgerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[LedgerItemID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[DateCreated] [datetime] NOT NULL CONSTRAINT [DF_NonResidentLedgerItem_DateCreated] DEFAULT (getdate()),
[TaxRateGroupID] [uniqueidentifier] NULL,
[PostingDay] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NonResidentLedgerItem] ADD CONSTRAINT [PK_NonResidentLedgerItem] PRIMARY KEY CLUSTERED  ([NonResidentLedgerItemID], [AccountID]) ON [PRIMARY]
GO
