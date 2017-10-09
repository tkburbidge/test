CREATE TABLE [dbo].[GrossRentChangeCertification]
(
[GrossRentChangeID] [uniqueidentifier] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GrossRentChangeCertification] ADD CONSTRAINT [PK_GrossRentChangeCertification] PRIMARY KEY CLUSTERED  ([GrossRentChangeID], [CertificationID]) ON [PRIMARY]
GO
