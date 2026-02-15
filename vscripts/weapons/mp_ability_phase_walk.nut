global function MpAbilityPhaseWalk_Init

global function OnWeaponActivate_ability_phase_walk
global function OnWeaponAttemptOffhandSwitch_ability_phase_walk
global function OnWeaponChargeBegin_ability_phase_walk
global function OnWeaponChargeEnd_ability_phase_walk

const string SOUND_ACTIVATE_1P = "pilot_phaseshift_firstarmraise_1p" // Play (to 1p only) as soon as the "arm raise" animation for placing the first gate starts (basically as soon as the ability key is pressed and the ability successfully starts).
const string SOUND_ACTIVATE_3P = "pilot_phaseshift_firstarmraise_3p" // Play (to everyone except 1p) as soon as the 3p Wraith begins activating the ability to place the first gate.

const float PHASE_WALK_PRE_TELL_TIME = 1.5
const asset PHASE_WALK_APPEAR_PRE_FX = $"P_phase_dash_pre_end_mdl"
const float EXIT_PHASE_ATTACK_DELAY  = 0.5

struct
{
	#if SERVER
		table< entity, bool > hasLockedWeaponsAndMelee
	#elseif CLIENT 
		var phaseHintRui
		bool bHasRegisteredConCommand
	#endif 
	
} file

void function MpAbilityPhaseWalk_Init()
{
	PrecacheParticleSystem( PHASE_WALK_APPEAR_PRE_FX )
	
	#if SERVER
		AddClientCommandCallbackVoid( "attemptPhaseCancel", ClientCommand_AttemptPhaseCancel )
	#endif
	
	RegisterSignal( "RemoveCancelPhaseHintRui" )
}

void function OnWeaponActivate_ability_phase_walk( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	float deploy_time = weapon.GetWeaponSettingFloat( eWeaponVar.deploy_time )

	#if CLIENT
		if( !file.bHasRegisteredConCommand )
		{
			RegisterConCommandTriggeredCallback( "+attack", AttemptPhaseCancel )
			file.bHasRegisteredConCommand = true
		}
	#endif 
	
	#if SERVER
		EmitSoundOnEntityExceptToPlayer( player, player, "pilot_phaseshift_armraise_3p" )

	if ( player.GetActiveWeapon( eActiveInventorySlot.mainHand ) != player.GetOffhandWeapon( OFFHAND_INVENTORY ) )
		PlayBattleChatterLineToSpeakerAndTeam( player, "bc_tactical" )
	#endif
	
	if ( !weapon.HasMod( "ult_active" ) )
	{
		#if SERVER
			EmitSoundOnEntityExceptToPlayer( player, player, SOUND_ACTIVATE_3P )
		#endif

		#if CLIENT
			if ( !InPrediction() )
				return

			EmitSoundOnEntity( player, SOUND_ACTIVATE_1P )
		#endif

		float amount = GetCurrentPlaylistVarFloat( "wraith_phase_walk_slow_amount", 0.2 )
		StatusEffect_AddTimed( player, eStatusEffect.move_slow, amount, deploy_time, deploy_time )	
	}
}

#if SERVER
	void function ClientCommand_AttemptPhaseCancel( entity player, array<string> args )
	{
		if( !IsValid( player ) )
			return 
			
		if( !player.IsPhaseShifted() )
			return 
			
		entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
		if( !IsValid( weapon ) )
			return
		
		if ( !weapon.IsWeaponCharging() )
			return
		
		/*
			(mk): 	uses stack based system. Gamemodes that call HolsterAndDisableWeapons without a 
					matching DeployAndEnableWeapons call will render weapons unusable. 
					The stack must reach 0 before DeployAndEnableWeapons will enable the weapons.
		*/
		HolsterAndDisableWeapons( player ) 
		FullyCancelPhaseShift( player, weapon )		
		
		thread
		(
			void function() : ( player )
			{
				if( !IsValid( player ) )
					return 
				
				player.EndSignal( "OnDestroy" )		
				wait EXIT_PHASE_ATTACK_DELAY
				
				DeployAndEnableWeapons( player )			
			}
		)()
	}
#elseif CLIENT 
	void function AttemptPhaseCancel( entity player )
	{
		if ( player != GetLocalViewPlayer() )
			return
			
		entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
		if ( !IsValid( weapon ) )
			return

		if ( !weapon.IsWeaponCharging() )
			return
			
		if( player.IsPhaseShifted() )
			player.ClientCommand( "attemptPhaseCancel" )
	}
#endif 

void function FullyCancelPhaseShift( entity player, entity weapon )
{
	CancelPhaseShift( player )
	OnWeaponChargeEnd_ability_phase_walk( weapon )
	
	#if CLIENT
		if( !InPrediction() )
			return
	#endif
	
	if( weapon.Anim_HasActivity( "ACT_VM_PRIMARYATTACK" ) )
		weapon.StartCustomActivity( "ACT_VM_PRIMARYATTACK", 0 )
}

bool function OnWeaponAttemptOffhandSwitch_ability_phase_walk( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	if ( IsValid( player ) && player.IsPhaseShifted() )
	{
		FullyCancelPhaseShift( player, weapon )
		return false
	}

	return true
}

bool function OnWeaponChargeBegin_ability_phase_walk( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )

	bool doStatus = true
	#if CLIENT
		if ( !InPrediction() )
			doStatus = false
	#endif

	if ( doStatus )
	{
		int speedHandle = StatusEffect_AddTimed( player, eStatusEffect.speed_boost, 0.3, chargeTime, chargeTime * 0.3 )

		#if SERVER
		weapon.w.statusEffects.append( speedHandle )
		#endif
	}
	
	#if SERVER
		thread PhaseWalk_Thread( player, chargeTime )
		PlayerUsedOffhand( player, weapon )
	#endif
	
	PhaseShift( player, 0, chargeTime, eShiftStyle.Balance )
	
	#if CLIENT 
		if( player == GetLocalViewPlayer() )
			thread DisplayCancelHintThread( player, weapon )
	#endif
	
	return true
}

#if SERVER
void function PhaseWalk_Thread( entity player, float chargeTime )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "BleedOut_OnStartDying" )
	player.EndSignal( "ForceStopPhaseShift" )

	ForceAutoSprintOn( player )

	LockWeaponsAndMelee( player )
	file.hasLockedWeaponsAndMelee[player] <- true

	//StatsHook_Tactical_TimeSpentInPhase( player, chargeTime )
	TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_ABILITIES_PHASE_DASH_START, player, player.GetOrigin(), player.GetTeam(), player )

	entity dashFX

	OnThreadEnd(
	function() : ( player, dashFX )
		{
			if ( IsValid( player ) )
			{
				TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_ABILITIES_PHASE_DASH_STOP, player, player.GetOrigin(), player.GetTeam(), player )
				ForceAutoSprintOff( player )    
			}
			if ( player in file.hasLockedWeaponsAndMelee && file.hasLockedWeaponsAndMelee[player]  )
			{
				if ( IsValid( player ) )
				{
					UnlockWeaponsAndMelee( player )
				}
				
				file.hasLockedWeaponsAndMelee[player] <- false
			}
			if ( IsValid( dashFX ) )
			{
				EffectStop( dashFX )
			}
		}
	)

	float tellWait = chargeTime - PHASE_WALK_PRE_TELL_TIME
	wait tellWait

	asset fxAsset = PHASE_WALK_APPEAR_PRE_FX
	int fxid     = GetParticleSystemIndex( fxAsset )
	int attachId = player.LookupAttachment( "ORIGIN" )

	dashFX = StartParticleEffectOnEntity_ReturnEntity( player, fxid, FX_PATTACH_POINT_FOLLOW, attachId )
	dashFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)	// everyone but owner
	dashFX.SetOwner( player )


	wait PHASE_WALK_PRE_TELL_TIME
}
#endif

void function OnWeaponChargeEnd_ability_phase_walk( entity weapon )
{	
	entity player = weapon.GetWeaponOwner()
		
	#if CLIENT 
		Signal( player, "RemoveCancelPhaseHintRui" )
	#endif
	
	#if SERVER
		foreach ( effect in weapon.w.statusEffects )
		{
			StatusEffect_Stop( player, effect )
		}
		if ( player in file.hasLockedWeaponsAndMelee && file.hasLockedWeaponsAndMelee[player]  )
		{
			if ( IsValid(player) )
				UnlockWeaponsAndMelee( player )
			file.hasLockedWeaponsAndMelee[player] <- false
		}
		int ammoAfterFiring = weapon.GetWeaponPrimaryClipCount() - weapon.GetAmmoPerShot()
		weapon.SetWeaponPrimaryClipCount( maxint( ammoAfterFiring, 0 ) )
	#endif
}

#if CLIENT 
	void function DisplayCancelHintThread( entity player, entity weapon )
	{
		string hint = Localize( "#CANCEL_PHASE_HINT" )
		
		OnThreadEnd
		(
			void function()
			{
				if( file.phaseHintRui != null )
				{
					RuiDestroyIfAlive( file.phaseHintRui )
					file.phaseHintRui = null
				}
				
				if( file.bHasRegisteredConCommand )
				{
					DeregisterConCommandTriggeredCallback( "+attack", AttemptPhaseCancel )
					file.bHasRegisteredConCommand = false
				}
			}
		)
		
		player.EndSignal( "OnDestroy", "RemoveCancelPhaseHintRui", "OnDeath" )
		weapon.EndSignal( "OnDestroy" )

		if( file.phaseHintRui != null )
		{
			RuiDestroyIfAlive( file.phaseHintRui )
			file.phaseHintRui = null
		}

		file.phaseHintRui = CreateFullscreenRui( $"ui/wraith_comms_hint.rpak" )
		float endTime = Time() + weapon.GetWeaponSettingFloat( eWeaponVar.charge_time ) + PHASE_WALK_PRE_TELL_TIME

		RuiSetGameTime( file.phaseHintRui, "startTime", Time() )
		RuiSetGameTime( file.phaseHintRui, "endTime", endTime )
		RuiSetBool( file.phaseHintRui, "commsMenuOpen", false )
		RuiSetString( file.phaseHintRui, "msg", hint )

		WaitForever()
	}
#endif 