global function InitR5RMainMenuPanel

struct
{
	var menu
	var panel
	var launchButton
	var status

	bool is_working
	
} file

void function InitR5RMainMenuPanel( var panel )
{
	RegisterSignal( "EndPrelaunchValidation" )
	RegisterSignal( "EndSearchForPartyServerTimeout" )
	RegisterSignal( "SetLaunchState" )
	RegisterSignal( "MainMenu_Think" )
	
	file.panel = GetPanel( "MainMenuPanel" )
	file.menu = GetParentMenu( file.panel )
	file.launchButton = Hud_GetChild( panel, "LaunchButton" )

	file.status = Hud_GetRui( Hud_GetChild( panel, "Status" ) )

	AddPanelEventHandler( file.panel, eUIEvent.PANEL_SHOW, OnMainMenuPanel_Show )
	Hud_AddEventHandler( file.launchButton, UIE_CLICK, LaunchButton_OnActivate )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_EXIT_TO_DESKTOP", "#B_BUTTON_EXIT_TO_DESKTOP", null, null )
	AddPanelFooterOption( panel, LEFT, BUTTON_Y, true, "#BUTTON_REVIEW_TERMS", "#REVIEW_TERMS", OpenEULAReviewFromFooter, null )
}

void function OpenEULAReviewFromFooter( var button )
{
	OpenEULADialog( IsEULAAccepted() )
}

void function LaunchButton_OnActivate( var button )
{
	if( file.is_working )
		return

	if( developer() ) //(mk): must use function call developer() here
	{
		if( !HasSeenDevWarning() && GetConVarInt( "show_dev_warning_dialogue" ) == 1 )
		{
			OpenDevWarningDialog()
			return
		}
		
		#if ( false ) //for npp
		
		#endif 
	}
	
	if( !IsEULAAccepted() && !HasSeenEula() ) //(mk): Force open eula as a fallback during continue click if not accepted and also not seen.
	{
		OpenEULADialog( false )
		return
	}

	thread LaunchLobby()
}

void function LaunchLobby()
{
	file.is_working = true

	ShowSpinner( true )
	
	#if LISTEN_SERVER
		wait 1
		CreateServer( "Lobby", "", "mp_lobby", "dev_default", eServerVisibility.OFFLINE )
	#else 
		wait 1 //(mk): for effect
		IsClientModeWarningDialog( true )
		OpenDevWarningDialog()
	#endif // LISTEN_SERVER
	
	ShowSpinner( false )

	file.is_working = false
}

void function ShowSpinner( bool show )
{
	RuiSetBool( file.status, "showSpinner", show )
	RuiSetBool( file.status, "showPrompt", !show )
}

void function OnMainMenuPanel_Show( var panel )
{
	var statusDetailsRui = Hud_GetRui( Hud_GetChild( file.panel, "StatusDetails" ) )
	var statusRui = Hud_GetRui( Hud_GetChild( file.panel, "Status" ) )

	RuiSetGameTime( statusDetailsRui, "initTime", Time() )
	RuiSetString( statusRui, "prompt", Localize("#MAINMENU_CONTINUE") )
	RuiSetBool( statusRui, "showPrompt", false )
	RuiSetBool( statusRui, "showSpinner", true )
	Hud_SetVisible( file.launchButton, false )
	
	thread WaitToShowMainMenu()
}

void function WaitToShowMainMenu()
{
	while( uiGlobal.bIsAutoLoadingLobby ) //(mk): when leaving a match via menu, scripts will attempt to auto load lobby in listen server. Wait for that state to prevent a crash from attempting to launch two servers on different threads
		WaitFrame()
		
	ShowSpinner( false )
	Hud_SetVisible( file.launchButton, true )
}