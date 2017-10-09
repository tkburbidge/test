CREATE TABLE [dbo].[ApplicantTypeFormLetter]
(
[ApplicantTypeFormLetterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ApplicantTypeID] [uniqueidentifier] NOT NULL,
[FormLetterID] [uniqueidentifier] NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantTypeFormLetter] ADD CONSTRAINT [PK_ApplicantTypeFormLetter] PRIMARY KEY CLUSTERED  ([ApplicantTypeFormLetterID], [AccountID]) ON [PRIMARY]
GO
