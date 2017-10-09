CREATE TABLE [dbo].[AffordableSubmission]
(
[AffordableSubmissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableProgramID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [datetime] NULL,
[EndDate] [datetime] NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NOT NULL,
[DateSubmitted] [datetime] NULL,
[SubmittedByPersonID] [uniqueidentifier] NULL,
[TIN] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[IsHUD] [bit] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NULL,
[VoucherID] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OADefinedData] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SubmittedData] [varbinary] (max) NULL,
[HUDSubmissionType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HapSignedDate] [date] NULL,
[Voucher52670PrintedDate] [datetime] NULL,
[Voucher52670PrintedByPersonID] [uniqueidentifier] NULL,
[DateArchived] [datetime] NULL,
[CorrectedByID] [uniqueidentifier] NULL,
[TotalRequestAmount] [int] NULL,
[TRACSVoucherSenderName] [nvarchar] (45) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TRACSVoucherSenderTitle] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TRACSVoucherSenderPhoneNumber] [nvarchar] (16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaidAmount] [money] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableSubmission] ADD CONSTRAINT [PK_AffordableSubmission] PRIMARY KEY CLUSTERED  ([AffordableSubmissionID], [AccountID]) ON [PRIMARY]
GO
