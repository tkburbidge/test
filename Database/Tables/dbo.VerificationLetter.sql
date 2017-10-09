CREATE TABLE [dbo].[VerificationLetter]
(
[VerificationLetterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[FormLetterID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CreatedDate] [datetime] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[DocumentID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
