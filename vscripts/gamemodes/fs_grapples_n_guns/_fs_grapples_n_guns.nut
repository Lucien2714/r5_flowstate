global function GrapplesNGunsInit																			//mkos

global function GrapplesNGuns_ReturnGrapples
global function GrapplesNGuns_ReturnHeadshots
global function GrapplesNGuns_ReturnMelees
global function GrapplesNGuns_ReturnWins

const float UNIQUE_AUDIO_PLAYTIME_GRACE = 5.0
const table<string, string> GRAPPLES_N_GUNS_PLAYER_SETTINGS = 
{
	["acceleration"] = "550.0",
	["airacceleration"] = "1000.0",
	["airspeed"] = "150.0",
	["automantle_enable"] = "1.0",
	/* ["doublejump"] = "0.0", */
	["gravityscale"] = "0.85",
	["grapple_detachAwaySpeed"] = "4000.0",
	["impactSpeed"] = "380.0",
	["jumpheight"] = "120.0",
	["landslowdownduration"] = "0.0",
	["leech_range"] = "64.0",
	["slidedecel"] = "50.0",
	["slidevelocitydecay"] = "0.7",
	["stepheight"] = "18.0",
	["superjumpHorzSpeed"] = "180.0",
	["superjumpMaxHeight"] = "60.0",
	["superjumpMinHeight"] = "60.0",
	["wallrun"] = "1.0",
	["wallrunAccelerateHorizontal"] = "1500.0",
	["wallrunAccelerateVertical"] = "360.0",
	["wallrunJumpInputDirSpeed"] = "80.0",
	["wallrunJumpOutwardSpeed"] = "205.0",
	["wallrunJumpUpSpeed"] = "230.0",
	["wallrunMaxSpeedHorizontal"] = "420.0",
	["wallrunMaxSpeedVertical"] = "225.0",
	["wallrun_timeLimit"] = "1.75",
	["ziplineSpeed"] = "600.0",
	["skip_time"] = "0.0",
	["antiMultiJumpHeightFrac"] = "1.0"
}

enum eSoundCategories
{
	ANY,
	ATTACH,
	HEADSHOT,
	MELEE,
	WINNER,
	LOSS,
	INTRO
}

struct GrapplesNGunsStats
{
	int grapples 
	int melees 
	int headshots
	int wins
}

struct
{
	array<string> headshotAudio
	array<string> introAudio
	array<string> winnerAudio
	array<string> lossAudio
	array<string> grappleAudio
	array<string> meleeAudio
	
	table<string,GrapplesNGunsStats> playerStats
	
} file

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////			INIT				////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

void function GrapplesNGunsInit()
{		
	if( GetCurrentPlaylistVarBool( "use_custom_audio", true ) )
	{
		WorldAssets_SetAllGroupsFunc( RegisterAudioGroups )
		WorldAssets_SetAllAssetsFunc( RegisterGroupAssets )
		WorldAssets_Init() //init early before callbacks

		AddCallback_OnClientConnected( OnConnected )
		SetFSCallback_ShouldTimerEnd( TimerFunction )
		AddCallback_OnTdmStateEnter_InProgress( OnGamePlaying )
		AddCallback_OnTdmStateEnter_EndGame( OnGameEnd )
		AddHeadshotCallback( "player", OnHeadshot )
	}
	
	AddCallback_OnClientConnected( SetupStatsForPlayer )
	Tracker_AddDestroyStatCallback( ResetStatsForAllPlayers )
	AddFSCallback_OnRespawned( OnRespawned )
}

void function RegisterAudioGroups()
{
	WorldAssets_RegisterAudioGroup
	(
		"grapples_n_guns_audio",
		true //is audio interruptable: true, or queued: false
	)
	
	WorldAssets_RegisterAudioGroup
	(
		"grapples_n_guns_audio_announce",
		false //is audio interruptable: true, or queued: false
	)
}

void function RegisterGroupAssets()
{
	array<string> audioAssets = WorldDrawAsset_GetAssetArrayByCategory( "grapples_n_guns" )
	foreach( assetRef in audioAssets )
	{
		WorldAssets_GroupAppendAsset( "grapples_n_guns_audio", assetRef )
		
		if( assetRef.find( "_hs" ) != -1 )
			file.headshotAudio.append( assetRef )
			
		if( assetRef.find( "_attach" ) != -1 )
			file.grappleAudio.append( assetRef )
			
		if( assetRef.find( "_melee" ) != -1 )
			file.meleeAudio.append( assetRef )
	}
		
	array<string> audioAnnounceAssets = WorldDrawAsset_GetAssetArrayByCategory( "grapples_n_guns_announce" )
	foreach( assetRef in audioAnnounceAssets )
	{
		WorldAssets_GroupAppendAsset( "grapples_n_guns_audio_announce", assetRef )
		
		if( assetRef.find( "_intro" ) != -1 )
			file.introAudio.append( assetRef )
			
		if( assetRef.find( "_win" ) != -1 )
			file.winnerAudio.append( assetRef )
			
		if( assetRef.find( "_loss" ) != -1 )
			file.lossAudio.append( assetRef )
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////			GAMESTATE				////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

void function OnConnected( entity player ) //only runs if audio enabled.
{
	if( GetTDMState() != eTDMState.IN_PROGRESS )
		return 
	
	AddEntityCallback_OnGrappled( player, OnGrappled )
	AddEntityCallback_OnMeleed( player, OnMeleed )
	
	thread //must wait for players channels to be created for audio
	(
		void function() : ( player )
		{
			if( !IsValid( player ) )
				return

			player.EndSignal( "OnDestroy" )
			player.WaitSignal( "FSOnRespawned" )
			
			if( GetTDMState() != eTDMState.IN_PROGRESS ) //already handled by OnGamePlaying
				return
		
			WorldAssets_WaitForChannelCreation( player, "grapples_n_guns_audio_announce" )	
			WorldAssets_PlayAudio( player, file.introAudio.getrandom(), "grapples_n_guns_audio_announce" )
		}
	)()
}

void function OnGamePlaying()
{
	AnnounceToPlayers( file.introAudio.getrandom(), GetPlayerArray() )
}

void function OnGameEnd()
{
	entity winner = GetBestPlayer()
	array<entity> players = GetPlayerArray()
	
	if( IsValid( winner ) )
	{
		players.fastremovebyvalue( winner )
		
		GetStats( winner.p.UID ).wins++
		AnnounceToPlayers( file.winnerAudio.getrandom(), [ winner ] )
	}
	
	ArrayRemoveInvalid( players )
	AnnounceToPlayers( file.lossAudio.getrandom(), players )
}

void function OnRespawned( entity player )
{
	thread
	(
		void function() : ( player )
		{
			if( !IsValid( player ) )
				return
			
			player.EndSignal( "OnDestroy" )			
			
			wait 1 //yet to determine why calling SetClassVar causes sync issues closely with SetPlayerSettingsWithMods, which is called during DecideRespawn
			
			foreach( string key, string value in GRAPPLES_N_GUNS_PLAYER_SETTINGS )
				player.SetClassVar( key, value )
				
			Inventory_SetPlayerEquipment( player, "helmet_pickup_lv1", "helmet" )
			
			player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
			player.TakeOffhandWeapon( OFFHAND_MELEE )
			player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
			player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
		}
	)()
}

void function OnHeadshot( entity player, var damageInfo )
{
	entity attacker = InflictorOwner( DamageInfo_GetInflictor( damageInfo ) )	
	
	if( !attacker.IsPlayer() )
		return
		
	GetStats( attacker.p.UID ).headshots++
	PlayUniqueRandomSoundForPlayers( [ attacker ], file.headshotAudio )
}

void function OnMeleed( entity attacker, entity ent, var damageInfo )
{
	if( !attacker.IsPlayer() )
		return

	GetStats( attacker.p.UID ).melees++
	PlayUniqueRandomSoundForPlayers( [ attacker ], file.meleeAudio )
}

void function OnGrappled( entity grapplePlayer, entity hitent, vector hitpos, vector hitNormal )
{
	if( IsValid( grapplePlayer ) && grapplePlayer.IsPlayer() && hitent.IsPlayer() )
	{
		GetStats( grapplePlayer.p.UID ).grapples++
		PlayUniqueRandomSoundForPlayers( [ grapplePlayer, hitent ], file.grappleAudio, eSoundCategories.ATTACH )
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////			AUDIO				////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

void function AnnounceToPlayers( string audioRef, array<entity> players )
{
	foreach( player in players )
		WorldAssets_PlayAudio( player, audioRef, "grapples_n_guns_audio_announce" )
}

const table< int, string > EVENT_ANNOUNCE_TIMES =
{
	[ 20 ] = "media/playlists/grapples_n_guns/grapples_countdown_20sec.bik",
	[ 60 ] = "media/playlists/grapples_n_guns/grapples_countdown_1min.bik"
}

bool function TimerFunction( int timeRemaining )
{
	if( ( timeRemaining in EVENT_ANNOUNCE_TIMES ) )
		AnnounceToPlayers( EVENT_ANNOUNCE_TIMES[ timeRemaining ], GetPlayerArray() )
	
	return false// returning true would end the game.
}

void function PlayUniqueRandomSoundForPlayers( array<entity> players, array<string> soundArray, int eSoundCategory = 0, string audioGroup = "grapples_n_guns_audio" )
{
	array<string> uniqueSounds = clone soundArray
	array<string> lastPlayedRefs
	
	foreach( player in players )
	{
		#if DEVELOPER
			printf
			(
				"[GrapplesNGuns] Last played audio for player %s was \"%s\"",
				player.GetPlayerName(),
				WorldAssets_GetLastPlayedAudio( player, audioGroup ).assetRef
			)
		#endif 
		
		lastPlayedRefs.append( WorldAssets_GetLastPlayedAudio( player, audioGroup ).assetRef )
				
		if( eSoundCategory == eSoundCategories.ATTACH )
		{
			float lastPlayedComeHereSound = WorldAssets_GetAudioHistoryForPlayerForAsset( player, "attach_come_here" ).lastPlayTime
			float lastPlayedGetOverHereSound = WorldAssets_GetAudioHistoryForPlayerForAsset( player, "attach_get_over" ).lastPlayTime
			float currentTime = Time()
			
			if( currentTime - lastPlayedComeHereSound < UNIQUE_AUDIO_PLAYTIME_GRACE )
				lastPlayedRefs.append( "media/playlists/grapples_n_guns/grapples_attach_come_here.bik" )
			
			if( currentTime - lastPlayedGetOverHereSound < UNIQUE_AUDIO_PLAYTIME_GRACE )
				lastPlayedRefs.append( "media/playlists/grapples_n_guns/grapples_attach_get_over.bik" )
		}
	}
	
	lastPlayedRefs = ArrayUniqueString( lastPlayedRefs )
	
	foreach( lastPlayedRef in lastPlayedRefs )
		uniqueSounds.fastremovebyvalue( lastPlayedRef )
	
	foreach( player in players )
	{
		print_string_array( uniqueSounds )
		
		if( uniqueSounds.len() )
			WorldAssets_PlayAudio( player, uniqueSounds.getrandom(), audioGroup )
		else
			WorldAssets_PlayAudio( player, soundArray.getrandom(), audioGroup )
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////			STATS				////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

void function SetupStatsForPlayer( entity player )
{
	string uid = player.p.UID
	if( uid in file.playerStats )
		return 
		
	GrapplesNGunsStats statsTemplate
	file.playerStats[ uid ] <- statsTemplate
}

void function ResetStatsForAllPlayers()
{
	foreach( string uid, GrapplesNGunsStats stats in file.playerStats )
	{
		GrapplesNGunsStats newStats
		file.playerStats[ uid ] = newStats
	}
}

GrapplesNGunsStats function GetStats( string uid )
{
	if( uid in file.playerStats )
		return file.playerStats[ uid ]
	
	GrapplesNGunsStats emptyStats //should never be hit
	return emptyStats
}

var function GrapplesNGuns_ReturnGrapples( string uid )
{
	return GetStats( uid ).grapples
}

var function GrapplesNGuns_ReturnHeadshots( string uid )
{
	return GetStats( uid ).headshots
}

var function GrapplesNGuns_ReturnMelees( string uid )
{
	return GetStats( uid ).melees
}

var function GrapplesNGuns_ReturnWins( string uid )
{
	return GetStats( uid ).wins
}