CREATE TABLE [dbo].[LateFeePostingDate]
(
[LateFeePostingDateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LateFeePostingDate] ADD CONSTRAINT [PK_LateFeePostingDate] PRIMARY KEY CLUSTERED  ([LateFeePostingDateID], [AccountID]) ON [PRIMARY]
GO
