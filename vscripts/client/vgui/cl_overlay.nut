// Taken from movement gym, minor refactor	
global function MovementOverlayInit														//mkos
global function ToggleMovementOverlay

const array<string> OVERLAY_KEYS =
[
	"MG_MO_W",
	"MG_MO_A",
	"MG_MO_S",
	"MG_MO_D",
	"MG_MO_CTRL",
	"MG_MO_SPACE"
]

struct
{
	bool bOverlayEnabled
	table< string, void functionref( var ) > inputfuncMap

} file 

void function MovementOverlayInit()
{
	file.inputfuncMap = 
	{
		[ "+forward" ] = Overlay_W_Pressed,
		[ "-forward" ] = Overlay_W_Released,
		[ "+moveleft" ] = Overlay_A_Pressed,
		[ "-moveleft" ] = Overlay_A_Released,
		[ "+backward" ] = Overlay_S_Pressed,
		[ "-backward" ] = Overlay_S_Released,
		[ "+moveright" ] = Overlay_D_Pressed,
		[ "-moveright" ] = Overlay_D_Released,
		[ "+duck" ] = Overlay_CTRL_Pressed,
		[ "-duck" ] = Overlay_CTRL_Released,
		[ "+jump" ] = Overlay_SPACE_Pressed,
		[ "-jump" ] = Overlay_SPACE_Released
	}
}

void function ToggleMovementOverlay( bool visible = true )
{
	if( Playlist() == ePlaylists.fs_movementgym )
		return

	if( !file.inputfuncMap.len() )
		return

	if( visible && !file.bOverlayEnabled )
	{
		foreach( element in OVERLAY_KEYS )
			Hud_SetVisible( HudElement( element ), true )
		
		foreach( command, callbackFunc in file.inputfuncMap )
			RegisterConCommandTriggeredCallback( command, callbackFunc )

		file.bOverlayEnabled = true 		
	}
	else if( file.bOverlayEnabled )
	{
		foreach( element in OVERLAY_KEYS )
			Hud_SetVisible( HudElement( element ), false )
		
		foreach( command, callbackFunc in file.inputfuncMap )
			DeregisterConCommandTriggeredCallback( command, callbackFunc )
	
		file.bOverlayEnabled = false
	}
}

void function Overlay_W_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_W" ), "%forward%" )
}

void function Overlay_W_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_W" ), "%$vgui/fonts/buttons/icon_unbound%")
}

void function Overlay_A_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_A" ), "%moveleft%")
}

void function Overlay_A_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_A" ), "%$vgui/fonts/buttons/icon_unbound%")
}

void function Overlay_S_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_S" ), "%backward%")
}

void function Overlay_S_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_S" ), "%$vgui/fonts/buttons/icon_unbound%")
}

void function Overlay_D_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_D" ), "%moveright%")
}

void function Overlay_D_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_D" ), "%$vgui/fonts/buttons/icon_unbound%")
}

void function Overlay_CTRL_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_CTRL" ), "%duck%")
}

void function Overlay_CTRL_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_CTRL" ), " ")
}

void function Overlay_SPACE_Pressed( var button )
{
	Hud_SetText( HudElement( "MG_MO_SPACE" ), "%jump%" )
}

void function Overlay_SPACE_Released( var button )
{
	Hud_SetText( HudElement( "MG_MO_SPACE" ), " " )
}