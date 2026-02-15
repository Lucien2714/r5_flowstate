//RealisticMode 																			//mkos
//Just a regular Flowstate gamemode with some tweaks & extra features

global function RealisticMode_Init
global function RealisticMode_GivePlayerBonusHeals
global function RealisticMode_GetBestSpawnPointFFA

#if DEVELOPER
	global function DEV_PrintTrackedDoors
#endif

const vector TTV_BUILDING_ORIGIN = < 9864.35, 5497.93, -3567.97 >
const float TTV_BUILDING_RADIUS = 4500.0
const float DOOR_RESPAWN_PLAYER_RADIUS_LIMIT = 130.0
const float DOOR_REGEN_GRACE = 60
const int HIGH_PLAYER_COUNT_THRESHOLD = 6

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
	"health_pickup_combo_small", //1
	"health_pickup_combo_small", //2
	"health_pickup_health_small", //3
	"health_pickup_health_small", //4
	"mp_weapon_grenade_emp", //5
	"optic_cq_hcog_classic", //6
	"optic_cq_hcog_bruiser", //7
	"optic_cq_holosight", //8
	"optic_ranged_hcog", //9
	"optic_ranged_aog_variable" //10
]

struct DoorDataStruct
{
    entity door
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
	
	int iTrackedDoors
	float fRandomDummySpawnMinTime
	float fRandomDummySpawnMaxTime
	bool bLegendChangeEnabled
	bool bAllowLegendAbilities
	bool bEnableTrainingMode
	
	table infoSignal

} file 

void function RealisticMode_Init()
{
	RegisterSignal( "PlayerSkyDive" )
	
	AddCallback_EntitiesDidLoad( InitializeDoorTracking )
	AddCallback_OnPlayerWeaponAttachmentChanged( Realistic_OnWeaponAttachmentChanged )
	AddFSCallback_OnRespawned( RealisticMode_OnSpawned )

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
		
		if( GetCurrentPlaylistVarBool( "realistic_ttv_ai_training_mode_auto_start", false ) )
			thread AiTrainingModeThread()
	}
	
	if( file.bEnableTrainingMode || GetCurrentPlaylistVarBool( "random_dummy_spawn", true ) )
	{
		AddCallback_OnTdmStateEnter_InProgress( DummyResetIfAlive )
		AddCallback_OnTdmStateEnter_EndGame( DummyPauseAggro )
	}
	
	file.bLegendChangeEnabled = GetCurrentPlaylistVarBool( "allow_legend_select", false )
	AddClientCommandCallbackVoid( "legend_select", AssignCharacter )
	if( file.bLegendChangeEnabled )
		AddCallback_OnClientDisconnected( CleanupCharacterTable )
	
	file.bAllowLegendAbilities = GetCurrentPlaylistVarBool( "realistic_mode_allow_legend_abilities", false )
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

void function UpdateDestroyTime( entity door )
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
			
			break
		}
	}
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
				UpdateDestroyTime( door )
				file.iTrackedDoors--
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
		
        doorData.door = door
        doorData.origin = door.GetOrigin()
        doorData.angles = door.GetAngles()
        doorData.model = door.GetModelName()
        doorData.scriptName = door.GetScriptName()

        file.trackedDoors.append( doorData )
		RunDoorMonitor( door )
		
        #if DEVELOPER
			//printt( "adding door at:", doorData.origin )
		#endif
    }
	
	#if DEVELOPER
		printw( "Total Doors Added:", file.trackedDoors.len() )
		printw( "Total doors tracked:", file.iTrackedDoors )
	#endif
}

void function RespawnDoor( DoorDataStruct doorData )
{
    if ( IsValid( doorData.door ) )
        return
	
	if( Time() - doorData.lastDestroyTime < DOOR_REGEN_GRACE ) 
		return
		
	#if DEVELOPER
		Warning( "Spawning visual debug sphere at", VectorToString( doorData.origin ) )
		DebugDrawSphere( doorData.origin, DOOR_RESPAWN_PLAYER_RADIUS_LIMIT, 255, 0, 0, true, 5.0 )
	#endif 
	
	array<entity> nearbyEntities = ArrayEntSphere( doorData.origin, DOOR_RESPAWN_PLAYER_RADIUS_LIMIT )
	
	bool bNearbyPlayerFound = false
	foreach ( entity ent in nearbyEntities )
	{
		if ( ent.IsPlayer() )
		{
			bNearbyPlayerFound = true 
			break
		}
	}
			
	if( bNearbyPlayerFound )
		return

    entity newDoor = CreateEntity( "prop_door" )
    
	newDoor.SetOrigin( doorData.origin )
    newDoor.SetAngles( doorData.angles )
    newDoor.SetModel( doorData.model )
    newDoor.SetScriptName( doorData.scriptName )

    DispatchSpawn( newDoor )
    doorData.door = newDoor

	RunDoorMonitor( newDoor )
	
    #if DEVELOPER
		//printt("Respawned door at:", doorData.origin, "with model:", doorData.model);
    #endif
}

void function DoorRespawn_Thread()
{
    for( ; ; )
    {
        foreach ( doorData in file.trackedDoors )
            RespawnDoor( doorData )

        wait 5
    }
}

void function InitializeDoorTracking()
{
    CollectAllDoors()
    thread DoorRespawn_Thread()
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
		player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
		player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
	}
}

//taken from fsdm, similar function
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
		SpawnsAndNearestEnemy[ dataSpawn.spawn ] <- AllPlayersDistancesForThisSpawnPoint[0] //grab nearest player distance for each spawn point
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
	
	bool enable = StringToBool( args[ 0 ] )
	
	if( enable )
		thread AiTrainingModeThread()
	else 
		Signal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	
	foreach( s_player in GetPlayerArray() )
		Message( s_player, "Game State Change", format( "TTV Realistic training mode was %s", enable ? "enabled" : "disabled" ) )
}

void function AiTrainingModeThread()
{
	mAssert( IsNewThread(), "Must be threaded off" )
	
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
		}
	)
	
	Signal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	EndSignal( file.infoSignal, "RealisticTTV_KillTrainingThread" )
	
	float fSpawnGracePeriod	= GetCurrentPlaylistVarFloat( "realistic_ttv_dummy_spawn_grace_period", 4 )
	int maxAllowedBots 		= GetCurrentPlaylistVarInt( "realistic_ttv_max_alive_bots", 2 )
	int currentAliveDummies = file.aiBots.len()
	entity dummy
	SpawnData dummySpawn
	
	for( ; ; )
	{
		currentAliveDummies = file.aiBots.len()
		
		if( currentAliveDummies >= maxAllowedBots )
		{
			WaitSignal( file.infoSignal, "RealisticTTV_SpawnTrainingDummy" )
			wait fSpawnGracePeriod
		}
		
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

void function __SpawnDummy( vector origin, vector angles, entity player = null, entity dummy = null, int team = 99, float fWaitMin = 2.0, float fWaitMax = 5.0 ) //taken from ai util
{	
	if ( dummy == null )
		dummy = CreateDummy( team, origin, angles )
		
	dummy.e.stateFlags = 0 | STATE_FLAG_NO_STATS
	SetSpawnOption_AISettings( dummy, "npc_combat_wraith" )

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
	
	if( player != null )
	{
		dummy.RemoveFromAllRealms()
		dummy.AddToOtherEntitysRealms( player )
		
		AddEntityCallback_OnKilled( dummy, OnDummyKilledForPlayer )
		file.aiBotsForPlayers.append( dummy )
	}

    array<string> weapons = ["npc_weapon_hemlok", "npc_weapon_energy_shotgun", "npc_weapon_lstar"]
    string randomWeapon = weapons[ RandomInt( weapons.len() ) ]
    dummy.GiveWeapon( randomWeapon, WEAPON_INVENTORY_SLOT_ANY )
	
	weapons.fastremovebyvalue( randomWeapon )
	randomWeapon = weapons[ RandomInt( weapons.len() ) ]
	dummy.GiveWeapon( randomWeapon, WEAPON_INVENTORY_SLOT_ANY )
	
	dummy.EnableNPCFlag( NPC_IGNORE_ALL )
	wait RandomFloatRange( fWaitMin, fWaitMax )
	
	if( IsValid( dummy ) )
	{
		dummy.DisableNPCFlag( NPC_IGNORE_ALL )
		dummy.EnableNPCFlag( NPC_USE_SHOOTING_COVER | NPC_CROUCH_COMBAT )
	}
}

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