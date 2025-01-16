blockstep = {}
blockstep.MESSAGE_PRINTINFO = 0
blockstep.MESSAGE_RESETOVERRIDES = 1
blockstep.MESSAGE_ZS_STEP_HEIGHT = 2
blockstep.NETWORK_BITS = 2
blockstep.VERSION = "1.0.0.rc2"

print( "[blockstep] Version " .. blockstep.VERSION )
print( "[blockstep] Initializing..." )

--function dprint( value, valueName )
--	print( valueName .. " is: " .. tostring( value ) )
--end

local function DebugCommand( ply, cmd, args, argStr )
	if SERVER then
		print( "Printing serverside blockstep state:" )
	else
		print( "This is the clientside blockstep state. To show the serverside state, use this command: \"rcon blockstep_debug\"" )
	end
	PrintTable( blockstep )
end

concommand.Add( "blockstep_debug", DebugCommand, nil, "Print the internal state of the blockstep library.", FCVAR_NONE )

if CLIENT then
	-- Client
	blockstep.FormatKey = function( translateKey, ... )
		local args = { ... }
		if args == nil then return language.GetPhrase( translateKey ) end
		return string.format( language.GetPhrase( translateKey ), unpack( args ) )
	end

	-- There can be only one net message handler per network string
	net.Receive( "blockstep", function ( length, ply )
		--print("[blockstep] Received a net message")
		local messageType = net.ReadUInt( blockstep.NETWORK_BITS )
		if messageType == blockstep.MESSAGE_PRINTINFO then 
			
			local translateKey = net.ReadString()
			local subIsPresent = net.ReadBool()
			local subIsString = net.ReadBool()

			local subNumOrString
			if subIsPresent then
				if subIsString then
					subNumOrString = net.ReadString()
				else
					subNumOrString = net.ReadFloat()
				end
			end

			LocalPlayer():ChatPrint( blockstep.FormatKey( translateKey, subNumOrString ) )
		elseif messageType == blockstep.MESSAGE_RESETOVERRIDES then
			notification.AddLegacy( "#blockstep.command.reset_overrides", NOTIFY_GENERIC, 2 )
			surface.PlaySound( "buttons/button15.wav" )
		elseif messageType == blockstep.MESSAGE_ZS_STEP_HEIGHT then
			--print("[blockstep] Received ZS network message")
			local jumpPower = net.ReadUInt(32)
			local stepHeight = net.ReadUInt(32)
			DEFAULT_JUMP_POWER = jumpPower
			DEFAULT_STEP_SIZE = stepHeight
		end
	end )
end

local function ResetOverridesCommand( ply, cmd, args, argStr )
	local playerIsValid = IsValid( ply )
	if playerIsValid then
		if not ply:IsAdmin() then
			print( "This command is for admins only!" )
		return end
	end
	if SERVER then
		blockstep.OverrideBlockSizeConVar:Revert()
		blockstep.OverrideStepHeightConVar:Revert()
		blockstep.OverrideJumpHeightConVar:Revert()
		blockstep.OverrideShouldAccountForGravityConVar:Revert()
		print( "Reset all override console variables!" )
		if playerIsValid then
			net.Start( "blockstep" )
				net.WriteUInt( blockstep.MESSAGE_RESETOVERRIDES, blockstep.NETWORK_BITS )
			net.Send( ply )
		end
	else
		print( "This is the clientside blockstep state. To reset the override console variables, use this command: \"rcon blockstep_reset_overrides\"" )
	end
end

concommand.Add( "blockstep_reset_overrides", ResetOverridesCommand, nil, "Reset all blockstep override console variables.", FCVAR_NONE )

--local function ConfigureCommand( ply, cmd, args, argStr )
--	if not IsValid( ply ) then return end
--	if not ply:IsAdmin() then return end
--	print( ply )
--	ply:Give( "gmod_tool" )
--	ply:SelectWeapon( "gmod_tool" )
--	ply:ConCommand( "gmod_toolmode blockstep" )
--end
--
--concommand.Add( "blockstep_configure", ConfigureCommand, nil, "If you're an admin, this command gives the BlockStep Configurator tool for easy block size measuring.", FCVAR_NONE )

if SERVER then
	util.AddNetworkString( "blockstep" )
	
	local currentMap = game.GetMap()
	blockstep.GravityConVar = GetConVar( "sv_gravity" )
	
	hook.Add( "SetPlayerStepHeight", "blockstep_setplayerstepheight", function( player, providedStepHeight )
		player:SetStepSize( providedStepHeight )
	end )
	
	hook.Add( "SetPlayerJumpPower", "blockstep_setplayerjumppower", function( player, providedJumpPower )
		player:SetJumpPower( providedJumpPower )
	end )
	
	
	
	local function CalculateJumpPower()
		-- Experimented with how much jump power is needed to clear certain Hammer unit heights
		-- and graphed them to create the jumpPower equation
		local bstep = blockstep
		
		local blocksToJumpUp = bstep.GetJumpHeightUserValue()
		if blocksToJumpUp < 0 then return bstep.DefaultJumpPower
		elseif blocksToJumpUp == 0 then return 0 end
		
		local blockSize = bstep.GetBlockSizeUserValue()
		if blockSize < 0 then return bstep.DefaultJumpPower
		elseif blockSize == 0 then return 0 end
		
		local gravityAmount = math.abs( bstep.GravityConVar:GetFloat() )
		if gravityAmount <= 0 then return 0 end
		
		local hammerDistance = blocksToJumpUp * blockSize
		
		-- These 2 gravity variables use magic numbers, 
		-- magicGravity makes the equation very close to the proper observed jumpPowers,
		-- and furtherMagicGravity tweaks the equation slightly to be even closer
		local magicGravity = 0.5 / gravityAmount
		local furtherMagicGravity = 0.007433 / magicGravity
		
		local furtherMagicGravityDiv = ( furtherMagicGravity / 2 )
		
		local jumpPower = math.sqrt( ( hammerDistance / magicGravity ) + furtherMagicGravityDiv ^ 2 ) + furtherMagicGravityDiv
		return jumpPower
	end
	
	local function CalculateStepHeight()
		local bstep = blockstep
		
		local blocksToStepUp = bstep.GetStepHeightUserValue()
		if blocksToStepUp < 0 then return bstep.DefaultStepHeight
		elseif blocksToStepUp == 0 then return 0 end
		
		local blockSize = bstep.GetBlockSizeUserValue()
		if blockSize < 0 then return bstep.DefaultStepHeight
		elseif blockSize == 0 then return 0 end
		
		local stepHeight = blockSize * blocksToStepUp
		return stepHeight
	end
	
	
	
	local function ShouldCallbackRun( newVal, conversionFunction, conVarName, overrideConVarName, mapConVar, mapConVarGetFunctionName, overrideConVar )
		local callbackShouldRun = true
		newVal = conversionFunction( newVal )
		-- Fix for tonumber returning nil, this is how GetFloat() functions
		if newVal == nil then newVal = 0 end
		-- Ignore callback when map's value is being overriden, and use newValue from map's convar when disabling override
		if conVarName == overrideConVarName then
			-- Override is being disabled
			if conversionFunction( newVal ) == -2 then
				newVal = mapConVar[ mapConVarGetFunctionName ]( mapConVar )
			end
		else
			if overrideConVar:GetFloat() != -2 then callbackShouldRun = false end
		end
		return callbackShouldRun, newVal
	end
	
	local function BlockSizeCallback( conVarName, oldVal, newVal )
		local callbackShouldRun, newValReturn = ShouldCallbackRun( newVal, tonumber, conVarName, "blockstep_override_block_size", blockstep.BlockSizeConVar, "GetFloat", blockstep.OverrideBlockSizeConVar )
		if not callbackShouldRun then return end
		newVal = newValReturn

		-- Check if numerical value actually changed or if it's an unnecessary string change
		oldVal = tonumber( oldVal ) or 0
		if oldVal == newVal then return end
		
		blockstep.StepHeight = CalculateStepHeight()
		blockstep.JumpPower = CalculateJumpPower()
		blockstep.UpdatePlayerAttributes()
	end
	
	local function StepHeightCallback( conVarName, oldVal, newVal )
		local callbackShouldRun, newValReturn = ShouldCallbackRun( newVal, tonumber, conVarName, "blockstep_override_step_height", blockstep.StepHeightConVar, "GetFloat", blockstep.OverrideStepHeightConVar )
		if not callbackShouldRun then return end
		newVal = newValReturn
		
		-- Check if numerical value actually changed or if it's an unnecessary string change
		oldVal = tonumber( oldVal ) or 0
		if oldVal == newVal then return end
		
		blockstep.StepHeight = CalculateStepHeight()
		blockstep.UpdatePlayerAttributes()
	end
	
	local function JumpPowerCallback( conVarName, oldVal, newVal )
		local callbackShouldRun, newValReturn = ShouldCallbackRun( newVal, tonumber, conVarName, "blockstep_override_jump_height", blockstep.JumpHeightConVar, "GetFloat", blockstep.OverrideJumpHeightConVar )
		if not callbackShouldRun then return end
		newVal = newValReturn
		
		-- Check if numerical value actually changed or if it's an unnecessary string change
		oldVal = tonumber( oldVal ) or 0
		if oldVal == newVal then return end
		
		blockstep.JumpPower = CalculateJumpPower()
		blockstep.UpdatePlayerAttributes()
	end
	
	local function ShouldAccountForGravityConVarCallback( conVarName, oldVal, newVal )
		local callbackShouldRun, newValReturn = ShouldCallbackRun( newVal, tobool, conVarName, "blockstep_override_should_account_for_gravity", blockstep.ShouldAccountForGravityConVar, "GetBool", blockstep.OverrideShouldAccountForGravityConVar )
		if not callbackShouldRun then return end
		newVal = newValReturn
		
		oldVal = tobool( oldVal )
		-- Check if boolean value actually changed or if it's an unnecessary string change
		if oldVal == newVal then return end
		
		-- Recalculate jumpPower if admin decided that gravity changes should be accounted for
		if newVal then
			blockstep.JumpPower = CalculateJumpPower()
		end
		blockstep.UpdatePlayerAttributes()
	end
	
	blockstep.SetDefaultBlockSize = function( desiredDefault )
		local conVarName = string.format( "blockstep_%s_block_size", currentMap )
		if ConVarExists( conVarName ) then return end
		desiredDefault = tonumber( desiredDefault ) or 0
		if desiredDefault == nil then desiredDefault = -1 end
		blockstep.BlockSizeConVar = CreateConVar( conVarName, desiredDefault, FCVAR_ARCHIVE, "Size of this map's blocks in Hammer units. Set to a negative value to effectively disable the addon.", -1, nil )
		cvars.AddChangeCallback( conVarName, BlockSizeCallback )
		print( "[blockstep] Created block size convar!" )
	end
	
	blockstep.SetDefaultStepHeight = function( desiredDefault )
		local conVarName = string.format( "blockstep_%s_step_height", currentMap )
		if ConVarExists( conVarName ) then return end
		desiredDefault = tonumber( desiredDefault ) or 0
		if desiredDefault == nil then desiredDefault = -1 end
		blockstep.StepHeightConVar = CreateConVar( conVarName, desiredDefault, FCVAR_ARCHIVE, "Maximum block height players can step up onto. Set to a negative value to disable this aspect of the addon.", -1, nil )
		cvars.AddChangeCallback( conVarName, StepHeightCallback )
		print( "[blockstep] Created step height convar!" )
	end
	
	blockstep.SetDefaultJumpHeight = function( desiredDefault )
		local conVarName = string.format( "blockstep_%s_jump_height", currentMap )
		if ConVarExists( conVarName ) then return end
		desiredDefault = tonumber( desiredDefault ) or 0
		if desiredDefault == nil then desiredDefault = -1 end
		blockstep.JumpHeightConVar = CreateConVar( conVarName, desiredDefault, FCVAR_ARCHIVE, "How high players can jump in blocks. Set to a negative value to disable this aspect of the addon.", -1, nil )
		cvars.AddChangeCallback( conVarName, JumpPowerCallback )
		print( "[blockstep] Created jump height convar!" )
	end
	
	blockstep.SetDefaultShouldAccountForGravity = function( desiredDefault )
		local conVarName = string.format( "blockstep_%s_should_account_for_gravity", currentMap )
		if ConVarExists( conVarName ) then return end
		desiredDefault = tobool( desiredDefault )
		if desiredDefault then desiredDefault = 1 else desiredDefault = 0 end
		blockstep.ShouldAccountForGravityConVar = CreateConVar( conVarName, desiredDefault, FCVAR_ARCHIVE, "When set to 1, jump height will recalculate if sv_gravity is changed during play. If players could jump 1 block on Earth, they'll continue jumping 1 block on the Moon.", 0, 1 )
		cvars.AddChangeCallback( conVarName, ShouldAccountForGravityConVarCallback )
		print( "[blockstep] Created gravity convar!" )
	end
	
	blockstep.GetBlockSizeUserValue = function()
		local overrideValue = blockstep.OverrideBlockSizeConVar:GetFloat()
		if overrideValue != -2 then return overrideValue end
		return blockstep.BlockSizeConVar:GetFloat()
	end
	
	blockstep.GetStepHeightUserValue = function()
		local overrideValue = blockstep.OverrideStepHeightConVar:GetFloat()
		if overrideValue != -2 then return overrideValue end
		return blockstep.StepHeightConVar:GetFloat()
	end
	
	blockstep.GetJumpHeightUserValue = function()
		local overrideValue = blockstep.OverrideJumpHeightConVar:GetFloat()
		if overrideValue != -2 then return overrideValue end
		return blockstep.JumpHeightConVar:GetFloat()
	end
	
	blockstep.GetShouldAccountForGravityUserValue = function()
		local overrideValue = blockstep.OverrideShouldAccountForGravityConVar:GetFloat()
		if overrideValue != -2 then return tobool( overrideValue ) end
		return blockstep.ShouldAccountForGravityConVar:GetBool()
	end
	
	
	-- Benchmarked this, having this outside the function instead of nested has a bit better performance
	local function InternalUpdatePlayerAttributes( player, bstep )
		-- These 2 functions automatically network their new values to the called player
		hook.Run( "SetPlayerStepHeight", player, bstep.StepHeight )
		hook.Run( "SetPlayerJumpPower", player, bstep.JumpPower )
	end
		
	-- Only calls when player attributes need to be updated
	blockstep.UpdatePlayerAttributes = function( providedPlayer )
		local bstep = blockstep
		
		if IsValid( providedPlayer ) then
			InternalUpdatePlayerAttributes( providedPlayer, bstep )
		else
			for _, loopPlayer in player.Iterator() do
				InternalUpdatePlayerAttributes( loopPlayer, bstep )
			end
		end
	end

	-- API opens up for custom Lua scripting here
	-----------------------
	local mapThirdpartyPath = string.format( "blockstep_thirdparty/%s.lua", currentMap )
	local mapMapmakerPath = string.format( "blockstep_maps/%s.lua", currentMap )
	local mapDefaultsPath = string.format( "blockstep_defaults/%s.lua", currentMap )
	
	if file.Exists( mapThirdpartyPath, "LUA" ) then
		print( "[blockstep] Loading defaults from third parties..." )
		include( mapThirdpartyPath )
	end

	if file.Exists( mapMapmakerPath, "LUA" ) then
		print( "[blockstep] Loading defaults from the map maker..." )
		include( mapMapmakerPath )
	end

	if file.Exists( mapDefaultsPath, "LUA" ) then
		print( "[blockstep] Loading defaults from blockstep..." )
		include( mapDefaultsPath )
	end
	-----------------------
	
	-- Verify addon is properly intialized after API
	-----------------------

	print( "[blockstep] Creating convars if they were missing..." )
	if not ConVarExists( string.format( "blockstep_%s_block_size", currentMap ) ) then
		blockstep.SetDefaultBlockSize( -1 )
	end
	
	if not ConVarExists( string.format( "blockstep_%s_step_height", currentMap ) ) then
		blockstep.SetDefaultStepHeight( -1 )
	end
	
	if not ConVarExists( string.format( "blockstep_%s_jump_height", currentMap ) ) then
		blockstep.SetDefaultJumpHeight( -1 )
	end
	
	if not ConVarExists( string.format( "blockstep_%s_should_account_for_gravity", currentMap ) ) then
		blockstep.SetDefaultShouldAccountForGravity( false )
	end
	print( "[blockstep] Finished initializing convars!" )
	-----------------------
	
	-- Finish initializing addon
	-----------------------
	
	blockstep.OverrideBlockSizeConVar = CreateConVar( "blockstep_override_block_size", -2, FCVAR_ARCHIVE, "Set to -2 to disable this override. Overrides map's value for block_size.", -2, nil )
	cvars.AddChangeCallback( "blockstep_override_block_size", BlockSizeCallback )
	
	blockstep.OverrideStepHeightConVar = CreateConVar( "blockstep_override_step_height", -2, FCVAR_ARCHIVE, "Set to -2 to disable this override. Overrides map's value for step_height.", -2, nil )
	cvars.AddChangeCallback( "blockstep_override_step_height", StepHeightCallback )
	
	blockstep.OverrideJumpHeightConVar = CreateConVar( "blockstep_override_jump_height", -2, FCVAR_ARCHIVE, "Set to -2 to disable this override. Overrides map's value for jump_height.", -2, nil )
	cvars.AddChangeCallback( "blockstep_override_jump_height", JumpPowerCallback )
	
	blockstep.OverrideShouldAccountForGravityConVar = CreateConVar( "blockstep_override_should_account_for_gravity", -2, FCVAR_ARCHIVE, "Set to -2 to disable this override. Overrides map's value for should_account_for_gravity.", -2, 1 )
	cvars.AddChangeCallback( "blockstep_override_should_account_for_gravity", ShouldAccountForGravityConVarCallback )
	
	-- These don't have setter functions because they're intended for gamemode authors to adjust
	-- Or just override the 2 provided hooks and do your own thing
	blockstep.DefaultJumpPower = 200
	blockstep.DefaultStepHeight = 18 -- Return from player:GetStepSize()
	
	-- Calc values before first player spawns
	blockstep.JumpPower = CalculateJumpPower()
	blockstep.StepHeight = CalculateStepHeight()
	
	cvars.AddChangeCallback( "sv_gravity", function ( convarName, oldGravity, newGravity )
		local bstep = blockstep
		local addonInitialized = bstep.GetBlockSizeUserValue() >= 0
		if not addonInitialized then return end
		if not bstep.GetShouldAccountForGravityUserValue() then return end
		-- Check if numerical gravity value actually changed or if it's an unnecessary string change
		oldGravity = tonumber( oldGravity ) or 0
		newGravity = tonumber( newGravity ) or 0
		if oldGravity == newGravity then return end
		bstep.JumpPower = CalculateJumpPower()
		bstep.UpdatePlayerAttributes()
	end )

	-- GMod's default gamemode calls this after player_manager resets jumppower to 200
	-- https://github.com/Facepunch/garrysmod/blob/fff01df0cfaf6152336f5026d0bedf5225052bbe/garrysmod/gamemodes/base/gamemode/player.lua#L250
	-- This hook basically functions as a PostPlayerSpawn
	hook.Add( "PlayerSetModel", "blockstep_playersetmodel", function ( player )
		--print("[blockstep] PlayerSetModel")
		local bstep = blockstep
		-- Avoid running an update here when addon is disabled
		local addonInitialized = bstep.GetBlockSizeUserValue() >= 0
		if not addonInitialized then return end
		bstep.UpdatePlayerAttributes( player )
	end )
	
	-- Murder support, fix jump power being constantly reset by the gamemode
	local gamemode = engine.ActiveGamemode()
	if gamemode == "murder" then
		--print("[blockstep] Murder found!")
		hook.Add( "PostGamemodeLoaded", "blockstep_postgamemodeloaded", function ()
			--print("[blockstep] PostGamemodeLoaded")
			
			local plyMeta = FindMetaTable("Player")
			-- Copied and edited version of plyMeta:CalculateSpeed() from murder/gamemodes/murder/gamemode/sv_player.lua line 137
			-- Replaced the hardcoded jumppower variable with an address to blockstep.JumpPower
			function plyMeta:CalculateSpeed()
				--print("[blockstep] Running replaced CalculateSpeed hook!")
				local bstep = blockstep
				
				-- set the defaults
				local walk,run,canrun = 250,310,false
				local jumppower = bstep.JumpPower

				if self:GetMurderer() then
					canrun = true
				end

				if self:GetTKer() then
					walk = walk * 0.5
					run = run * 0.5
					jumppower = jumppower * 0.5
				end

				local wep = self:GetActiveWeapon()
				if IsValid(wep) then
					if wep.GetCarrying && wep:GetCarrying() then
						walk = walk * 0.3
						run = run * 0.3
						jumppower = jumppower * 0.3
					end
				end

				-- set out new speeds
				if canrun then
					self:SetRunSpeed(run)
				else
					self:SetRunSpeed(walk)
				end
				self.CanRun = canrun
				self:SetWalkSpeed(walk)
				self:SetJumpPower(jumppower)
			end
		end )
		-- PlayerSetHandsModel hook didn't end up working for fixing the jumppower issue in Murder
	-- Zombie survival support, fix step height and jump power not working
	-- Variable names gathered from zombiesurvival/gamemodes/zombiesurvival/gamemode/sh_globals.lua line 86
	elseif gamemode == "zombiesurvival" then
	
		-- Send DEFAULT_JUMP_POWER and DEFAULT_STEP_SIZE to joining client
		gameevent.Listen( "player_activate" )
		hook.Add( "player_activate", "blockstep_playeractivate", function( data ) 
			local id = data.userid
			local player = Player(id)
			
			local bstep = blockstep
			
			net.Start( "blockstep" )
				--print("[blockstep] Sending ZS network message")
				net.WriteUInt( bstep.MESSAGE_ZS_STEP_HEIGHT, bstep.NETWORK_BITS )
				
				net.WriteUInt( bstep.JumpPower, 32 )
				net.WriteUInt( bstep.StepHeight, 32 )
			net.Send( player )
		end )
	
		--print("[blockstep] Zombie Survival found!")
		hook.Add( "PostGamemodeLoaded", "blockstep_postgamemodeloaded", function ()
			--print("[blockstep] PostGamemodeLoaded Zombie Survival")
			
			local bstep = blockstep
			DEFAULT_JUMP_POWER = bstep.JumpPower
			DEFAULT_STEP_SIZE = bstep.StepHeight
		end )
		
		hook.Add( "PlayerSpawn", "blockstep_playerspawn", function( player, fromMapTransition ) 
			--print("[blockstep] PlayerSpawn")
				
			-- Only explicitly set StepSize for humans, DEFAULT_STEP_SIZE handles zombies
			if player:IsValidLivingHuman() then
				local bstep = blockstep
				player:SetStepSize(DEFAULT_STEP_SIZE)
			end
		end)
	end
	
	-----------------------
end
print("[blockstep] Finished initializing blockstep!")

-- blockstep_jump_analyzer tool commented out cause it's a janky dev tool
--[[TOOL.AddToMenu = true
TOOL.Category = "Construction"
TOOL.Name = "BlockStep Jump Analyzer"]

-- Shared
-- Predicted
function TOOL:LeftClick( trace )
	if CLIENT then return true end
	return true
end

-- Shared
-- Predicted
function TOOL:Deploy()
	if CLIENT then return true end
	local owner = self:GetOwner()
	owner:ChatPrint( "Welcome to the BlockStep Jump Analyzer" )
	owner:ChatPrint( "Say your desired jump power in the chat" )
	
	-- Don't seem to work?
	self.TestingJumpPower = 0
	self.OwnerStartHeight = 0
	self.OwnerBestHeight = 0
	self.JumpTestsPerformed = 0
	
	hook.Add( "PlayerSay", "blockstep_playersay", function( ply, text )
		local weapon = ply:GetActiveWeapon()
		weapon.TestingJumpPower = tonumber( text )
		weapon.OwnerStartHeight = ply:GetPos().z
		weapon.OwnerBestHeight = ply:GetPos().z
		weapon.JumpTestsPerformed = weapon.JumpTestsPerformed or 0
		dprint( weapon, "weapon" )
		dprint( weapon.JumpTestsPerformed, "weapon.JumpTestsPerformed" )
		
		ply:SetJumpPower( weapon.TestingJumpPower )
		
		ply:ChatPrint( "Grabbed jump power, please jump to test" )
		
		hook.Add( "Think", "blockstep_think", function()
			local ply = Entity( 1 )
			local weapon = ply:GetActiveWeapon()
			local currentHeight = ply:GetPos().z
			
			if currentHeight >= weapon.OwnerBestHeight then
				weapon.OwnerBestHeight = currentHeight
			else
				weapon.JumpTestsPerformed = weapon.JumpTestsPerformed + 1
				local heightDifference = weapon.OwnerBestHeight - weapon.OwnerStartHeight
				local graphingString = string.format( "a_{%u}=(%f,%f) newline cancel", weapon.JumpTestsPerformed, weapon.TestingJumpPower, heightDifference )
				-- Started falling
				ply:ChatPrint( string.format( "%f jump power resulted in %f jump height under %f gravity!", weapon.TestingJumpPower, heightDifference, physenv.GetGravity().z ) )
				ply:ChatPrint( graphingString )
				hook.Remove( "Think", "blockstep_think" )
			end
			
		end )
	end )
	self.FirstHeight = nil
return true end

-- Client
if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" },
	}
end]]--