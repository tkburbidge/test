CREATE TYPE [dbo].[EmailRecipientDeliveryStatusCollection] AS TABLE
(
[EmailRecipientID] [uniqueidentifier] NULL,
[EmailStatus] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EmailErrorMessage] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TextStatus] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TextErrorMessage] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
