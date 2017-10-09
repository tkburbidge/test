CREATE TABLE [dbo].[LeaseTerm]
(
[LeaseTermID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NULL,
[EndDate] [date] NULL,
[IsFixed] [bit] NOT NULL,
[Months] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LeaseTerm] ADD CONSTRAINT [PK_LeaseTerm] PRIMARY KEY CLUSTERED  ([LeaseTermID], [AccountID]) ON [PRIMARY]
GO
