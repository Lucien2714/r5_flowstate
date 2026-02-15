global function InitEULADialog
global function OpenEULADialog
global function IsEULAAccepted
global function IsLobbyAndEULAAccepted
global function UICodeCallback_OnEULARequestCompleted
global function HasSeenEula
global function IsEulaFetched

struct
{
	var menu
	var agreement
	var acknowledgement
	var footersPanel
	var parentMenuPanel
	int eulaVersion
	bool reviewing

	string eulaContents
	string eulaLanguage
	
	bool bEulaFetched
	bool bIsEulaFetching
	bool bHasSeenEula
	
} file


void function InitEULADialog( var newMenuArg )
{	
	var menu = GetMenu( "EULADialog" )
	file.menu = menu

	SetDialog( menu, true )
	SetGamepadCursorEnabled( menu, false )

	file.agreement = Hud_GetChild( menu, "Agreement" )
	file.acknowledgement = Hud_GetRui( Hud_GetChild( menu, "Acknowledgement" ) )
	file.footersPanel = Hud_GetChild( menu, "FooterButtons" )

	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_ACCEPT", "#A_BUTTON_ACCEPT", AcceptEULA, IsNotReviewingAndStandardVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_CONTINUE", "#A_BUTTON_CONTINUE", AcceptEULA, IsNotReviewingAndEUVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_DECLINE", "#B_BUTTON_DECLINE", null, IsNotReviewingAndStandardVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CANCEL", "#CANCEL", null, IsNotReviewingAndEUVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CLOSE", "#CLOSE", null, IsReviewing )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, EULADialog_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, EULADialog_OnClose )

	FetchEULA()
}


//(mk): This does not need coroutined in scripts, since native handles via a callback.
void function FetchEULA()
{
	if( file.bEulaFetched || file.bIsEulaFetching )
		return
		
	file.bIsEulaFetching = true	
	RequestEULAContents() //(mk): this must be fired or file.bEulaFetched will remain false forever, causing "continue" to not appear for players.
}


//(mk): This function is a dependency and must always exist exactly as named.
void function UICodeCallback_OnEULARequestCompleted( bool success, string errorMsg, string language, string eulaData )
{
	file.bIsEulaFetching = false 
	
	if( !success )
	{
		string error = format( "Failed getting eula: %s", errorMsg )
		printl( error )
		
		file.eulaContents = error	
	}
	else
	{
		file.eulaContents = eulaData
		file.eulaLanguage = language
	}
	
	file.bEulaFetched = true
}


bool function IsReviewing()
{
	return file.reviewing
}


bool function IsEUVersion()
{
	return true //ShouldUserSeeEULAForEU()
}


bool function IsNotReviewingAndStandardVersion()
{
	return !IsReviewing() && !IsEUVersion()
}


bool function IsNotReviewingAndEUVersion()
{
	return !IsReviewing() && IsEUVersion()
}


void function OpenEULADialog( bool review, var parentMenu = null )
{
	file.reviewing = review
	file.parentMenuPanel = parentMenu
	AdvanceMenu( file.menu )
}


void function EULADialog_OnOpen()
{
	if( file.reviewing && file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, false )
	
	RegisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )

	var frameElem = Hud_GetChild( file.menu, "DialogFrame" )
	RuiSetImage( Hud_GetRui( frameElem ), "basicImage", $"rui/menu/common/dialog_gradient" )

	int agreementHeight = IsReviewing() ? 480 : 410
	Hud_SetHeight( file.agreement, ContentScaledYAsInt( agreementHeight ) )

	int footerPanelWidth = IsReviewing() ? 200 : 422
	Hud_SetWidth( file.footersPanel, ContentScaledXAsInt( footerPanelWidth ) )
	
	thread SetEulaText_Thread()
}


void function SetEulaText_Thread()
{
	Assert( IsNewThread(), "Must be spun off" )
	
	EndSignal( uiGlobal.signalDummy, "LevelShutdown", "OpenErrorDialog" )
	OnThreadEnd
	( 
		void function()
		{
			if( !file.bHasSeenEula )
				file.bHasSeenEula = true
		}
	)
	
	Hud_SetText( file.agreement, "Eula content is loading..." )
	
	while( !file.bEulaFetched )
		WaitFrame()
	
	//(mk): these must be set after the eula has been fetched and the return callback has fired to prevent a race conditon.
	file.eulaVersion = GetCurrentEULAVersion()
	Hud_SetText( file.agreement, file.eulaContents )
	
	//(mk): Don't set the accept button until it has been fetched fully, in order to prevent a rare case where a fast click accepts a stale file.eulaVersion
	string acknowledgementText = ""
	if ( !IsReviewing() )
		acknowledgementText = "#EULA_ACKNOWLEDGEMENT" //IsEUVersion() ? "#EULA_ACKNOWLEDGEMENT_EU" : "#EULA_ACKNOWLEDGEMENT"
	RuiSetArg( file.acknowledgement, "acknowledgementText", Localize( acknowledgementText ) )
	
	RegisterButtonPressedCallback( KEY_ENTER, AcceptEULA ) //(mk): likewise, don't register the callback until file.bEulaFetched is true to prevent rare case as well. This callback is a fallback to rare issue where mouse cannot click accept.
	RegisterButtonPressedCallback( BUTTON_START, AcceptEULA ) //(mk): controller fallback
}


void function EULADialog_OnClose()
{
	if ( uiGlobal.launching )
	{
		if ( IsEULAAccepted() )
			PrelaunchValidateAndLaunch()
		else
			SetLaunchState( eLaunchState.WAIT_TO_CONTINUE, "", Localize( "#MAINMENU_CONTINUE" ) )
	}

	if( file.reviewing && file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, true )

	DeregisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( KEY_ENTER, AcceptEULA )
	DeregisterButtonPressedCallback( BUTTON_START, AcceptEULA )
}


void function AcceptEULA( var button )
{
	SetEULAVersionAccepted( file.eulaVersion )
	CloseActiveMenu()
}


bool function IsEULAAccepted()
{
	return GetEULAVersionAccepted() >= GetCurrentEULAVersion()
}


bool function IsLobbyAndEULAAccepted()
{
	return IsLobby() &&	IsEULAAccepted()
}


void function FocusAgreementForScrolling( ... )
{
	if( !Hud_IsFocused( file.agreement ) )
		Hud_SetFocused( file.agreement )
}


bool function HasSeenEula()
{
	return file.bHasSeenEula
}


bool function IsEulaFetched()
{
	return file.bEulaFetched
}