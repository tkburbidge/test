CREATE TABLE [dbo].[QuoteLineItem]
(
[QuoteLineItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[QuoteID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[Length] [int] NULL,
[CanEditAmount] [bit] NOT NULL,
[CanEditLength] [bit] NOT NULL,
[IsRequired] [bit] NOT NULL,
[IsSelected] [bit] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Origin] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[QuoteLineItem] ADD CONSTRAINT [PK_QuoteLineItem] PRIMARY KEY CLUSTERED  ([QuoteLineItemID], [AccountID]) ON [PRIMARY]
GO
