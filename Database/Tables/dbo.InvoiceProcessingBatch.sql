CREATE TABLE [dbo].[InvoiceProcessingBatch]
(
[InvoiceProcessingBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[BatchDocumentID] [uniqueidentifier] NOT NULL,
[IsCompleted] [bit] NOT NULL
) ON [PRIMARY]
GO
