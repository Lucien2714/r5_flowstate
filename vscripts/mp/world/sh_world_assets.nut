// world assets																					//mkos

global function WorldAssets_SetEnabled						// ( bool state )
global function WorldAssets_IsEnabled						// ()

#if SERVER
global function WorldAssets_Init
global function WorldAssets_RegisterGroup					// ( string name, LocPair groupLoc, float width, float height, float alpha = 1.0, bool visible = true, int cycleTime = 10, bool useRandom = false, float intermediateTime = 0.0, int fadeSpeed = SLOWEST )
global function WorldAssets_SetAllGroupsFunc				// ( void functionref() callbackFunc )
global function WorldAssets_SetAllAssetsFunc 				// ( void functionref() callbackFunc )
global function WorldAssets_GroupAppendAsset 				// ( string groupName, string assetResourceRef = "", int assetId = -1, bool bLoopVideo = false, string assetName = "" )

global function WorldAssets_GetAssetRefByName				// ( string assetName )
global function WorldAssets_ModifyGroupData 				// ( string groupName, table tbl )
global function WorldAssets_SyncAllPlayers					// ( int assetRefId = -1, bool bLocked = false, int groupId = -1, string assetRef = "",  ) //groupId -1 for all groups, assetRefId -1 for restarting all groups to first asset for each respective group
global function WorldAssets_DoesSignalExist    				// ( string signal )
global function WorldAssets_LockGroupsTo					// ( int assetId, int groupId = -1 ) //-1 is all groups.
global function WorldAssets_Lock							// ( int groupId )
global function WorldAssets_Unlock							// ( int groupId )
global function WorldAssets_KillAllBanners					// ()
global function WorldAssets_Restart							// ()
global function WorldAssets_SetVisible						// ( string groupName, bool toggle )
global function WorldAssets_GroupVisibilityMover 			// ( vector initialPosition, vector initialAngles, float bannerWidth, float bannerHeight, float adjustmentDistance = 5.0, float maxIterations = 1000 ) 
global function WorldAssets_GetGroupIdByName				// ( string groupName )
global function WorldAssets_GetGroupNameByID				// ( int groupId )
global function WorldAssets_SwitchToPlayerAssetForGroupNow	// ( entity player, string assetRef, string groupName )
global function WorldAssets_DestroyAllRuiAndTopo			// ( entity player )

global function WorldAssets_RegisterAudioGroup				// ( string name, bool interupt = true, bool isVisible = true )
global function WorldAssets_PlayAudio						// ( entity player, string assetRef, string groupName = "" )
global function WorldAssets_PlayAudioID						// ( entity player, int assetId = -1, string groupName = "" )
global function WorldAssets_PlayAudioName					// ( entity player, string audioName, string groupName = "" )
global function WorldAssets_GetPlayCountForPlayer			// ( entity player, int assetId )
global function WorldAssets_GetLastPlayTime					// ( entity player, int assetId )
global function WorldAssets_WaitForChannelCreation			// ( entity player, string groupName )
global function WorldAssets_IsChannelCreatedForPlayer		// ( entity player, string groupName )
global function WorldAssets_WasAudioPlayedLast				// ( entity player, string assetName = "", string assetRef = "", string groupName = "", int assetId = -1 )
global function WorldAssets_GetLastPlayedAudio				// ( entity player, string groupName = "" )
global function WorldAssets_GetAudioHistoryForPlayerForAsset// ( entity player, string assetName = "", string assetRef = "", int assetId = -1 )

global const MAX_BIK_CHANNELS 			= 10 //this must not surpass engine internals.
global const CURRENT_RESERVED_CHANNELS 	= 5 //this is the limit we start from. (todo: disable systems where posible)

const int SLOWEST	= -4
const int SLOWER	= -3
const int SLOW		= -2
const int MODERATE	= -1
const int NORMAL 	= 0
const int FAST 		= 1
const int FASTER	= 2

const string INVALID_GROUP_NAME = "_INVALID"
const bool DEBUG_WORLD_ASSET = false


/*
											DOCUMENTATION:
									
	====================================================================================================================================================	
	Introduction:
	
		The WorldAssets system was originally designed to display and play in-world video/images. 
		However, the system was later designed to support audio queues.
		
		Video/Audio/Image using this system is controlled by the server.
		
		The system allows you to create as many groups as you want, and append assets to each group. 
		You can position them anywhere you want, with additional functionality for game logic such as:
		
		- Syncing all players to a specific asset, for instance, on a specific game event such as end game via WorldAssets_SyncAllPlayers
		- Displaying a specific group's asset to a specific player for example: WorldAssets_SwitchToPlayerAssetForGroupNow( p(0), "rui/world/flowstate1v1_banner02", "main_banner" )
		- Auto adjusting visibility to specific eye coordinates via WorldAssets_GroupVisibilityMover
		- Getting the last played audio or creating elaborate audio logic using helpers such as WorldAssets_GetLastPlayedAudio( player )
		- ..more
		
	====================================================================================================================================================	
	Registering Assets:
	
		Assets must exist on the client in order for the server to command their usage. 
			- Images: Are paked using repak and become available via their reference such as "rui/world/flowstate1v1_banner02". repak is availabke in the \bin\ folder as repak.exe.
			- Video/Audio: Are created as .bik with Rad Video Tools https://www.radgametools.com/bnkdown.htm

		Assets are registered in 3 main ways, via an Rpak datatable. 
			1. Call WorldDrawAsset_RegisterAssetDatatable( string dataTableString, bool bValidate )			
				- Example: WorldDrawAsset_RegisterAssetDatatable( "datatable/flowstate_audio.rpak", true ) -- This will force client to validate the rpak with 'true' set. Defaults to false
				- Each Datatable row should contain columns 'path', 'name', 'category'. 
					
					- path: 		Location of the asset. 						Example:   media/playlists/grapples_n_guns/grapples_cash.bik
					- name: 		Unique name. 								Example:   cash
					- category: 	Category this asset is sorted under 		Example:   grapples_n_guns
			
			
			2. From a script local function ScriptRegisterAsset(), within function RegisterHardcodedScriptAssets of \platform\scripts\vscripts\sh_draw_register_assets.gnut
				- Provide the same 'path', 'name', 'category' as exampled above in your calls to ScriptRegisterAsset(). 
	
	
			3. From Playlist file string var "banner_assets".  This allows server hosts to control what assets are registered for clients that connect to their server. 
				 - For 1v1 playlist, this is auto hooked up to display assets registered via this playlist on the floating banner group seen in the 1v1 waiting	area.
				 
			
		Paking information or registering from script makes fetching assets by category simple, with: WorldDrawAsset_GetAssetArrayByCategory( "grapples_n_guns" ) for example.
		It is not required to associate category information. If the asset is registered by any of the 3 methods above, it can be 
		played(if is audio/video) or appended to a banner group with it's full qualifying name.
		
				Example during appending to banner group:						WorldAssets_GroupAppendAsset( "mygroup", "rui/world/flowstate1v1_banner02" )
				Example playing an audio that does not have a name:   			WorldAssets_PlayAudio( player, "media/playlists/grapples_n_guns/grapples_cash.bik" )
				Example playing an audio that was paked or script registered:	WorldAssets_PlayAudioName( player, "cash" )		
				Example switching an asset in a floating display:				WorldAssets_SwitchToPlayerAssetForGroupNow( player, "rui/world/flowstate1v1_banner02", "mygroup" )
	
	====================================================================================================================================================
	Standard Usage:
		
		Besides paking the assets and registering them, there are 3 steps to utilize them in game logic.
		
			1. Register groups. You can have as many groups as you want. Each group can contain any amount of assets.
			
				- Call first:  WorldAssets_SetAllGroupsFunc( MyRegisterFunc ) 
				- This function lets you register groups. 
				
				** Only:  "name, groupLoc, width, height" are required, the rest can be left out. **		
					These parameters control how assets in your group behave. However, this can be modified during runtime with WorldAssets_ModifyGroupData()
				
					Example: 
					
						void function MyRegisterFunc()
						{
							WorldAssets_RegisterGroup
							(
								"group1", 	// string: 		name				- the name of your assets group
								myLocPair, 	// LocPair: 	groupLoc 			- ( origin and angles ), created with NewLocPair() function. This is where your group apppears. Additionally, WorldAssets_GroupVisibilityMover is a viable utility to automatically move the display to a best effort position so that images/videos are always visible to a player
								width,		// float: 		width 				- of the display
								height,		// float: 		height				- of the display
								.95,		// float: 		alpha				- transparency between 0.0 (fully transparent) and 1.0 (fully solid)
								5,			// float: 		startDelay			- ( wait this long to start cycling assets in this group )
								true,		// bool: 		isVisible			- true: visible, false: must be made visible with WorldAssets_SetVisible( "groupName", true ) -- This also effectively pauses audio queues for all players for that audio group.
								10,			// int:			cycleTime			- Amount of seconds that pass before changing to next asset in the group.
								false,		// bool:		useRandom			- true/false. If true will always pick a random asset from the group
								2.00,		// float:		intermediateTime	- The time waited between fade-ins ( after an image has faded out, wait this time before the next fades in )
								SLOWEST  	// int:			fadeSpeed			- Use constants:  	SLOWEST, SLOWER, SLOW, MODERATE, NORMAL, FAST, FASTER
							)
						}
	

			2. Once groups are created, add assets to them inside of WorldAssets_SetAllAssetsFunc( MyAssetsFunc )
				
				**Only groupName is required, however, you must choose either assetResourceRef or assetId to append.**
			
				Example:
				
					void function MyAssetsFunc()
					{
						WorldAssets_GroupAppendAsset
						( 
							"group1", 								//string:      	groupName 			- Name of the group to append this asset to ( previously registered with WorldAssets_RegisterGroup() )
							"rui/world/flowstate1v1_banner02",		//string:		assetResourceRef	- Asset path to your resource ( would be paked with repak ), or within /media/ for .bik video
							-1,										//int:			assetId				- Optionally append by assetId. Can be got with:  WorldDrawAsset_AssetRefToID( "rui/world/flowstate1v1_banner02" ) for example.
							bLoopVideo,								//bool:			bLoopVideo			- Optional toggle to continuously loop a video. Useful for groups with only one video desired to be played on repeat.
							assetName								//string:		assetName			- Optionally name for debug purposes. If left blank, will attempt to fetch name from it's registration or use the assets resourceRef derrived from assetResourceRef/id if needed.
						)	
					}
	
			3. Once your groups are created and assets appended, initialize the system from your gamemode with:
				
				WorldAssets_Init()
	
	====================================================================================================================================================		
	Audio Usage:
	
		1. Similar to standard usage, audio queues are created with WorldAssets_RegisterAudioGroup(), within your WorldAssets_SetAllGroupsFunc
			
			** only the groupName is required, all others are optional **
		
			Example:
			
				WorldAssets_RegisterAudioGroup
				(
					"grapples_n_guns_audio",		//string:		groupName		- Name of the group
					true,							//bool:	 		interupt		- is audio interruptable: true, or queued: false. If set to true, subsequent audio queues for this group with interrupt and play the new audio sound immediately
					true							//bool:			isVisible		- If set to false, audio will puase for all players from this group. If preconfigured as false, use WorldAssets_SetVisible( "groupName", true) during runtime to enable again.
				)
				
		2.	Append audio assets to the group similar to standard usage above, using WorldAssets_GroupAppendAsset()
			A common method to get the assets you want is by getting all assets for the category you registered it as using:
				WorldDrawAsset_GetAssetArrayByCategory( "categoryname" ), which returns an array of string asset refs, such as [ "media/playlists/grapples_n_guns/grapples_cash.bik" ]
		
		3. Utilize any of the PlayAudio variant functions to play the audio to a player entity. (see top of this doc for more)
			
			-- Optionally, the third parameter of PlayAudio functions allows you to specify which audiogroup to queue from. 
			-- If you have more than one audio group, it is reccomended to specify the group in your audio play calls, otherwise, 
			the system attempts a best effort (fast)lookup to find any group that has the desired audio and queues it to the player.
				
			Examples:
			
				WorldAssets_PlayAudioName( player, "cash" )   -- Uses the name you registered it with.	Most common usage.	
				WorldAssets_PlayAudio( player, "media/playlists/grapples_n_guns/grapples_cash.bik" )
				WorldAssets_PlayAudioID( player, 5 )   --(useful if known) or lookup with WorldDrawAsset_AssetRefToID( "media/playlists/grapples_n_guns/grapples_cash.bik" )
				
			
		Additionally, audio playback is tracked to enable conditional audio playing. By utilizing:
			
			WorldAssets_GetPlayCountForPlayer( entity player, int assetId )
			WorldAssets_GetLastPlayTime( entity player, int assetId )
			WorldAssets_WasAudioPlayedLast( entity player, string assetName = "", string assetRef = "", string groupName = "", int assetId = -1 )  -- can provide any optional parameter to return if this was the last played audio
			WorldAssets_GetLastPlayedAudio( entity player, string groupName = "" )  -- Returns an AudioHistory struct of the last played audio(any) or if group is specified from that group only. contains useful information, see: struct AudioHistory 
			
			You will have to pass the asset id for some functions, which can be got with WorldDrawAsset_AssetRefToID( "media/playlists/grapples_n_guns/grapples_cash.bik" )  for example.
	
	
		A good example utilizing this system is in: \platform\scripts\vscripts\gamemodes\fs_grapples_n_guns\_fs_grapples_n_guns.nut
*/

struct AssetData
{
	int id
	int assetType
	string assetName
	string assetResourceRef //optional for baseasset
	bool loopVideo
	bool isValid
}

struct AssetGroupData
{
	string groupName
	array<AssetData> groupBanners
	vector org 
	vector ang
	int groupId			= -1
	float width 		= -1
	float height 		= -1
	float alpha 		= 1
	bool isVisible 		= true
	int cycleTime 		= 10
	bool isValid 		= false
	bool useRandom 		= false
	float intermediateTime = 2.00
	int fadeSpeed 		= SLOWEST
	int bikCount		= 0
	float startDelay	= 0
	bool bLocked		= false 
	int syncToAsset		= -1
	bool videoFinished	= false
	bool isAudioQueue	= false
	bool interupt		= true
}

struct AudioHistory
{
	int playAmount
	int assetId
	float lastPlayTime
	string assetRef 
	string assetName
	int groupId
	bool isValid = false 
}

#endif //SERVER

struct
{
	#if SERVER
		table< string, table< int, AudioHistory > > audioHistoryMap
		table< string, AssetGroupData > groupDataMap
		table< string, bool > groupSignals
		array< int > __channelRequiredGroups
		table< int, int > audioAssetToGroupMap
		table< string, int > groupNameToGroupIdMap
		
		void functionref() groupsInitCallbackFunc
		void functionref() runAssetAppendtoGroupsFunc
		
		entity dummyEnt
		int	 _uniqueGroupId			= -1
		int iDefaultAudioGroup		= -1
	#endif //SERVER
	
	bool _bAssetGroups_Loaded 	= false
	bool isEnabled = true
	
} file

void function WorldAssets_SetEnabled( bool state )
{
	mAssert( !file._bAssetGroups_Loaded, "[WorldAssets] Tried to set banner assets enabled state with %s() but initialization is already complete. ( Not called early enough )", FUNC_NAME() )
	file.isEnabled = state
}

bool function WorldAssets_IsEnabled()
{
	return file.isEnabled && GetCurrentPlaylistVarBool( "enable_world_assets", true )
}

#if SERVER
void function WorldAssets_Init()
{
	file.isEnabled = WorldAssets_IsEnabled()
	file.dummyEnt = CreateEntity( "info_target" )

	RegisterSignal( "KillAllBannerGroups" )
	
	if( file.isEnabled && file.groupsInitCallbackFunc != null )
	{
		file.groupsInitCallbackFunc()
		
		if( file.runAssetAppendtoGroupsFunc != null )
		{
			file.runAssetAppendtoGroupsFunc()
			
			array<int> bikGroups
			foreach( AssetGroupData bannerGroup in file.groupDataMap )
			{
				if( bannerGroup.bikCount > 0 )
					bikGroups.append( bannerGroup.groupId )
					
				__RegisterGroupSignal( "VisibilityChanged", bannerGroup.groupId )
				__RegisterGroupSignal( "KillGroupForPlayer", bannerGroup.groupId )
			}
			
			foreach( groupId in bikGroups )
				__RegisterGroupSignal( "VideoFinishedPlaying", groupId )
			
			// not used -- no validation is needed from the server, clients validate via client command, and invalid assets are removed from that player's queueable assets
			// array<int> invalidAssets = WorldDrawAsset_GetInvalid()
			// foreach( string groupName, AssetGroupData bannerData in file.groupDataMap )
			// {
				// foreach( banner in bannerData.groupBanners )
				// {
					// if( invalidAssets.contains( banner.id ) )
					// {
						// banner.isValid = false
						
						// #if DEVELOPER && DEBUG_WORLD_ASSET
							// printw( "[WorldAssets] Asset ID:", banner.id, "for group", bannerData.groupId, "ref = ", banner.assetName, "was marked as invalid." )
						// #endif
					// }
				// }
			// }
			
			file.__channelRequiredGroups = bikGroups
			__SetupChannels()	
		}
		
		__SetupThreads()
	}
	
	file._bAssetGroups_Loaded = true
}

bool function WorldAssets_DoesSignalExist( string signal )
{
	return ( signal in file.groupSignals )
}

void function WorldAssets_RegisterGroup( string name, LocPair groupLoc, float width, float height, float alpha = -1.0, float startDelay = 0, bool isVisible = true, int cycleTime = 10, bool useRandom = false, float intermediateTime = 2.00, int fadeSpeed = SLOWEST, bool isAudioQueue = false, bool interupt = true )
{	
	mAssert( !file._bAssetGroups_Loaded, "[WorldAssets] Tried to register WorldAssets_RegisterGroup [" + name + "] but group registration is already complete." )

	AssetGroupData bannerGroup 	
	int iGroupId = ++file._uniqueGroupId
	
	bannerGroup.groupId		= iGroupId
	bannerGroup.groupName 	= name
	bannerGroup.org 		= groupLoc.origin
	bannerGroup.ang 		= groupLoc.angles
	bannerGroup.width 		= width
	bannerGroup.height 		= height
	bannerGroup.alpha 		= alpha
	bannerGroup.isVisible	= isVisible
	bannerGroup.cycleTime	= cycleTime
	bannerGroup.isValid		= true
	bannerGroup.useRandom	= useRandom
	bannerGroup.fadeSpeed	= fadeSpeed
	bannerGroup.startDelay	= startDelay
	bannerGroup.isAudioQueue= isAudioQueue
	bannerGroup.interupt	= interupt
	
	if( isAudioQueue )
	{
		__RegisterGroupSignal( "AudioQueue_Dequeue", iGroupId )
		__RegisterGroupSignal( "AudioChannelReady", iGroupId )

		if( file.iDefaultAudioGroup == -1 )
			file.iDefaultAudioGroup = iGroupId
	}
	
	#if DEVELOPER && DEBUG_WORLD_ASSET
		printt
		(
			bannerGroup.groupName,
			bannerGroup.org,
			bannerGroup.ang,
			bannerGroup.width,
			bannerGroup.height,
			bannerGroup.alpha,
			bannerGroup.isVisible,
			bannerGroup.cycleTime,
			bannerGroup.isValid,
			bannerGroup.useRandom,
			bannerGroup.fadeSpeed,
			bannerGroup.startDelay,
			bannerGroup.isAudioQueue
		)
	#endif
	
	bannerGroup.intermediateTime = intermediateTime
	
	mAssert( !( name in file.groupDataMap ), "[WorldAssets] Tried to add bannerGroup \"" + name + "\" with " + FUNC_NAME() + "()" + " but file.groupDataMap already contains bannerGroup \"" + name + "\"" )
	
	file.groupDataMap[ name ] <- bannerGroup
	file.groupNameToGroupIdMap[ name ] <- iGroupId
}

void function __RegisterGroupSignal( string signalKey, int groupId )
{
	string signal = format( "%s_%d", signalKey, groupId )			
	RegisterSignal( signal )	
	file.groupSignals[ signal ] <- true
}

int function WorldAssets_GetGroupIdByName( string groupName )
{
	if( ( groupName in file.groupNameToGroupIdMap ) )
		return file.groupNameToGroupIdMap[ groupName ]
		
	mAssert( 0, "[WorldAssets] BannerAsset Group name \"%s\" does not exist", groupName )
	return -1
}

void function WorldAssets_RegisterAudioGroup( string name, bool interupt = true, bool isVisible = true, LocPair ornull groupLocOrNull = null, float width = 0.1, float height = 0.1, float alpha = -1.0, float startDelay = 0, int cycleTime = 10, bool useRandom = false, float intermediateTime = 2.00, int fadeSpeed = SLOWEST, bool isAudioQueue = true )
{
	LocPair groupLoc
	if( groupLocOrNull != null )
		groupLoc = expect LocPair ( groupLocOrNull )
	else 
		groupLoc = NewLocPair( ZERO_VECTOR, ZERO_VECTOR )

	WorldAssets_RegisterGroup
	(
		name, 
		groupLoc, 
		width, 
		height, 
		alpha,
		startDelay,
		isVisible,
		cycleTime,
		useRandom,
		intermediateTime,
		fadeSpeed, 
		isAudioQueue,
		interupt
	)
}

void function WorldAssets_SetAllGroupsFunc( void functionref() callbackFunc )
{
	mAssert( !file._bAssetGroups_Loaded, "[WorldAssets] Tried to register WorldAssets_SetAllGroupsFunc [ " + string( callbackFunc ) + "() ] but group registration is already complete." )
	file.groupsInitCallbackFunc = callbackFunc
}

void function WorldAssets_SetAllAssetsFunc( void functionref() callbackFunc )
{
	mAssert( !file._bAssetGroups_Loaded, "[WorldAssets] Tried to register " + FUNC_NAME() + "() [ " + string( callbackFunc ) + "() ] but group registration is already complete." )
	file.runAssetAppendtoGroupsFunc = callbackFunc
}

AssetGroupData function GetAssetGroup( string groupName )
{
	AssetGroupData group 
	
	if( groupName in file.groupDataMap )
		return file.groupDataMap[ groupName ]

	return group
}

string function GetAssetGroupName( int groupId )
{
	foreach( string groupName, AssetGroupData groupData in file.groupDataMap )
	{
		if( groupData.groupId == groupId )
			return groupName
	}
	
	return INVALID_GROUP_NAME
}

AssetGroupData function GetAssetGroupByID( int groupId ) //check with .isValid
{
	return GetAssetGroup( GetAssetGroupName( groupId ) )
}

void function WorldAssets_GroupAppendAsset( string groupName, string assetResourceRef = "", int assetId = -1, bool bLoopVideo = false, string assetName = "" )
{
	AssetGroupData group = GetAssetGroup( groupName )
	
	if( !group.isValid ) 
	{
		#if DEVELOPER
			Warning( "Group " + groupName + " was invalid." )
		#endif
		
		return
	}
	
	AssetData banner
	asset potentialAsset
	int assetType 
	
	if ( !empty( assetResourceRef ) )
	{
		assetType = WorldDrawAsset_GetAssetType( potentialAsset, assetResourceRef )
		if( assetId == -1 )
			assetId = WorldDrawAsset_AssetRefToID( assetResourceRef )
	}
	else
	{
		potentialAsset  = WorldDrawAsset_GetAssetByID( assetId )
		assetType		= WorldDrawAsset_GetAssetType( potentialAsset )
	}
	
	if( assetType == eAssetType.INVALID )
		mAssert( 0, "[WorldAssets] Asset was invalid during appendature for group: \"%s\", assetId: [%d], assetResourceRef: \"%s\"", groupName, assetId, assetResourceRef )
	
	if( assetType == eAssetType.BIK )
	{
		MapAudioAssetToGroup( assetId, group.groupId ) //This is for best effort playing without providing the groupName in PlayAudio functions. Has no adverse effect for video types.
		group.bikCount++
	}
		
	if( empty( assetName ) )
	{
		assetName = !empty( assetResourceRef ) ? assetResourceRef : string( potentialAsset )
		assetName = WorldDrawAsset_LookupAssetNameByRef( assetName )
	}
	
	banner.id					= assetId
	banner.assetType			= assetType
	banner.assetName			= assetName
	banner.assetResourceRef		= assetResourceRef
	banner.loopVideo			= bLoopVideo
	banner.isValid				= true
	
	file.groupDataMap[ groupName ].groupBanners.append( banner )
}

void function __SetupChannels()
{
	foreach( player in GetPlayerArray() ) //edge case
	{
		if( !player.p.isConnected )
			continue
			
		WorldAssets_InitPlayerVideoChannels( player )
	}
	
	AddCallback_OnClientConnected( WorldAssets_InitPlayerVideoChannels ) //main case
}

void function WorldAssets_InitPlayerVideoChannels( entity player )
{
	foreach( int iter, int groupId in file.__channelRequiredGroups )
	{
		if( iter + CURRENT_RESERVED_CHANNELS > MAX_BIK_CHANNELS )
		{
			mAssert( 0, "[WorldAssets] Cannot create any more channels for clients." )
			return
		}
		else 
		{
			Remote_CallFunction_NonReplay( player, "ServerCallback_CreateChannel", groupId )
		}
	}
}

void function __SignalAudioChannelReadyForPlayerForGroup( entity player, int groupId )
{	
	player.p.isGroupChannelCreatedTbl[ groupId ] <- true
	player.Signal( GetGroupSignal( "AudioChannelReady", groupId ) )
}

void function WorldAssets_WaitForChannelCreation( entity player, string groupName )
{
	int groupId = WorldAssets_GetGroupIdByName( groupName )
	
	if( IsChannelCreatedForPlayerForGroup( player, groupId ) )
		return 
		
	player.WaitSignal( GetGroupSignal( "AudioChannelReady", groupId ) )
}

bool function WorldAssets_IsChannelCreatedForPlayer( entity player, string groupName )
{
	int groupId = WorldAssets_GetGroupIdByName( groupName )
	if( groupId < 0 )
		return false 
		
	return IsChannelCreatedForPlayerForGroup( player, groupId )
}

bool function IsChannelCreatedForPlayerForGroup( entity player, int groupId )
{
	if( !( groupId in player.p.isGroupChannelCreatedTbl ) )
		return false 
		
	return player.p.isGroupChannelCreatedTbl[ groupId ]
}

void function WorldAssets_KillAllBanners()
{
	Signal( file.dummyEnt, "KillAllBannerGroups" )
}

bool function HasValidRuiData( entity player, int groupId )
{
	return GroupDataHasRuiSet( GetGroupData( player, groupId ) )
}

void function WorldAssets_DestroyAllRuiAndTopo( entity player )
{
	foreach( string groupName, AssetGroupData groupData in file.groupDataMap )
	{
		if( HasValidRuiData( player, groupData.groupId ) )
		{
			int ruiId
			foreach( int assetType in eAssetType )
			{
				if( assetType == eAssetType.INVALID )
					continue 
					
				ruiId = GetRUIID( player, groupData.groupId, assetType )
				
				if( assetType != eAssetType.INVALID )
					WorldDrawAsset_DestroyOnClient( player, ruiId )
			}
			
			if( groupData.groupId in player.p.groupTypeToRuiID ) //should always be
				delete player.p.groupTypeToRuiID[ groupData.groupId ]
		}
	}
}

void function WorldAssets_LockGroupsTo( int assetId, int groupId = -1 )
{
	WorldAssets_SyncAllPlayers( assetId, true, groupId, "" )
}

void function WorldAssets_Lock( int groupId )
{
	string group = GetAssetGroupName( groupId )
	
	if( group == INVALID_GROUP_NAME )
	{
		Warning( "groupId '%d' was invalid", groupId )
		return
	}
	
	WorldAssets_ModifyGroupData( group, { bLocked = true } )
}

void function WorldAssets_Restart()
{
	WorldAssets_SyncAllPlayers()
}

void function WorldAssets_Unlock( int groupId )
{
	string group = GetAssetGroupName( groupId )
	
	if( group == INVALID_GROUP_NAME )
	{
		Warning( "groupId '%d' was invalid", groupId )
		return
	}
		
	WorldAssets_ModifyGroupData( group, { bLocked = false } )
}

AssetData function __GetBannerDataForID( array<AssetData> banners, int bannerId )
{
	AssetData invalidBanner
	
	foreach( bannerData in banners )
	{
		if( bannerData.id == bannerId )
			return bannerData
	}
	
	return invalidBanner
}

void function WorldAssets_SetVisible( string groupName, bool setting )
{
	if( !WorldAssets_ModifyGroupData( groupName, { visible = setting } ) )
		sqwarning( "[WorldAssets] Tried to modify group \"%s\" visibility but the group does not exist", groupName )
}

bool function WorldAssets_ModifyGroupData( string groupName, table tbl )
{
	AssetGroupData group = GetAssetGroup( groupName )
	
	if( !group.isValid )
		return false
		
	foreach( key, value in tbl )
	{
		switch( key )
		{
			case "groupName":
				group.groupName 	= expect string ( value )
				break
				
			case "org":
				group.org 			= expect vector ( value )
				break
				
			case "ang":	
				group.ang 			= expect vector ( value )
				break
				
			case "width":	
				group.width 		= expect float ( value )
				break
				
			case "height":	
				group.height 		= expect float ( value )
				break
				
			case "alpha":	
				group.alpha 		= expect float ( value )
				break
				
			case "visible":	
				
				bool visibility 	= expect bool ( value )	
				
				if( group.isVisible != visibility )
				{
					group.isVisible	= visibility
					
					string signal = GetGroupSignal( "VisibilityChanged", group.groupId )
					
					if( WorldAssets_DoesSignalExist( signal ) )
						Signal( file.dummyEnt, signal )
					else 
						sqwarning( "Tried to signal group %d for visibility but signal %s does not exist", group.groupId, signal )
				}
					
				break
				
			case "cycleTime":	
				group.cycleTime		= expect int ( value )
				break
				
			case "isValid":	
				group.isValid		= expect bool ( value )
				break
				
			case "useRandom":	
				group.useRandom		= expect bool ( value )
				break
				
			case "videoFinished":
				group.videoFinished	= expect bool ( value )
				break
				
			case "bLocked":
				group.bLocked		= expect bool ( value )
				break
				
			default:
				mAssert( 0, "[WorldAssets] key name [" + key + "] does not exist in struct AssetGroupData" )
				return true
		}
	}
	
	return true
}


void function __SetupThreads()
{
	foreach( string name, AssetGroupData data in file.groupDataMap )
	{		
		#if DEVELOPER && DEBUG_WORLD_ASSET
			Warning( "Spawning banner group: " + name )
		#endif
		
		AddCallback_OnClientConnected
		(
			void function( entity player ) : ( data )
			{			
				thread __Singlethread( player, data )
			}
		)
	}
}

void function WorldAssets_SyncAllPlayers( int assetRefId = -1, bool bLocked = false, int groupId = -1, string assetRef = "" )
{
	if( !empty( assetRef ) )
	{
		assetRefId = WorldDrawAsset_AssetRefToID( assetRef )
		
		if( assetRefId <= -1 )
		{
			Warning( "Asset ref id '" + assetRefId + "' is invalid." )
			return
		}
	}
	
	thread
	(
		void function() : ( assetRefId, bLocked, groupId )
		{
			WorldAssets_KillAllBanners()
			WaitEndFrame() //let banners hide before restarting.
			
			foreach( player in GetPlayerArray() )
			{
				foreach( string name, AssetGroupData data in file.groupDataMap )
				{	
					data = clone data
					data.syncToAsset = assetRefId 
					data.bLocked	 = bLocked
					
					if( groupId > -1 )
					{
						if( data.groupId != groupId )
							continue
					}
					
					thread __Singlethread( player, data )
				}
			}
		}
	)()
}

void function __HideAllBanners( entity player, AssetGroupData groupData )
{
	if( !IsValid( player ) ) //player might have disconnected
		return
		
	if( !HasValidRuiData( player, groupData.groupId ) )
		return 
		
	array<AssetData> banners = groupData.groupBanners
		
	int iter = -1
	foreach( banner in banners )
	{
		++iter
		if( !banners[ iter ].isValid )
			continue 
			
		int iRui = GetRUIID( player, groupData.groupId, banner.assetType )

		if( iRui < 0 )
			continue
			
		WorldDrawAsset_SetVisible
		(
			player,
			iRui,
			groupData.groupId,
			false,
			false, 
			false, 
			banners[ iter ].id,
			0,
			false
		)
	}
}


table< int, int > function CreateAssetTbl()
{
	table< int, int > tbl = {} 
	
	foreach( keyName, value in eAssetType )
		tbl[ value ] <- -1
	
	return tbl
}

void function SetGroupData( entity player, int groupId, table<int,int> groupData )
{
	player.p.groupTypeToRuiID[ groupId ] <- groupData
}

bool function GroupDataHasRuiSet( table<int, int> tbl )
{
	foreach( k,v in tbl )
	{
		if( v != -1 )
			return true
	}
	
	return false
}

table<int, int> function GetGroupData( entity player, int groupId )
{
	if( !( groupId in player.p.groupTypeToRuiID ) )
	{
		table< int, int > tbl = CreateAssetTbl()
		player.p.groupTypeToRuiID[ groupId ] <- tbl
	}
		
	return player.p.groupTypeToRuiID[ groupId ]
}

int function GetRUIID( entity player, int groupId, int assetType )
{
	return player.p.groupTypeToRuiID[ groupId ][ assetType ]
}

void function SetRUIID( entity player, int groupId, int assetType, int RUIID )
{
	player.p.groupTypeToRuiID[ groupId ][ assetType ] = RUIID
}

array<AssetData> function DeepCopyBanner( array<AssetData> banners )
{
	array<AssetData> returnBanners = []
	
	foreach ( AssetData banner in banners )
	{
		AssetData bannerClone
		
		bannerClone.id = banner.id
		bannerClone.assetType = banner.assetType
		bannerClone.assetName = banner.assetName
		bannerClone.assetResourceRef = banner.assetResourceRef
		bannerClone.loopVideo = banner.loopVideo
		bannerClone.isValid = banner.isValid

		returnBanners.append( bannerClone )
	}

    return returnBanners
}

vector function WorldAssets_GroupVisibilityMover( vector eyePos, vector eyeAngles, vector initialPosition, vector initialAngles, float bannerWidth, float bannerHeight, float adjustmentDistance = 5.0, float maxIterations = 1000 ) 
{
	array<vector> corners
	vector forward, right, up, simulateEyePos, playerEyeAngles

	float halfWidth = bannerWidth * 0.5
	float halfHeight = bannerHeight * 0.5

	vector currentPosition = initialPosition
	
	corners.resize(4)
	
	forward 	= AnglesToForward( initialAngles )
	right 		= AnglesToRight( initialAngles )
	up			= AnglesToUp( initialAngles )

	simulateEyePos 	= eyePos
	playerEyeAngles = eyeAngles
	
	int iter = 0
    while ( iter < maxIterations ) 
	{
		#if DEVELOPER && DEBUG_WORLD_ASSET
			Warning( "Adjusting..." )
		#endif

        corners[ 0 ] = currentPosition + ( forward * halfHeight ) - ( right * halfWidth )
        corners[ 1 ] = currentPosition + ( forward * halfHeight ) + ( right * halfWidth )
        corners[ 2 ] = currentPosition - ( forward * halfHeight ) - ( right * halfWidth )
        corners[ 3 ] = currentPosition - ( forward * halfHeight ) + ( right * halfWidth )

        bool allCornersVisible = true

		for ( int i = 0; i < 4; i++ ) 
		{
			vector corner = corners[ i ]
			TraceResults traceResult = TraceLine( simulateEyePos, corner, [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
			
			float distanceToCorner = Distance( simulateEyePos, corner )
			float traceEndDistance = Distance( simulateEyePos, traceResult.endPos )

			if ( traceResult.fraction < 1.0 && traceEndDistance < distanceToCorner ) 
			{
				allCornersVisible = false
				break
			}
		}

        if ( allCornersVisible ) 
		{
			#if DEVELOPER && DEBUG_WORLD_ASSET
				Warning( "FOUND A GOOD POSITION: " + currentPosition )
			#endif
			
            return currentPosition
        }

		currentPosition = AdjustBannerPosition( currentPosition, initialAngles, simulateEyePos, adjustmentDistance )
		adjustmentDistance += 5

		iter++
	}

	return initialPosition
}

vector function AdjustBannerPosition( vector currentPosition, vector currentAngles, vector simulateEyePos, float adjustmentDistance ) 
{
	array<vector> adjustments
	
	//adjustments.append( AnglesToForward( currentAngles ) * -adjustmentDistance )
	adjustments.append( <0, 0, adjustmentDistance> )
	adjustments.append( <0, 0, -adjustmentDistance> )
	adjustments.append( AnglesToRight( currentAngles ) * adjustmentDistance )
	adjustments.append( AnglesToRight( currentAngles ) * -adjustmentDistance )
	adjustments.append( AnglesToForward( currentAngles ) * adjustmentDistance )
    
	int adjustmentsLen = adjustments.len()
	for ( int i = 0; i < adjustmentsLen; i++ ) 
	{
		vector adjustment = adjustments[ i ]
		vector newPosition = currentPosition + adjustment
	
		if ( IsPositionClear( newPosition, simulateEyePos ) )  
			return newPosition
	}

	#if DEVELOPER && DEBUG_WORLD_ASSET
		Warning( "Failed to find a good position" )
	#endif

	return currentPosition
}

bool function IsPositionClear( vector position, vector simulateEyePos ) 
{
	TraceResults traceResult = TraceLine( simulateEyePos, position, [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
	return traceResult.fraction == 1.0
}

void function UpdateAudioHistory( entity player, int assetId, int groupId )
{
	AudioHistory history = GetAssetAudioHistoryForPlayer( player, assetId )
	
	#if DEVELOPER && DEBUG_WORLD_ASSET
		printf
		(
			"[WorldAssets] Setting audio history for assetId %d, groupId %d",
			assetId, 
			groupId
		)
	#endif
	
	history.playAmount		+= 1
	history.assetId			= assetId
	history.lastPlayTime	= Time()
	history.assetRef		= WorldDrawAsset_GetAssetRefById( assetId )
	history.assetName		= WorldDrawAsset_LookupAssetNameByRef( history.assetRef )
	history.groupId 		= groupId
}

bool function WorldAssets_WasAudioPlayedLast( entity player, string assetName = "", string assetRef = "", string groupName = "", int assetId = -1 )
{	
	if( assetName != "" )
	{
		assetRef = WorldAssets_GetAssetRefByName( assetName )
		assetId = WorldDrawAsset_AssetRefToID( assetRef )
	}
	else if( assetRef != "" )
	{
		assetId = WorldDrawAsset_AssetRefToID( assetRef )
	}
	else if( assetId == -1 )
	{
		mAssert( 0, "[WorldAssets] Must provide one of: assetName, assetref, or assetId in a call to %s()", FUNC_NAME() )
	}
	
	AudioHistory lastPlayed = WorldAssets_GetLastPlayedAudio( player, groupName )
	
	if( lastPlayed.assetId == assetId )
		return true
	
	return false
}

AudioHistory function WorldAssets_GetLastPlayedAudio( entity player, string groupName = "" )
{
	int groupId = -1
	
	if( groupName != "" )
		groupId = WorldAssets_GetGroupIdByName( groupName )
	
	array<AudioHistory> allHistory = GetAllAudioHistoryForPlayer( player, groupId )	
	
	allHistory.sort( SortAudioHistory )	
	
	if( allHistory.len() )
		return allHistory.pop()
	
	AudioHistory nullHistory
	return nullHistory
}

int function SortAudioHistory( AudioHistory a, AudioHistory b )
{
	if( a.lastPlayTime > b.lastPlayTime )
		return 1
		
	if( a.lastPlayTime < b.lastPlayTime )
		return -1

	return 0
}

array<AudioHistory> function GetAllAudioHistoryForPlayer( entity player, int groupId )
{
	array<AudioHistory> allHistory
	
	if( !( player.p.UID in file.audioHistoryMap ) )
		return allHistory
	
	foreach( AudioHistory history in file.audioHistoryMap[ player.p.UID ] )
	{
		if( groupId > -1 && groupId != history.groupId )
			continue 
			
		allHistory.append( history )
	}
		
	return allHistory
}

AudioHistory function GetAssetAudioHistoryForPlayer( entity player, int assetId )
{
	CheckAudioTrackingForPlayer( player, assetId )
	return file.audioHistoryMap[ player.p.UID ][ assetId ]
}

int function WorldAssets_GetPlayCountForPlayer( entity player, int assetId )
{
	AudioHistory history = GetAssetAudioHistoryForPlayer( player, assetId )
	return history.playAmount
}

float function WorldAssets_GetLastPlayTime( entity player, int assetId )
{
	AudioHistory history = GetAssetAudioHistoryForPlayer( player, assetId )
	return history.lastPlayTime
}

AudioHistory function WorldAssets_GetAudioHistoryForPlayerForAsset( entity player, string assetName = "", string assetRef = "", int assetId = -1 )
{
	if( assetName != "" )
	{
		assetRef = WorldAssets_GetAssetRefByName( assetName )
		assetId = WorldDrawAsset_AssetRefToID( assetRef )
	}
	else if( assetRef != "" )
	{
		assetId = WorldDrawAsset_AssetRefToID( assetRef )
	}
	else if( assetId == -1 )
	{
		mAssert( 0, "[WorldAssets] Must provide one of: assetName, assetref, or assetId in a call to %s()", FUNC_NAME() )
	}
	
	return GetAssetAudioHistoryForPlayer( player, assetId )
}

void function __AudioQueue( entity player, AssetData baseBannerVideo, AssetGroupData groupData )
{
	if( !IsValid( player ) )//threaded off
		return

	string groupKillSignal = GetGroupSignal( "KillGroupForPlayer", groupData.groupId )
	
	player.Signal( groupKillSignal )
	player.EndSignal
	( 
		"OnDestroy", 
		"KillAllBannerGroups", 
		groupKillSignal
	)
	
	__SetupAudioQueueForPlayer( player, groupData.groupId )
	__SignalAudioChannelReadyForPlayerForGroup( player, groupData.groupId )
	
	if( !groupData.isValid )
	{
		#if DEVELOPER 
			printf( "[WorldAssets] Invalid group: '%d' for player: %s", groupData.groupId, string( player ) )
		#endif 	
		
		return
	}
	
	for( ; ; )
	{	
		if( !groupData.isVisible )
		{
			WaitSignal( file.dummyEnt, GetGroupSignal( "VisibilityChanged", groupData.groupId ) )
			continue
		}
	
		if( !groupData.interupt )
		{
			while( IsPlayingAudioForPlayer( player, groupData.groupId ) )
				WaitFrame()
		}
		
		int audioAssetId
		
		if( AudioQueue_Len( player, groupData.groupId ) > 0 )
		{
			audioAssetId = AudioQueue_Dequeue( player, groupData.groupId )
		}
		else
		{
			string signal = GetGroupSignal( "AudioQueue_Dequeue", groupData.groupId )
			if( !WorldAssets_DoesSignalExist( signal ) )
			{
				sqwarning( "[WorldAssets] Signal \"%s\" does not exist, ending audio thread for player: %s.", signal, string( player ) )
				return
			}
				
			table results = player.WaitSignal( signal )	
			
			if ( results.len() == 0 )
				continue
				
			if( !( "assetRefId" in results ) )
				continue
		
			if( !groupData.isVisible )
				continue
		
			audioAssetId = expect int( results.assetRefId )
		}
		
		AssetData banner = __GetBannerDataForID( groupData.groupBanners, audioAssetId )	
		if( !banner.isValid )
		{
			Warning( format( "[WorldAssets] Audio AssetId [%d] does not exist in group [%d]", audioAssetId, groupData.groupId ) )
			continue
		}
		
		//set the server managed ruiid instance to use based on type.
		int clientRUIID = GetRUIID( player, groupData.groupId, banner.assetType )
		
		#if DEVELOPER && DEBUG_WORLD_ASSET
			printf
			( 
				"[WorldAssets] playing sound '%s' as type: '%s', in group: '%s', RUIID = '%d' for player: %s",
				banner.assetName,
				GetEnumString( "eAssetType", banner.assetType ),
				groupData.groupName,
				clientRUIID,
				string( player )
			)
		#endif 
		
		//change over to next asset.
		WorldDrawAsset_Modify
		(
			player, 
			clientRUIID,
			groupData.groupId,
			ZERO_VECTOR, 
			ZERO_VECTOR, 
			-1.0, 
			-1.0, 
			0, 
			banner.id 
		)
		
		//play it on the client
		WorldDrawAsset_SetVisible
		(
			player,
			clientRUIID, 
			groupData.groupId,
			true,
			true, 
			true, 
			banner.id,
			groupData.fadeSpeed,
			banner.loopVideo
		)
			
		thread AudioMonitor( player, groupData.groupId, banner.id )
		
		if( !groupData.interupt )
			player.WaitSignal( GetGroupSignal( "VideoFinishedPlaying", groupData.groupId ) )
	}
}

void function __SetupAudioQueueForPlayer( entity player, int groupId )
{
	if( !( groupId in player.p.isPlayingAudio ) )	
		player.p.isPlayingAudio[ groupId ] <- false

	if( !( groupId in player.p.audioQueue ) )
		player.p.audioQueue[ groupId ] <- []
}

void function MapAudioAssetToGroup( int audioAssetId, int groupId )
{
	if( !( audioAssetId in file.audioAssetToGroupMap ) )
		file.audioAssetToGroupMap[ audioAssetId ] <- groupId
	else 
	{	
		#if DEVELOPER 
			int currentGroup = file.audioAssetToGroupMap[ audioAssetId ]
			printf
			( 
				"[WorldAssets] Audio asset id [%d] is already assigned to group [%d], reassigning to group: [%d]. If audio is not playing correctly provide the groupId when playing (third parameter)",
				audioAssetId,
				currentGroup,
				groupId
			)
		#endif 
		
		file.audioAssetToGroupMap[ audioAssetId ] = groupId
	}
}

void function AudioMonitor( entity player, int groupId, int audioId )
{
	if( !IsValid( player ) )
		return

	IsPlayingAudioForPlayer( player, groupId, true )
	UpdateAudioHistory( player, audioId, groupId )
		
	OnThreadEnd
	(
		void function() : ( player, groupId )
		{
			if( IsValid( player ) )
				IsPlayingAudioForPlayer( player, groupId, false )
		}
	)
	
	player.EndSignal( "OnDestroy", GetGroupSignal( "VideoFinishedPlaying", groupId ), GetGroupSignal( "KillGroupForPlayer", groupId ) ) //potential abuse without a timeout
	EndSignal( file.dummyEnt, "KillAllBannerGroups" )
	
	WaitForever()
}

//bool from flag 
bool function IsPlayingAudioForPlayer( entity player, int groupId, bool ornull isPlayingOrNull = null )
{	
	if( isPlayingOrNull != null )
	{
		if( !( groupId in player.p.isPlayingAudio ) )
			player.p.isPlayingAudio[ groupId ] <- expect bool( isPlayingOrNull )
		else 
			player.p.isPlayingAudio[ groupId ] = expect bool( isPlayingOrNull )
	}
	
	if( ( groupId in player.p.isPlayingAudio ) )
		return player.p.isPlayingAudio[ groupId ]

	return false
}

void function CheckAudioTrackingForPlayer( entity player, int assetId )
{
	if( !( player.p.UID in file.audioHistoryMap ) )
		file.audioHistoryMap[ player.p.UID ] <- {}
	
	if( !( assetId in file.audioHistoryMap[ player.p.UID ] ) )
	{
		AudioHistory history
		history.isValid = true
		
		file.audioHistoryMap[ player.p.UID ][ assetId ] <- history
	}
}

int function AudioQueue_Dequeue( entity player, int groupId )
{
	#if DEVELOPER
		if( player.p.audioQueue[ groupId ].len() == 0 )
			mAssert( 0, "[WorldAssets] Tried to pop audio queue with no items in it." )
	#endif 
	
	return player.p.audioQueue[ groupId ].remove( 0 )
}

void function AudioQueue_Enqueue( entity player, int audio, int groupId )
{
	player.p.audioQueue[ groupId ].append( audio )
}

void function AudioQueue_Remove( entity player, int audio, int groupId )
{
	player.p.audioQueue[ groupId ].removebyvalue( audio )
}

void function AudioQueue_Clear( entity player, int groupId )
{
	player.p.audioQueue[ groupId ].clear()
}

array<int> function AudioQueue_Get( entity player, int groupId )
{
	return player.p.audioQueue[ groupId ]
}

int function AudioQueue_Len( entity player, int groupId )
{
	return player.p.audioQueue[ groupId ].len()
}

bool function __HandleAudioQueue( entity player, int audioId, string groupName = "" ) //returns true for audio exists, false if not
{
	if( audioId != -1 )
	{
		if( !player.IsPlayer() )
			return true
	
		int groupId
		if( groupName == "" )
			groupId = GetBestEffortGroupForAudioAsset( audioId )
		else
			groupId = WorldAssets_GetGroupIdByName( groupName )
	
		if( IsPlayingAudioForPlayer( player, groupId ) )
			AudioQueue_Enqueue( player, audioId, groupId )
		//else ( else statement not tested for timing issues)
		
		string signal = GetGroupSignal( "AudioQueue_Dequeue", groupId )
		if( WorldAssets_DoesSignalExist( signal ) )
			player.Signal( signal, { assetRefId = audioId } )
		else 
			sqwarning( "Signal \"%s\" does not exist. Cannot queue audio.", signal )
			
		return true
	}
	
	return false
}

int function GetBestEffortGroupForAudioAsset( int audioId )
{
	if( ( audioId in file.audioAssetToGroupMap ) )
		return file.audioAssetToGroupMap[ audioId ]
		
	return file.iDefaultAudioGroup
}

//Wrappers for playing audio files: 
void function WorldAssets_PlayAudio( entity player, string assetRef, string groupName = "" )
{
	int assetId = WorldDrawAsset_AssetRefToID( assetRef )
	if ( !__HandleAudioQueue( player, assetId, groupName ) )
		sqwarning( "Audio assetRef \"%s\" does not exist", assetRef )
}

void function WorldAssets_PlayAudioID( entity player, int assetId = -1, string groupName = "" )
{
	if( !__HandleAudioQueue( player, assetId, groupName ) )
		sqwarning( "Audio assetId \"%d\" does not exist", assetId )
}

void function WorldAssets_PlayAudioName( entity player, string audioName, string groupName = "" )
{
	string assetRef = WorldAssets_GetAssetRefByName( audioName )
	int assetId = WorldDrawAsset_AssetRefToID( assetRef )

	if( !__HandleAudioQueue( player, assetId, groupName ) )
		sqwarning( "Audio asset by name \"%s\" does not exist", audioName )
}

string function WorldAssets_GetAssetRefByName( string assetName )
{	
	if( assetName in WorldDrawAsset_GetAssetLookupTable() )
		return WorldDrawAsset_GetAssetLookupTable()[ assetName ]
		
	return ""
}

void function __PrintAssetMissingForGroup( int assetId, int groupId )
{
	Warning
	( 
		"[WorldAssets] AssetId [%d]\"%s\" does not exist in group [%d]\"%s\"", 
		assetId, 
		WorldDrawAsset_GetAssetRefById( assetId ),
		groupId, 
		WorldAssets_GetGroupNameByID( groupId )
	)
}

string function WorldAssets_GetGroupNameByID( int groupId )
{
	return GetAssetGroupName( groupId )
}

void function SetupGroupSyncAssetsForPlayer( entity player, int groupId )
{
	if( !( groupId in player.p.syncGroupToAssetForPlayer )  )
		player.p.syncGroupToAssetForPlayer[ groupId ] <- -1
}

void function WorldAssets_SwitchToPlayerAssetForGroupNow( entity player, string assetRef, string groupName )
{
	AssetGroupData group = GetAssetGroup( groupName )
	if( !group.isValid )
	{
		Warning( "[WorldAssets] Group \"%s\" is not a valid group name.", groupName )
		return
	}
	
	int groupId 	= group.groupId 
	int assetId 	= WorldDrawAsset_AssetRefToID( assetRef )
	
	if( assetId == -1 )
	{
		Warning( "[WorldAssets] Asset Ref \"%s\" is not a valid asset or is not registered", assetRef )
		return
	}
	
	if( !( groupId in player.p.syncGroupToAssetForPlayer ) )
		player.p.syncGroupToAssetForPlayer[ groupId ] <- assetId 
	else 
		player.p.syncGroupToAssetForPlayer[ groupId ] = assetId
		
	player.Signal( GetGroupSignal( "KillGroupForPlayer", groupId ) )
	thread __Singlethread( player, clone group )
}

string function GetGroupSignal( string signal, int groupId )
{
	return format( "%s_%d", signal, groupId )
}

void function __Singlethread( entity player, AssetGroupData groupData )
{
	//FlagWait( "EntitiesDidLoad" )
	
	#if DEVELOPER
		mAssert( IsNewThread(), "[WorldAssets] Must be threaded off." )
	#endif
	
	array<AssetData> banners = DeepCopyBanner( groupData.groupBanners )
	
	if( banners.len() == 0 )
	{
		#if DEVELOPER && DEBUG_WORLD_ASSET
			Warning( "(0) banners were found, returning." )
		#endif 
		return
	}
	else 
	{
		#if DEVELOPER && DEBUG_WORLD_ASSET
			Warning( "Found: " + banners.len() + " assets in group: " + groupData.groupName )
		#endif 
	}
	
	string groupKillSignal = GetGroupSignal( "KillGroupForPlayer", groupData.groupId )
	
	player.Signal( groupKillSignal )
	EndSignal( player, "OnDestroy", groupKillSignal )
	EndSignal( file.dummyEnt, "KillAllBannerGroups" )
	
	if( !player.p.bannersValidated )
		player.WaitSignal( "BannersValidated" )
		
	int ogBannersLen = banners.len()
	for( int i = ogBannersLen - 1; i >= 0; i-- )
	{
		if( player.p.invalidAssets.contains( banners[ i ].id ) )
			banners.remove( i )
	}
	
	#if DEVELOPER && DEBUG_WORLD_ASSET
		int currentBannerLen = banners.len()
		if( ogBannersLen != currentBannerLen )
			Warning( "some assets were invalid and removed, newLen = %d, oldLen = %d, player =", currentBannerLen, ogBannersLen, string( player ) )
	#endif 

	AssetData baseBannerImage
	AssetData baseBannerVideo
	
	bool bFirstRun = !HasValidRuiData( player, groupData.groupId )
	int clientRUIID = -1
	bool bDontSync
	int iter
	
	WaitEndFrame()
	//////////////
	//	CREATE 	//
	//////////////
	if( bFirstRun )
	{
		#if DEVELOPER && DEBUG_WORLD_ASSET
			printw( "[WorldAssets] setting group first run for group ", groupData.groupId )
		#endif 
		
		SetupGroupSyncAssetsForPlayer( player, groupData.groupId )
		
		GetGroupData( player, groupData.groupId )[ eAssetType.IMAGE ] <- -1 
		GetGroupData( player, groupData.groupId )[ eAssetType.BIK ] <- -1 
		
		bool bFoundImage = false
		bool bFoundVideo = false

		iter = -1
		foreach( banner in banners )
		{
			iter++
			
			switch( banner.assetType )
			{
				case eAssetType.IMAGE:
				
					if( bFoundImage )
						break
					
					#if DEVELOPER && DEBUG_WORLD_ASSET
						printw( "[WorldAssets] found base bannerIMAGE in group", groupData.groupId, "for banner id", banners[ iter ].id  )
					#endif 
				
					baseBannerImage = banners[ iter ]
					bFoundImage = true
					break 
					
				case eAssetType.BIK:
				
					if( bFoundVideo )
						break
						
					#if DEVELOPER && DEBUG_WORLD_ASSET
						printw( "[WorldAssets] found base bannerVIDEO in group", groupData.groupId, "for banner id", banners[ iter ].id  )
					#endif
					
					baseBannerVideo = banners[ iter ]
					bFoundVideo = true
					break
			}
		}
		
		WaitFrame()
		///////////
		// IMAGE //
		///////////
		if( bFoundImage )
		{
			clientRUIID = WorldDrawAsset_CreateOnClient //returns a single topo+ruiid that will cycle any image
			(
				player, 
				baseBannerImage.assetResourceRef,
				groupData.org,
				groupData.ang,
				groupData.width,
				groupData.height,
				groupData.groupId,
				baseBannerImage.id,
				groupData.alpha,
				groupData.isVisible
			)
			
			GetGroupData( player, groupData.groupId )[ eAssetType.IMAGE ] = clientRUIID
			
			WorldDrawAsset_SetVisible
			(
				player,
				clientRUIID,
				groupData.groupId,
				false,
				false, 
				false, 
				baseBannerImage.id,
				groupData.fadeSpeed
			)
			
			#if DEVELOPER && DEBUG_WORLD_ASSET
				printt( "[WorldAssets] Spawning base rui for banner:", baseBannerImage.assetName )
			#endif
			
			#if DEVELOPER && DEBUG_WORLD_ASSET
				printt
				(
					"clientRUIID", clientRUIID, "\n",
					"player", player, "\n",
					"baseBannerImage.assetResourceRef", baseBannerImage.assetResourceRef, "\n",
					"groupData.org", groupData.org, "\n",
					"groupData.ang", groupData.ang, "\n",
					"groupData.width", groupData.width, "\n",
					"groupData.height", groupData.height, "\n",
					"baseBannerImage.id", baseBannerImage.id, "\n",
					"groupData.alpha", groupData.alpha, "\n",
					"groupData.isVisible", groupData.isVisible, "\n",
					"groupData.groupId", groupData.groupId, "\n",
					"groupData.intermediateTime", groupData.intermediateTime, "\n",
					"groupData.fadeSpeed", groupData.fadeSpeed, "\n",
					"groupData.startDelay", groupData.startDelay, "\n",
					"groupData.cycleTime", groupData.cycleTime, "\n",
					"groupData.isAudioQueue", groupData.isAudioQueue, "\n",
					"groupData.interupt", groupData.interupt, "\n",
					"groupData.bikCount", groupData.bikCount, "\n"
				)
			#endif
		}
		
		WaitFrame() //always wait before creating another rui on the client.
		///////////
		// VIDEO //
		///////////
		if( bFoundVideo )
		{
			clientRUIID = WorldDrawAsset_CreateOnClient //returns a single topo+ruiid that will cycle any video
			(
				player, 
				baseBannerVideo.assetResourceRef,
				groupData.org,
				groupData.ang,
				groupData.width,
				groupData.height,
				groupData.groupId,
				baseBannerVideo.id,
				groupData.alpha,
				groupData.isVisible	
			)
			
			GetGroupData( player, groupData.groupId )[ eAssetType.BIK ] = clientRUIID
			
			WorldDrawAsset_SetVisible
			(
				player,
				clientRUIID,
				groupData.groupId,
				false,
				false, 
				false, 
				baseBannerVideo.id,
				groupData.fadeSpeed,
				baseBannerVideo.loopVideo
			)
			
			#if DEVELOPER && DEBUG_WORLD_ASSET
				printt( "[WorldAssets] Spawning base rui for banner:", baseBannerVideo.assetName )
			#endif
			
			#if DEVELOPER && DEBUG_WORLD_ASSET
				printt
				(
					"clientRUIID", clientRUIID, "\n",
					"player", player, "\n",
					"baseBannerVideo.assetResourceRef", baseBannerVideo.assetResourceRef, "\n",
					"groupData.org", groupData.org, "\n",
					"groupData.ang", groupData.ang, "\n",
					"groupData.width", groupData.width, "\n",
					"groupData.height", groupData.height, "\n",
					"baseBannerVideo.id", baseBannerVideo.id, "\n",
					"groupData.alpha", groupData.alpha, "\n",
					"groupData.isVisible", groupData.isVisible, "\n",
					"groupData.groupId", groupData.groupId, "\n",
					"groupData.intermediateTime", groupData.intermediateTime, "\n",
					"groupData.fadeSpeed", groupData.fadeSpeed, "\n",
					"groupData.startDelay", groupData.startDelay, "\n",
					"groupData.cycleTime", groupData.cycleTime, "\n",
					"groupData.isAudioQueue", groupData.isAudioQueue, "\n",
					"groupData.interupt", groupData.interupt, "\n",
					"groupData.bikCount", groupData.bikCount, "\n"
				)
			#endif
		}
	}
	
	if( groupData.isAudioQueue ) //group only needed for audio channel/validation of assets
	{
		if( ogBannersLen != banners.len() )
		{
			//tell server something?
			#if DEVELOPER && DEBUG_WORLD_ASSET
				Warning( "[WorldAssets] Some audio files were removed from the queue as the client does not have them." )
			#endif
		}
		
		thread __AudioQueue( player, baseBannerVideo, groupData )
		return
	}
	else 
	{
		OnThreadEnd
		(
			void function() : ( player, groupData )
			{
				__HideAllBanners( player, groupData )
			}
		)
	}
	
	if( bFirstRun )
		wait groupData.startDelay
	
	//todo: check for rui creation on client or shut down.
	
	////////
	iter = -1
	////////
	
	for( ; ; )
	{
		if( !groupData.isValid )
			break
			
		int bannerLen = banners.len()
		int lastBanner = bannerLen - 1 //determine current len, as client may have removed assets from queue.
		
		if( bannerLen == 0 )
			break
			
		// iter set //
		iter = iter == lastBanner ? 0 : ++iter
			
		if( !groupData.isVisible )
		{
			WaitSignal( file.dummyEnt, GetGroupSignal( "VisibilityChanged", groupData.groupId ) )
			continue
		}
		
		wait groupData.intermediateTime //between fadeins
		
		AssetData banner	
		int playerSyncAsset = player.p.syncGroupToAssetForPlayer[ groupData.groupId ]
	
		if( playerSyncAsset != -1 && !groupData.bLocked )
		{
			banner = __GetBannerDataForID( banners, playerSyncAsset )
			player.p.syncGroupToAssetForPlayer[ groupData.groupId ] = -1
			
			if( !banner.isValid )
			{
				__PrintAssetMissingForGroup( playerSyncAsset, groupData.groupId )			
				continue
			}
		}
		else if( groupData.syncToAsset == -1 && !groupData.bLocked )
		{
			if( groupData.useRandom )
				banner = banners.getrandom()
			else
				banner = banners[ iter ]
		}
		else
		{
			banner = __GetBannerDataForID( banners, groupData.syncToAsset )	
			groupData.syncToAsset = -1
			
			if( !banner.isValid )
			{
				__PrintAssetMissingForGroup( groupData.syncToAsset, groupData.groupId )
				continue
			}
		}

		if( !HasValidRuiData( player, groupData.groupId ) )
			break

		clientRUIID = GetRUIID( player, groupData.groupId, banner.assetType )
		//set the server managed ruiid instance to use based on type.
		#if DEVELOPER && DEBUG_WORLD_ASSET
			printf
			( 
				"[WorldAssets] setting next asset '%s' as type: '%s' in group: '%s', RUIID = '%d' for player: %s",
				banner.assetName,
				GetEnumString( "eAssetType", banner.assetType ),
				groupData.groupName,
				clientRUIID,
				string( player )
			)
		#endif 
		
		//change over to next asset.
		WorldDrawAsset_Modify
		(
			player, 
			clientRUIID,
			groupData.groupId,
			ZERO_VECTOR, 
			ZERO_VECTOR, 
			-1.0, 
			-1.0, 
			0, 
			banner.id 
		)
		
		//make it fadein/appear based on group settings.
		WorldDrawAsset_SetVisible
		(
			player,
			clientRUIID, 
			groupData.groupId,
			true,
			true, 
			true, 
			banner.id,
			groupData.fadeSpeed,
			banner.loopVideo
		)
		
		//if locked, wait for signals 
		if( groupData.bLocked )
			WaitForever()
		
		//behavior based on asset type.
		bool bKeepShow = true
		switch( banner.assetType )
		{
			case eAssetType.IMAGE:
				wait groupData.cycleTime
				break
				
			case eAssetType.BIK:
				bKeepShow = false
				
				string signal = GetGroupSignal( "VideoFinishedPlaying", groupData.groupId )
				player.WaitSignal( signal )
				
				break
				
			default:
				#if DEVELOPER && DEBUG_WORLD_ASSET 
					mAssert( 0, "[WorldAssets] Invalid assetType." )
				#endif 
		}
		
		//fadeout/disappear
		WorldDrawAsset_SetVisible
		(
			player,
			clientRUIID,
			groupData.groupId,			
			bKeepShow, //We want to let fade handle images.
			true,
			false,
			banner.id,
			groupData.fadeSpeed,
			banner.loopVideo
		)
	}
	
	#if DEVELOPER && DEBUG_WORLD_ASSET
		Warning( "[WorldAssets] AssetGroupData: \"%s\" was set to invalid and shutdown for player: \"%s\"", groupData.groupName, string( player ) )
	#endif 
}

#endif //SERVER