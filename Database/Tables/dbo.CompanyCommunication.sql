CREATE TABLE [dbo].[CompanyCommunication]
(
[CompanyCommunicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SenderPersonID] [uniqueidentifier] NOT NULL,
[DeliveryDate] [date] NULL,
[Subject] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Body] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RecurringItemID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CompanyCommunication] ADD CONSTRAINT [PK_CompanyCommunication] PRIMARY KEY CLUSTERED  ([CompanyCommunicationID], [AccountID]) ON [PRIMARY]
GO
