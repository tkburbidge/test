SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[CopyPropertySettings]
	@accountID bigint,
	@copyFromPropertyID uniqueidentifier,
	@copyToPropertyIDs GuidCollection readonly,
	@settingsToCopy StringCollection readonly
AS
BEGIN

	CREATE TABLE #CopyToProperties (
		Sequence int identity,
		PropertyID uniqueidentifier not null)

	INSERT INTO #CopyToProperties
		SELECT ctp.Value 
			FROM @copyToPropertyIDs ctp
				INNER JOIN Property p ON p.PropertyID = ctp.Value
			WHERE p.IsArchived = 0

	DECLARE @propertyCount int = (SELECT COUNT(*) FROM #CopyToProperties)

	CREATE TABLE #SettingsToCopy (
		Setting nvarchar(100) not null)

	INSERT INTO #SettingsToCopy
		SELECT Value 
			FROM @settingsToCopy
	
	CREATE TABLE #CopiedPersonIDs (
		PersonID uniqueidentifier not null)

	
	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.Management')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.ManagementCompanyVendorID	= cfp.ManagementCompanyVendorID,
				ctp.RegionalManagerPersonID		= cfp.RegionalManagerPersonID,
				ctp.ManagerPersonID				= cfp.ManagerPersonID
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID

		--ManagerPersonID and RegionalManagerPersonID are copied to the other properties but we need to make sure those people are
		-- tied to the properties we are copying to so we will save them in this table and check that at the end.
		INSERT INTO #CopiedPersonIDs
			SELECT Property.ManagerPersonID
				FROM Property
				WHERE PropertyID = @copyFromPropertyID
				  AND Property.ManagerPersonID IS NOT NULL
			
			UNION

			SELECT Property.RegionalManagerPersonID
				FROM Property
				WHERE PropertyID = @copyFromPropertyID
				  AND Property.RegionalManagerPersonID IS NOT NULL

					
		--Add a VendorProperty for the properties that weren't tied to the ManagementCompanyVendor
		INSERT VendorProperty (AccountID, BeginningBalance, BeginningBalanceYear, CustomerNumber, PropertyID, TaxRateGroupID, VendorID, VendorPropertyID)
			SELECT @accountID, vpToCopy.BeginningBalance, vpToCopy.BeginningBalanceYear, vpToCopy.CustomerNumber, #ctp.PropertyID, vpToCopy.TaxRateGroupID, vpToCopy.VendorID, NEWID()
				FROM VendorProperty vpToCopy
					INNER JOIN Property cfp ON cfp.ManagementCompanyVendorID = vpToCopy.VendorID AND cfp.PropertyID = vpToCopy.PropertyID
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN VendorProperty existingVp ON existingVp.PropertyID = #ctp.PropertyID AND existingVp.VendorID = cfp.ManagementCompanyVendorID
				WHERE cfp.AccountID = @accountID
					AND cfp.PropertyID = @copyFromPropertyID
					AND existingVp.VendorPropertyID IS NULL

		--Add a Property tax rate group if it is not already tied 
		INSERT PropertyTaxRateGroup (AccountID, IsObsolete, PropertyID, TaxRateGroupID)
			SELECT @accountID, ptrgToCopy.IsObsolete, #ctp.PropertyID, ptrgToCopy.TaxRateGroupID
				FROM PropertyTaxRateGroup ptrgToCopy
					INNER JOIN Property cfp ON cfp.PropertyID = ptrgToCopy.PropertyID
					INNER JOIN VendorProperty cfvp ON cfvp.PropertyID = cfp.PropertyID AND cfvp.VendorID = cfp.ManagementCompanyVendorID
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN PropertyTaxRateGroup existingPtrg ON existingPtrg.PropertyID = #ctp.PropertyID AND existingPtrg.TaxRateGroupID = ptrgToCopy.TaxRateGroupID
				WHERE ptrgToCopy.AccountID = @accountID
					AND ptrgToCopy.PropertyID = @copyFromPropertyID
					AND ptrgToCopy.TaxRateGroupID = cfvp.TaxRateGroupID
					AND existingPtrg.TaxRateGroupID IS NULL

	END


	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.FiscalYear')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.FiscalYearStartMonth = cfp.FiscalYearStartMonth
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.LateFees')) > 0)
	BEGIN

		UPDATE ctp 
			SET ctp.LateFeeScheduleID			= cfp.LateFeeScheduleID,
				ctp.AssessLateFeesAutomatically	= cfp.AssessLateFeesAutomatically,
				ctp.LateFeeAssessmentIncludePaymentsOnDay = cfp.LateFeeAssessmentIncludePaymentsOnDay,
				ctp.AutomaticLateFeePostingDelay = cfp.AutomaticLateFeePostingDelay,
				ctp.AutomaticLateFeeAssessmentPolicy = cfp.AutomaticLateFeeAssessmentPolicy				
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID

		--Add a PropertyLateFeeSchedule for the properties that weren't tied to it yet.
		INSERT PropertyLateFeeSchedule (AccountID, PropertyLateFeeScheduleID, PropertyID, LateFeeScheduleID)
			SELECT @accountID, NEWID(), #ctp.PropertyID, cfp.LateFeeScheduleID
				FROM Property cfp 
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN PropertyLateFeeSchedule plfs ON #ctp.PropertyID = plfs.PropertyID AND cfp.LateFeeScheduleID = plfs.LateFeeScheduleID
				WHERE cfp.AccountID = @accountID
					AND cfp.PropertyID = @copyFromPropertyID
					AND cfp.LateFeeScheduleID IS NOT NULL
					AND plfs.LateFeeScheduleID IS NULL
		
		--Late Fee Posting Date Exceptions
		DELETE lfpd
		  FROM LateFeePostingDate lfpd
			INNER JOIN #CopyToProperties #ctp ON lfpd.PropertyID = #ctp.PropertyID
		  WHERE lfpd.AccountID = @accountID

		INSERT INTO LateFeePostingDate (LateFeePostingDateID, AccountID, PropertyID, [Date])
			SELECT NEWID(), lfpd.AccountID, #ctp.PropertyID, lfpd.[Date]
			FROM LateFeePostingDate lfpd, #CopyToProperties #ctp
			WHERE lfpd.PropertyID = @copyFromPropertyID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.NsfFees')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.NSFCharge			= cfp.NSFCharge, 
				ctp.NSFCashOnlyLimit	= cfp.NSFCashOnlyLimit,
				ctp.NSFCashOnlyMonths	= cfp.NSFCashOnlyMonths
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END
		
		
	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.Proration')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.ProrationType					 = cfp.ProrationType,
				ctp.RentProrationType				 = cfp.RentProrationType,
				ctp.RoundProrationAmount			 = cfp.RoundProrationAmount,
				ctp.MoveOutProrateChargeDistribution = cfp.MoveOutProrateChargeDistribution
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END
	
	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingGeneral')) > 0)
	BEGIN
		UPDATE ctp 
			SET	ctp.DrivingDirections			 = cfp.DrivingDirections,
				ctp.Latitude	 = cfp.Latitude,
				ctp.Longitude	 = cfp.Longitude,
				ctp.LeaseLength	 = cfp.LeaseLength,
				ctp.LongDescription	 = cfp.LongDescription,
				ctp.ShortDescription	 = cfp.ShortDescription,				
				ctp.AirCon	 = cfp.AirCon
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingTexting')) > 0)
	BEGIN
		UPDATE ctp 
			SET	ctp.MarketingTextResponse			 = cfp.MarketingTextResponse,
				ctp.MarketingCss	 = cfp.MarketingCss
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END


	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingUtilities')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.BroadbandInternet	 = cfp.BroadbandInternet,
				ctp.Cable	 = cfp.Cable,
				ctp.Gas	 = cfp.Gas,
				ctp.Heat	 = cfp.Heat,
				ctp.HotWater	 = cfp.HotWater,
				ctp.Sewer	 = cfp.Sewer,
				ctp.Telephone	 = cfp.Telephone,
				ctp.Trash	 = cfp.Trash,
				ctp.Water	 = cfp.Water,
				ctp.UtilityPortionIncluded	 = cfp.UtilityPortionIncluded
				
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END


	

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingOfficeHours')) > 0)
	BEGIN
		--Delete all current office hours, 
		DELETE ofh
			FROM OfficeHour ofh
				INNER JOIN #CopyToProperties #ctp ON ofh.PropertyID = #ctp.PropertyID
			WHERE ofh.AccountID = @accountID

		INSERT OfficeHour
			SELECT NEWID(), @accountID, #ctp.PropertyID, ofh.[Day], ofh.[Start], ofh.[End] 
			FROM OfficeHour ofh
				INNER JOIN #CopyToProperties #ctp ON 1 = 1
			WHERE ofh.AccountID = @accountID
			  AND ofh.PropertyID = @copyFromPropertyID
			  
	END
	
	
	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingServices')) > 0)
	BEGIN
		--Delete all current office hours, 
		DELETE srv
			FROM [Service] srv
				INNER JOIN #CopyToProperties #ctp ON srv.PropertyID = #ctp.PropertyID
			WHERE srv.AccountID = @accountID

		INSERT [Service]
			SELECT NEWID(), #ctp.PropertyID, @accountID, srv.Nearest, srv.Name, srv.Detail, srv.DistanceTo, srv.Comment
			FROM [Service] srv
				INNER JOIN #CopyToProperties #ctp ON 1 = 1
			WHERE srv.AccountID = @accountID
			  AND srv.PropertyID = @copyFromPropertyID
			  
	END


	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MarketingParking')) > 0)
	BEGIN
		--Delete all current office hours, 
		DELETE park
			FROM Parking park
				INNER JOIN #CopyToProperties #ctp ON park.PropertyID = #ctp.PropertyID
			WHERE park.AccountID = @accountID

		INSERT Parking
			SELECT NEWID(), @accountID, #ctp.PropertyID, park.Assigned, park.AssignedFee, park.SpaceFee, park.Spaces, park.Comment, park.ParkingType 
			FROM Parking park
				INNER JOIN #CopyToProperties #ctp ON 1 = 1
			WHERE park.AccountID = @accountID
			  AND park.PropertyID = @copyFromPropertyID
			  
	END
	

			
			
			
			
			
			
			  
	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.TerminationFees')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.NoticeToVacateDaysRequired		= cfp.NoticeToVacateDaysRequired,
				ctp.InsufficientNoticeFeeType		= cfp.InsufficientNoticeFeeType,
				ctp.InsufficientNoticeFeeAmount		= cfp.InsufficientNoticeFeeAmount,
				ctp.EarlyLeaseTerminationFeeType	= cfp.EarlyLeaseTerminationFeeType,
				ctp.EarlyLeaseTerminationFeeAmount	= cfp.EarlyLeaseTerminationFeeAmount
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MonthToMonthLeases')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.AutoAdjustMonthToMonthLeaseCharges	= cfp.AutoAdjustMonthToMonthLeaseCharges,
				ctp.MTMRentChargesOption				= cfp.MTMRentChargesOption,
				ctp.MTMFeeChargeType					= cfp.MTMFeeChargeType,
				ctp.MTMStopAtSignedRenewal				= cfp.MTMStopAtSignedRenewal,
				ctp.MTMExtendCredits					= cfp.MTMExtendCredits,
				ctp.MTMExtendNonRentCharges				= cfp.MTMExtendNonRentCharges,
				ctp.ProrateExpiringAndRenewalLeases		= cfp.ProrateExpiringAndRenewalLeases,
				ctp.MonthToMonthFee						= cfp.MonthToMonthFee,
				ctp.MonthToMonthFeeType					= cfp.MonthToMonthFeeType
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.GrossPotentialRent')) > 0)
	BEGIN
		UPDATE ctp 


			SET ctp.AutoPostGPRNightly	      = cfp.AutoPostGPRNightly,
				ctp.AutoPostGPRChangePeriod	  = cfp.AutoPostGPRChangePeriod
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.LossGainToLease')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.TrackLossGainToLease = cfp.TrackLossGainToLease
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.Transactions')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.AutoTotalDepositBatches					= cfp.AutoTotalDepositBatches,
				ctp.SpecifyRecurringChargePostingDay		= cfp.SpecifyRecurringChargePostingDay,
				ctp.ProrateMoveOutsOnPostRecurringCharges	= cfp.ProrateMoveOutsOnPostRecurringCharges,
				ctp.PreventClosedPeriodTransactionEdits		= cfp.PreventClosedPeriodTransactionEdits,
				ctp.OnlyAllowPostingTransactionsTodaysDate	= cfp.OnlyAllowPostingTransactionsTodaysDate
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.Prospects')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.AutoLostProspectReasonID = cfp.AutoLostProspectReasonID,
				ctp.MaxProspectInactiveDays	 = cfp.MaxProspectInactiveDays
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.ApplicantsAndResidents')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.AutoApproveScreenedApplicants				= cfp.AutoApproveScreenedApplicants,
				ctp.AutoApproveConditionalScreenedApplicants	= cfp.AutoApproveConditionalScreenedApplicants,
				ctp.DefaultIDNumberType							= cfp.DefaultIDNumberType,
				ctp.DefaultPhoneNumberType						= cfp.DefaultPhoneNumberType,
				ctp.DefaultLeaseTermID							= cfp.DefaultLeaseTermID,
				ctp.NTVDefaultPostMakeReadyWorkOrders			= cfp.NTVDefaultPostMakeReadyWorkOrders,
				ctp.MoveInBackDateDays							= cfp.MoveInBackDateDays,
				ctp.MoveInFutureDateDays						= cfp.MoveInFutureDateDays,
				ctp.MoveOutBackDateDays							= cfp.MoveOutBackDateDays,
				ctp.MoveOutFutureDateDays						= cfp.MoveOutFutureDateDays,
				ctp.AllowUnderEvictionPreleasing        		= cfp.AllowUnderEvictionPreleasing,
				ctp.DefaultCancelApplicationReasonForLeavingPickListItemID        = cfp.DefaultCancelApplicationReasonForLeavingPickListItemID,
				ctp.AutocheckDisableOnlinePayments				= cfp.AutocheckDisableOnlinePayments,
                ctp.AllowRenewingWithoutOffers                  = cfp.AllowRenewingWithoutOffers,
				ctp.RenewalOfferMessage							= cfp.RenewalOfferMessage
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.MoveOutReconciliation')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.DefaultMOROutstandingBalanceAction = cfp.DefaultMOROutstandingBalanceAction,
				ctp.FinalAccountStatementText = cfp.FinalAccountStatementText
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.PurchaseOrders')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.POApprovalRequirement	= cfp.POApprovalRequirement,
				ctp.POApprovalBudgetPercent	= cfp.POApprovalBudgetPercent,
				ctp.POApprovalTotal			= cfp.POApprovalTotal
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.Invoices')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.InvoiceRequiresBatchBeforeApproval = cfp.InvoiceRequiresBatchBeforeApproval
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.EmailServer')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.SMTPServerName		= cfp.SMTPServerName,
				ctp.SmtpUserName		= cfp.SmtpUserName,
				ctp.SmtpPortNumber		= cfp.SmtpPortNumber,
				ctp.SmtpPassword		= cfp.SmtpPassword,
				ctp.SMTPRequiresSSL		= cfp.SMTPRequiresSSL,
				ctp.SMTPEmailsPerHour	= cfp.SMTPEmailsPerHour,
				ctp.EmailProviderType	= cfp.EmailProviderType
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ((SELECT COUNT(*) FROM #SettingsToCopy WHERE Setting IN ('Settings.*', 'Settings.WorkOrders')) > 0)
	BEGIN
		UPDATE ctp 
			SET ctp.NextWorkOrderNumber		= cfp.NextWorkOrderNumber,
				ctp.DefaultWorkOrderNotes	= cfp.DefaultWorkOrderNotes
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ('ResidentPortalSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		UPDATE ctp 
			SET ctp.PortalWelcomePageHtml				= cfp.PortalWelcomePageHtml,
			    ctp.PortalWelcomePageHtmlApplicants		= cfp.PortalWelcomePageHtmlApplicants,
				ctp.PortalWorkOrderAssignedToPersonID	= CASE 
															WHEN woptp.PersonTypePropertyID IS NULL --When the assigned person is not tied to the property we are copying to
															THEN ctp.PortalWorkOrderAssignedToPersonID    --Then we will not update the assigned person
															ELSE cfp.PortalWorkOrderAssignedToPersonID    --Else we will update the assigned person
														  END,
				ctp.PortalWorkOrderCategoryID			= cfp.PortalWorkOrderCategoryID,
				ctp.PortalWorkOrderDaysDue				= cfp.PortalWorkOrderDaysDue,
				ctp.FacebookPageUrl						= cfp.FacebookPageUrl,
				ctp.PortalCss							= cfp.PortalCss,
				ctp.PortalCssUrl						= cfp.PortalCssUrl,
				ctp.WorkOrderMessage					= cfp.WorkOrderMessage,
				ctp.ViewablePortalModules				= cfp.ViewablePortalModules,
				ctp.AllowFormerInPortal					= cfp.AllowFormerInPortal,
				ctp.AllowEvictedInPortal				= cfp.AllowEvictedInPortal,
				ctp.EnableCommunityMembersPortal		= cfp.EnableCommunityMembersPortal,
				ctp.IncludeNonPortalWorkOrders			= cfp.IncludeNonPortalWorkOrders,
				ctp.ResidentPortalAppointmentOptions    = cfp.ResidentPortalAppointmentOptions,
				ctp.PortalWelcomePageHtmlAlwaysShow		= cfp.PortalWelcomePageHtmlAlwaysShow
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
				--Find the "Employee" person type for the assigned work order person of the property we are copying FROM.
				LEFT JOIN PersonType wopt ON wopt.PersonID = cfp.PortalWorkOrderAssignedToPersonID AND wopt.[Type] = 'Employee'
				--See if that employee is tied to the property we are copying TO.
				LEFT JOIN PersonTypeProperty woptp ON woptp.PersonTypeID = wopt.PersonTypeID AND woptp.PropertyID = #ctp.PropertyID AND woptp.HasAccess = 1
			WHERE cfp.AccountID = @accountID
	END

	IF ('PermanentPortalDocuments' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete all current documents, 
		-- this will orphan the actual documents... 
		DELETE d
			FROM Document d
				INNER JOIN #CopyToProperties #ctp ON d.PropertyID = #ctp.PropertyID
			WHERE d.AccountID = @accountID
			  AND d.ObjectType = 'Portal'

		--Copy the documents from the copyFromProperty
		INSERT Document (AccountID, PropertyID, DocumentID, AttachedByPersonID, DateAttached, ContentType, FileType, Name, ObjectID, ObjectType, OrderBy, [Path], ShowInResidentPortal, Size, ThumbnailUri, [Type], Uri, IsExternal)
			SELECT @accountID, #ctp.PropertyID, NEWID(), cfpd.AttachedByPersonID, cfpd.DateAttached, cfpd.ContentType, cfpd.FileType, cfpd.Name, cfpd.ObjectID, cfpd.ObjectType, cfpd.OrderBy, cfpd.[Path], cfpd.ShowInResidentPortal, cfpd.Size, cfpd.ThumbnailUri, cfpd.[Type], cfpd.Uri, cfpd.IsExternal
				FROM Document cfpd
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE cfpd.AccountID = @accountID
				  AND cfpd.PropertyID = @copyFromPropertyID
				  AND cfpd.ObjectType = 'Portal'
	END

	IF ('DefaultQuoteCharges' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete all current quote line items
		DELETE dqli
			FROM DefaultQuoteLineItem dqli
				INNER JOIN #CopyToProperties #ctp ON dqli.PropertyID = #ctp.PropertyID
			WHERE dqli.AccountID = @accountID

		--Copy the default quote line items from the copyFromProperty
		INSERT DefaultQuoteLineItem (AccountID, DefaultQuoteLineItemID, PropertyID, LedgerItemTypeID, Amount, [Description], [Required], IsLengthOfLease, [Type])
			SELECT @accountID, NEWID(), #ctp.PropertyID, dqli.LedgerItemTypeID, dqli.Amount, dqli.[Description], dqli.[Required], dqli.IsLengthOfLease, dqli.[Type]
				FROM DefaultQuoteLineItem dqli
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE dqli.AccountID = @accountID
				  AND dqli.PropertyID = @copyFromPropertyID
	END
	
	IF ('ApplicantPortalSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN

		DECLARE @counter int = 1			
		DECLARE @propertyID uniqueidentifier

		CREATE TABLE #IDMapping ( OriginalID uniqueidentifier, [NewID] uniqueidentifier )

		WHILE (@counter <= @propertyCount)
		BEGIN
			DECLARE @counter2 int = 1
			DECLARE @surveyIDToCopy uniqueidentifier 
			DECLARE @newSurveyID uniqueidentifier = null
			DECLARE @existingSurvey1ID uniqueidentifier = null
			DECLARE @existingSurvey2ID uniqueidentifier = null

			SELECT @propertyID = PropertyID FROM #CopyToProperties WHERE [Sequence] = @counter
			SELECT @existingSurvey1ID = OnlineApplicationSurvey1ID, @existingSurvey2ID = OnlineApplicationSurvey2ID FROM Property WHERE PropertyID = @propertyID
			SELECT @surveyIDToCopy = OnlineApplicationSurvey1ID FROM Property WHERE PropertyID = @copyFromPropertyID
			
			EXEC DeleteSurvey @accountID, @existingSurvey1ID
			EXEC DeleteSurvey @accountID, @existingSurvey2ID

			WHILE (@counter2 < 3) -- Run this twice
			BEGIN
				IF (@surveyIDToCopy IS NOT NULL)
				BEGIN
					TRUNCATE TABLE #IDMapping

					INSERT INTO #IDMapping 
						SELECT SurveyID, NEWID() FROM Survey WHERE SurveyID = @surveyIDToCopy
						UNION
						SELECT SurveyQuestionID, NEWID() FROM SurveyQuestion WHERE SurveyID = @surveyIDToCopy
						UNION
						SELECT PossibleSurveyAnswerID, NEWID() FROM PossibleSurveyAnswer pas INNER JOIN SurveyQuestion sq ON sq.SurveyQuestionID = pas.SurveyQuestionID WHERE sq.SurveyID = @surveyIDToCopy
					
					SELECT @newSurveyID = #id.[NewID] FROM #IDMapping #id WHERE #id.OriginalID = @surveyIDToCopy

					INSERT INTO Survey
						SELECT #id.[NewID], s.AccountID, s.Name, s.Instructions, s.CreatedByPersonID, GetDate(), s.StartDate, s.EndDate, 0, s.LimitationType, s.Published, s.IsSystem, s.SystemType 
						FROM Survey s
							INNER JOIN #IDMapping #id ON #id.OriginalID = s.SurveyID 
						WHERE SurveyID = @surveyIDToCopy

					INSERT INTO SurveyQuestion
						SELECT #qid.[NewID], sq.AccountID, #sid.[NewID], sq.[Type], sq.Question, sq.HelpText, sq.OrderBy, sq.Required, sq.IsDeleted 
						FROM SurveyQuestion sq
							INNER JOIN #IDMapping #qid ON #qid.OriginalID = sq.SurveyQuestionID
							INNER JOIN #IDMapping #sid ON #sid.OriginalID = @surveyIDToCopy
						WHERE sq.SurveyID = @surveyIDToCopy

					INSERT INTO SurveyProperty
						SELECT s.AccountID, #id.[NewID], @propertyID
						FROM Survey s 
						INNER JOIN  #IDMapping #id ON #id.OriginalID = s.SurveyID
						WHERE s.SurveyID = @surveyIDToCopy

					INSERT INTO PossibleSurveyAnswer
						SELECT #psaid.[NewID], psa.AccountID, #qid.[NewID], psa.AnswerText, psa.OrderBy, psa.IsOther, psa.IsDeleted
						FROM PossibleSurveyAnswer psa
							INNER JOIN SurveyQuestion sq ON sq.SurveyQuestionID = psa.SurveyQuestionID
							INNER JOIN #IDMapping #qid ON #qid.OriginalID = sq.SurveyQuestionID
							INNER JOIN #IDMapping #psaid ON #psaid.OriginalID = psa.PossibleSurveyAnswerID
			



		  
				END

				IF (@counter2 = 1)		
				BEGIN			
					UPDATE Property SET OnlineApplicationSurvey1ID = @newSurveyID WHERE PropertyID = @propertyID
					PRINT '@counter2 = 1'
					PRINT @newSurveyID
				END
				ELSE
				BEGIN
					UPDATE Property SET OnlineApplicationSurvey2ID = @newSurveyID WHERE PropertyID = @propertyID
					PRINT '@counter2 = 2'
					PRINT @newSurveyID
				END
				SELECT @surveyIDToCopy = OnlineApplicationSurvey2ID FROM Property WHERE PropertyID = @copyFromPropertyID

				SET @newSurveyID = NULL						
				SET @counter2 = @counter2 + 1
			END

			SET @counter = @counter + 1
		END

		UPDATE ctp 
			SET ctp.PortalDefaultApplicantWelcomeMessage			= cfp.PortalDefaultApplicantWelcomeMessage,
				ctp.AssignedLeasingAgentPersonID					= CASE 
																		WHEN alaptp.PersonTypePropertyID IS NULL --When the assigned leasing agent is not tied to the property we are copying to
																		THEN ctp.AssignedLeasingAgentPersonID    --Then we will not update the leasing agent ID
																		ELSE cfp.AssignedLeasingAgentPersonID    --Else we will update the leasing agent ID
																	  END,
				ctp.ApplicationTermsAndConditions					= cfp.ApplicationTermsAndConditions,
				ctp.ApplicationGuarantorTermsAndConditions			= cfp.ApplicationGuarantorTermsAndConditions,
				ctp.ApplicationSubmittedTitle						= cfp.ApplicationSubmittedTitle,
				ctp.ApplicationSubmittedMessage						= cfp.ApplicationSubmittedMessage,
				ctp.ApplicationVerificationDocumentsInstructions	= cfp.ApplicationVerificationDocumentsInstructions,
				ctp.ApplicationMaxDaysOut							= cfp.ApplicationMaxDaysOut,
				ctp.ApplicationSubmittedScript						= cfp.ApplicationSubmittedScript,
				ctp.GuestCardSubmittedTitle							= cfp.GuestCardSubmittedTitle,
				ctp.GuestCardSubmittedMessage						= cfp.GuestCardSubmittedMessage,
				ctp.GuestCardSubmittedScript						= cfp.GuestCardSubmittedScript,
				ctp.PortalScreeningIntegrationPartnerItemID			= cfp.PortalScreeningIntegrationPartnerItemID,
				ctp.PortalScreeningUsername							= cfp.PortalScreeningUsername,
				ctp.PortalScreeningPassword							= cfp.PortalScreeningPassword,
				ctp.HideOnlineHeader								= cfp.HideOnlineHeader,




				ctp.EnableOnlineGuestcard							= cfp.EnableOnlineGuestcard,
				ctp.EnableOnlineAvailability						= cfp.EnableOnlineAvailability,
				ctp.EnableOnlineApplication							= cfp.EnableOnlineApplication,
				ctp.OnlineAvailabilityUnitTypeLimit					= cfp.OnlineAvailabilityUnitTypeLimit,
				ctp.ImmediatePaymentNotRequiredMessage				= cfp.ImmediatePaymentNotRequiredMessage,
				ctp.ImmediatePaymentRequiredMessage					= cfp.ImmediatePaymentRequiredMessage,
				ctp.HideGenderField									= cfp.HideGenderField,
				ctp.HideCitizenField								= cfp.HideCitizenField,
				ctp.GuarantorThresholdType							= cfp.GuarantorThresholdType,
				ctp.GuarantorThresholdAmount						= cfp.GuarantorThresholdAmount,
				ctp.GuestCardForms									= cfp.GuestCardForms,
				ctp.OnlineAvailabilityUnitUnavailableMessage		= cfp.OnlineAvailabilityUnitUnavailableMessage,
				ctp.MinimumApplicantAge								= cfp.MinimumApplicantAge,
				ctp.ApprovedStatusMarketingName						= cfp.ApprovedStatusMarketingName,
				ctp.ApprovedStatusMessage							= cfp.ApprovedStatusMessage,
				ctp.ConditionallyApprovedStatusMarketingName		= cfp.ConditionallyApprovedStatusMarketingName,
				ctp.ConditionallyApprovedStatusMessage				= cfp.ConditionallyApprovedStatusMarketingName,
				ctp.PendingStatusMarketingName						= cfp.PendingStatusMarketingName,
				ctp.PendingStatusMessage							= cfp.PendingStatusMessage,
				ctp.DeniedStatusMarketingName						= cfp.DeniedStatusMarketingName,
				ctp.DeniedStatusMessage								= cfp.DeniedStatusMessage,
				ctp.SignLeaseMessage								= cfp.SignLeaseMessage,

				ctp.AvailbilityDepositViewState						= cfp.AvailbilityDepositViewState,
                ctp.AvalabilityDepositTextOverride                  = cfp.AvalabilityDepositTextOverride,
				ctp.AvailabilityHideRent							= cfp.AvailabilityHideRent,
				ctp.ApplicationRentableItemsInstructions			= cfp.ApplicationRentableItemsInstructions,
				ctp.AvailabilityUnitTypeSortBy						= cfp.AvailabilityUnitTypeSortBy																
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
				--Find the "Employee" person type for the assigned leasing agent of the property we are copying FROM.
				LEFT JOIN PersonType alapt ON alapt.PersonID = cfp.AssignedLeasingAgentPersonID AND alapt.[Type] = 'Employee'
				--See if that employee is tied to the property we are copying TO.
				LEFT JOIN PersonTypeProperty alaptp ON alaptp.PersonTypeID = alapt.PersonTypeID AND alaptp.PropertyID = #ctp.PropertyID AND alaptp.HasAccess = 1
			WHERE cfp.AccountID = @accountID

	END
	
	IF ('ApplicantTypes' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete all current applicant types, applicant fees, and applicant type form letters
		CREATE TABLE #ApplicantTypesToDelete (
			ApplicantTypeID uniqueidentifier not null)

		INSERT INTO #ApplicantTypesToDelete (ApplicantTypeID)
			SELECT at.ApplicantTypeID 
				FROM ApplicantType at
					INNER JOIN #CopyToProperties #ctp ON at.PropertyID = #ctp.PropertyID
				WHERE at.AccountID = @accountID

		DELETE ataf
			FROM ApplicantTypeApplicationFee ataf
				INNER JOIN #ApplicantTypesToDelete #attd ON ataf.ApplicantTypeID = #attd.ApplicantTypeID
			WHERE ataf.AccountID = @accountID

		DELETE atfl
			FROM ApplicantTypeFormLetter atfl
				INNER JOIN #ApplicantTypesToDelete #attd ON atfl.ApplicantTypeID = #attd.ApplicantTypeID
			WHERE atfl.AccountID = @accountID
			
		DELETE at
			FROM ApplicantType at
				INNER JOIN #ApplicantTypesToDelete #attd ON at.ApplicantTypeID = #attd.ApplicantTypeID
			WHERE at.AccountID = @accountID

		--Copy the applicant types, applicant fees, and applicant type form letters from the copyFromProperty
		CREATE TABLE #ApplicantTypesToCopy (
			ApplicantTypeID uniqueidentifier not null,
			NewApplicantTypeID uniqueidentifier not null,
			NewPropertyID uniqueidentifier not null)

		INSERT INTO #ApplicantTypesToCopy (ApplicantTypeID, NewApplicantTypeID, NewPropertyID)
			SELECT at.ApplicantTypeID, NEWID(), #ctp.PropertyID
				FROM ApplicantType at
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE at.AccountID = @accountID
				  AND at.PropertyID = @copyFromPropertyID

		INSERT ApplicantType (AccountID, AddressCount, AllowInvitingRoommates, ApplicantTypeID, AutoGenerateLease, AutoScreenApplicant, CollectDepositsImmediately, CollectFeesImmediately, CollectUnitTypeDeposit, DefaultIDNumberType, DocuSignLeaseTemplateID, EmploymentCount, Forms, IsDefault, Name, PropertyID, LimitNumberOfApplicantsPerApplication, MaxApplicantCount, NewLeaseSignaturePackageID, DisplayScreeningResults, AvailableForOnlineApplication, OtherIncomeCount, AssetCount, ExpenseCount, RentableItemsIncludeAttachedToUnits, IsSystem, ShowRentersInsuranceForm, RequireRentersInsuranceProof, IdentificationRequired, DriversLicenseInfoRequired)
			SELECT @accountID, at.AddressCount, at.AllowInvitingRoommates, #attc.NewApplicantTypeID, at.AutoGenerateLease, at.AutoScreenApplicant, at.CollectDepositsImmediately, at.CollectFeesImmediately, at.CollectUnitTypeDeposit, at.DefaultIDNumberType, at.DocuSignLeaseTemplateID, at.EmploymentCount, at.Forms, at.IsDefault, at.Name, #attc.NewPropertyID, at.LimitNumberOfApplicantsPerApplication, at.MaxApplicantCount, at.NewLeaseSignaturePackageID, at.DisplayScreeningResults, at.AvailableForOnlineApplication, at.OtherIncomeCount, at.AssetCount, at.ExpenseCount, at.RentableItemsIncludeAttachedToUnits, at.IsSystem, 
					at.ShowRentersInsuranceForm, at.RequireRentersInsuranceProof, at.IdentificationRequired, at.DriversLicenseInfoRequired 
				FROM ApplicantType at
					INNER JOIN #ApplicantTypesToCopy #attc ON at.ApplicantTypeID = #attc.ApplicantTypeID
				WHERE at.AccountID = @accountID

		INSERT ApplicantTypeApplicationFee (AccountID, Amount, ApplicantTypeApplicationFeeID, ApplicantTypeID, [Description], LedgerItemTypeID, OrderBy, PerUnit)
			SELECT @accountID, ataf.Amount, NEWID(), #attc.NewApplicantTypeID, ataf.[Description], ataf.LedgerItemTypeID, ataf.OrderBy, ataf.PerUnit
				FROM ApplicantTypeApplicationFee ataf
					INNER JOIN #ApplicantTypesToCopy #attc ON ataf.ApplicantTypeID = #attc.ApplicantTypeID
				WHERE ataf.AccountID = @accountID

		INSERT ApplicantTypeFormLetter (AccountID, ApplicantTypeFormLetterID, ApplicantTypeID, FormLetterID, OrderBy)
			SELECT @accountID, NEWID(), #attc.NewApplicantTypeID, atfl.FormLetterID, atfl.OrderBy
				FROM ApplicantTypeFormLetter atfl
					INNER JOIN #ApplicantTypesToCopy #attc ON atfl.ApplicantTypeID = #attc.ApplicantTypeID
				WHERE atfl.AccountID = @accountID
	END


	IF ('RecurringCharges' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete PropertyLedgerItemUnitType records first
		DELETE pliut
			FROM PropertyLedgerItemUnitType pliut
				INNER JOIN PropertyLedgerItem pli ON pliut.PropertyLedgerItemID = pli.PropertyLedgerItemID
				INNER JOIN #CopyToProperties #ctp ON pli.PropertyID = #ctp.PropertyID
			WHERE pliut.AccountID = @accountID 

		--Delete all current recurring charges
		DELETE pli
			FROM PropertyLedgerItem pli
				INNER JOIN #CopyToProperties #ctp ON pli.PropertyID = #ctp.PropertyID
			WHERE pli.AccountID = @accountID

		--Copy the recurring charges from the copyFromProperty
		INSERT PropertyLedgerItem (AccountID, PropertyLedgerItemID, PropertyID, LedgerItemID, [Description], Amount)
			SELECT @accountID, NEWID(), #ctp.PropertyID, cfpli.LedgerItemID, cfpli.[Description], cfpli.Amount
				FROM PropertyLedgerItem cfpli
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE cfpli.AccountID = @accountID
				  AND cfpli.PropertyID = @copyFromPropertyID

		-- Wrong because UnitTypeID is different for each property, so do we not add any at all? Or do we add for every UnitType at the copy to property.
		----Copy the PropertyLedgerItemUnitType records
		--INSERT PropertyLedgerItemUnitType (AccountID, PropertyLedgerItemUnitTypeID, PropertyLedgerItemID, UnitTypeID)
		--	SELECT @accountID, NEWID(), pli.PropertyLedgerItemID, cfpliut.UnitTypeID
		--		FROM PropertyLedgerItemUnitType cfpliut
		--			INNER JOIN #CopyToProperties #ctp ON 1 = 1
		--			INNER JOIN PropertyLedgerItem pli ON #ctp.PropertyID = pli.PropertyID
		--		WHERE cfpliut.AccountID = @accountID
		--			AND cfpliut.PropertyID = @copyFromPropertyID
	END

	IF ('DocumentSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		UPDATE ctp 
		SET ctp.DocumentsDefaultEmailMessage = cfp.DocumentsDefaultEmailMessage,
			ctp.DocumentsDefaultEmailSubject = cfp.DocumentsDefaultEmailSubject,
			ctp.AutoCreateDocuSignTemplates	 = cfp.AutoCreateDocuSignTemplates
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ('FormSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN

		--Delete tiers from the copy to property
		DELETE fst
			FROM FormSettingsTier fst
				INNER JOIN #CopyToProperties #ctp ON fst.PropertyID = #ctp.PropertyID
			WHERE fst.AccountID = @accountID

		UPDATE ctp 



		SET ctp.FormSettingsNoticeOfDefaultReport	= cfp.FormSettingsNoticeOfDefaultReport
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID

		--Copy tiers to the copy to property
		INSERT FormSettingsTier (AccountID, FormSettingsTierID, PropertyID, BaseCourtFee, PerOccupantCourtFee, AttorneyFees, MinBalance, MaxBalance)
			SELECT @accountID, NEWID(), #ctp.PropertyID, fst.BaseCourtFee, fst.PerOccupantCourtFee, fst.AttorneyFees, fst.MinBalance, fst.MaxBalance
				FROM FormSettingsTier fst
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE fst.AccountID = @accountID
				  AND fst.PropertyID = @copyFromPropertyID
	END

	IF ('AddVendors' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		INSERT VendorProperty (VendorPropertyID, AccountID, VendorID, PropertyID, TaxRateGroupID, BeginningBalanceYear, BeginningBalance, CustomerNumber)
			SELECT NEWID(), @accountID, vp.VendorID, ctp.Value, NULL, NULL, NULL, NULL 
				FROM VendorProperty vp
					INNER JOIN @copyToPropertyIDs ctp ON 1 = 1
				WHERE vp.PropertyID = @copyFromPropertyID
					AND NOT EXISTS(SELECT * FROM VendorProperty vp1
									WHERE vp1.PropertyID = ctp.Value
											AND vp1.VendorID = vp.VendorID)
	END

	IF ('NotificationSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete NotificationProperty's
		DELETE np
			FROM NotificationProperty np
				INNER JOIN #CopyToProperties #ctp ON np.PropertyID = #ctp.PropertyID
			WHERE np.AccountID = @accountID

		--Copy NotificationProperty's
		INSERT NotificationProperty (AccountID, NotificationID, NotificationPropertyID, PropertyID)
			SELECT @accountID, np.NotificationID, NEWID(), #ctp.PropertyID
				FROM NotificationProperty np
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE np.AccountID = @accountID
				  AND np.PropertyID = @copyFromPropertyID

		--Delete NoficationPersonGroup's with Level="Property" and Type="Employee"
		DELETE npg
			FROM NotificationPersonGroup npg
				INNER JOIN [Notification] n ON npg.NotificationID = n.NotificationID
				INNER JOIN #CopyToProperties #ctp ON npg.PropertyID = #ctp.PropertyID
			WHERE npg.AccountID = @accountID
			  AND n.[Level] = 'Property'
			  AND n.[Type] = 'Employee'

		--Copy NoficationPersonGroup's with Level="Property" and Type="Employee"
		INSERT NotificationPersonGroup (AccountID, IsEmailSubscribed, IsSMSSubscribed, NotificationID, NotificationPersonGroupID, ObjectID, ObjectType, PropertyID)
			SELECT @accountID, npg.IsEmailSubscribed, npg.IsSMSSubscribed, npg.NotificationID, NEWID(), npg.ObjectID, npg.ObjectType, #ctp.PropertyID
				FROM NotificationPersonGroup npg
					INNER JOIN [Notification] n ON npg.NotificationID = n.NotificationID
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE npg.AccountID = @accountID
				  AND npg.PropertyID = @copyFromPropertyID
				  AND n.[Level] = 'Property'
				  AND n.[Type] = 'Employee'


		--Save the personIDs that we copied over so that we can make sure they are tied to the properties we are copying to.
		INSERT INTO #CopiedPersonIDs
			SELECT npg.ObjectID
				FROM NotificationPersonGroup npg
					INNER JOIN [Notification] n ON npg.NotificationID = n.NotificationID
				WHERE npg.AccountID = @accountID
				  AND npg.PropertyID = @copyFromPropertyID
				  AND npg.ObjectType = 'Person'
				  AND n.[Level] = 'Property'
				  AND n.[Type] = 'Employee'
	END

	IF ('EventTaskSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--A TaskTemplate is an event task if Type = 'MoveIn' OR 'WorkOrderCompleted'
		--A event task is tied to only one property through TaskTemplateProperty
		--Delete the 
		--	TaskTemplate that defines the event task, 
		--	TaskTemplateProperty's tied to it (there should only be one, though), 
		--	RecurringItem tied to it, 
		--	TaskTemplateSecurityRole's tied to it, 
		--	TaskTemplatePerson's tied to it

		CREATE TABLE #TaskTemplatesToDelete (
			TaskTemplateID uniqueidentifier not null,
			RecurringItemID uniqueidentifier not null)

		INSERT INTO #TaskTemplatesToDelete (TaskTemplateID, RecurringItemID)
			SELECT tt.TaskTemplateID, tt.RecurringItemID
				FROM TaskTemplate tt
					INNER JOIN TaskTemplateProperty ttp ON tt.TaskTemplateID = ttp.TaskTemplateID
					INNER JOIN #CopyToProperties #ctp ON ttp.PropertyID = #ctp.PropertyID
				WHERE tt.AccountID = @accountID
				  AND tt.[Type] IN ('MoveIn', 'WorkOrderCompleted')
				  
		DELETE ttp
			FROM TaskTemplateProperty ttp
				INNER JOIN #TaskTemplatesToDelete #tttd ON ttp.TaskTemplateID = #tttd.TaskTemplateID
			WHERE ttp.AccountID = @accountID

		DELETE ttsr
			FROM TaskTemplateSecurityRole ttsr
				INNER JOIN #TaskTemplatesToDelete #tttd ON ttsr.TaskTemplateID = #tttd.TaskTemplateID
			WHERE ttsr.AccountID = @accountID

		DELETE ttp 
			FROM TaskTemplatePerson ttp
				INNER JOIN #TaskTemplatesToDelete #tttd ON ttp.TaskTemplateID = #tttd.TaskTemplateID
			WHERE ttp.AccountID = @accountID

		DELETE ri
			FROM RecurringItem ri
				INNER JOIN #TaskTemplatesToDelete #tttd ON ri.RecurringItemID = #tttd.RecurringItemID
			WHERE ri.AccountID = @accountID

		DELETE tt
			FROM TaskTemplate tt
				INNER JOIN #TaskTemplatesToDelete #tttd ON tt.TaskTemplateID = #tttd.TaskTemplateID
			WHERE tt.AccountID = @accountID


		--Copy all the same stuff!
		CREATE TABLE #TaskTemplatesToCopy (
			TaskTemplateID uniqueidentifier not null,
			RecurringItemID uniqueidentifier not null,
			NewTaskTemplateID uniqueidentifier not null,
			NewRecurringItemID uniqueidentifier not null,
			NewPropertyID uniqueidentifier not null)

		INSERT INTO #TaskTemplatesToCopy (TaskTemplateID, RecurringItemID, NewTaskTemplateID, NewRecurringItemID, NewPropertyID)
			SELECT DISTINCT tt.TaskTemplateID, tt.RecurringItemID, NEWID(), NEWID(), #ctp.PropertyID
				FROM TaskTemplate tt
					INNER JOIN TaskTemplateProperty ttp ON tt.TaskTemplateID = ttp.TaskTemplateID
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE ttp.AccountID = @accountID
				  AND ttp.PropertyID = @copyFromPropertyID
				  AND tt.[Type] IN ('MoveIn', 'WorkOrderCompleted')

		INSERT INTO RecurringItem (AccountID, AssignedToPersonID, DayToRun, EndDate, Frequency, ItemType, LastManualPostDate, LastManualPostPersonID, LastRecurringPostDate, Name, PersonID, RecurringItemID, RepeatsEvery, StartDate)
			SELECT @accountID, ri.AssignedToPersonID, ri.DayToRun, ri.EndDate, ri.Frequency, ri.ItemType, null, null, null, ri.Name, ri.PersonID, #tttc.NewRecurringItemID, ri.RepeatsEvery, ri.StartDate
				FROM RecurringItem ri
					INNER JOIN #TaskTemplatesToCopy #tttc ON ri.RecurringItemID = #tttc.RecurringItemID
				WHERE ri.AccountID = @accountID
					
		INSERT INTO TaskTemplate (AccountID, AssignedByPersonID, DaysUntilDue, Importance, IsAssignedtoPeople, IsCopiedToPeople, IsGroupTask, [Message], RecurringItemID, [Subject], TaskTemplateID, [Type])
			SELECT @accountID, tt.AssignedByPersonID, tt.DaysUntilDue, tt.Importance, tt.IsAssignedtoPeople, tt.IsCopiedToPeople, tt.IsGroupTask, tt.[Message], #tttc.NewRecurringItemID, tt.[Subject], #tttc.NewTaskTemplateID, tt.[Type]
				FROM TaskTemplate tt
					INNER JOIN #TaskTemplatesToCopy #tttc ON tt.TaskTemplateID = #tttc.TaskTemplateID
				WHERE tt.AccountID = @accountID

		INSERT INTO TaskTemplatePerson (AccountID, IsCarbonCopy, PersonID, TaskTemplateID, TaskTemplatePersonID)
			SELECT @accountID, ttp.IsCarbonCopy, ttp.PersonID, #tttc.NewTaskTemplateID, NEWID()
				FROM TaskTemplatePerson ttp
					INNER JOIN #TaskTemplatesToCopy #tttc ON ttp.TaskTemplateID = #tttc.TaskTemplateID
				WHERE ttp.AccountID = @accountID

		INSERT INTO TaskTemplateProperty (AccountID, IsCarbonCopy, PropertyID, TaskTemplateID, TaskTemplatePropertyID)
			SELECT @accountID, ttp.IsCarbonCopy, #tttc.NewPropertyID, #tttc.NewTaskTemplateID, NEWID()
				FROM TaskTemplateProperty ttp
					INNER JOIN #TaskTemplatesToCopy #tttc ON ttp.TaskTemplateID = #tttc.TaskTemplateID
				WHERE ttp.AccountID = @accountID

		INSERT INTO TaskTemplateSecurityRole (AccountID, IsCarbonCopy, SecurityRoleID, TaskTemplateID, TaskTemplateSecurityRoleID)
			SELECT @accountID, ttsr.IsCarbonCopy, ttsr.SecurityRoleID, #tttc.NewTaskTemplateID, NEWID()
				FROM TaskTemplateSecurityRole ttsr
					INNER JOIN #TaskTemplatesToCopy #tttc ON ttsr.TaskTemplateID = #tttc.TaskTemplateID
				WHERE ttsr.AccountID = @accountID


		--Save the personIDs to make sure they are tied to the properties we are copying to.
		INSERT INTO #CopiedPersonIDs
			SELECT ri.AssignedToPersonID
				FROM RecurringItem ri
					INNER JOIN #TaskTemplatesToCopy #tttc ON ri.RecurringItemID = #tttc.RecurringItemID
				WHERE ri.AccountID = @accountID
				
			UNION

			SELECT ri.PersonID
				FROM RecurringItem ri
					INNER JOIN #TaskTemplatesToCopy #tttc ON ri.RecurringItemID = #tttc.RecurringItemID
				WHERE ri.AccountID = @accountID

			UNION

			SELECT ttp.PersonID
				FROM TaskTemplatePerson ttp
					INNER JOIN #TaskTemplatesToCopy #tttc ON ttp.TaskTemplateID = #tttc.TaskTemplateID
				WHERE ttp.AccountID = @accountID
	END

	IF ('AutoMakeReadyWorkOrders' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		--Delete old ones
		DELETE amr
			FROM AutoMakeReady amr
				INNER JOIN #CopyToProperties #ctp ON amr.PropertyID = #ctp.PropertyID
			WHERE amr.AccountID = @accountID

		--Copy the other ones
		INSERT INTO AutoMakeReady (AccountID, Abbreviation, AssignedToPersonID, AutoMakeReadyID, DaysToComplete, [Description], OrderBy, [Priority], PropertyID, WorkOrderCategoryID, Prepopulate)
			SELECT @accountID, amr.Abbreviation, amr.AssignedToPersonID, NEWID(), amr.DaysToComplete, amr.[Description], amr.OrderBy, amr.[Priority], #ctp.PropertyID, amr.WorkOrderCategoryID, amr.Prepopulate
				FROM AutoMakeReady amr
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE amr.AccountID = @accountID
				  AND amr.PropertyID = @copyFromPropertyID

		--Save the personIDs to make sure they are tied to the properties we are copying to.
		INSERT INTO #CopiedPersonIDs
			SELECT amr.AssignedToPersonID
				FROM AutoMakeReady amr
				WHERE amr.AccountID = @accountID
				  AND amr.PropertyID = @copyFromPropertyID
	END
	
	IF ('DefaultMoveOutCharges' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN

		DELETE dmoc
			FROM DefaultMoveOutCharge dmoc
				INNER JOIN #CopyToProperties #ctp ON dmoc.PropertyID = #ctp.PropertyID
			WHERE dmoc.AccountID = @accountID

		INSERT INTO DefaultMoveOutCharge (AccountID, Amount, DefaultMoveOutChargeID, [Description], LedgerItemTypeID, Notes, PropertyID)
			SELECT @accountID, dmoc.Amount, NEWID(), dmoc.[Description], dmoc.LedgerItemTypeID, dmoc.Notes, #ctp.PropertyID
				FROM DefaultMoveOutCharge dmoc
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE dmoc.AccountID = @accountID
				  AND dmoc.PropertyID = @copyFromPropertyID

	END

	IF ('LedgerLineItemGroups' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		
		--Delete the old ones
		CREATE TABLE #LedgerLineItemGroupsToDelete (
			LedgerLineItemGroupID uniqueidentifier not null)

		INSERT INTO #LedgerLineItemGroupsToDelete (LedgerLineItemGroupID)
			SELECT llig.LedgerLineItemGroupID
				FROM LedgerLineItemGroup llig
					INNER JOIN #CopyToProperties #ctp ON llig.PropertyID = #ctp.PropertyID
				WHERE llig.AccountID = @accountID

		DELETE lliglit
			FROM LedgerLineItemGroupLedgerItemType lliglit
				INNER JOIN #LedgerLineItemGroupsToDelete #lligtd ON lliglit.LedgerLineItemGroupID = #lligtd.LedgerLineItemGroupID
			WHERE lliglit.AccountID = @accountID

		DELETE llig
			FROM LedgerLineItemGroup llig
				INNER JOIN #LedgerLineItemGroupsToDelete #lligtd ON llig.LedgerLineItemGroupID = #lligtd.LedgerLineItemGroupID
			WHERE llig.AccountID = @accountID


		--Copy the other ones
		CREATE TABLE #LedgerLineItemGroupsToCopy (
			LedgerLineItemGroupID uniqueidentifier not null,
			NewLedgerLineItemGroupID uniqueidentifier not null,
			NewPropertyID uniqueidentifier not null)

		INSERT INTO #LedgerLineItemGroupsToCopy (LedgerLineItemGroupID, NewLedgerLineItemGroupID, NewPropertyID)
			SELECT llig.LedgerLineItemGroupID, NEWID(), #ctp.PropertyID
				FROM LedgerLineItemGroup llig
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE llig.AccountID = @accountID
				  AND llig.PropertyID = @copyFromPropertyID

		INSERT INTO LedgerLineItemGroup (AccountID, LedgerLineItemGroupID, Name, PropertyID)
			SELECT @accountID, #lligtc.NewLedgerLineItemGroupID, llig.Name, #lligtc.NewPropertyID
				FROM LedgerLineItemGroup llig
					INNER JOIN #LedgerLineItemGroupsToCopy #lligtc ON llig.LedgerLineItemGroupID = #lligtc.LedgerLineItemGroupID
				WHERE llig.AccountID = @accountID

		INSERT INTO LedgerLineItemGroupLedgerItemType (AccountID, LedgerItemTypeID, LedgerLineItemGroupID, LedgerLineItemGroupLedgerItemTypeID)
			SELECT @accountID, lliglit.LedgerItemTypeID, #lligtc.NewLedgerLineItemGroupID, NEWID()
				FROM LedgerLineItemGroupLedgerItemType lliglit
					INNER JOIN #LedgerLineItemGroupsToCopy #lligtc ON #lligtc.LedgerLineItemGroupID = lliglit.LedgerLineItemGroupID
				WHERE lliglit.AccountID = @accountID


	END

	IF ('ActionPrerequisites' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
	
		--Update: set IsDeleted = 1 for all items in destination
		--Update: set Destination.IsDeleted = Source.IsDeleted for all matching from source & destination
		--Insert: into Destination all source items not in destination & where source.IsDeleted = 0
		
		UPDATE api SET IsDeleted = 1
			FROM ActionPrerequisiteItem api
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = api.PropertyID
			WHERE api.AccountID = @accountID
			
		
		UPDATE api
			SET api.IsDeleted = apiToCopy.IsDeleted
			FROM ActionPrerequisiteItem api
				INNER JOIN ActionPrerequisiteItem apiToCopy ON apiToCopy.Name = api.Name AND apiToCopy.[Type] = api.[Type]
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = api.PropertyID
			WHERE api.AccountID = @accountID
			  AND apiToCopy.PropertyID = @copyFromPropertyID
		
		INSERT INTO ActionPrerequisiteItem(AccountID, ActionPrerequisiteItemID, IsSystem, Name, OrderBy, PropertyID, [Type], IsDeleted)
			SELECT @accountID, NEWID(), apiToCopy.IsSystem, apiToCopy.Name, apiToCopy.OrderBy, #ctp.PropertyID, apiToCopy.[Type], apiToCopy.IsDeleted
				FROM ActionPrerequisiteItem apiToCopy
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN ActionPrerequisiteItem existingApi ON existingApi.Name = apiToCopy.Name AND existingApi.[Type] = apiToCopy.[Type] AND existingApi.PropertyID = #ctp.PropertyID
				WHERE apiToCopy.AccountID = @accountID
					AND apiToCopy.PropertyID = @copyFromPropertyID
					AND apiToCopy.IsDeleted = 0
					AND existingApi.ActionPrerequisiteItemID IS NULL

	END

	IF ('ProspectSources' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		
		--Copy PropertyProspectSources from the main property to the properties if they don't exist in the properties being copied to and they aren't already deleted.
		 INSERT INTO PropertyProspectSource (AccountID, CostPerYear, ExpirationDate, IsDeleted, PropertyID, PropertyProspectSourceID, ProspectSourceID)
			SELECT @accountID, ppsToCopy.CostPerYear, ppsToCopy.ExpirationDate, 0, #ctp.PropertyID, NEWID(), ppsToCopy.ProspectSourceID
				FROM PropertyProspectSource ppsToCopy
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN PropertyProspectSource existingPps ON existingPps.PropertyID = #ctp.PropertyID AND existingPps.ProspectSourceID = ppsToCopy.ProspectSourceID
				WHERE ppsToCopy.AccountID = @accountID
				  AND ppsToCopy.PropertyID = @copyFromPropertyID
				  AND ppsToCopy.IsDeleted = 0
				  AND existingPps.PropertyProspectSourceID IS NULL

		--Update the existing PropertyProspectSources to match the ones being copied, or set to deleted if a match doesn't exist.
		UPDATE pps
			SET pps.CostPerYear		= CASE WHEN ppsToCopy.PropertyProspectSourceID IS NULL THEN pps.CostPerYear ELSE ppsToCopy.CostPerYear END,
				pps.ExpirationDate	= CASE WHEN ppsToCopy.PropertyProspectSourceID IS NULL THEN pps.ExpirationDate ELSE ppsToCopy.ExpirationDate END,
				pps.IsDeleted		= CASE WHEN ppsToCopy.PropertyProspectSourceID IS NULL THEN 1 ELSE ppsToCopy.IsDeleted END
			FROM PropertyProspectSource pps
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = pps.PropertyID
				LEFT JOIN PropertyProspectSource ppsToCopy ON ppsToCopy.ProspectSourceID = pps.ProspectSourceID AND ppsToCopy.PropertyID = @copyFromPropertyID
			WHERE pps.AccountID = @accountID

	END


	IF ('ServiceProviders' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		
		-- Add nonexistant providers
		INSERT INTO ServiceProvider (AccountID, IsDeleted, IsSystem, Name, PhoneNumber, PropertyID, ServiceProviderID, UtilityType, [Type])
			SELECT @accountID, 0, spToCopy.IsSystem, spToCopy.Name, spToCopy.PhoneNumber, #ctp.PropertyID, NEWID(), spToCopy.UtilityType, spToCopy.[Type]
				FROM ServiceProvider spToCopy
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
					LEFT JOIN ServiceProvider existingSp ON existingSp.PropertyID = #ctp.PropertyID
														AND ((existingSp.UtilityType = spToCopy.UtilityType)
															OR ((existingSp.UtilityType IS NULL)
																AND (spToCopy.UtilityType IS NULL)))
														AND existingSp.Name = spToCopy.Name
				WHERE spToCopy.AccountID = @accountID
				  AND spToCopy.PropertyID = @copyFromPropertyID
				  AND spToCopy.IsDeleted = 0
				  -- There isn't a provider with the same name and utility type
				  AND existingSp.ServiceProviderID IS NULL

		-- Update providers that existed at both properties
		UPDATE sp
			SET sp.PhoneNumber	= CASE WHEN spToCopy.ServiceProviderID IS NULL THEN sp.PhoneNumber ELSE spToCopy.PhoneNumber END,
				sp.IsDeleted	= CASE WHEN spToCopy.ServiceProviderID IS NULL THEN 1 ELSE spToCopy.IsDeleted END
			FROM ServiceProvider sp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = sp.PropertyID
				LEFT JOIN ServiceProvider spToCopy ON spToCopy.Name = sp.Name
														AND spToCopy.PropertyID = @copyFromPropertyID
															AND ((sp.UtilityType = spToCopy.UtilityType)
																OR ((sp.UtilityType IS NULL) 
																	AND (spToCopy.UtilityType IS NULL)))
			WHERE sp.AccountID = @accountID

	END


	IF ('LeaseExpirationSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		
		--Update lease expiration limits
		UPDATE pap
			SET pap.LeaseExpirationLimit = papToCopy.LeaseExpirationLimit
			FROM PropertyAccountingPeriod pap
				INNER JOIN PropertyAccountingPeriod papToCopy ON papToCopy.AccountingPeriodID = pap.AccountingPeriodID
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = pap.PropertyID
			WHERE pap.AccountID = @accountID
			  AND papToCopy.PropertyID = @copyFromPropertyID
			  AND pap.Closed = 0

		--Update lease expriation black out dates by deleting and then copying
		DELETE leb 
			FROM LeaseExpirationBlackout leb
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = leb.PropertyID
			WHERE leb.AccountID = @accountID

		INSERT INTO LeaseExpirationBlackout (AccountID, LeaseExpirationBlackoutID, DaysAfter, DaysBefore, PropertyID, [Type], Value)
			SELECT @accountID, NEWID(), leb.DaysAfter, leb.DaysBefore, #ctp.PropertyID, leb.[Type], leb.Value
				FROM LeaseExpirationBlackout leb
					INNER JOIN #CopyToProperties #ctp ON 1 = 1
				WHERE leb.AccountID = @accountID
				  AND leb.PropertyID = @copyFromPropertyID

		--Update settings on property
		UPDATE ctp 
			SET ctp.ForcedLeaseEndDate = cfp.ForcedLeaseEndDate
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	IF ('UncommonSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		UPDATE ctp 
		SET ctp.AllowMultipleRecurringChargePostings = cfp.AllowMultipleRecurringChargePostings
			FROM Property ctp
				INNER JOIN #CopyToProperties #ctp ON #ctp.PropertyID = ctp.PropertyID
				INNER JOIN Property cfp ON cfp.PropertyID = @copyFromPropertyID
			WHERE cfp.AccountID = @accountID
	END

	--IF ('CustomFields' IN (SELECT Setting FROM #SettingsToCopy))
	--BEGIN
	--	--Delete the old ones
	--	DELETE cfv
	--		FROM CustomFieldValue cfv 
	--			INNER JOIN #CopyToPropertyIDs #ctp ON #ctp.PropertyID = cfv.ObjectID
	--		WHERE cfv.AccountID = @accountID

	--  --Copy the CustomFieldPropertys? or just Copy the CustomFieldValues that are tied to the property being copied to?

	--	--Copy the new ones
	--	INSERT CustomFieldValue (AccountID, CustomFieldID, CustomFieldValueID, ObjectID, Value)
	--		SELECT @accountID, cfvToCopy.CustomFieldID, NEWID(), #ctp.PropertyID, cfvToCopy.Value
	--			FROM CustomFieldValue cfvToCopy
	--				INNER JOIN #CopyToProperties #ctp ON 1 = 1
	--			WHERE cfvToCopy.AccountID = @accountID
	--			  AND cfvToCopy.ObjectID = @copyFromPropertyID

	--END
	IF('IncomeLimitTables' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		
		CREATE TABLE  #TempAffordableProgramTableGroup (
			[AffordableProgramTableGroupID] UNIQUEIDENTIFIER NOT NULL,
			[AccountID]                     BIGINT           NOT NULL,
			[Name]                          NVARCHAR (50)    NULL,
			[IsHUD]                         BIT              NOT NULL,
			[PropertyID]                    UNIQUEIDENTIFIER NOT NULL,
			OldID UNIQUEIDENTIFIER NOT NULL);
		
		INSERT INTO #TempAffordableProgramTableGroup SELECT NEWID(), @accountID, aptg.Name, aptg.IsHUD, #ctp.PropertyID, aptg.AffordableProgramTableGroupID 
			FROM AffordableProgramTableGroup aptg, #CopyToProperties #ctp
			WHERE aptg.AccountID = @accountID
				AND aptg.PropertyID = @copyFromPropertyID
				
		UPDATE g1 SET g1.[AffordableProgramTableGroupID] = g2.[AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTableGroup g1 
				INNER JOIN AffordableProgramTableGroup g2 ON g1.AccountID = g2.AccountID AND g1.Name = g2.Name AND g1.PropertyID = g2.PropertyID
		UPDATE g1 SET g1.[AffordableProgramTableGroupID] = g2.[AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTableGroup g1 
				INNER JOIN AffordableProgramTableGroup g2 ON g1.AccountID = g2.AccountID AND g1.IsHUD = g2.IsHUD AND g1.PropertyID = g2.PropertyID
				
		CREATE TABLE #TempAffordableProgramTable(
			[AffordableProgramTableID]       UNIQUEIDENTIFIER NOT NULL,
			[AccountID]                      BIGINT           NOT NULL,
			[Type]                           NVARCHAR (10)    NOT NULL,
			[ParentAffordableProgramTableID] UNIQUEIDENTIFIER NULL,
			[EffectiveDate]                  DATE             NOT NULL,
			[Notes]                          NVARCHAR (MAX)   NULL,
			[AffordableProgramTableGroupID]  UNIQUEIDENTIFIER NOT NULL,
			PropertyID UNIQUEIDENTIFIER NULL,
			OldID UNIQUEIDENTIFIER NULL);

		INSERT INTO #TempAffordableProgramTable SELECT apt.*, #ctp.PropertyID, apt.AffordableProgramTableID FROM AffordableProgramTable apt
				INNER JOIN AffordableProgramTableGroup aptg ON apt.AffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID, #CopyToProperties #ctp
			WHERE apt.AccountID = @accountID
				AND aptg.PropertyID = @copyFromPropertyID
				
		UPDATE #TempAffordableProgramTable SET [AffordableProgramTableID] = NEWID();
		
		UPDATE t1 SET t1.[ParentAffordableProgramTableID] = t2.[AffordableProgramTableID] 
			FROM #TempAffordableProgramTable t1 
				INNER JOIN #TempAffordableProgramTable t2 ON t1.[ParentAffordableProgramTableID] = t2.OldID AND t1.PropertyID = t2.PropertyID
				
		UPDATE t1 SET t1.[AffordableProgramTableGroupID] = g2.[AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTable t1 
				INNER JOIN #TempAffordableProgramTableGroup g2 ON t1.AccountID = g2.AccountID AND t1.AffordableProgramTableGroupID = g2.OldID AND t1.PropertyID = g2.PropertyID

		CREATE TABLE #TempAffordableProgramTableRow (
			[AffordableProgramTableRowID] UNIQUEIDENTIFIER NOT NULL,
			[AccountID]                   BIGINT           NOT NULL,
			[AffordableProgramTableID]    UNIQUEIDENTIFIER NOT NULL,
			[Percent]                     INT              NULL,
			[Value1]                      MONEY            NULL,
			[Value2]                      MONEY            NULL,
			[Value3]                      MONEY            NULL,
			[Value4]                      MONEY            NULL,
			[Value5]                      MONEY            NULL,
			[Value6]                      MONEY            NULL,
			[Value7]                      MONEY            NULL,
			[Value8]                      MONEY            NULL,
			[OrderBy]                     TINYINT          NOT NULL,
			PropertyID UNIQUEIDENTIFIER NULL,
			OldID UNIQUEIDENTIFIER NULL);

		INSERT INTO #TempAffordableProgramTableRow SELECT aptr.*, #ctp.PropertyID, aptr.AffordableProgramTableRowID FROM AffordableProgramTable apt
				INNER JOIN AffordableProgramTableGroup aptg ON apt.AffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID
				INNER JOIN AffordableProgramTableRow aptr ON apt.AffordableProgramTableID = aptr.AffordableProgramTableID, #CopyToProperties #ctp
			WHERE apt.AccountID = @accountID
				AND aptg.PropertyID = @copyFromPropertyID
			  
		UPDATE #TempAffordableProgramTableRow SET [AffordableProgramTableRowID] = NEWID();
		
		UPDATE r1 SET r1.[AffordableProgramTableID] = t2.[AffordableProgramTableID] 
			FROM #TempAffordableProgramTableRow r1 
				INNER JOIN #TempAffordableProgramTable t2 ON r1.AccountID = t2.AccountID AND r1.[AffordableProgramTableID] = t2.OldID AND r1.PropertyID = t2.PropertyID
				
				
		DELETE FROM AffordableProgramTableRow WHERE [AffordableProgramTableID] in (SELECT [AffordableProgramTableID] FROM AffordableProgramTable WHERE [AffordableProgramTableGroupID] in (select [AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTableGroup))
		DELETE FROM AffordableProgramTable WHERE [AffordableProgramTableGroupID] in (select [AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTableGroup)
		DELETE FROM AffordableProgramTableGroup WHERE [AffordableProgramTableGroupID] in (select [AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTableGroup)
		INSERT INTO AffordableProgramTableGroup SELECT [AffordableProgramTableGroupID], [AccountID], [Name], [IsHUD], [PropertyID]	
			FROM #TempAffordableProgramTableGroup             
		INSERT INTO AffordableProgramTable SELECT [AffordableProgramTableID], [AccountID], [Type], [ParentAffordableProgramTableID], [EffectiveDate], [Notes], [AffordableProgramTableGroupID] 
			FROM #TempAffordableProgramTable
		INSERT INTO AffordableProgramTableRow SELECT [AffordableProgramTableRowID], [AccountID], [AffordableProgramTableID], [Percent], [Value1], [Value2], [Value3], [Value4], [Value5], [Value6], [Value7], [Value8], [OrderBy] 
			FROM #TempAffordableProgramTableRow                  

END

	IF('AffordableSettings' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		UPDATE p SET AffordableIsFloating = pcf.AffordableIsFloating, EnableHapLedger = pcf.EnableHapLedger, TenantRentShouldDeductRentConcessions = pcf.TenantRentShouldDeductRentConcessions, 
			AutoRecertificationRenewalLease = pcf.AutoRecertificationRenewalLease, DisableDemographicsForForms = pcf.DisableDemographicsForForms, DefaultRecertificationsToFirstOfMonth = pcf.DefaultRecertificationsToFirstOfMonth, 
			RoundIncomeOnTics = pcf.RoundIncomeOnTics, DisableNaurAndUvr = pcf.DisableNaurAndUvr, EnableTwoSalaryAmounts = pcf.EnableTwoSalaryAmounts,

			EnableResComm = pcf.EnableResComm, AutoNotices = pcf.AutoNotices, 
			ResCommPersonID = (SELECT pt.PersonID FROM Person p
					INNER JOIN PersonType pt on pt.PersonID = p.PersonID AND pt.[Type] IN ('User', 'Employee')
					INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
				WHERE ptp.HasAccess = 1
					AND ptp.PropertyID IN (SELECT PropertyID FROM #CopyToProperties)
					AND pt.PersonID = pcf.ResCommPersonID), 

			NoticeEmailTemplate120 = ISNULL((SELECT EmailTemplateID FROM EmailTemplate 
												WHERE EmailTemplateID = pcf.NoticeEmailTemplate120 
												AND PropertyOrGroupID in (SELECT PropertyGroupID FROM PropertyGroupProperty WHERE PropertyID = p.PropertyID)), 
											NEWID()),
											
			NoticeEmailTemplate90 = ISNULL((SELECT EmailTemplateID FROM EmailTemplate 
												WHERE EmailTemplateID = pcf.NoticeEmailTemplate90 
												AND PropertyOrGroupID in (SELECT PropertyGroupID FROM PropertyGroupProperty WHERE PropertyID = p.PropertyID)), 
											NEWID()),
			NoticeEmailTemplate60 = ISNULL((SELECT EmailTemplateID FROM EmailTemplate 
												WHERE EmailTemplateID = pcf.NoticeEmailTemplate60 
												AND PropertyOrGroupID in (SELECT PropertyGroupID FROM PropertyGroupProperty WHERE PropertyID = p.PropertyID)), 
											NEWID()),
			NoticeEmailTemplate30 = ISNULL((SELECT EmailTemplateID FROM EmailTemplate 
												WHERE EmailTemplateID = pcf.NoticeEmailTemplate30 
												AND PropertyOrGroupID in (SELECT PropertyGroupID FROM PropertyGroupProperty WHERE PropertyID = p.PropertyID)), 
											NEWID()),

			TaxCreditReportingPlatform = pcf.TaxCreditReportingPlatform,

			TRACSAdministratorPersonID = (SELECT pt.PersonID FROM Person p
					INNER JOIN PersonType pt on pt.PersonID = p.PersonID AND pt.[Type] IN ('User', 'Employee')
					INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
				WHERE ptp.HasAccess = 1
					AND ptp.PropertyID IN (SELECT PropertyID FROM #CopyToProperties)
					AND pt.PersonID = pcf.TRACSAdministratorPersonID), 
			UseTracsRelease202D = pcf.UseTracsRelease202D, TRACSProjectMailID = pcf.TRACSProjectMailID, 
			TRACSProjectMailPassword = pcf.TRACSProjectMailPassword, TRACSCAMailID = pcf.TRACSCAMailID, ConfirmUnitBaseline = pcf.ConfirmUnitBaseline, 
			DefaultRepaymentAgreementTransactionCategoryID = pcf.DefaultRepaymentAgreementTransactionCategoryID,
			AutoCreateCorrections = pcf.AutoCreateCorrections,

			ComplianceCenterShowBuildingModule = pcf.ComplianceCenterShowBuildingModule, ComplianceCenterShowRecertificationModule = pcf.ComplianceCenterShowRecertificationModule, 
			ComplianceCenterShowWaitListModule = pcf.ComplianceCenterShowWaitListModule, ComplianceCenterShowPropertyModule = pcf.ComplianceCenterShowPropertyModule, 
			ComplianceCenterShowNAURModule = pcf.ComplianceCenterShowNAURModule, ComplianceCenterShowUnitVacancyModule = pcf.ComplianceCenterShowUnitVacancyModule, 
			ComplianceCenterShowSpecialClaimsModule = pcf.ComplianceCenterShowSpecialClaimsModule, ComplianceCenterShowPropertyDemographicsModule = pcf.ComplianceCenterShowPropertyDemographicsModule, 
			ComplianceCenterShowPendingCertificationsModule = pcf.ComplianceCenterShowPendingCertificationsModule, ComplianceCenterShowHUDReportingModule = pcf.ComplianceCenterShowHUDReportingModule, 
			ComplianceCenterShowTaxCreditReportingModule = pcf.ComplianceCenterShowTaxCreditReportingModule,
			EnableAffordableWaitList = pcf.EnableAffordableWaitList
			FROM Property p, Property pcf
			WHERE p.AccountID = @accountID AND p.PropertyID IN (SELECT PropertyID FROM #CopyToProperties)
			AND pcf.AccountID = @accountID AND pcf.PropertyID = @copyFromPropertyID
			
			INSERT INTO EmailTemplate (EmailTemplateID, AccountID, Name, [Subject], Body, PropertyOrGroupID, CreatedByPersonID, LastModified, IsArchived, [Type], IsSystem, IsTemporary, SendingMethod, NotificationID, SMSBody)
			SELECT p.NoticeEmailTemplate120, @accountID, et.Name, et.[Subject], et.Body, p.PropertyID, et.CreatedByPersonID, et.LastModified, et.IsArchived, et.[Type], et.IsSystem, et.IsTemporary, et.SendingMethod, et.NotificationID, et.SMSBody 
			FROM Property p, EmailTemplate et 
			WHERE p.NoticeEmailTemplate120 NOT IN (SELECT EmailTemplateID FROM EmailTemplate) AND et.EmailTemplateID = (SELECT NoticeEmailTemplate120 FROM Property WHERE PropertyID = @copyFromPropertyID)

			INSERT INTO EmailTemplate (EmailTemplateID, AccountID, Name, [Subject], Body, PropertyOrGroupID, CreatedByPersonID, LastModified, IsArchived, [Type], IsSystem, IsTemporary, SendingMethod, NotificationID, SMSBody)
			SELECT p.NoticeEmailTemplate90, @accountID, et.Name, et.[Subject], et.Body, p.PropertyID, et.CreatedByPersonID, et.LastModified, et.IsArchived, et.[Type], et.IsSystem, et.IsTemporary, et.SendingMethod, et.NotificationID, et.SMSBody 
			FROM Property p, EmailTemplate et 
			WHERE p.NoticeEmailTemplate90 NOT IN (SELECT EmailTemplateID FROM EmailTemplate) AND et.EmailTemplateID = (SELECT NoticeEmailTemplate90 FROM Property WHERE PropertyID = @copyFromPropertyID)

			INSERT INTO EmailTemplate (EmailTemplateID, AccountID, Name, [Subject], Body, PropertyOrGroupID, CreatedByPersonID, LastModified, IsArchived, [Type], IsSystem, IsTemporary, SendingMethod, NotificationID, SMSBody)
			SELECT p.NoticeEmailTemplate60, @accountID, et.Name, et.[Subject], et.Body, p.PropertyID, et.CreatedByPersonID, et.LastModified, et.IsArchived, et.[Type], et.IsSystem, et.IsTemporary, et.SendingMethod, et.NotificationID, et.SMSBody 
			FROM Property p, EmailTemplate et 
			WHERE p.NoticeEmailTemplate60 NOT IN (SELECT EmailTemplateID FROM EmailTemplate) AND et.EmailTemplateID = (SELECT NoticeEmailTemplate60 FROM Property WHERE PropertyID = @copyFromPropertyID)

			INSERT INTO EmailTemplate (EmailTemplateID, AccountID, Name, [Subject], Body, PropertyOrGroupID, CreatedByPersonID, LastModified, IsArchived, [Type], IsSystem, IsTemporary, SendingMethod, NotificationID, SMSBody)
			SELECT p.NoticeEmailTemplate30, @accountID, et.Name, et.[Subject], et.Body, p.PropertyID, et.CreatedByPersonID, et.LastModified, et.IsArchived, et.[Type], et.IsSystem, et.IsTemporary, et.SendingMethod, et.NotificationID, et.SMSBody 
			FROM Property p, EmailTemplate et 
			WHERE p.NoticeEmailTemplate30 NOT IN (SELECT EmailTemplateID FROM EmailTemplate) AND et.EmailTemplateID = (SELECT NoticeEmailTemplate30 FROM Property WHERE PropertyID = @copyFromPropertyID)

			DELETE FROM FormLetter WHERE PropertyOrGroupID in (SELECT PropertyID FROM #CopyToProperties) AND VerificationLetterID IS NOT NULL
			
			DELETE FROM WaitListIncomeLevel WHERE PropertyID IN (SELECT PropertyID FROM #CopyToProperties)
				
			DELETE FROM WaitListLottery WHERE AccountID = @accountID AND WaitListID in (SELECT WaitListID FROM WaitList WHERE PropertyID in (SELECT PropertyID FROM #CopyToProperties) AND [Type] = 'Affordable')

			IF (SELECT TOP 1 EnableAffordableWaitList FROM Property WHERE AccountID = @accountID AND PropertyID = @copyFromPropertyID) = 1
			BEGIN

				INSERT INTO WaitListIncomeLevel (WaitListIncomeLevelID, AccountID, PropertyID, AmiPercent, Label, OrderBy, IsIncomeLevel)
					SELECT NEWID(), @accountID, p.PropertyID, wlil.AmiPercent, wlil.Label, wlil.OrderBy, wlil.IsIncomeLevel 
					FROM Property p, WaitListIncomeLevel wlil
					WHERE p.PropertyID IN (SELECT PropertyID FROM #CopyToProperties) AND wlil.PropertyID = @copyFromPropertyID

				INSERT INTO WaitList (WaitListID, AccountID, PropertyID, [Type], EnableLottery)
					SELECT NEWID(), @accountID, p.PropertyID, wl.[Type], 0 
						FROM #CopyToProperties p
							JOIN WaitList wl ON @copyFromPropertyID = wl.PropertyID AND wl.[Type] = 'Affordable'
						WHERE (SELECT COUNT(*) FROM WaitList WHERE PropertyID = p.PropertyID AND [Type] = 'Affordable') = 0

				UPDATE WaitList SET EnableLottery = (SELECT EnableLottery FROM WaitList WHERE PropertyID = @copyFromPropertyID AND [Type] = 'Affordable') 
					WHERE PropertyID in (SELECT PropertyID FROM #CopyToProperties) AND [Type] = 'Affordable'

				IF (SELECT TOP 1 EnableLottery FROM WaitList WHERE AccountID = @accountID AND PropertyID = @copyFromPropertyID) = 1
				BEGIN
					INSERT INTO WaitListLottery (WaitListLotteryID, AccountID, WaitListID, Name)
						SELECT NEWID(), @accountID, wl.WaitListID, wll.Name
						FROM WaitList wl, WaitListLottery wll
						WHERE wl.PropertyID in (SELECT PropertyID FROM #CopyToProperties) AND wl.[Type] = 'Affordable' 
							AND wll.WaitListID = (SELECT WaitListID FROM WaitList WHERE PropertyID = @copyFromPropertyID AND [Type] = 'Affordable') 
				END
			END
			
	END


	IF('GLAccountPermissions' IN (SELECT Setting FROM #SettingsToCopy))
	BEGIN
		DELETE glapr

		  FROM GLAccountPropertyRestriction glapr
			INNER JOIN #CopyToProperties #ctp ON glapr.PropertyID = #ctp.PropertyID
		  WHERE glapr.AccountID = @accountID


		INSERT GLAccountPropertyRestriction
		  SELECT NEWID(), @accountID, glapr.GLAccountID, #ctp.PropertyID

			FROM GLAccountPropertyRestriction glapr
				INNER JOIN #CopyToProperties #ctp ON 1 = 1
			WHERE glapr.AccountID = @accountID
			  AND glapr.PropertyID = @copyFromPropertyID


		--DELETE glap
		--	FROM GLAccountProperty glap
		--		INNER JOIN #CopyToProperties #ctp ON glap.PropertyID = #ctp.PropertyID
		--	WHERE glap.AccountID = @accountID 

		--INSERT GLAccountProperty
		--	SELECT NEWID(), @accountID, glap.GLAccountID, #ctp.PropertyID
		--	FROM GLAccountProperty glap
		--		INNER JOIN #CopyToProperties #ctp ON 1 = 1
		--	WHERE glap.AccountID = @accountID
		--	  AND glap.PropertyID = @copyFromPropertyID
	END

	CREATE TABLE #DistinctPersonIDs (
		PersonID uniqueidentifier not null)

	INSERT INTO #DistinctPersonIDs 
		SELECT DISTINCT PersonID
			FROM #CopiedPersonIDs

	--We have a list of all personIDs that we involved the copying. We need to make sure that they are all tied to the properties we copied to
	INSERT INTO PersonTypeProperty (AccountID, HasAccess, PersonTypeID, PersonTypePropertyID, PropertiesSelected, PropertyID, PropertySelected)
		SELECT DISTINCT @accountID, 1, pt.PersonTypeID, NEWID(), 0, #ctp.PropertyID, 0
			FROM PersonType pt
				INNER JOIN #CopyToProperties #ctp ON 1 = 1
				LEFT JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND #ctp.PropertyID = ptp.PropertyID
				INNER JOIN #DistinctPersonIDs #cpid ON pt.PersonID = #cpid.PersonID
			WHERE pt.AccountID = @accountID
			  AND pt.[Type] IN ('User', 'Employee')
			  AND ptp.PersonTypePropertyID IS NULL

	UPDATE ptp	
		SET HasAccess = 1
		FROM PersonType pt
			INNER JOIN #CopyToProperties #ctp ON 1 = 1
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND #ctp.PropertyID = ptp.PropertyID
			INNER JOIN #DistinctPersonIDs #cpid ON pt.PersonID = #cpid.PersonID
		WHERE pt.AccountID = @accountID
		  AND pt.[Type] IN ('User', 'Employee')
		  AND ptp.HasAccess = 0


	SELECT 0

END
GO
