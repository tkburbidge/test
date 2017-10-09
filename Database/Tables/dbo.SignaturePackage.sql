CREATE TABLE [dbo].[SignaturePackage]
(
[SignaturePackageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CounterSigner] [int] NOT NULL,
[LastModifiedByPersonID] [uniqueidentifier] NOT NULL,
[LastModifiedDate] [datetime] NOT NULL,
[EmailTemplateID] [uniqueidentifier] NOT NULL,
[SetLeaseSignedDate] [bit] NOT NULL,
[PushToResidentPortal] [bit] NOT NULL,
[PropertyOrGroupID] [uniqueidentifier] NOT NULL,
[EnableExpire] [bit] NOT NULL,
[ExpireAfterDays] [int] NULL,
[ExpireWarnDays] [int] NULL,
[EnableReminders] [bit] NOT NULL,
[ReminderDelayDays] [int] NULL,
[ReminderFrequencyDays] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SignaturePackage] ADD CONSTRAINT [PK_SignaturePackage] PRIMARY KEY CLUSTERED  ([SignaturePackageID], [AccountID]) ON [PRIMARY]
GO
