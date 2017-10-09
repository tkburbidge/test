SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[DeleteSurvey] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@surveyID uniqueidentifier
AS
BEGIN
	IF (
		(SELECT COUNT(*) FROM  SurveyResponse WHERE SurveyID = @surveyID and AccountID = @accountID)
		= 0)
	BEGIN
		DELETE  PossibleSurveyAnswer FROM PossibleSurveyAnswer psa
		join SurveyQuestion sq on psa.SurveyQuestionID = sq.SurveyQuestionID
		join survey s on sq.SurveyID = @surveyID		
		WHERE psa.AccountID = @accountID and  s.SurveyID = @surveyID
		DELETE SurveyQuestion FROM SurveyQuestion sq
		join survey s on sq.SurveyID = @surveyID
		WHERE sq.AccountID = @accountID and  sq.SurveyID = @surveyID
		DELETE SurveyProperty from SurveyProperty  sp
		WHERE sp.AccountID = @accountID and  sp.SurveyID = @SurveyID
		DELETE  Survey WHERE AccountID = @accountID and  SurveyID = @SurveyID
		RETURN 1
	END
	ELSE
	BEGIN
		RETURN 0
	END
END
GO
