global function GrapplesNGunsInit

struct
{
	
	
} file 


const table GRAPPLES_N_GUNS_PLAYER_SETTINGS = 
{
	["acceleration"] = 550.0,
	["airacceleration"] = 1000.0,
	["airspeed"] = 150.0,
	["automantle_enable"] = 1.0,
	["doublejump"] = 0.0,
	["gravityscale"] = 0.85,
	["grapple_detachAwaySpeed"] = 4000.0,
	["impactSpeed"] = 380.0,
	["jumpheight"] = 120.0,
	["landslowdownduration"] = 0.0,
	["leech_range"] = 64.0,
	["slidedecel"] = 50.0,
	["slidevelocitydecay"] = 0.7,
	["stepheight"] = 18.0,
	["superjumpHorzSpeed"] = 180.0,
	["superjumpMaxHeight"] = 60.0,
	["superjumpMinHeight"] = 60.0,
	["wallrun"] = 0.0,
	["wallrunAccelerateHorizontal"] = 1500.0,
	["wallrunAccelerateVertical"] = 360.0,
	["wallrunJumpInputDirSpeed"] = 80.0,
	["wallrunJumpOutwardSpeed"] = 205.0,
	["wallrunJumpUpSpeed"] = 230.0,
	["wallrunMaxSpeedHorizontal"] = 420.0,
	["wallrunMaxSpeedVertical"] = 225.0,
	["wallrun_timeLimit"] = 1.75,
	["ziplineSpeed"] = 600.0,
	["skip_time"] = 0.0,
	["antiMultiJumpHeightFrac"] = 1.0
}

void function GrapplesNGunsInit()
{	
	AddCallback_OnClientConnected( OnConnected )
	AddCallback_OnPlayerRespawned( OnRespawned )
	AddHeadshotCallback( "player", OnHeadshot )
	
	AddFSCallback_ShouldTimerEnd( TimerFunction )
	AddCallback_OnTdmStateEnter_InProgress( OnGamePlaying )
	AddCallback_OnTdmStateEnter_EndGame( OnGameEnd )
	
	BannerAssets_SetAllGroupsFunc( RegisterAudioGroup )	//must be called first
	BannerAssets_SetAllAssetsFunc( RegisterGroupAssets )
	BannerAssets_Init()
}

void function RegisterAudioGroup()
{
	BannerAssets_RegisterAudioGroup
	(
		"grapples_n_guns_audio",
		true //is audio interruptable: true, or queued: false
	)
}

void function RegisterGroupAssets()
{
	array<string> audioAssets = WorldDrawAsset_GetAssetArrayByCategory( "grapples_n_guns" )

	foreach( assetRef in audioAssets )
		BannerAssets_GroupAppendAsset( "grapples_n_guns_audio", WorldDrawAsset_AssetRefToID( assetRef ) )
}

void function OnConnected( entity player )
{
	
}

const array INTRO_AUDIO =
[
	"intro1",
	"intro2",
	"intro3"
]

void function OnGamePlaying()
{
	Announce( INTRO_AUDIO.getrandom() )
}

const array OUTRO_AUDIO =
[
	"outro1",
	"outro2",
	"outro3",
]

void function OnGameEnd()
{
	Announce( OUTRO_AUDIO.getrandom() )
}

void function Announce( string audioName )
{
	foreach( player in GetPlayerArray() )
		BannerAssets_PlayAudioName( player, audioName )
}

const table< int, string > EVENT_ANNOUNCE_TIMES =
{
	[ 0 ] = "proof of concept"
}

bool function TimerFunction( int timeRemaining )
{
	if( ( timeRemaining in EVENT_ANNOUNCE_TIMES ) )
		Announce( EVENT_ANNOUNCE_TIMES[ timeRemaining ] )
	
	return false
}

void function OnRespawned( entity player )
{
	thread
	(
		void function() : ( player )
		{
			if( !IsValid( player ) )
				return 
				
			player.EndSignal( "OnDestroy", "OnDeath" )
				
			wait 3 //Todo: unweave fsdm logic, so fsdm modes have more control.
			
			foreach( string key, float value in GRAPPLES_N_GUNS_PLAYER_SETTINGS )
				player.SetClassVar( key, value.tostring() )
				
			Inventory_SetPlayerEquipment( player, "helmet_pickup_lv1", "helmet" )
		}
	)()
}

const array< string > HEADSHOT_SOUND_NAMES =
[
	"cash",
	"coin",
	"meow",
	"uwu",
	"terminated"
]

void function OnHeadshot( entity player, var damageInfo )
{
	entity attacker = InflictorOwner( DamageInfo_GetInflictor( damageInfo ) )	
	
	if( !attacker.IsPlayer() )
		return
		
	if( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
	{
		string sound = HEADSHOT_SOUND_NAMES.getrandom()
		BannerAssets_PlayAudioName( attacker, sound )
	}
}