CREATE TABLE [dbo].[FormInformation]
(
[FormInformationID] [int] NOT NULL,
[FormID] [int] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Key] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Year] [int] NOT NULL,
[Value1] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value3] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormInformation] ADD CONSTRAINT [PK_FormInformation] PRIMARY KEY CLUSTERED  ([FormInformationID]) ON [PRIMARY]
GO
