CREATE TABLE [dbo].[ProcessorPaymentForm]
(
[ProcessorPaymentFormID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[HtmlForm] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExpirationDate] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProcessorPaymentForm] ADD CONSTRAINT [PK_ProcessorPaymentForm] PRIMARY KEY CLUSTERED  ([ProcessorPaymentFormID], [AccountID]) ON [PRIMARY]
GO
