CREATE TABLE [dbo].[DaylightSavingsTime]
(
[DaylightSavingsTimeID] [uniqueidentifier] NOT NULL,
[Year] [int] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DaylightSavingsTime] ADD CONSTRAINT [PK_DaylightSavingsTime] PRIMARY KEY CLUSTERED  ([DaylightSavingsTimeID]) ON [PRIMARY]
GO
