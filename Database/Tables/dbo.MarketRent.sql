CREATE TABLE [dbo].[MarketRent]
(
[MarketRentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[DateChanged] [date] NOT NULL,
[Amount] [money] NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectType] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[MarketRent] ADD CONSTRAINT [PK_MarketRent] PRIMARY KEY CLUSTERED  ([MarketRentID], [AccountID]) ON [PRIMARY]
GO
