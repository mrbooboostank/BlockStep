TOOL.Category = "BlockStep"
TOOL.Name = "#tool.blockstep.name"
TOOL.AddToMenu = true

-- Cache global library reference cause Lua likes that
local bstep = blockstep
local FormatKey = bstep.FormatKey

-- CallOnClient() didn't work consistently for the Reload() function in singleplayer,
-- so I'll just bite the net library bullet and use it efficiently with one string slot.
-- This will improve the API for other people by opening some things up clientside anyway

-- Shared
-- Predicted
function TOOL:SetFirstHeight( desiredHeight )
	local toolGun = self:GetWeapon()
	toolGun:SetNW2Float( "blockstep_FirstHeight", desiredHeight )
end


-- Shared
-- Predicted
function TOOL:GetFirstHeight()
	local toolGun = self:GetWeapon()
	return toolGun:GetNW2Float( "blockstep_FirstHeight" )
end


-- Shared, but only does work on client
-- Predicted
function TOOL:PrintInfo( translateKey, valueToInsert )
	--print( "PrintInfo called!" )
	if SERVER then 
		if game.SinglePlayer() then
			net.Start( "blockstep" )
				--dprint( blockstep.MESSAGE_PRINTINFO, "messageType when writing" )
				net.WriteUInt( bstep.MESSAGE_PRINTINFO, bstep.NETWORK_BITS )
				net.WriteString( translateKey )
				local valueIsPresent = valueToInsert != nil
				net.WriteBool( valueIsPresent )
				local valueIsString = isstring( valueToInsert )
				net.WriteBool( valueIsString )
					
				if valueIsPresent then
					if valueIsString then
						net.WriteString( valueToInsert )
					else
						net.WriteFloat( valueToInsert )
					end
				end
			net.Send( self:GetOwner() )
		end
	return end

	if not IsFirstTimePredicted() then return end
	local owner = self:GetOwner()
	owner:ChatPrint( FormatKey( translateKey, valueToInsert ) )
end


-- Shared
-- Predicted
function TOOL:CheckForAdmin()
	local owner = self:GetOwner()

	local ownerIsAdmin = owner:IsAdmin()
	
	if not ownerIsAdmin then
		self:PrintInfo( "#tool.blockstep.admins" )
	end
	return ownerIsAdmin
end


-- Client
function TOOL.BuildCPanel( CPanel )
	local mapNameLua = game.GetMap() .. ".lua"
	CPanel:Help( "#tool.blockstep.desc" )
	
	CPanel:Button( "#tool.blockstep.panel.reset_overrides", "blockstep_reset_overrides" )
	
	CPanel:Help( FormatKey( "#tool.blockstep.panel.0", "BlockStep" ) )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.1", "Lua", mapNameLua ) )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.2", mapNameLua, "lua/blockstep_maps/") )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.3", mapNameLua, "lua/blockstep_thirdparty/" ) )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.4", "retry" ) )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.5", "\"third parties\"", "\"map maker\"" ) )
	
	CPanel:Help( "#tool.blockstep.separator" )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.6", "BlockStep" ) )
	local coffeeButton = CPanel:Button( "#tool.blockstep.support.1" )
	coffeeButton.DoClick = function()
		gui.OpenURL( "https://buymeacoffee.com/mrbooboostank" )
	end
	
	local tradeButton = CPanel:Button( FormatKey( "#tool.blockstep.support.2", "Steam" ) )
	tradeButton.DoClick = function()
		gui.OpenURL( "https://steamcommunity.com/tradeoffer/new/?partner=42559487&token=6es1eb07" )
	end
	
	local youtubeButton = CPanel:Button( FormatKey( "#tool.blockstep.support.3", "YouTube" ) )
	youtubeButton.DoClick = function()
		gui.OpenURL( "https://www.youtube.com/channel/UCIbpZJmfLIT2LjqIPdgTDWw" )
	end
	
	CPanel:Help( "#tool.blockstep.separator" )
	
	CPanel:Help( FormatKey( "#tool.blockstep.panel.7", "Lua API" ) )
	
	local guideButton = CPanel:Button( FormatKey( "#tool.blockstep.guide", "Steam" ) )
	guideButton.DoClick = function()
		gui.OpenURL( "https://steamcommunity.com/sharedfiles/filedetails/?id=3404258252" )
	end
	
	CPanel:Help( FormatKey( "#tool.blockstep.panel.8", "BlockStep" ) )
	CPanel:Help( FormatKey( "#tool.blockstep.panel.9", "blockstep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.num", "blockstep.SetDefaultBlockSize", "blockstep.BlockSizeConVar") )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.SetDefaultBlockSize", "Hammer" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.num", "blockstep.SetDefaultStepHeight", "blockstep.StepHeightConVar" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.SetDefaultStepHeight" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.num", "blockstep.SetDefaultJumpHeight", "blockstep.JumpHeightConVar" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.SetDefaultJumpHeight", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.bool", "blockstep.SetDefaultShouldAccountForGravity", "blockstep.ShouldAccountForGravityConVar" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.SetDefaultShouldAccountForGravity", "sv_gravity" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.getter", "blockstep.GetBlockSizeUserValue" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.GetBlockSizeUserValue", "Hammer" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.getter", "blockstep.GetStepHeightUserValue" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.GetStepHeightUserValue" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.getter", "blockstep.GetJumpHeightUserValue" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.GetJumpHeightUserValue", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.getter", "blockstep.GetShouldAccountForGravityUserValue" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.GetShouldAccountForGravityUserValue", "sv_gravity" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.func.UpdatePlayerAttributes", "blockstep.UpdatePlayerAttributes" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.UpdatePlayerAttributes", "SetPlayerStepHeight", "SetPlayerJumpPower", "BlockStep", "\"blockstep_playersetmodel\"" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.hook.step", "SetPlayerStepHeight" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.hook", "BlockStep", "\"blockstep_setplayerstepheight\"", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.hook.jump", "SetPlayerJumpPower" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.hook", "BlockStep", "\"blockstep_setplayerjumppower\"", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.field.num", "blockstep.JumpPower" ) )
	CPanel:ControlHelp( FormatKey( "tool.blockstep.api.desc.JumpPower", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.field.num", "blockstep.StepHeight" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.StepHeight", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.field.num", "blockstep.DefaultJumpPower = 200" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.DefaultJumpPower", "BlockStep" ) )
	
	CPanel:Help( FormatKey( "#tool.blockstep.api.field.num", "blockstep.DefaultStepHeight = 18" ) )
	CPanel:ControlHelp( FormatKey( "#tool.blockstep.api.desc.DefaultStepHeight", "BlockStep" ) )
end


-- Shared
-- Predicted
function TOOL:ResolveCapture( trace, stepSizeMultiplier )
	if not self:CheckForAdmin() then return false end
	
	--print( "ResolveCapture called!" )

	local owner = self:GetOwner()
	
	local firstHeight = self:GetFirstHeight()
	
	if firstHeight == 0 then
		self:SetFirstHeight( trace.HitPos[3] )
		self:PrintInfo( "#tool.blockstep.capture.partial" )
	else
		local secondHeight = trace.HitPos[3]
		local blockHeight = math.Round( math.abs( firstHeight - secondHeight ), 0 )

		if stepSizeMultiplier == 0.5 then
			self:PrintInfo( "#tool.blockstep.capture.step.slabs", blockHeight )
		else
			self:PrintInfo( "#tool.blockstep.capture.step.blocks", blockHeight )
		end
		
		self:PrintInfo( "#tool.blockstep.capture.help", "Lua" )
		self:PrintInfo( game.GetMap() .. ".lua" )
		self:PrintInfo( "blockstep.SetDefaultBlockSize( %G )", blockHeight )
		self:PrintInfo( "blockstep.SetDefaultStepHeight( %G )", stepSizeMultiplier )
		self:PrintInfo( "blockstep.SetDefaultJumpHeight( 1.25 )" )
		self:PrintInfo( "blockstep.SetDefaultShouldAccountForGravity( true )" )
		self:SetFirstHeight( 0 )
		
		if SERVER then
			-- Set other convars before block size, avoids some recalculations in the API
			bstep.JumpHeightConVar:SetFloat( 1.25 )
			bstep.StepHeightConVar:SetFloat( stepSizeMultiplier )
			bstep.ShouldAccountForGravityConVar:SetBool( true )
			bstep.BlockSizeConVar:SetInt( blockHeight )
		end
	end
	
	return true
end


-- Shared
-- Predicted
function TOOL:LeftClick( trace )
	return self:ResolveCapture( trace, 1 )
end


-- Shared
-- Predicted
function TOOL:Reload( trace )
	if not self:CheckForAdmin() then return false end
	
	self:SetFirstHeight( 0 )
	
	if SERVER then
		bstep.JumpHeightConVar:Revert()
		bstep.StepHeightConVar:Revert()
		bstep.ShouldAccountForGravityConVar:Revert()
		bstep.BlockSizeConVar:Revert()
	end
	
	self:PrintInfo( "#tool.blockstep.reset" )
	return true
end


-- Shared
-- Predicted
function TOOL:RightClick( trace )
	return self:ResolveCapture( trace, 0.5 )
end


-- Shared
-- Predicted
function TOOL:Think()
	--dprint( self:GetFirstHeight(), "Tool first height" )
end


-- Shared
-- Predicted
function TOOL:Deploy()
	self:SetFirstHeight( 0 )
return true end


-- Shared
-- Predicted
function TOOL:Holster()
	-- In some cases deploy won't call for a deploy :)
	-- So reset this here too
	self:SetFirstHeight( 0 )
return true end


-- Client
if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" },
	}
end