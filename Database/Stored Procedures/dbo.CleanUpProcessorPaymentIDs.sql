SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[CleanUpProcessorPaymentIDs]	
AS
BEGIN
	CREATE TABLE #PaymentIDs ( PaymentID uniqueidentifier )

	INSERT INTO #PaymentIDs	
		SELECT PaymentID
		FROM ProcessorPayment
		WHERE ProcessorTransactionID LIKE '%-DEP'
	
	UPDATE Payment SET ReferenceNumber = REPLACE(ReferenceNumber, '-DEP', '') WHERE PaymentID IN (SELECT PaymentID FROM #PaymentIDs)
	UPDATE ProcessorPayment SET ProcessorTransactionID = REPLACE(ProcessorTransactionID, '-DEP', '') WHERE PaymentID IN (SELECT PaymentID FROM #PaymentIDs)
END
GO
