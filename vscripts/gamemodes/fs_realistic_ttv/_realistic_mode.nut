//RealisticMode 																			//mkos
//Just a regular Flowstate gamemode with some tweaks & extra features

global function RealisticMode_Init
global function RealisticMode_GivePlayerBonusHeals
global function RealisticMode_GetBestSpawnPointFFA
global function RealisticMode_GetBotKills
 
#if DEVELOPER
	global function DEV_PrintTrackedDoors
	global function DEV_RealisticModeGetAllDummies
#endif

const vector TTV_BUILDING_ORIGIN 						= < 9864.35, 5497.93, -3567.97 >
const float TTV_BUILDING_RADIUS 						= 4500.0
const float DOOR_RESPAWN_PLAYER_RADIUS_LIMIT 			= 130.0
const float DOOR_REGEN_GRACE 							= 60
const int HIGH_PLAYER_COUNT_THRESHOLD					= 6
const float SCHED_ATTACK1_ANIM_LEN 						= 1.3
const string SCHED_MELEE 								= "SCHED_MELEE_ATTACK1"
const vector TIMEOUT_ORIGIN 							= < 0, 0, 50001 >
const vector TIMEOUT_ANGLES 							= < 0, 0, 0 >
const vector ZIPLINE_TRIGGER_ORIGIN 					= < 9762.2, 5399.29, -4295.97 >
const vector ZIPLINE_TRIGGER_ANGLES 					= < 271, 127.178, 0 >
const float ZIPLINE_TRIGGER_RADIUS 						= 150
const float ZIPLINE_TRIGGER_HEIGHT 						= 650
const float STANDARD_PORTAL_DESTROY_DELAY 				= 3.0
const vector MYSTIC_MAGICAL_ELEVATOR_SHAFT_ORIGIN 		= < 9761, 5392.29, -4295.97 >
const float MAX_ELEVATOR_SUCKING_BEHAVIOR_RADIUS 		= 150
const bool PHASE_TUNNEL_DEBUG_DRAW_PROJECTILE_TELEPORT	= false
const float MAX_KIDNAP_TIME_AFTER_END_PORTAL 			= 1.85

const array<string> STANDARD_REALISTIC_KILL_LOOT = 
[
	"health_pickup_combo_small", 
	"health_pickup_combo_small", 
	"health_pickup_combo_large",
	"health_pickup_health_large",
	"mp_weapon_grenade_emp"
]

const array<string> STANDARD_SPAWN_LOOT = 
[
	"health_pickup_combo_small",
	"health_pickup_combo_small",
	"health_pickup_health_small",
	"health_pickup_health_small",
	"mp_weapon_grenade_emp",
	"health_pickup_combo_large",
	"health_pickup_health_large"
	// "optic_cq_hcog_classic",
	// "optic_cq_hcog_bruiser",
	// "optic_cq_holosight",
	// "optic_ranged_hcog",
	// "optic_ranged_aog_variable"
]

const array<string> TIER_ZERO_LOOT =
[
	"health_pickup_combo_small",
	"health_pickup_health_small"
]

const array<string> TIER_ONE_LOOT = 
[
	"health_pickup_combo_large",
	"health_pickup_health_large",
]

const array<string> TIER_TWO_LOOT =
[
	"mp_weapon_grenade_emp",
	"mp_weapon_thermite_grenade",
	"mp_weapon_frag_grenade"
]

const array<string> TIER_THREE_LOOT =
[
	"mp_weapon_sniper"
]

const array<string> AIRDROP_ITEMS_POOL =
[
	"armor_pickup_lv3",
	"armor_pickup_lv3",
	"mp_weapon_sniper"
]

struct DoorDataStruct
{
    entity door
	bool bLinkOwner
	int index = -1
	int linkedDoorIdx = -1
	bool bHasLink
    vector origin
    vector angles
    asset model
    string scriptName
	float lastDestroyTime
}

struct 
{
	array< SpawnData > gamemodeSpawns
	array< SpawnData > aiSpawns
	array< DoorDataStruct > trackedDoors
	array< entity > aiBots
	array< entity > aiBotsForPlayers
	table< entity, ItemFlavor ornull > tbl_selectedLegends
	array< SpawnData > lootSpawns
	array< SpawnData > airDropSpawnData
	
	int iTrackedDoors
	int max_players_for_bots
	int min_players_for_bots
	float fRandomDummySpawnMinTime
	float fRandomDummySpawnMaxTime
	bool bLegendChangeEnabled
	bool bAllowLegendAbilities
	bool bEnableTrainingMode
	bool bGiveHeirloom
	bool bTrainingModeActive
	bool bBotsEnabled
	
	table infoSignal

} file 

void function RealisticMode_Init()
{
	RegisterSignal( "PlayerSkyDive" )
	
	Onboarding_SetNegateDespawnStats( true )
	AddCallback_OnDoorInteraction( OnDoorInteraction )
	AddCallback_EntitiesDidLoad( InitializeDoorTracking )
	AddCallback_OnPlayerWeaponAttachmentChanged( Realistic_OnWeaponAttachmentChanged )
	AddFSCallback_OnRespawned( RealisticMode_OnSpawned )
	AddDeathCallback( "player", OnPlayerKilledCommon )

	SpawnSystem_InitGamemodeOptions()
	
	int eMap 				= SpawnSystem_FindBaseMapForPak( MapName() )
	file.gamemodeSpawns 	= SpawnSystem_ReturnAllSpawnLocations( eMap )
	
	mAssert( file.gamemodeSpawns.len() > 0, "No valid spawns configured" )
	
	#if DEVELOPER
		printw( file.gamemodeSpawns.len(), "Realistic TTV Spawns loaded for ", AllMapsArray()[ eMap ] )
	#endif
	
	if ( !FlowState_AdminTgive() )
		INIT_WeaponsMenu()
	else 
		INIT_WeaponsMenu_Disabled()	
		
	if( GetCurrentPlaylistVarBool( "random_dummy_spawn", true ) )
	{	
		file.fRandomDummySpawnMinTime = GetCurrentPlaylistVarFloat( "random_dummy_spawn_mintime", 100.0 )
		file.fRandomDummySpawnMaxTime = GetCurrentPlaylistVarFloat( "random_dummy_spawn_maxtime", 250.0 )
		thread SpawnDummyOnRandomPlayer_Thread()
	}
	
	file.bEnableTrainingMode = GetCurrentPlaylistVarBool( "realistic_ttv_ai_training_feature", false )
	
	if( file.bEnableTrainingMode )
	{
		file.aiSpawns = SpawnSystem_ReturnAllSpawnLocationsFromDatatable( "datatable/fs_spawns_realistic_ai.rpak" )
		
		if( file.aiSpawns.len() == 0 )
			mAssert( 0, "Tried to launch 'ai_training_mode' but there are no valid ai spawns" )
		
		RegisterSignal( "RealisticTTV_KillTrainingThread" )
		RegisterSignal( "RealisticTTV_SpawnTrainingDummy" )
		AddClientCommandCallbackVoid( "training", ClientCommand_RealisticTrainingMode )
		
		file.max_players_for_bots = GetCurrentPlaylistVarInt( "realistic_max_players_for_bots", 0 ) 
		file.min_players_for_bots = GetCurrentPlaylistVarInt( "realistic_min_players_for_bots", 0 )
		
		if( GetCurrentPlaylistVarBool( "realistic_ttv_ai_training_mode_auto_start", false ) )
		{	
			if( file.max_players_for_bots > 0 || file.min_players_for_bots > 0 )
			{
				AddCallback_OnClientDisconnected( CheckPlayerCountForBots )
				AddCallback_OnClientConnected( CheckPlayerCountForBots )
			}
			
			AddCallback_EntitiesDidLoad( AiTrainingModeThread ) //threads in callbacks
		}
	}
	
	if( file.bEnableTrainingMode || GetCurrentPlaylistVarBool( "random_dummy_spawn", true ) )
	{
		file.bBotsEnabled = true
				
		AddCallback_OnTdmStateEnter_InProgress( DummyResetIfAlive )
		AddCallback_OnTdmStateEnter_EndGame( DummyPauseAggro )
		AddCallback_OnClientConnected( OnConnectedSetupPlayerForBots )
	}
	
	AddCallback_OnTdmStateEnter_EndGame( OnGameEnd )
	
	file.bLegendChangeEnabled = GetCurrentPlaylistVarBool( "allow_legend_select", false )
	AddClientCommandCallbackVoid( "legend_select", AssignCharacter )
	if( file.bLegendChangeEnabled )
		AddCallback_OnClientDisconnected( CleanupCharacterTable )
	
	file.bAllowLegendAbilities	= GetCurrentPlaylistVarBool( "realistic_mode_allow_legend_abilities", false )
	file.bGiveHeirloom			= GetCurrentPlaylistVarBool( "realistic_mode_give_heirloom", false )

	if( GetCurrentPlaylistVarBool( "realistic_enable_spectate", true ) )
	{
		// SetDefaultObserverBehavior( DetermineObservee )
		AddClientCommandCallbackVoid( "realistic_mode_spectate", ClientCommand_RealisticSpectate )
		// AddClientCommandCallbackVoid( "spec_next", ClientCommand_SpecNext )
		// AddClientCommandCallbackVoid( "spec_prev", ClientCommand_SpecPrev )
	}
	
	if( GetCurrentPlaylistVarBool( "realistic_player_timeout_enabled", true ) )
	{
		SpawnOITCRoom( < 0, 0, 50000 > )
		AddCallback_TimedOut( OnTimedOut ) 
	}
	
	if( GetCurrentPlaylistVarBool( "realistic_npc_zipline_think", false ) ) //proto
		SetupZiplineTriggerForNpcs()
		
	if( GetCurrentPlaylistVarBool( "realistic_portal_tracking", true ) )
		AddCallback_OnPlayerPlacedPortalEnd( OnPortalPlaced )
		
	if( GetCurrentPlaylistVarBool( "realistic_ground_loot", true ) )
		RealisticGroundLootInit()
		
	if( GetCurrentPlaylistVarBool( "realistic_air_drops", true ) )
		RealisticAirDropsInit()
}

void function RealisticGroundLootInit()
{
	file.lootSpawns = SpawnSystem_ReturnAllSpawnLocationsFromDatatable( "datatable/fs_spawns_realistic_lootspawns.rpak" )
	
	float minWait 	= GetCurrentPlaylistVarFloat( "realistic_ground_loot_spawn_min", 10 )
	float maxWait 	= GetCurrentPlaylistVarFloat( "realistic_ground_loot_spawn_max", 25 )
	int numItems	= GetCurrentPlaylistVarInt( "realistic_ground_loot_num_items_at_once", 8 )
	
	mAssert( file.lootSpawns.len() != 0, "Tried to enable \"realistic_ground_loot\", but no valid lootspawns were configured." )
	mAssert( minWait < maxWait, "\"realistic_ground_loot_spawn_min\" must be greater than \"realistic_ground_loot_spawn_max\"" )
	mAssert( numItems > 0, "\"realistic_ground_loot_num_items_at_once\" must be greater than 0. Set \"realistic_ground_loot 0\" to disable instead." )
	
	thread __SpawnLootAtIntervals( minWait, maxWait, numItems )
}

void function RealisticAirDropsInit()
{
	file.airDropSpawnData = SpawnSystem_ReturnAllSpawnLocationsFromDatatable( "datatable/fs_spawns_realistic_airdrops.rpak" )
	
	float minWait = GetCurrentPlaylistVarFloat( "realistic_airdrop_spawn_min", 60 )
	float maxWait = GetCurrentPlaylistVarFloat( "realistic_airdrop_spawn_max", 180 )
	
	mAssert( minWait < maxWait, "\"realistic_airdrop_spawn_min\" must be less than \"realistic_airdrop_spawn_max\" " )
	mAssert( file.airDropSpawnData.len() != 0, "Tried to enable \"realistic_air_drops\", but no spawns were configured for air drops." )
	
	thread __SpawnAirDropsAtIntervals( minWait, maxWait )
}

void function __SpawnAirDropsAtIntervals( float minWait, float maxWait )
{
	svGlobal.levelEnt.EndSignal( "GameEnd" )
	
	for( ; ; )
	{
		wait RandomFloatRange( minWait, maxWait )
		
		if( file.airDropSpawnData.len() == 0 )
		{
			#if DEVELOPER 
				Warning( "Ran out of spawns for AirDrops." )
			#endif 
			
			break
		}
			
		SpawnData data = file.airDropSpawnData.getrandom()
		RealisticAirDrop( data )
		
		file.airDropSpawnData.fastremovebyvalue( data )
	}
}

void function __SpawnLootAtIntervals( float minWait, float maxWait, int numItems = 8 )
{
	svGlobal.levelEnt.EndSignal( "GameEnd" )
	
	for( ; ; )
	{
		array< SpawnData > currentLootSpawns = []	
		wait RandomFloatRange( minWait, maxWait )
		
		for( int i = 0; i < numItems; i++ )
			currentLootSpawns.append( file.lootSpawns.getrandom() )
			
		foreach( SpawnData data in currentLootSpawns )
		{
			switch( data.info )
			{
				case "tier0":
					SpawnGenericLoot( TIER_ZERO_LOOT.getrandom(), data.spawn.origin, data.spawn.angles, 2 )
				break
					
				case "tier1":
					SpawnGenericLoot( TIER_ONE_LOOT.getrandom(), data.spawn.origin, data.spawn.angles, 1 )
				break
				
				case "tier2":
					SpawnGenericLoot( TIER_TWO_LOOT.getrandom(), data.spawn.origin, data.spawn.angles, 2 )
				break 
				
				case "tier3":
					SpawnGenericLoot( TIER_THREE_LOOT.getrandom(), data.spawn.origin, data.spawn.angles, 1 )
				break 
			}
		}
	}
}

void function CheckPlayerCountForBots( entity _ )
{
	int playerCount = GetConnectedPlayerCount() + GetPendingClientsCount()
	
	if( file.bTrainingModeActive && ( playerCount > file.max_players_for_bots || playerCount < file.min_players_for_bots ) )
	{
		EnableOrDisableTrainingMode( false )
	}
	else if( !file.bTrainingModeActive && playerCount >= file.min_players_for_bots && playerCount <= file.max_players_for_bots )
	{
		EnableOrDisableTrainingMode( true )
	}
}

bool function ShouldEnableTrainingMode()
{
	if( !file.bEnableTrainingMode )
		return false 

	if( file.max_players_for_bots > 0 || file.min_players_for_bots > 0 )
	{
		int playerCount = GetConnectedPlayerCount() + GetPendingClientsCount()		
		if( playerCount <= file.max_players_for_bots && playerCount >= file.min_players_for_bots )
			return true
		else
			return false
	}
	
	return true
}

void function AssignCharacter( entity player, array< string > args )
{
	if( !CheckRate( player, "legend_select", 1, true ) )
		return

	if( !file.bLegendChangeEnabled )
	{
		LocalMsg( player, "#FS_FAILED", "#FS_DisabledLegends" )
		return
	}
				
	if( !args.len() )
		return
		
	if( !IsStringNumber( args[ 0 ] ) )
		return
		
	int characterGUID = int( args[ 0 ] )	
	
	ItemFlavor ornull characterOrNull = GetItemFlavorOrNullByGUID( characterGUID )
	if( characterOrNull == null )
	{
		#if DEVELOPER 
			printf( "[REALISTIC MODE]: \"%d\" is not a valid character guid.", characterGUID )
		#endif 
		
		return
	}
	
	expect ItemFlavor ( characterOrNull )
	if( ItemFlavor_GetType( characterOrNull ) != eItemType.character )
		return 
		
	if( !ItemFlavor_ShouldBeVisible( characterOrNull, player ) )
	{
		LocalMsg( player, "#FS_FAILED", "#FS_InvalidLegend" )
		return
	}

	if( !( player in file.tbl_selectedLegends ) )
		file.tbl_selectedLegends[ player ] <- characterOrNull
	else 
		file.tbl_selectedLegends[ player ] = characterOrNull
}

void function CleanupCharacterTable( entity player )
{
	if( player in file.tbl_selectedLegends )
		delete file.tbl_selectedLegends[ player ]
}

void function SpawnDummyOnRandomPlayer_Thread()
{
	for( ; ; )
	{
		wait RandomFloatRange( file.fRandomDummySpawnMinTime, file.fRandomDummySpawnMaxTime )
		
		if( !GetPlayerArray().len() )
			continue
			
		entity player = GetPlayerArray().getrandom()

		vector origin = GetPlayerCrosshairOrigin( player )
		vector org2 = player.GetOrigin()
		vector vec1 = org2 - origin
		vector angles = VectorToAngles( vec1 )
		angles.x = 0
		
		waitthread __SpawnDummy( origin, angles, player )
	}
}

DoorDataStruct ornull function UpdateDestroyTime( entity door )
{
	foreach( DoorDataStruct data in file.trackedDoors )
	{
		if( data.door == door )
		{
			#if DEVELOPER
				printt( "UpdateDestroyTime() Found door, setting destroy time to:", Time() )
			#endif
			
			int dataIndex = file.trackedDoors.find( data )
			
			if( dataIndex > -1 )
				file.trackedDoors[ dataIndex ].lastDestroyTime = Time()
			
			return data		
		}
	}
	
	return null
}

DoorDataStruct ornull function GetDoorData( entity door )
{
	foreach( DoorDataStruct data in file.trackedDoors )
	{
		if( data.door == door )
			return data 
	}
	
	return null
}

int function GetDoorDataIndex( entity door )
{
	int trackedDoorsLen = file.trackedDoors.len()
	for( int i = 0; i < trackedDoorsLen; i++ )
	{	
		if( file.trackedDoors[ i ].door == door )
			return i
	}
	
	return -1
}

bool function InTrackedDoors( entity door )
{
	foreach( data in file.trackedDoors )
	{
		if( data.door == door )
			return true
	}
	
	return false
}

void function RunDoorMonitor( entity door )
{
	#if DEVELOPER
		//printw( "Checking to run door monitor" )
	#endif 
	
	if( InTrackedDoors( door ) )
	{
		//printt( " --- SUCCESS --- : running monitor" )
		thread RunDoorMonitor_Thread( door )
		file.iTrackedDoors++
	}
	else
	{
		//printt( "ERROR. Door is not in tracked doors." )
	}
}

#if DEVELOPER
	void function DEV_PrintTrackedDoors()
	{
		printt( file.iTrackedDoors )
	}
#endif

void function RunDoorMonitor_Thread( entity door )
{
	if( !IsValid( door ) ) //threaded off 
		return
		
	svGlobal.levelEnt.EndSignal( "GameEnd" )
	door.EndSignal( "OnDestroy" )
	
	OnThreadEnd
	(
		void function() : ( door )
		{
			if( InTrackedDoors( door ) )
			{
				DoorDataStruct ornull doorData = UpdateDestroyTime( door )
				
				if( doorData != null )
				{				
					file.iTrackedDoors--				
					thread RespawnDoorAtTime( expect DoorDataStruct ( doorData ), DOOR_REGEN_GRACE )
				}
			}
			#if DEVELOPER
			else
				printt( "Not in tracked doors?", door )
			#endif
		}
	)
	
	#if DEVELOPER
		//printt( "Waiting for destroy" )
	#endif 
	
	WaitForever()
}

void function RespawnDoorAtTime( DoorDataStruct doorData, float respawnTime )
{
	wait respawnTime
	
	int doorState
	for( ; ; )
	{
		doorState = TryRespawnDoor( doorData )
		
		switch( doorState )
		{
			case eDoorRespawnSate.DOOR_ALIVE:
			case eDoorRespawnSate.DOOR_RESPAWNED:
				return 
			
			case eDoorRespawnSate.DOOR_WAITING:		
				break
		}
		
		wait 1
	}
}

const bool LINKDEBUG = false
#if DEVELOPER && LINKDEBUG
	int s_linkedDoorCount
#endif 

void function CollectAllDoors()
{
    foreach ( door in GetAllPropDoors() )
    {
        if ( !IsValid( door ) )
            continue
								
		float distance = Distance2D( door.GetOrigin(), TTV_BUILDING_ORIGIN )
        if ( distance > TTV_BUILDING_RADIUS )
        {
			#if DEVELOPER
				//printt( "Skipping door outside radius" )
			#endif 
			
            continue
        }
		
        DoorDataStruct doorData
		
        doorData.door 		= door
        doorData.origin 	= door.GetOrigin()
        doorData.angles 	= door.GetAngles()
        doorData.model 		= door.GetModelName()
        doorData.scriptName = door.GetScriptName()
		
		bool bLinkOwner 		= IsValid( door.GetLinkEnt() )
		doorData.bLinkOwner 	= bLinkOwner
		doorData.index 			= file.trackedDoors.len()

		if( bLinkOwner )
		{
			#if DEVELOPER && LINKDEBUG
				++s_linkedDoorCount
				Warning( "Has link door count = " + s_linkedDoorCount )

				DebugDrawCircleOnEnt( door, 25, 0, 255, 0, 500 )
				foreach( entity ent in door.GetLinkEntArray() )
					printf( "s_linkedDoorCount[%d] - ent: %s", s_linkedDoorCount, string( ent ) )
			#endif
		}
		
        file.trackedDoors.append( doorData )
		RunDoorMonitor( door )
		
        #if DEVELOPER
			//printt( "adding door at:", doorData.origin )
		#endif
    }
	
	int trackedDoorsLen = file.trackedDoors.len()
	for ( int i = 0; i < trackedDoorsLen; i++ )
	{
        if ( !file.trackedDoors[ i ].bLinkOwner )
            continue

        entity a = file.trackedDoors[ i ].door
        entity b = a.GetLinkEnt()
        if ( !IsValid( b ) )
            continue

        int j = GetDoorDataIndex( b )
        if ( j == -1 )
            continue

        file.trackedDoors[ i ].linkedDoorIdx = j
        file.trackedDoors[ j ].linkedDoorIdx = i
	}
	
	#if DEVELOPER
		printw( "Total Doors Added:", trackedDoorsLen )
		printw( "Total doors tracked:", file.iTrackedDoors )
	#endif
}

enum eDoorRespawnSate
{
	DOOR_ALIVE,
	DOOR_WAITING,
	DOOR_RESPAWNED
}

int function TryRespawnDoor( DoorDataStruct doorData )
{
    if ( IsValid( doorData.door ) )
        return eDoorRespawnSate.DOOR_ALIVE
	
	if( Time() - doorData.lastDestroyTime < DOOR_REGEN_GRACE ) 
		return eDoorRespawnSate.DOOR_WAITING
		
	#if DEVELOPER
		Warning( "Spawning visual debug sphere at %s", VectorToString( doorData.origin ) )
		DebugDrawSphere( doorData.origin, DOOR_RESPAWN_PLAYER_RADIUS_LIMIT, 255, 0, 0, true, 5.0 )
	#endif
	
	array<entity> nearbyEntities = ArrayEntSphere( doorData.origin, DOOR_RESPAWN_PLAYER_RADIUS_LIMIT )
	
	bool bNearbyPlayerFound = false
	foreach ( entity ent in nearbyEntities )
	{
		if ( ent.IsPlayer() || ent.IsNPC() )
		{
			bNearbyPlayerFound = true 
			break
		}
	}
			
	if( bNearbyPlayerFound )
		return eDoorRespawnSate.DOOR_WAITING

    entity newDoor = CreateEntity( "prop_door" )
    
	newDoor.SetOrigin( doorData.origin )
    newDoor.SetAngles( doorData.angles )
    newDoor.SetModel( doorData.model )
    newDoor.SetScriptName( doorData.scriptName )
	
	if ( doorData.linkedDoorIdx != -1 )
	{
		entity oppositeDoor = file.trackedDoors[ doorData.linkedDoorIdx ].door
		if ( IsValid( oppositeDoor ) )
			newDoor.LinkToEnt( oppositeDoor )
	}
	
    DispatchSpawn( newDoor )
    file.trackedDoors[ doorData.index ].door = newDoor

	RunDoorMonitor( newDoor )
	
    #if DEVELOPER
		//printt("Respawned door at:", doorData.origin, "with model:", doorData.model);
    #endif
	
	return eDoorRespawnSate.DOOR_RESPAWNED
}

void function InitializeDoorTracking()
{
    CollectAllDoors()
}

void function RealisticMode_GivePlayerBonusHeals( entity player, bool spawn = false )
{
	if( !spawn )
	{
		vector playerOriginAtKillTime = player.GetOrigin()
		
		foreach( ref in STANDARD_REALISTIC_KILL_LOOT )
		{
			if( SURVIVAL_AddToPlayerInventory( player, ref, 1, false ) == 0 )
				SpawnLoot( ref, playerOriginAtKillTime, true )
			else
				SURVIVAL_AddToPlayerInventory( player, ref, 1 )
		}
	}
	else
	{
		foreach( ref in STANDARD_SPAWN_LOOT )
			SURVIVAL_AddToPlayerInventory( player, ref, 1 )
	}
}

void function Realistic_OnWeaponAttachmentChanged( entity player, entity weapon, string modToAdd, string modToRemove )
{
	if( !CheckRate( player, "attachment_change", 0.05, false ) )
		return
				
	ClientCommand_SaveCurrentWeapons( player, [] )
}

void function RealisticMode_OnSpawned( entity player )
{		
	Inventory_SetPlayerEquipment( player, "", "helmet" )
	player.TakeOffhandWeapon( OFFHAND_SLOT_FOR_CONSUMABLES )
	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
	player.TakeOffhandWeapon( OFFHAND_MELEE )

	RealisticMode_GivePlayerBonusHeals( player, true )	
	
	bool bHasValidLegend
	if( file.bLegendChangeEnabled )
	{
		if( ( player in file.tbl_selectedLegends ) && file.tbl_selectedLegends[ player ] != null )
		{		
			ItemFlavor ornull character = file.tbl_selectedLegends[ player ]
			if( character == null )
				return
				
			bHasValidLegend = true	
			expect ItemFlavor ( character )
			CharacterSelect_AssignCharacter( ToEHI( player ), character )
		}
	}
	
	if( file.bAllowLegendAbilities && bHasValidLegend )
		GiveLoadoutRelatedWeapons( player )
	else
	{
		player.GiveOffhandWeapon( CONSUMABLE_WEAPON_NAME, OFFHAND_SLOT_FOR_CONSUMABLES, [] )
		
		if( file.bGiveHeirloom )
		{
			player.GiveWeapon( "mp_weapon_bolo_sword_primary", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
			player.GiveOffhandWeapon( "melee_bolo_sword", OFFHAND_MELEE, [] )
		}
		else
		{
			player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
			player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
		}		
	}
}

//similar function from fsdm
LocPair function RealisticMode_GetBestSpawnPointFFA()
{	
	table<LocPair, float> SpawnsAndNearestEnemy = {}
	bool bHighVolume = GetPlayerArray_Alive().len() > HIGH_PLAYER_COUNT_THRESHOLD

	foreach( SpawnData dataSpawn in file.gamemodeSpawns )
    {
		if( !bHighVolume && dataSpawn.info == "overfill" )
			continue
	
		array<float> AllPlayersDistancesForThisSpawnPoint
		
		foreach( player in GetPlayerArray_Alive() )
			AllPlayersDistancesForThisSpawnPoint.append( Distance( player.GetOrigin(), dataSpawn.spawn.origin ) )
		AllPlayersDistancesForThisSpawnPoint.sort()
		SpawnsAndNearestEnemy[ dataSpawn.spawn ] <- AllPlayersDistancesForThisSpawnPoint[ 0 ] //grab nearest player distance for each spawn point
	}

	LocPair finalLoc
	float compareDis = -1
	foreach( loc, dis in SpawnsAndNearestEnemy ) //calculate the best spawn point which is the one with the furthest enemy of the nearest
	{
		if( dis > compareDis )
		{
			finalLoc = loc
			compareDis = dis
		}
	}
	
    return finalLoc
}

void function INIT_WeaponsMenu()
{
	AddClientCommandCallback( "CC_MenuGiveAimTrainerWeapon", CC_MenuGiveAimTrainerWeapon ) 
	AddClientCommandCallback( "CC_AimTrainer_SelectWeaponSlot", CC_AimTrainer_SelectWeaponSlot )
	AddClientCommandCallback( "CC_AimTrainer_WeaponSelectorClose", CC_AimTrainer_CloseWeaponSelector )
}

void function INIT_WeaponsMenu_Disabled()
{
	AddClientCommandCallback( "CC_MenuGiveAimTrainerWeapon", MessagePlayer_Disabled ) 
	AddClientCommandCallback( "CC_AimTrainer_SelectWeaponSlot", MessagePlayer_Disabled )
	AddClientCommandCallback( "CC_AimTrainer_WeaponSelectorClose", MessagePlayer_Disabled )
}

bool function MessagePlayer_Disabled( entity player, array<string> args )
{
	LocalEventMsg( player, "#FS_DisabledTDMWeps" )
	return true
}

void function ClientCommand_RealisticTrainingMode( entity player, array< string > args )
{
	if( !IsValid( player ) )
		return 
	
	if( !file.bEnableTrainingMode )	
		return
		
	if( !IsServerAdmin( player.p.UID ) )
		return 
		
	if( !args.len() )
		return 
		
	string param = args [ 0 ]
	if( !IsStringBool( param ) )
	{
		Message( player, "Error", format( "Param \"%s\" is not a valid bool representation", param ) )
		return
	}
	
	EnableOrDisableTrainingMode( StringToBool( args[ 0 ] ) )
}

void function EnableOrDisableTrainingMode( bool enable )
{
	if( enable )
		thread AiTrainingModeThread()
	else
		Signal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	
	foreach( s_player in GetPlayerArray() )
		Message( s_player, "Game State Change", format( "TTV Realistic Ai patrol mode was %s", enable ? "enabled" : "disabled" ) )
}


void function AiTrainingModeThread()
{
	mAssert( IsNewThread(), "Must be threaded off" )
	
	if( !ShouldEnableTrainingMode() )
		return 
		
	OnThreadEnd
	(
		void function()
		{
			foreach( entity bot in file.aiBots )
			{
				if( IsValid( bot ) )
					bot.Destroy()
			}
			
			file.aiBots.clear()
			file.bTrainingModeActive = false
		}
	)
	
	Signal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	EndSignal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	
	file.bTrainingModeActive = true
	
	float fSpawnGracePeriod	= GetCurrentPlaylistVarFloat( "realistic_ttv_dummy_spawn_grace_period", 4 )
	int maxAllowedBots 		= minint( 180, GetCurrentPlaylistVarInt( "realistic_ttv_max_alive_bots", 2 ) )
	int currentAliveDummies = file.aiBots.len()
	entity dummy
	SpawnData dummySpawn
	
	while( GetTDMState() != eTDMState.IN_PROGRESS )// don't spawn if round hasn't started yet
		WaitFrame()
	
	for( ; ; )
	{
		currentAliveDummies = file.aiBots.len()
		
		wait fSpawnGracePeriod
		if( currentAliveDummies >= maxAllowedBots )
			WaitSignal( file.infoSignal, "RealisticTTV_SpawnTrainingDummy" )
		
		dummySpawn = file.aiSpawns.getrandom()
		dummy = CreateDummy( 99, dummySpawn.spawn.origin, dummySpawn.spawn.angles )
		
		file.aiBots.append( dummy )
		AddEntityCallback_OnKilled( dummy, OnTrainingDummyKilled )
		
		__SpawnDummy( dummySpawn.spawn.origin, dummySpawn.spawn.angles, null, dummy, 99, 0.8, 2.3 )	
	}
}

void function OnTrainingDummyKilled( entity dummy, var damageInfo )
{
	if( IsValid( dummy ) )
	{
		file.aiBots.fastremovebyvalue( dummy )
	
		entity attacker = DamageInfo_GetAttacker( damageInfo )
		
		if( IsValid( attacker ) && attacker.IsPlayer() )
			RealisticMode_GivePlayerBonusHeals( attacker )
		
		dummy.Destroy()
	}

	Signal( file.infoSignal, "RealisticTTV_SpawnTrainingDummy" )
}

void function OnDummyKilledForPlayer( entity dummy, var damageInfo )
{
	if( IsValid( dummy ) )
	{
		file.aiBotsForPlayers.fastremovebyvalue( dummy )
		
		entity attacker = DamageInfo_GetAttacker( damageInfo )
		
		if( IsValid( attacker ) && attacker.IsPlayer() )
			RealisticMode_GivePlayerBonusHeals( attacker )
			
		dummy.Destroy()
	}
}

void function __SpawnDummy( vector origin, vector angles, entity player = null, entity dummy = null, int team = 99, float fWaitMin = 2.0, float fWaitMax = 5.0 )
{	
	if ( dummy == null )
		dummy = CreateDummy( team, origin, angles )
		
	dummy.e.stateFlags = 0 | STATE_FLAG_NO_STATS
	SetSpawnOption_AISettings( dummy, "npc_combat_wraith" )
	dummy.kv.doScheduleChangeSignal = true //amazing
	
	int shield = 100
	int shieldskin = 1

	DispatchSpawn( dummy )
	
	dummy.SetOrigin( origin )
	dummy.SetShieldHealthMax( shield )
	dummy.SetShieldHealth( shield )
	dummy.SetMaxHealth( 100 )
	dummy.SetHealth( 100 )
	dummy.SetTakeDamageType( DAMAGE_YES )
	dummy.SetDamageNotifications( true )
	dummy.SetDeathNotifications( true )
	dummy.SetValidHealthBarTarget( true )
	
	SetObjectCanBeMeleed( dummy, true )
	
	dummy.DisableHibernation()
	dummy.SetAngles( angles )
	dummy.SetEfficientMode( false )
	dummy.SetSkin( RandomInt(6) )
	dummy.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
	dummy.SetTitle( "Wraith Killer" )
	
	dummy.SetCapabilityFlag( bits_CAP_SYNCED_MELEE_ATTACK | bits_CAP_INITIATE_SYNCED_MELEE, true )
	dummy.e.isDoorBlocker = true
	
	if( player != null )
	{
		dummy.RemoveFromAllRealms()
		dummy.AddToOtherEntitysRealms( player )
		
		AddEntityCallback_OnKilled( dummy, OnDummyKilledForPlayer )
		file.aiBotsForPlayers.append( dummy )
	}
	
	AddEntityCallback_OnKilled( dummy, OnDummyKilledCommon )
	
	#if TRACKER
		AddEntityCallback_OnPostDamaged( dummy, OnDummyDamagedCommon ) //dirty
	#endif
	
    array<string> weapons = ["npc_weapon_hemlok", "npc_weapon_energy_shotgun", "npc_weapon_lstar"]
    string randomWeapon = weapons[ RandomInt( weapons.len() ) ]
    dummy.GiveWeapon( randomWeapon, WEAPON_INVENTORY_SLOT_ANY )
	
	weapons.fastremovebyvalue( randomWeapon )
	randomWeapon = weapons[ RandomInt( weapons.len() ) ]
	dummy.GiveWeapon( randomWeapon, WEAPON_INVENTORY_SLOT_ANY )
	
	dummy.EnableNPCFlag( NPC_IGNORE_ALL )
	wait RandomFloatRange( fWaitMin, fWaitMax ) //wait to make aggro
	
	if( IsValid( dummy ) )
	{
		dummy.DisableNPCFlag( NPC_IGNORE_ALL )
		dummy.EnableNPCFlag( NPC_USE_SHOOTING_COVER | NPC_CROUCH_COMBAT )
	}
}

#if DEVELOPER 
	array<entity> function DEV_RealisticModeGetAllDummies()
	{
		return GetAllDummies()
	}
#endif 

array<entity> function GetAllDummies() //not using GetNPCArrayByClass( "npc_dummie" ) incase we add other classes later
{
	array<entity> allDummies
	
	allDummies.extend( file.aiBots )
	allDummies.extend( file.aiBotsForPlayers )
	
	return allDummies
}

void function DummyResetIfAlive()
{
	foreach( entity dummy in GetAllDummies() )
	{
		if( IsValid( dummy ) && IsAlive( dummy ) )
			dummy.Destroy()
	}
	
	file.aiBots.clear()
	file.aiBotsForPlayers.clear()
}

void function DummyPauseAggro()
{
	foreach( entity dummy in GetAllDummies() )
	{
		if( IsValid( dummy ) && IsAlive( dummy ) )
		{
			dummy.Freeze()
			dummy.EnableNPCFlag( NPC_IGNORE_ALL | NPC_DISABLE_SENSING )
		}
	}
}

var function RealisticMode_GetBotKills( string uid )
{
	entity player = GetPlayerEntityByUID( uid )
	return player.p.realisticMode_bot_kills
}

void function OnDummyKilledCommon( entity dummy, var damageInfo )
{
	entity attacker = InflictorOwner( DamageInfo_GetAttacker( damageInfo ) )
	if( IsValid( attacker ) && attacker.IsPlayer() )
	{
		attacker.p.realisticMode_bot_kills++
		
		if( !Tracker_ShouldShip() )
			Tracker_SetShouldShip( true ) //we do this so stats ship even if only bots were killed.
	}
}

entity function GetDoorBlockedByPlayer( entity door )
{
    vector mins = door.GetBoundingMins()
    vector maxs = door.GetBoundingMaxs()

    foreach ( entity player in ArrayEntSphere( door.GetOrigin(), 130 ) ) //touching ent not working?
    {
        if ( !IsValidPlayer( player ) || !IsAlive( player ) )
            continue

        vector loc = WorldPosToLocalPos( player.GetOrigin(), door )

        const float PAD_XY = 32.0
        const float PAD_Z  = 32.0

        if ( loc.x >= mins.x - PAD_XY && loc.x <= maxs.x + PAD_XY &&
             loc.y >= mins.y - PAD_XY && loc.y <= maxs.y + PAD_XY &&
             loc.z >= mins.z - PAD_Z  && loc.z <= maxs.z + PAD_Z )
        {
            return player
        }
    }

    return null
}

void function OnDoorInteraction( entity door, entity user, entity oppositeDoor, bool opening )
{
	if ( !user.IsNPC() )
		return
		
	if( !opening )
		return
	
	entity blockingPlayer = GetDoorBlockedByPlayer( door )
	if ( blockingPlayer == null )
	{
		door.SetAIObstacle( false )
		return
	}
		
	door.SetAIObstacle( true )
		
	entity enemy = user.GetEnemy()
	if ( !IsValid( enemy ) || !enemy.IsPlayer() )
		return
		
	entity npcPlayerEnemy = user.GetClosestEnemyPlayer()
	if( blockingPlayer == npcPlayerEnemy )
	{
		ToggleNPCPathsForEntity( door, false )
		user.SetEnemy( door )
		user.SetSecondaryEnemy( blockingPlayer )
		user.LockEnemy( door )
		user.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
		
		thread NPCDoorFightThink( user, blockingPlayer, door )
	}
}

void function NPCDoorFightThink( entity npc, entity enemyPlayer, entity door )
{
	if( !IsValid( npc ) || !IsValid( enemyPlayer ) )
		return

	OnThreadEnd
	(
		void function() : ( npc, enemyPlayer, door )
		{
			#if DEVELOPER 
				Warning( "NPCDoorFightThink end" )
			#endif
		
			if( IsAlive( npc ) )
			{
				npc.ai.bIsInDoorFight = false
				npc.ClearEnemy()
				
				if( IsValid( door ) )
				{
					door.SetAIObstacle( false )
					ToggleNPCPathsForEntity( door, true )
				}
				
				if( IsAlive( enemyPlayer ) )
					npc.SetEnemy( enemyPlayer )
					
				npc.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
			}
		}
	)
	
	npc.ai.bIsInDoorFight = true
	
	npc.EndSignal( "OnDestroy" )
	enemyPlayer.EndSignal( "OnDestroy", "OnDeath" )
	door.EndSignal( "OnDestroy" )

	while( GetDoorBlockedByPlayer( door ) != null )
	{
		// printt( "schedule: ", npc.GetCurScheduleName() )
		// printt( "door open?: ", IsDoorOpen( door ) )
		// if( !npc.CanSee( enemyPlayer ) )
		// {
			// if( npc.TimeSinceSeen( enemyPlayer ) > 2 )
			// {
				// Warning( "break because npc cannot see player for 2 seconds" )
				// break
			// }
		// }
		
		npc.WaitSignal( "OnScheduleChange" )		
		if( npc.GetCurScheduleName() == SCHED_MELEE )
		{		
			wait SCHED_ATTACK1_ANIM_LEN			
			door.TakeDamage( 30, npc, npc, { damageSourceId = eDamageSourceId.melee_pilot_emptyhanded, scriptType = DF_MELEE } )
		}
		
		DoorDataStruct ornull doorData = GetDoorData( door )
		if( doorData != null )
		{
			expect DoorDataStruct ( doorData )
			array< entity > doors = [ door ]
			
			if( doorData.linkedDoorIdx != -1 )
				doors.append( file.trackedDoors[ doorData.linkedDoorIdx ].door )
			
			if( IsAnyDoorClear( doors ) )
				break
		}
	}
}

bool function IsAnyDoorClear( array<entity> doors )
{
	foreach( door in doors )
	{
		if( !IsValid( door ) )
			return true
	
		if ( IsDoorOpen( door ) )
		{
			DoorDataStruct ornull doorData = GetDoorData( door )
			if ( doorData != null && IsDoorFullyOpen( expect DoorDataStruct( doorData ) ) )
				return true
		}
	}
	
	return false
}

vector function DoorClosedDir( DoorDataStruct data )
{
    return Normalize( AnglesToForward( data.angles ) )
}

bool function IsDoorFullyOpen( DoorDataStruct data, float tolerance = 0.10 )
{
    vector closedDir  = DoorClosedDir( data )
    vector currentDir = Normalize( AnglesToForward( data.door.GetAngles() ) )

    float dot = DotProduct( closedDir, currentDir )
    return fabs( dot ) <= tolerance
}

void function ClientCommand_RealisticSpectate( entity player, array<string> args ) // "realistic_mode_spectate"
{
	if ( !IsValid( player ) ) 
		return
	
	if ( GetTDMState() != eTDMState.IN_PROGRESS )
	{
		LocalMsg( player, "#FS_GameNotPlaying" )
		return
	}
	
	if( Timeout_IsPlayerTimedOut( player ) )
	{
		LocalMsg( player, "#FS_TIMEOUT" )
		return
	}
	
	if( player.p.isSpectating )
	{
		RealisticEndSpectate( player )
		return
	}

	try
	{
		array<entity> enemiesArray = GetPlayerArray_AliveConnected()
		enemiesArray.fastremovebyvalue( player )
		
		if ( enemiesArray.len() == 0 )
		{
			LocalMsg( player, "#FS_NO_PLAYERS_TO_SPEC" )
			return
		}
		
		entity specTarget = enemiesArray.getrandom()

		player.p.isSpectating = true
		player.SetPlayerNetInt( "spectatorTargetCount", GetPlayerArray().len() )
		player.SetObserverTarget( specTarget )
		player.SetSpecReplayDelay( 0.5 )
		player.StartObserverMode( OBS_MODE_IN_EYE )
		player.p.lastTimeSpectateUsed = Time()
		
		LocalEventMsg( player, "#FS_JumpToStopSpec", "", 20 )
		player.MakeInvisible()
	}
	catch ( e )
	{
		#if DEVELOPER 
			printw( "Error:", e )
		#endif
	}
	
	AddButtonPressedPlayerInputCallback( player, IN_JUMP, RealisticEndSpectate )
}

void function RealisticEndSpectate( entity player )
{
	if( !player.p.isSpectating )
		return

	player.SetPlayerNetInt( "spectatorTargetCount", 0 )
	player.SetSpecReplayDelay( 0 )
	player.SetObserverTarget( null )
	player.StopObserverMode()
	Remote_CallFunction_ByRef( player, "ServerCallback_KillReplayHud_Deactivate" )
    player.MakeVisible()	
	player.p.isSpectating = false
	
	LocalEventMsg( player, "#FS_NULL", "", 0.01 )
    RemoveButtonPressedPlayerInputCallback( player, IN_JUMP, endSpectate )
	
	DespawnPlayer( player )
}

void function DespawnPlayer( entity player )
{
	try
	{
		player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_despawn } )
	}
	catch ( error )
	{}
}

void function ClientCommand_SpecNext( entity player, array<string> args )
{

}

void function ClientCommand_SpecPrev( entity player, array<string> args )
{

}

void function OnGameEnd()
{
	foreach( player in GetPlayerArray() )
	{
		if( !IsValidPlayer( player ) )
			continue 
		
		if( !player.p.isSpectating )
			continue 
			
		RealisticEndSpectate( player )
	}
}

entity function DetermineObservee( entity observer, bool direction )
{
	if ( !IsValidPlayer( observer ) )
		return null
		
	entity observerTarget = observer.GetObserverTarget()
		
	array<entity> observeablePlayers = GetPlayerArray_AliveConnected()
	int observeablePlayersLen = observeablePlayers.len()
	for( int i = observeablePlayersLen; i > 0; i-- )
	{	
		if( observeablePlayers[ i ] == observer || ( observeablePlayers[ i ].IsPlayer() && observeablePlayers[ i ].p.isSpectating ) )
			observeablePlayers.remove( i )		
	}
	
	int currentIndex = observeablePlayers.find( observerTarget )	
	if( currentIndex == -1 )
		return observeablePlayers.getrandom()
	
	int indexToObserve
	observeablePlayersLen = observeablePlayers.len()
	if ( direction == true )
		indexToObserve = ( currentIndex + 1 ) % observeablePlayersLen
	else
		indexToObserve = ( ( currentIndex - 1 ) + observeablePlayersLen ) % observeablePlayersLen
		
	return observeablePlayers[ indexToObserve ]
}

void function OnTimedOut( entity player, bool toggle )
{
	if( toggle )
	{
		thread 
		(
			void function() : ( player, toggle )
			{
				if( !IsValid( player ) )
					return 
					
				player.EndSignal( "OnDestroy" )
				
				while( GetTDMState() != eTDMState.IN_PROGRESS )
					WaitFrame()
				
				if( !IsAlive( player ) )
					player.WaitSignal( "FSOnRespawned" )
				
				while( !IsAlive( player ) ) //just a sanity assurance
					WaitFrame()
					
				TakeAllWeapons( player )
				TakeAllPassives( player )
				Gamemode1v1_TeleportPlayer( player, NewLocPair( TIMEOUT_ORIGIN, TIMEOUT_ANGLES )  )
				player.SetTakeDamageType( DAMAGE_NO )
			}
		)()
	}
	else 
	{
		player.SetTakeDamageType( DAMAGE_YES )
		DespawnPlayer( player )
	}
}

void function OnConnectedSetupPlayerForBots( entity player )
{
	AddEntityCallback_OnDamaged( player, OnDamagedByBot )
}

void function OnDamagedByBot( entity damagedEnt, var damageInfo ) //prevent melee-through door target
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )	
	if( !attacker.IsNPC() )
		return
	
	if( !attacker.ai.bIsInDoorFight )
		return
		
	entity victimTarget = attacker.GetEnemy()
	if( damagedEnt != victimTarget && !victimTarget.IsPlayer() )
	{
		if( attacker.GetCurScheduleName() == SCHED_MELEE )
			DamageInfo_SetDamage( damageInfo, 0 )
	}
}

void function SetupZiplineTriggerForNpcs()
{
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( ZIPLINE_TRIGGER_RADIUS )
	trigger.SetAboveHeight( ZIPLINE_TRIGGER_HEIGHT )
	trigger.SetBelowHeight( ZIPLINE_TRIGGER_HEIGHT )
	trigger.SetOrigin( ZIPLINE_TRIGGER_ORIGIN )
	trigger.SetAngles( ZIPLINE_TRIGGER_ANGLES )
	
	DispatchSpawn( trigger )
	trigger.SetEnterCallback( OnZiplineTriggerEnter )
	
	#if DEVELOPER 
		DebugDrawCylinder
		( 
			ZIPLINE_TRIGGER_ORIGIN, 
			ZIPLINE_TRIGGER_ANGLES, 
			ZIPLINE_TRIGGER_RADIUS, 
			ZIPLINE_TRIGGER_HEIGHT, 
			0, 
			255, 
			0, 
			true, 
			300 
		)
	#endif 
}

void function OnZiplineTriggerEnter( entity trigger, entity ent ) //proto
{
	if( !ent.IsNPC() )
		return 
		
	if( ent.IsZiplining() )
		return 
		
	// bool zipSuccess = ent.Zipline_TryUse()
	
	// #if DEVELOPER
		// printt
		// (
			// "ent:", ent,
			// "used zipline?:", zipSuccess
		// )
	// #endif
}

void function RemovePortalDelayed( entity player, PhaseTunnelData tunnelData )
{
	wait STANDARD_PORTAL_DESTROY_DELAY
	
	if( IsValid( tunnelData.tunnelEnt ) )
	{
		tunnelData.tunnelEnt.Signal( "PhaseTunnel_DestroyTunnel" )
		
		if( IsValid( player ) )
			LocalMsg( player, "#FS_REMOVED_PORTAL", "#FS_REMOVED_PORTAL_DESC", eMsgUI.IBMM, 10 )
	}
}

void function CheckForKidnaps( PhaseTunnelData tunnelData, float checkForTime )
{
	float startTime = Time()
	entity tunnelOwner = IsValid( tunnelData.owner ) ? tunnelData.owner : GetEnt( "worldspawn" )
	
	EndSignal( tunnelOwner, "OnDestroy" )
	
	array<entity> kidnapees
	
	while( Time() < startTime + checkForTime )
	{
		WaitFrame()
		
		if( tunnelData.entUsers.len() == 0 )
			continue
			
		foreach( entity user in tunnelData.entUsers )
		{
			WaitFrame() 
			
			if( tunnelOwner == user )
				continue 
				
			if( !IsValid( user ) )
				continue
				
			//printw( "Checking enter direction", user.e.portalDirection )
			if( user.e.portalDirection == ePortalDirection.ENDTOSTART && !kidnapees.contains( user ) )
			{
				kidnapees.append( user )
				__HandleKidnap( tunnelOwner, user )	
			}
		}
	}		
}

void function __HandleKidnap( entity kidnapper, entity victim )
{
	//printw( "Message kidnapper: ", kidnapper )
	
	if( !IsValid( kidnapper ) )
		return
	
	if( kidnapper.IsPlayer() )
	{
		kidnapper.p.portalKidnaps++	
	
		string victimName = IsValid( victim ) ? victim.p.name : "unknown"	
		LocalEventMsg( kidnapper, "#FS_KIDNAPPED", format( "%s in %d seconds", victimName, Time() - kidnapper.p.portalPlaceTime ) )
	}
}

bool function InAllowedZone( vector origin )
{
	//printw( "checking allowed zone:", VectorToString( origin ) )
	float dist2d = Distance2D( origin, MYSTIC_MAGICAL_ELEVATOR_SHAFT_ORIGIN )
	
	if ( PHASE_TUNNEL_DEBUG_DRAW_PROJECTILE_TELEPORT )
		DebugDrawCircle( MYSTIC_MAGICAL_ELEVATOR_SHAFT_ORIGIN, <0,0,0>, MAX_ELEVATOR_SUCKING_BEHAVIOR_RADIUS, 255, 0, 0, true, 10.0, 32 )
	
	if( dist2d > MAX_ELEVATOR_SUCKING_BEHAVIOR_RADIUS )
		return true

	return false
}

void function OnPortalPlaced( entity player, PhaseTunnelData tunnelData, float lifetime )
{
	vector startPos = tunnelData.startPortal.startOrigin
	vector endPos = tunnelData.endPortal.startOrigin

	if( !InAllowedZone( endPos ) )
		thread RemovePortalDelayed( player, tunnelData )
		
	player.p.portalPlacements++
	player.p.portalPlaceTime = Time()	
	thread CheckForKidnaps( tunnelData, MAX_KIDNAP_TIME_AFTER_END_PORTAL )
}

void function RealisticAirDrop( SpawnData data )
{
	AddSurvivalCommentaryEvent( eSurvivalEventType.CARE_PACKAGE_DROPPING )

	entity fx = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( DROPPOD_SPAWN_FX ), data.spawn.origin, data.spawn.angles )
    thread AirdropItems( data.spawn.origin, data.spawn.angles, AIRDROP_ITEMS_POOL, fx, "droppod_loot_drop", null, 0, "" )
}

void function OnDummyDamagedCommon( entity dummy, var damageInfo ) //dirty hack
{
	#if TRACKER
		entity attacker	= DamageInfo_GetAttacker( damageInfo )
		if( !attacker.IsPlayer() )
			return

		Tracker_NegateWeaponShot( attacker, DamageInfo_GetDamageSourceIdentifier( damageInfo ) )
	#endif
}

void function OnPlayerKilledCommon( entity player, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	CreateFlowStateDeathBoxForPlayer( player, attacker, damageInfo )
}