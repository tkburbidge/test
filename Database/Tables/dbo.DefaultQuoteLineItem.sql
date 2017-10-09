CREATE TABLE [dbo].[DefaultQuoteLineItem]
(
[DefaultQuoteLineItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NULL,
[Required] [bit] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsLengthOfLease] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DefaultQuoteLineItem] ADD CONSTRAINT [PK_DefaultQuoteLineItem] PRIMARY KEY CLUSTERED  ([DefaultQuoteLineItemID], [AccountID]) ON [PRIMARY]
GO
