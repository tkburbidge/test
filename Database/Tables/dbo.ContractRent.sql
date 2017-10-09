CREATE TABLE [dbo].[ContractRent]
(
[ContractRentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateChanged] [date] NOT NULL,
[Amount] [int] NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL,
[GrossRentChangeID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ContractRent] ADD CONSTRAINT [PK_ContractRent] PRIMARY KEY CLUSTERED  ([ContractRentID], [AccountID]) ON [PRIMARY]
GO
