global function InitDevWarningDialog														//mkos -- copied and modified menu_eula_dialog.nut
global function HasSeenDevWarning
global function OpenDevWarningDialog
global function IsClientModeWarningDialog

/*
	This dialog is also used for the client mode warning.
*/

struct
{
	var menu
	var warningHeader
	var warningComponent
	var acknowledgement
	var footersPanel
	var parentMenuPanel
	bool bHasSeenWarning
	bool bIsClientModeWarning

} file

bool function HasSeenDevWarning( bool ornull setting = null )
{
	if( setting != null )
		file.bHasSeenWarning = expect bool( setting )
		
	return file.bHasSeenWarning
}

void function InitDevWarningDialog( var newMenuArg )
{	
	var menu = GetMenu( "DevWarningDialog" )
	file.menu = menu

	SetDialog( menu, true )
	SetGamepadCursorEnabled( menu, false )

	file.warningHeader 		= Hud_GetChild( menu, "DialogHeader" )
	file.warningComponent 	= Hud_GetChild( menu, "DevWarning" )
	file.acknowledgement	= Hud_GetRui( Hud_GetChild( menu, "Acknowledgement" ) )
	file.footersPanel 		= Hud_GetChild( menu, "FooterButtons" )

	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_ACCEPT", "#MOUSE_CLICK_ACCEPT", AcceptDevWarning )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "", "", AcceptDevWarning )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, DevWarningDialog_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, DevWarningDialog_OnClose )
}

void function OpenDevWarningDialog( var parentMenu = null )
{
	file.parentMenuPanel = parentMenu
	AdvanceMenu( file.menu )
}

bool function IsClientModeWarningDialog( bool ornull setting = null )
{
	if( setting != null )
		file.bIsClientModeWarning = expect bool( setting )
		
	return file.bIsClientModeWarning
}

void function DevWarningDialog_OnOpen()
{
	if( file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, false )
	
	if( !file.bHasSeenWarning )
		file.bHasSeenWarning = true
	
	RegisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )

	var frameElem = Hud_GetChild( file.menu, "DialogFrame" )
	RuiSetImage( Hud_GetRui( frameElem ), "basicImage", $"rui/menu/common/dialog_gradient" )

	Hud_SetHeight( file.warningComponent, ContentScaledYAsInt( 480 ) )
	Hud_SetWidth( file.footersPanel, ContentScaledXAsInt( 200 ) )
	
	if( file.bIsClientModeWarning )
	{
		Hud_SetText( file.warningHeader, Localize( "#CLIENT_MODE_HEADER" ) )
		Hud_SetText( file.warningComponent, Localize( "#CLIENT_MODE_WARNING_TEXT" ) )
		
		file.bIsClientModeWarning = false
	}
	else 
	{
		Hud_SetText( file.warningHeader, Localize( "#DEV_WARNING_HEADER" ) )
		Hud_SetText( file.warningComponent, Localize( "#DEV_WARNING_TEXT" ) )
	}
		
	RegisterButtonPressedCallback( KEY_ENTER, AcceptDevWarning )
	RegisterButtonPressedCallback( BUTTON_START, AcceptDevWarning )
	RegisterButtonPressedCallback( KEY_ESCAPE, AcceptDevWarning )
}

void function DevWarningDialog_OnClose()
{
	if( file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, true )

	DeregisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( KEY_ENTER, AcceptDevWarning )
	DeregisterButtonPressedCallback( BUTTON_START, AcceptDevWarning )
	DeregisterButtonPressedCallback( KEY_ESCAPE, AcceptDevWarning )
}

void function AcceptDevWarning( var button )
{
	CloseActiveMenu()
}

void function FocusAgreementForScrolling( ... )
{
	if( !Hud_IsFocused( file.warningComponent ) )
		Hud_SetFocused( file.warningComponent )
}