Release:   March 7/2026

========================================
For Players:
----------------------------------------

- Added complete dev menu subsystem for equipping legend abilities (WateryContinent02)
- Added hopup turbo charger back to havoc (WateryContinent02)

- 1v1 Gamemode: Lock1v1 ( chal ) kills/damage no longer count towards a win.
- Fixed zipline behavior to match retail
- Fixed sometimes unable to loot from deathbox in realistic TTV mode
- Can vote to skip maps with chat command:  /skip  in participating  servers
- Enabling the movement overlay for gamemodes is now possible via settings menu
- Updated default kd weights for 1v1 mode
- Fixed crash related to inworld assets
- Fixed flashing tp hint in rankup map playlist
- Added bot kills stats to realistic mode (separate from core leaderboard )
- Added ui persist for legend select from lobby, applies to servers when joining (if legend selection is available on server)
- Added legend select from pause menu in free roam
- 1v1: Potential fix for respawning backwards in 1v1, prevent crash during challenge when using tactical in some instances
- Removed default killshot sound in grapples n guns
- Fixed rankup mode issues with velocity and recalling drone

========================================
For Hosts:
----------------------------------------

- Fixed auto unmute for expired mutes
- Added player map vote skip, disabled by default, configured in playlist. see playlist var: map_skip_enabled
- Removed broken spawns in mp_rr_olympus_tt for 1v1 playlist
- temporarily disable highcal_mag_l3 via playlists
- fixed all audio queing in grapples n guns playlist
- Added DoorFight ai think logic to realistic mode
- Added playlist var settings to control the player threshold for npc training mode in realistic ttv playlist
- Added giving heirloom playlist var realistic_mode_give_heirloom
- Added spectate to menu based on playlist var:  realistic_enable_spectate
- Added enabling ground loot via with tier data in spawns via playlist var:  realistic_ground_loot
- Added enabling air drops via playlist var: realistic_air_drops
- Timeout feature improvement: persistence based timeouts that survive server map change and restart via tracker PlayerData isolated to server host (if running tracker)
- Patched rare case where inability to melee during a fight can occur
- Fixed incorrect message in realistic ttv for enable/disable of bots

========================================
Misc (Scripters):
----------------------------------------

- Improved ParseWeapon function with better feedback and include disabled refs
- Fixed rotation bug when min/max are specified in a rotation file entry
- Updated notepad++ read me and squirrel.xml file, as well as provided EnhanceAnyLexer config for full native lexxing.
- Moved realistic mode portal logic out of portal weapon and isolated into gamemode
- Updated  ea_verify display to use eMsgUI.NOTIFICATION
- Prevent crash from array bounds access for anims
- Added callback registry for door interaction callbacks so gamemodes can move their logic there
- Added finalon player respawned registry to definitively control behavior on spawn in non flowstate gamemodes
- Added several utility functions
- Prevent rare crash from invalid net var
- Added quick custom item flavor unlock registry in sh_grx.nut (CUSTOM_UNLOCKED_REFS)
- Added new localization tokens ( also registered for remote calling )
- Repaked problem assets using newest repak source. (WateryContinent02)


========================================
Engine:
----------------------------------------

- Platform: Fix potential code execution vulnerability in LaunchExternalWebBrowser script function. (O-Robotic)
- Pylon: Normalise all ip addresses used in the auth process ( fixes reconnect ). (O-Robotic)
- Server: Implement automatic JWT public key fetching ( Rexx )
- Other refactors and optimizations








Release:  Feb 12/2026:

========================================
For Players:
----------------------------------------
- Updated all weapons values to Retail Apex season 28
- Added warning dialog for when launching in developer mode
- Added warning dialog for when launching in client mode
- Added the ability to cancel wraith q with tactical button / left click + with hint after entering the void
- New gamemode envisioned by SlapsMcGaps, implemented by mkos: fs_grapples_n_guns
- Fixed not being able to heal some times in (all modes), tested in realistic ttv building playlist ( mode )
- potential fix for sometimes spawning backwards in 1v1 applied
- prevent ability to melee or do damage in rest to prevent any exploits
- Fixed start in rest setting applying when joining a 1v1 server mid-game.
- added ability to enable cl_showfps from in game settings. Saves to settings.
- added settings menu setting to persist cl_show pos info with localization tokens
- Fixed weapons not saving in realistic ttv building playlist ( mode )
- Removed Helmets from realistic TTV playlist (mode)
- 1v1: Added legend select to esc menu buttons
- 1v1: Added view champion card to esc menu buttons
- Weapons menu: Added a 'reset' button for quickly resetting saved guns.
- MOTD will automatically show *one time* for any server you join unless changed in settings under "ACCESSIBILITY"
- Taking damage ( other than ring damage ) now closes a deathbox if setting "Taking Damage Closes Deathbox or Menu" is set to on.
- Fixed not being able to recall drone in fs_rankupmapmovementpractice
- Added 3p client command to fs_rankupmapmovementpractice playlist
- disabled battle chatter for fs_grapples_n_guns
- Added several new text to all 12 languages
- fixed movement recorder playback duration display
- Fixed scoreboard not toggling in some games such as vamp 1v1s
- Fixed healing amount preview display 
- Fixed bug in realistic mode creating inconsistent ordnance state ( unusable arc stars / healing items )
- Updated rankup movement map 
- Made 1v1 spawns spaced out in waiting area automatically.
- Prevented crash when leaving a game mode by basing continue button on current auto load lobby state
- Prevent aim trainer menu in wrong context

========================================
For Hosts:
----------------------------------------
- Added playlist var 'enable_loose_playername_comparison', which allows partial playername searches when doing cc commands - also works for things like chal. Example for a player named BobTheBuilder:  /chal bob  -- will match for "BobTheBuilder"
- New proto feature to reserve at least one admin slot by enabling the feature in playlists via playlist var: reserve_admin_slot
- Realistic TTV building now has a proto feature to spawn ai on a random player if playlist var 'random_dummy_spawn' is eanbled, and can be configured with: random_dummy_spawn_mintime and random_dummy_spawn_maxtime
- fixed disable pings playlist var.  Setting playlist var 'player_can_ping' to 0 will disable all player pings for the specified playlist.
- fixed 'cc map' command not loading specified playlist if gamemode was omitted in params.
- For servers running tracker, loop messages now function again. Todo: Global feature
- fix motd showing on join for players automatically on first join
- cc command to enable/disable map rotation
- added ability to change stim duration from playlists file via playlist var float:  octane_stim_duration
- Added a crypto disable scan playlist var to prevent crypto drones from scanning players. Set with 'disable_crypto_scan'. This was set to 1 for playlist: fs_rankupmapmovementpractice
- Set playlist var teammate_huds_enabled to 0 for fs_rankupmapmovementpractice
- Add abiltiy to disable giving items by default from playlist: give_basic_survival_items: Note this can interfere with loadout related abilities in survival playlists
- Validate admin provided timeout time, if it is less than or equal to 0, uses default timeout time set in playlist with playlist var: 'timeout_default_time'
- All cc admin commands that allow a reason to be specified now require you to add the reason with -r or -reason followed by the reason in quotes. Example: cc kick bobthebuilder -r "Bad boy"
- Timestring arguments for time units now additionally accept 's', 'd', 'm' and 'y' for seconds, days, months, and years respectively.
- Fixed an issue where game logic would not work correctly for admins causing IBMM to malfunction.
- Added the ability to register weapons from scripts ( complementing rpak/playlist registration )
- Added the ability to register worlddraw assets from scripts ( complementing playlist/rpak registration )
- CC admin commands that a reason is provided for can also be annoucned to the server by adding -say. Example:    cc kick bobthebuilder -r "Can't build" -say
- weapons charms are now disabled for a mode unless playlist var: flowstate_givecharms_weapons is set to 1.
- Removed giving helmets consistently unless playlist var: enable_helmets is set to 1
- added an additional spawn set for aqueduct
- expanded the SpawnSystem options to be able to cycle a list of spawn sets for each map as confgiured in playlist and enabled playlist var: spawnpaks_rotate_all 1
- added playlist vars to movement recorder for:  enable_helmets(default 0), dummy_shield_level(default 2 = blue ), dummy_health( default = 100 )
- Added 1v1 exploit protection for melee from rest -- If any issues arrive for 1v1 gamemode with not being able to melee or damage during a fight, you can set enable_state_flags to 0 in playlists file.
- Added the ability to disable message sounds via playlist with playlist var: disable_message_sounds
- Added training mode feature for realistic ttv mode
- Launched Tracker season 6
- Added cc command 'cc show_motd [playername/uid]' - Shows motd to a specified player even if already shown, but only if the player has not disabled 'Enable MOTD'


The following commands can utilize -say
[
    cc kick
    cc ban
    cc timeout
    cc mute
]

- Removed commands: cc kicksay, cc bansay

========================================
Misc (Scripters):
----------------------------------------
- restore playlist override to blank after usage so that subsequent usage of server browser loading does not get locked to previous override.
- badge stat crash fix
- fix a bug not allowing you to do 'cc map' to reload current map playlist gamemode in some situations
- antiafk system had other logic relying on it's functionality, this was split to retain required logic, and optionally disable the afk thread if setting 'enable_afk_thread' or 'flowstate_afk_kick_enable' is disabled.
- added FS callback registry for onspawned to remove the need for threading and waiting to control behavior
- fixed a crash exploit leftover from old respawn code + several others
- reworked bannerassets to WorldAssets and revitalized with refactors.
- Made WorldAsset audio queues multi group compatible and remove s_audioQueueRegistered temp flag
- fixed a bug in replay hud not deactivating when killer becomes invalid
- created client sided AddCallback_OnPlayerConnected registry
- rework client stats to uid indexed and fixed preload bugs
- match timer bug and other issues fixed due to replay logic replaying
- fixed error message display when incorrectly using 'cc map'
- improve WorldAssets to allow playing a single asset for a specific asset group for a specific player
- disabled usage of use_r2_deathcam in combo with replay system due to crashes
- fixed an issue in rpaks cuasing mismatched server/client issues (fs_spawns contained audio datatables that don't belong there)
- removed specifying map for global rpaks in scripts/levels/settings
- fixed an issue in remote func float precision
- ability to register tracking as non combat mode and ship only live data for custom stats
- other minor bug fixes and feature/code improvements / refactors
- added new eMsgUI type:  eMsgUI.NOTIFICATION for usage with LocalMsg() with playlist var controlled by server for should close all menus or not as 'eMsgUI_notification_closes_menus' set to true by default, and not added to playlists file.
- Fixed scoreboard toggle behavior causing an issue leaving scoreboard in an inconsistent state, which would cause other menus to not work properly such as ordnance, health items, quips, etc


=============================================== Weapons Updates: ===============================================
mp_weapon_semipistol.txt
----------------------------------------
  damage_near_value: 24 → 23
  damage_far_value: 24 → 23
  damage_very_far_value: 24 → 23
  damage_near_value_titanarmor: 24 → 23
  damage_far_value_titanarmor: 24 → 23
  damage_very_far_value_titanarmor: 24 → 23
 
========================================
mp_weapon_g2.txt
----------------------------------------
  fx_muzzle_flash_attach_scoped: muzzle_flash → muzzle_flash_scoped
  
========================================
mp_weapon_shotgun.txt
----------------------------------------
  blast_pattern_default_scale: 1.500000 → 1.400000
  fire_rate: 2.700000 → 2.800000
  
========================================
mp_weapon_bow.txt
----------------------------------------
  holster_angles_offset: 90 90 90 → -90 45 -30
  charge_time: 0.350000 → 0.450000
  
========================================
mp_ability_hunt_mode.txt
----------------------------------------
  toss_time: 1.600000 → 1.200000
  toss_overhead_time: 1.600000 → 1.200000
  ammo_clip_size: 240 → 150
  ammo_min_to_fire: 240 → 150
  ammo_per_shot: 240 → 150
  fire_duration: 30.000000 → 25.000000
  
========================================
mp_weapon_doubletake.txt
----------------------------------------
  fire_rate: 1.450000 → 1.300000
  
========================================
mp_weapon_3030.txt
----------------------------------------
  charge_time: 0.350000 → 0.400000
  charge_additional_damage_multiplier: 0.500000 → 0.400000
  damage_near_value: 43 → 41
  damage_far_value: 43 → 41
  damage_very_far_value: 43 → 41
  damage_near_value_titanarmor: 43 → 41
  damage_far_value_titanarmor: 43 → 41
  damage_very_far_value_titanarmor: 43 → 41
  viewkick_pattern: 3030 → 3030_repeater
  
========================================
mp_weapon_mastiff.txt
----------------------------------------

  blast_pattern: mastiff_3 → mastiff_4
  projectiles_per_shot: 6 → 5
  damage_near_value: 16 → 19
  damage_far_value: 16 → 19
  damage_near_value_titanarmor: 16 → 19
  damage_far_value_titanarmor: 16 → 19
 