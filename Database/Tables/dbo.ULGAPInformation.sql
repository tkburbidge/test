CREATE TABLE [dbo].[ULGAPInformation]
(
[ULGAPInformationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[AccountingPeriodID] [uniqueidentifier] NOT NULL,
[Late] [bit] NOT NULL,
[NSF] [tinyint] NULL,
[DelinquentReason] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DelinquentReasonPersonID] [uniqueidentifier] NULL,
[PrepaidReason] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PrepaidReasonPersonID] [uniqueidentifier] NULL,
[DoNotAssessLateFees] [bit] NULL,
[NetPeriodChange] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ULGAPInformation] ADD CONSTRAINT [PK_ULGAPInformation] PRIMARY KEY CLUSTERED  ([ULGAPInformationID], [AccountID]) ON [PRIMARY]
GO
