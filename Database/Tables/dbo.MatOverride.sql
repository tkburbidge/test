CREATE TABLE [dbo].[MatOverride]
(
[MatOverrideID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableSubmissionID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Field] [int] NOT NULL,
[StringValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NumberValue] [int] NULL,
[DateValue] [date] NULL,
[DateCreated] [datetime] NOT NULL,
[MatSection] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[MatOverride] ADD CONSTRAINT [PK__MatOverr__2BBB262CE793A36F] PRIMARY KEY CLUSTERED  ([MatOverrideID], [AccountID]) ON [PRIMARY]
GO
