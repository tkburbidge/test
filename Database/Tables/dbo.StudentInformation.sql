CREATE TABLE [dbo].[StudentInformation]
(
[StudentInformationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[School] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Class] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StudentIDNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GuarantorPersonID] [uniqueidentifier] NULL,
[PermanentAddressID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[StudentInformation] ADD CONSTRAINT [PK_StudentInformation] PRIMARY KEY CLUSTERED  ([StudentInformationID], [AccountID]) ON [PRIMARY]
GO
