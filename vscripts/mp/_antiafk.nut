global function Flowstate_Afk_Init
global function Flowstate_InitAFKThreadForPlayer

struct 
{
	float Flowstate_antiafk_warn
	float Flowstate_antiafk_grace
	float Flowstate_antiafk_interval
	
	bool flowstate_afk_kick_enable
	bool enable_afk_thread
	
} file

enum eAntiAfkPlayerState
{
	ACTIVE
	SUSPICIOUS
	AFK
}

void function Flowstate_Afk_Init()
{
	file.Flowstate_antiafk_warn 	= GetCurrentPlaylistVarFloat( "Flowstate_antiafk_warn", 15.0 )
	file.Flowstate_antiafk_grace 	= GetCurrentPlaylistVarFloat( "Flowstate_antiafk_grace", bAfkToRest() ? 45 : 120 )
	file.Flowstate_antiafk_interval = GetCurrentPlaylistVarFloat( "Flowstate_antiafk_interval", 10.0 )
	file.flowstate_afk_kick_enable 	= GetCurrentPlaylistVarBool( "flowstate_afk_kick_enable", true )
	file.enable_afk_thread 			= GetCurrentPlaylistVarBool( "enable_afk_thread", true )
}

void function Flowstate_InitAFKThreadForPlayer( entity player )
{
	#if DEVELOPER
		//return
	#endif

	if( !IsValid( player ) )
		return 
		
	//(mk): these are needed for game logic that utilizs p.lastmoved 
	AfkThread_AddPlayerCallbacks( player ) //readded mkos
	SetPlayerMoved( player )

	if( !file.flowstate_afk_kick_enable || !file.enable_afk_thread ) // IsAdmin( player ) //(mk): removed admin check here so admins can still be afked-to-rest
		return

	//player.SetSendInputCallbacks( true ) //disabled internal call
	thread CheckAfkKickThread( player )
}

int function GetAfkState( entity player )
{
    float localgrace = file.Flowstate_antiafk_grace
    float warn = file.Flowstate_antiafk_warn

	float lastmove = player.p.lastmoved
	
	if( bAfkToRest() && !Gamemode1v1_IsPlayerResting( player ) )
	{
		if ( Time() > lastmove + ( localgrace - warn ) )
		{
			if ( Time() > lastmove + localgrace )
				return eAntiAfkPlayerState.AFK

			return eAntiAfkPlayerState.SUSPICIOUS
		}
	}

    return eAntiAfkPlayerState.ACTIVE
}

void function AfkWarning( entity player )
{	
	if ( bAfkToRest() )
	{	
		LocalMsg( player, "#FS_AFK_ALERT", "#FS_AFK_REST_MSG", eMsgUI.DEFAULT, 10, "", string( file.Flowstate_antiafk_warn ) )		
	} 
	else
	{
		LocalMsg( player, "#FS_AFK_ALERT", "#FS_AFK_KICK_MSG", eMsgUI.DEFAULT, 10, "", string( file.Flowstate_antiafk_warn ) )
	}
}

void function CheckAfkKickThread(entity player)
{	
	//printt("Flowstate - AFK thread initialized for " + player.GetPlayerName() )	
	for( ; ; )
	{
		wait file.Flowstate_antiafk_interval
		
		if( !IsValid( player ) )
			break
		
        if ( GetGameState() != eGameState.Playing )
			continue
		
		if ( !IsAlive( player ) )
			continue
		
		if ( player.p.isSpectating )
			continue
			
		if ( bAfkToRest() && Gamemode1v1_IsRestEnabled() && Gamemode1v1_IsPlayerInState( player, e1v1State.RESTING ) )
			continue
		
		switch ( GetAfkState( player ) )
		{
			case eAntiAfkPlayerState.ACTIVE:
				break
		
			case eAntiAfkPlayerState.SUSPICIOUS:
				AfkWarning( player )
				break
			
			case eAntiAfkPlayerState.AFK:
				if ( bAfkToRest() )
				{
					player.p.lastmoved = Time()
					
					if( Gamemode1v1_IsRestEnabled()  )
					{
						if( Gamemode1v1_IsPlayerResting( player ) )
						{
							SetPlayerMoved( player )
							continue
						}
						
						Gamemode1v1_ForceRest( player )
					}
					else
						mAssert( false, "Playlist has afk_to_rest enabled, but mode has rest disabled internally. Try using Gamemode1v1_SetRestEnabled()" )
						//(mk): We WANT to assert here, because otherwise, this condition will always run with no effect. 
				}
				else
				{	
					if( !IsAdmin( player ) )
						KickPlayerById( player.GetPlatformUID(), "You were AFK for too long" )
				}
				break
				
			default:
				mAssert( false, "No valid afk rest state returned" )
				//Scripter issue.
				break
		}
		
		wait 1		
    }
}

void function SetPlayerMoved( entity player )
{
    player.p.lastmoved = Time()
}

void function AfkThread_AddPlayerCallbacks( entity player )
{
	AddPlayerPressedForwardCallback( player, SetPlayerMoved, 1 )
	AddPlayerPressedBackCallback( player, SetPlayerMoved, 1 )
	AddPlayerPressedLeftCallback( player, SetPlayerMoved, 1 )
	AddPlayerPressedRightCallback( player, SetPlayerMoved, 1 )
	
	
	//disabled and reworked to above (fixed callback move inputs) -- mkos
	
	/*
	AddButtonPressedPlayerInputCallback( player, IN_ATTACK, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_JUMP, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_FORWARD, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_BACK, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_USE, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_MOVELEFT, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_MOVERIGHT, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_LEFT, SetPlayerMoved )
	AddButtonPressedPlayerInputCallback( player, IN_RIGHT, SetPlayerMoved )
	*/
}