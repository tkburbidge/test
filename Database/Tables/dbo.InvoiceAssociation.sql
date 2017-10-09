CREATE TABLE [dbo].[InvoiceAssociation]
(
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[InvoiceID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceAssociation] ADD CONSTRAINT [PK_InvoiceAssociation] PRIMARY KEY CLUSTERED  ([ObjectID], [AccountID], [InvoiceID]) ON [PRIMARY]
GO
