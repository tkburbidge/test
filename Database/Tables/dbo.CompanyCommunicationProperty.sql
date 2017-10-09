CREATE TABLE [dbo].[CompanyCommunicationProperty]
(
[CompanyCommunicationPropertyID] [uniqueidentifier] NOT NULL,
[CompanyCommunicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CompanyCommunicationProperty] ADD CONSTRAINT [PK_CompanyCommunicationProperty_1] PRIMARY KEY CLUSTERED  ([CompanyCommunicationPropertyID], [AccountID]) ON [PRIMARY]
GO
