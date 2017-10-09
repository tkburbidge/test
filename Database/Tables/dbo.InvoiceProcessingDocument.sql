CREATE TABLE [dbo].[InvoiceProcessingDocument]
(
[InvoiceProcessingDocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InvoiceProcessingBatchID] [uniqueidentifier] NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL,
[InvoiceID] [uniqueidentifier] NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
