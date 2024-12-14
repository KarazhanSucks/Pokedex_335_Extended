local Pokedex = Pokedex
local L = LibStub("AceLocale-3.0"):GetLocale("Pokedex")
local BZ = LibStub("LibBabble-Zone-3.0"):GetLookupTable()

--=========================================================================--
-- global variables, constants and types
--=========================================================================--

local IS = Pokedex.Globals.Types.InitStates;       -- Initialization States
local DL = Pokedex.Globals.Types.DebugLevels;      -- Debug Levels
local SL = Pokedex.Globals.Types.SkillLevels;      -- minimum skill level to hold that rank of profession
local MS = Pokedex.Globals.Types.MountSpeeds;      -- Mount Speeds
local MF = Pokedex.Globals.Types.MountFamilies;    -- Mount Families
local DC = {};  -- Debug Categories 
local gc = Pokedex.Globals.Constants;
local gv = Pokedex.Globals.Variables;


--=========================================================================--
-- Addon Management functions
--=========================================================================--

-- Called when the addon is loaded
function Pokedex:OnInitialize()
	self.db = Pokedex.LoadSavedSettings()

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Pokedex", Pokedex.GetUIOptions)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Pokedex", "Pokedex")
	self:RegisterChatCommand("pd", "ChatCommand")
	self:RegisterChatCommand("pokedex", "ChatCommand")
end


function Pokedex:ChatCommand(input)
	if (gv.InitState ~= IS.INITIALIZED and self:Initialize("ChatCommand") == IS.UNINITIALIZED) then
		self:Print(L["ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."]);
		return
	end

	if (not input or input:trim() == "") then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame);
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(Pokedex, "pd", "Pokedex", input);
	end
end


-- Called when the addon is enabled
function Pokedex:OnEnable()
	DC = self.db.global.rgDebugInfo;

	-- we should be able to migrate saved data formats immediately, we don't have to wait for init
	self:MigrateSavedData();

	-- check that none of our actions are blocked
	self:RegisterEvent("ADDON_ACTION_BLOCKED");

	-- check that none of our actions are forbidden
	self:RegisterEvent("ADDON_ACTION_FORBIDDEN");

	-- create scanning tooltip for use in scraping tooltip text
	CreateFrame( "GameTooltip", "PokedexScanningTooltip" ); -- Tooltip name cannot be nil
	PokedexScanningTooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );
	PokedexScanningTooltip:AddFontStrings(
		PokedexScanningTooltip:CreateFontString( "$parentTextLeft1",  nil, "GameTooltipText" ),
		PokedexScanningTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );

	-- init data tables and register events and hooks
	self:Initialize("OnEnable");
end


-- Called when the addon is disabled
function Pokedex:OnDisable()
	self:UnregisterEvent("ADDON_ACTION_BLOCKED");
	self:UnregisterEvent("ADDON_ACTION_FORBIDDEN");

	if (gv.InitState == IS.INITIALIZED) then
		self:UnregisterEvent("COMPANION_LEARNED");
		
		self:UnregisterEvent("KNOWN_TITLES_UPDATE");
		self:UnregisterEvent("NEW_TITLE_EARNED");
		self:UnregisterEvent("OLD_TITLE_LOST");

		-- skills
		self:UnregisterEvent("ACHIEVEMENT_EARNED");
		self:UnregisterEvent("SKILL_LINES_CHANGED");
		
		-- dismount
		self:UnregisterEvent("CVAR_UPDATE");
		self:UnregisterEvent("PLAYER_REGEN_DISABLED");
		self:UnregisterEvent("PLAYER_REGEN_ENABLED");
		self:UnregisterEvent("PLAYER_TARGET_CHANGED");
		
		Pokedex:UnhookAll();
	end
end


-- Initialize all the pet data in the addon
function Pokedex:Initialize(strCaller)
	strCaller = (strCaller or "unknown caller");
	
	if (gv.InitState == IS.INITIALIZED) then 
		if (DC.MISC >= DL.EXCEP) then self:Print("attempt to reinitialize by " .. strCaller); end
		return IS.INITIALIZED;
	end

	if (gv.InitState == IS.INITIALIZING) then 
		if (DC.MISC >= DL.EXCEP) then self:Print("attempt to initialize during initialization by " .. strCaller); end
		return IS.INITIALIZING;
	end

	if (DC.MISC >= DL.EXCEP) then self:Print("initialization triggered by " .. strCaller); end

	-- get skills
	self:GetSkills();

	-- if we can't get names for skill, mounts, companions or titles, then 
	-- we know we're probably in the bad cache state and will have to try
	-- initializing again later
	if ( not self:FUpdateMountInfo() or
	     not self:FUpdateCompanionInfo() or
	     not self:FUpdateTitleInfo() ) then
	     return IS.UNINITIALIZED;
	end
	
	self:UpdateDismountSettings();

	self.db.profile.fFirstBoot = false;

	gv.InitState = IS.INITIALIZING;

	-- update mount data if riding skill changes
	self:RegisterEvent("ACHIEVEMENT_EARNED");

	-- update data when new mount or companion added	
	self:RegisterEvent("COMPANION_LEARNED");

	-- keep track of current mount or companion
	self:SecureHook(   "CallCompanion",    "CallCompanionHook");
	self:SecureHook("DismissCompanion", "DismissCompanionHook");

	-- update data when new title added	
	self:RegisterEvent("KNOWN_TITLES_UPDATE");
	self:RegisterEvent("NEW_TITLE_EARNED");
	self:RegisterEvent("OLD_TITLE_LOST");

	-- keep track of current title
	self:SecureHook("SetCurrentTitle", "SetCurrentTitleHook");

	-- update dismount settings if the CVAR gets changed
	self:RegisterEvent("CVAR_UPDATE");
	
	-- allow flying dismount if in combat or if you've targeted something attackable
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");

	-- update dismount for gathering if profession gained or lost
	-- LEARNED_SPELL_IN_TAB lets us know when spell is added to general tab, but not when we drop the skill
	-- SPELLS_CHANGED seems like it would get called *all* the time, we'd be a small perf drag on the game
	-- SKILL_LINES_CHANGED even though we look at spells now, this may still be the best way to know that we should
	self:RegisterEvent("SKILL_LINES_CHANGED");

	-- hook tooltip to see if we're about to try to gather
	self:SecureHookScript(GameTooltip, "OnShow", "MainTooltipShow");
	self:SecureHookScript(GameTooltip, "OnHide", "MainTooltipHide");

	self:EchoCounts();
	gv.InitState = IS.INITIALIZED;
end

function Pokedex:SafeCall(fn, ...)
	if (gv.InitState ~= IS.INITIALIZED and self:Initialize("SafeCall") == IS.UNINITIALIZED) then
		self:Print(L["ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."]);
	else
		return fn(self, ...);
	end
end

--=========================================================================--
--=========================================================================--
--
-- DEBUG AND INFRASTRUCTURE FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:EchoTest()
--[===[@debug@
	-- table validation
	for k,v in pairs(gc.rgMountAttributes) do
		local strName = GetSpellInfo(k);
		if (strName ~= v.name) then
			self:Printf("table mismatch for spellID %s, expected: %s  got: %s", tostring(k), tostring(v.name), tostring(strName));
		end
	end
--@end-debug@]===]

--[===[@debug@
--[[
	self:Print("start: compare table to tooltips");
	for k,v in pairs(gc.rgMountAttributes) do
		local strName = GetSpellInfo(k);
		local msTip = self:GetMountTypeFromTooltip(k);
		if (v.speed ~= msTip) then
			self:Printf("mismatch for %s  %s  table:%s  tip:%s", tostring(k), tostring(strName), gc.rgstrMountSpeeds[v.speed], gc.rgstrMountSpeeds[msTip]);
		end
	end
	self:Print("end: compare table to tooltips");
--]]
--@end-debug@]===]

	if (DC.DISMOUNT >= DL.AV) then 
		self:Printf("fManageAutoDismount=%s  fDismountForGathering=%s  fDismountForCombat=%s  fDismountForAttack=%s", 
			tostring(self.db.profile.fManageAutoDismount), tostring(Pokedex.db.profile.fDismountForGathering), 
			tostring(self.db.profile.fDismountForCombat), tostring(self.db.profile.fDismountForAttack));
	end
end


function Pokedex:EchoCounts()
	if (DC.MISC >= DL.BASIC) then 
		self:Printf("Current counts are %i mounts, %i companions and %i titles", #self.db.profile.rgMountInfo, #self.db.profile.rgCompanionInfo, #self.db.profile.rgTitleInfo);
	end
end

function Pokedex:EchoSpeed()
	local nSpeed = GetUnitSpeed("player");
	local nPercent = nSpeed - 7;
	local strOut = "";

	if (nSpeed == 0) then
		strOut = format("%i yards per second", nSpeed);
	elseif (nPercent == 0) then
		strOut = format("%i yards per second, standard run speed", nSpeed);
	elseif (nPercent > 0) then
		nPercent = ((nSpeed - 7) * 100) / 7;
		strOut = format("%.2f yards per second, speed boosted by %.2f%%", nSpeed, nPercent);
	else
		nPercent = (nSpeed * 100) / 7;
		strOut = format("%.2f yards per second, speed reduced to %.2f%% of run speed", nSpeed, nPercent);
	end
	
	strOut = gsub(strOut, "%.00", "");
	self:Print(strOut);
end

function Pokedex:EchoZone()
	SetMapToCurrentZone();

	local rgstrContinents = { GetMapContinents() };
	local strSubZone = GetSubZoneText();
	local rgMSFiltered = self:FilterMountSpeeds();

	if (strSubZone == "") then strSubZone = nil; end
	if (#rgMSFiltered == 0) then 
		rgMSFiltered = { L["no mounts available"] };
	else
		for i = 1, #rgMSFiltered do
			rgMSFiltered[i] = gc.rgstrMountSpeedDescsShort[ rgMSFiltered[i] ];
		end
	end

	local strLocation = self:StrFromVarArg(nil, unpack( { rgstrContinents[GetCurrentMapContinent()], GetZoneText(), strSubZone } ));
	local strMountList = self:StrFromVarArg(" ", unpack(rgMSFiltered));
	
	self:Printf("%s.  Mount order: %s.", strLocation, strMountList);
end

function Pokedex:ADDON_ACTION_BLOCKED(_, culprit, action, ...)
	if (culprit ~= "Pokedex") then return end
	self:Printf("ERROR: ADDON_ACTION_BLOCKED calling %s  %s", action, self:StrFromVarArg(nil, ...));
end

function Pokedex:ADDON_ACTION_FORBIDDEN(_, culprit, action, ...)
	if (culprit ~= "Pokedex") then return end
	self:Printf("ERROR: ADDON_ACTION_BLOCKED calling %s  %s", action, self:StrFromVarArg(nil, ...));
end


function Pokedex:SetDebug(info, value)
	local strName, strValue, index = self:GetArgs(value, 2);
	
	if (strName == nil) then
		self:DebugValues();
		return;
	end

	if (index ~= 1e9) then
		self:Print("ERROR: too many parameters passed");
		self:DebugUsage();
		return;
	end

	local iValue = tonumber(strValue)
	if (iValue == nil) then
		self:Print("ERROR: no value given for debug level");
		self:DebugUsage();
		return;
	elseif (iValue < DL.NONE or iValue > DL.MAX) then
		self:Printf("ERROR: level_value must be number between %i and %i", DL.NONE, DL.MAX);
		self:DebugUsage();
		return;
	end

	strName = strupper(strName);
	if (strName == "ALL") then
		for k in pairs(DC) do
			DC[k] = iValue;
		end
	elseif (DC[strName] ~= nil) then
			DC[strName] = iValue;
	else
		self:Print("ERROR: level_name not recognized. Must match an existing value or ALL.");
		self:DebugUsage();
		return;
	end

	self:DebugValues();
end

function Pokedex:DebugValues()
	self:Print("current debug levels:");
	for k,v in pairs(DC) do
		self:Printf("value: %i  name: %s", v, k);
		-- self:Printf("lvalue:%i pvalue:%i name:%s", DL[v.category], v, k);
	end
end

function Pokedex:DebugUsage()
	self:Print("to see current debug levels:");
	self:Print("  /pd debug ");
	self:Print("to set a level:");
	self:Print("  /pd debug level_name level_value");
end


function Pokedex:PrintSpellTip(spellId)
	PokedexScanningTooltip:ClearLines();
	PokedexScanningTooltip:SetHyperlink("spell:" .. spellId);
	for iLines=1,PokedexScanningTooltip:NumLines() do
		local TipTextObject = getglobal("PokedexScanningTooltipTextLeft" .. iLines);
		local strText = TipTextObject:GetText();
		self:Print(strText); 
	end
end

function Pokedex:PrintTable(table, tableName)
	tableName = tableName or tostring(table);
	if (table == nil) then 
		self:Print("'table' is nil");
	elseif (type(table) ~= "table") then
		self:Printf("'table' is actually of type %s", type(table));
	else
		self:Printf("key/value pairs for table %s", tableName);
		for k,v in pairs(table) do
			self:Printf("key(%s): %s   value(%s): %s", type(k), tostring(k), type(v), tostring(v));
		end
	end
end

function Pokedex:StrFromVarArg(strDelim, ...)
	if (select("#", ...) == 0) then return ""; end
	strDelim = strDelim or "  "

	local strOut = tostring(select(1, ...));
	for i=2, select("#", ...), 1 do
		strOut = format("%s%s%s", strOut, strDelim, tostring(select(i, ...)));
	end

	return strOut;	
end


--=========================================================================--
--=========================================================================--
--
-- SKILL FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:GetSkills()
	gv.idLastAchievement = GetLatestCompletedAchievements();

	for k,v in pairs(gc.rgRidingIds) do
		local _, strName, _, fHas = GetAchievementInfo(k);
		strName = strName or L["name not yet available"];
		if (DC.MISC >= DL.AV) then self:Printf("for %s riding skill, %s achievement is %s", gc.rgstrSkillRankName[v], strName, tostring(fHas)); end
		if (fHas) then gv.rsRidingSkill = max(gv.rsRidingSkill, v); end
	end

	gv.fMiner = IsSpellKnown(gc.idSpellFindMinerals);
	gv.fHerbalist = IsSpellKnown(gc.idSpellFindHerbs);

	for k,v in pairs(gc.rgSkinningIds) do
		if (IsSpellKnown(k)) then
			if (DC.MISC >= DL.AV) then self:Printf("spell known for %s Skinning skill", gc.rgstrSkillRankName[v]); end
			gv.fSkinner = true;
			break; -- only one rank of skinning will be present, and we only care that they have some level anyway right now
		end
	end

	if (DC.MISC >= DL.BASIC) then self:Printf("SKILLS  Riding:%s  Mining:%s  Herbalism:%s  Skinning:%s", gc.rgstrSkillRankName[gv.rsRidingSkill], tostring(gv.fMiner), tostring(gv.fHerbalist), tostring(gv.fSkinner)); end
end

function Pokedex:ACHIEVEMENT_EARNED()
	local ids = { GetLatestCompletedAchievements() };

	for i = 1, #ids do
		local id = ids[i]
		if (gv.idLastAchievement == id) then break; end

		if (DC.MISC >= DL.AV) then 
			local _, strName = GetAchievementInfo(id);
			strName = strName or L["name not yet available"];
			self:Printf("new achievement learned: %s", strName); 
		end		

		if (gc.rgRidingIds[id] ~= nil) then 
			if (DC.MISC >= DL.BASIC) then self:Printf("achievement for %s riding skill earned", gc.rgstrSkillRankName[ gc.rgRidingIds[id] ]); end
			if (gc.rgRidingIds[id] > gv.rsRidingSkill) then  -- just in case we have achievement spam from some kind of reset
				gv.rsRidingSkill = gc.rgRidingIds[id];
				self:FUpdateMountInfo();
				LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
			end
		end
	end
	
	gv.idLastAchievement = ids[1];
end

function Pokedex:SKILL_LINES_CHANGED(...)
	-- if (DC.MISC >= DL.AV) then self:Printf("SKILL_LINES_CHANGED  %s", self:StrFromVarArg(nil, ...)); end

	local fTemp = IsSpellKnown(gc.idSpellFindMinerals);
	if (gv.fMiner ~= fTemp) then
		if (DC.MISC >= DL.BASIC) then self:Printf("%s Mining skill", fTemp and "gained" or "lost"); end
		gv.fMiner = fTemp;
		LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
	end

	fTemp = IsSpellKnown(gc.idSpellFindHerbs);
	if (gv.fHerbalist ~= fTemp) then
		if (DC.MISC >= DL.BASIC) then self:Printf("%s Herbalism skill", fTemp and "gained" or "lost"); end
		gv.fHerbalist = fTemp;
		LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
	end

	fTemp = false;
	for k,v in pairs(gc.rgSkinningIds) do
		if (IsSpellKnown(k)) then
			fTemp = true;
			break; -- only one rank of skinning will be present, and we only care that they have some level anyway right now
		end
	end
	if (gv.fSkinner ~= fTemp) then
		if (DC.MISC >= DL.BASIC) then self:Printf("%s Skinning skill", fTemp and "gained" or "lost"); end
		gv.fSkinner = fTemp;
		LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
	end

	if (self.db.profile.fDismountForGathering and not (gv.fMiner or gv.fHerbalist or gv.fSkinner)) then
		if (DC.MISC >= DL.BASIC) then self:Print("we no longer have a gathering skill and so will disable dismount for gathering"); end
		self.db.profile.fDismountForGathering = false;
		LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
	end
end


--=========================================================================--
--=========================================================================--
--
-- MOUNT AND COMPANION SHARED FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:SuperToggle() 
	if IsOutdoors() then
		self:ToggleMount()
	else
		self:ToggleCompanion()
	end
end

function Pokedex:SummonVendor()
	if (IsOutdoors()) then 
		if (gv.iTravelersMammoth ~= 0) then
			if (gv.iTravelersMammoth ~= self:GetCurrentMount()) then self:SummonPet("MOUNT", gv.iTravelersMammoth); end
		elseif (gv.iArgentSquire ~= 0) then
			if (gv.iArgentSquire ~= self:GetCurrentCompanion()) then self:SummonPet("CRITTER", gv.iArgentSquire); end
		else
			self:Print(L["ERROR: You have no mounts or pets with vendor capabilities"]);
		end
	else
		if (gv.iArgentSquire ~= 0) then
			if (gv.iArgentSquire ~= self:GetCurrentCompanion()) then self:SummonPet("CRITTER", gv.iArgentSquire); end
		elseif (gv.iTravelersMammoth ~= 0) then
			self:Print(L["ERROR: You cannot summon your mammoth in this area"]);
		else
			self:Print(L["ERROR: You have no mounts or pets with vendor capabilities"]);
		end
	end
end

function Pokedex:COMPANION_LEARNED(...)
	if (DC.MOUNTS >= DL.BASIC or DC.PETS >= DL.BASIC) then self:Print("COMPANION_LEARNED  " .. self:StrFromVarArg(nil, ...)); end

	self:FUpdateMountInfo()
	self:FUpdateCompanionInfo()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
end

function Pokedex:CallCompanionHook(type, index)
	if (type == "CRITTER" ) then
		self:SetCurrentCompanion(index)
	elseif (type == "MOUNT") then
		self:SetCurrentMount(index)
	else
		self:Print(L["ERROR: type error"])
	end
end


function Pokedex:DismissCompanionHook(type)
	if (type == "CRITTER" ) then
		self:SetCurrentCompanion(0)
	elseif (type == "MOUNT") then
		self:SetCurrentMount(0)
	else
		self:Print(L["ERROR: type error"])
	end
end


function Pokedex:SummonPet(strType, iPet, fNext, fOther)
	local _, _, idSpell = GetCompanionInfo(strType, iPet);

	if (strType == "CRITTER" ) then
		if (self.db.profile.rgCompanionInfo[iPet].id == idSpell) then
			CallCompanion(strType, iPet);
			self:AnnounceSummon(self.db.profile.rgCompanionInfo[iPet].name);
		else
			if (DC.PETS >= DL.BASIC) then self:Print("spellId mismatch between live and saved data; rebuilding and reselecting"); end
			self:FUpdateCompanionInfo();
			self:SummonCompanion(fNext);
		end
	elseif (strType == "MOUNT") then
		if (self.db.profile.rgMountInfo[iPet].id == idSpell) then
			CallCompanion(strType, iPet);
			--self:AnnounceSummon(self.db.profile.rgMountInfo[iPet].name);

			-- change title on load
			if (self.db.profile.fChangeTitleOnMount) then self:ChangeTitle(); end
		else
			if (DC.MOUNTS >= DL.BASIC) then self:Print("spellId mismatch between live and saved data; rebuilding and reselecting"); end
			self:FUpdateMountInfo();
			self:SummonMount(fNext, fOther);
		end
	else
		self:Print(L["ERROR: type error"]);
	end
end


function Pokedex:AnnounceSummon(strName)
	if (not self.db.profile.fAnnounce) then return end

	local iChannel = self.db.profile.iChannel

	-- if not in raid, try sending it to party
	if (3 == iChannel and 0 == GetNumRaidMembers()) then
		iChannel = 2
	end
	-- if not in a party, just send it to yourself
	if (2 == iChannel and 0 == GetNumPartyMembers()) then
		iChannel = 1
	end

	local strOut
	if (iChannel == 4) then
		strOut = format(L["lets %s know that they have been chosen."], strName);
	else
		strOut = format(L["%s, I choose you!"], strName);
	end

	if (iChannel == 1) then
		self:Print(strOut);
	else
		SendChatMessage(strOut, gc.rgstrChannels[iChannel]);
	end

end


--=========================================================================--
--=========================================================================--
--
-- MOUNT FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:ToggleMount()
	if (self:GetCurrentMount() > 0 or UnitInVehicle("player")) then
		self:DismissMount()
	else
		self:SummonMount()
	end
end


function Pokedex:DismissMount()
	if UnitInVehicle("player") then
		VehicleExit()
	else
		-- TODO find if this goes through dismiss companion hook for tracking
		Dismount()
	end
end

-- returns list of mount speeds eligible for current location
function Pokedex:FilterMountSpeeds(fOther)
	local rgMSFiltered = {};
	local fQiraji = false;
	local fSwimming = IsSwimming();

	-- check if we can fly - cover 99% of situations
	local fFlyable = IsFlyableArea() and not fSwimming;

	-- check locations for special rules about what kinds of mounts we can actually summon
	SetMapToCurrentZone();
	local continent = GetCurrentMapContinent();

	if (1 == continent) then fQiraji = strfind(BZ["Ahn'Qiraj"], GetZoneText()); end
	if (2 == continent) then 
		local zone = GetRealZoneText();
		fVashjir = strfind(BZ["Abyssal Depths"], zone) or 
		           strfind(BZ["Kelp'thar Forest"], zone) or 
		           strfind(BZ["Shimmering Expanse"], zone);
	end
	if (4 == continent and fFlyable) then
		-- if they haven't bought cold weather flying, then they can't fly in northrend
		if (not IsSpellKnown(gc.idSpellColdWeatherFlying)) then
			fFlyable = false;
		-- if Wintergrasp is being contested, you can't fly there
		else
			if (GetZoneText() == BZ["Wintergrasp"]) then
				fFlyable = (nil ~= GetWintergraspWaitTime());
			end
		end
	end

	-- flip the type if the user has asked for that
	if fOther then fFlyable = not fFlyable; end

	if (fFlyable) then 
		if (gv.rgMountsByType[MS.AllFlyers]  ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.AllFlyers  end
		if (gv.rgMountsByType[MS.FastFlyers] ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.FastFlyers end
		if (gv.rgMountsByType[MS.Flyer310]   ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Flyer310   end
		if (gv.rgMountsByType[MS.Flyer280]   ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Flyer280   end
		if (gv.rgMountsByType[MS.Flyer150]   ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Flyer150   end
	end

	if (fSwimming) then
		if (fVashjir and gv.rgMountsByType[MS.Vashjir] ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Vashjir end
		if              (gv.rgMountsByType[MS.Swimmer] ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Swimmer end
	end

	if (fQiraji and gv.rgMountsByType[MS.Qiraji] ~= nil) then 
		rgMSFiltered[#rgMSFiltered+1] = MS.Qiraji
	end

	if (gv.rgMountsByType[MS.AllRunners] ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.AllRunners end
	if (gv.rgMountsByType[MS.Runner100]  ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Runner100  end
	if (gv.rgMountsByType[MS.Runner60]   ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Runner60   end
	if (gv.rgMountsByType[MS.Runner0]    ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Runner0    end
	if (gv.rgMountsByType[MS.Unknown]    ~= nil) then rgMSFiltered[#rgMSFiltered+1] = MS.Unknown    end

	return rgMSFiltered;
end


function Pokedex:SummonMount(fNext, fOther)
	local strCurCast = UnitCastingInfo("player")
	if (strCurCast ~= nil) then
		if (DC.MOUNTS >= DL.EXCEP) then self:Printf("currently casting %s; summon will fail for this reason so ignore this summons attempt", strCurCast); end
		return
	end

	-- We may need to search across multiple lists. For example, if the only 
	-- mount in the set was given a rank of 0. Another case is supporting a 
	-- "style over substance" type feature where 310% and 280% mounts are 
	-- treated as the same category.
	local rgMSFiltered = self:FilterMountSpeeds(fOther);

	if (DC.MOUNTS >= DL.AV) then
		self:Print("mount types elligible for this zone:")
		for i=1, #rgMSFiltered, 1 do
			self:Print("  " .. gc.rgstrMountSpeeds[rgMSFiltered[i]])
		end
	end

	local iCurMount = self:GetCurrentMount();
	local rgiFiltered = {};
	local cTotalRanks = 0;
	local fSkippedCur = false;
	local fSkippedHot = false;

	--=====================================================================--
	-- FilterMounts -- Local function that builds list of mounts elligible
	-- for summoning as well as providing a sum of the ranks of those mounts.
	-- Best done as seperate function to support different ways of calling,
	-- next mount versus random mount, and as local function we can reference 
	-- and modify variables in the scope of the calling function.
	-- NOTE: appends to rgiFiltered, so multiple calls can build bigger list
	--=====================================================================--
	local function FilterMounts(msType, iStart, iEnd, fFirstOnly)
		if (iStart == 0 or iStart > iEnd) then
			if (DC.MOUNTS >= DL.EXCEP) then self:Print("invalid search range"); end
			return;
		end 

		if (DC.MOUNTS >= DL.EXCEP) then self:Printf("building list of eligible %s ...", gc.rgstrMountSpeedDescs[msType]); end
		for iMountOfType = iStart, iEnd, 1 do
			-- translate from index in speed group to all mounts index
			iMount = gv.rgMountsByType[msType].rgIndices[iMountOfType];
			
			-- if its ranked as 0, then it gets skipped
			if (self.db.profile.rgMountInfo[iMount].rank == 0) then
				if (DC.MOUNTS >= DL.EXCEP) then self:Printf("mount %i %s skipped for having rank of 0", iMount, self.db.profile.rgMountInfo[iMount].name); end
			else
				-- if its the current mount, then it is skipped
				if (iMount == iCurMount) then
					if (DC.MOUNTS >= DL.EXCEP) then self:Printf("mount %i %s skipped for being current mount", iMount, self.db.profile.rgMountInfo[iMount].name); end
					fSkippedCur = true;
				else
					if (fFirstOnly) then
						-- if looking for first good value, then this is it
						rgiFiltered[#rgiFiltered + 1] = iMount;
						cTotalRanks = cTotalRanks + self.db.profile.rgMountInfo[iMount].rank;
						if (DC.MOUNTS >= DL.BASIC) then self:Printf("mount %i %s is Next eligible mount", iMount, self.db.profile.rgMountInfo[iMount].name); end
						return;
					-- if hot mount and hotness is enabled then don't add to list, it will be handled seperately
					elseif (self.db.profile.fEnableHotness and iMount == gv.iHotMount) then
						if (DC.MOUNTS >= DL.EXCEP) then self:Printf("mount %i %s skipped for being hot mount", iMount, self.db.profile.rgMountInfo[iMount].name); end
						fSkippedHot = true;
					-- else its put into the pool of summonables
					else
						rgiFiltered[#rgiFiltered + 1] = iMount;
						cTotalRanks = cTotalRanks + self.db.profile.rgMountInfo[iMount].rank;
						if (DC.MOUNTS >= DL.AV) then self:Printf("mount %i %s added to list of summonable mounts with a rank of %i. Total rank count is %i", iMount, self.db.profile.rgMountInfo[iMount].name, self.db.profile.rgMountInfo[iMount].rank, cTotalRanks); end
					end
				end
			end
		end

		if (DC.MOUNTS >= DL.BASIC) then self:Printf("list built: %i %s with a total rank of %i", #rgiFiltered, gc.rgstrMountSpeedDescs[msType], cTotalRanks); end
	end
	--=====================================================================--
	-- end of local function FilterMounts
	-- resumption of parent function SummonMount
	--=====================================================================--

	-- Generate filtered list of elligible mounts and total ranks.
	for msFilteredType = 1, #rgMSFiltered, 1 do
		local msType = rgMSFiltered[msFilteredType];

		if (fNext and msType == gv.rgMountMap[iCurMount].speed) then
			-- We can optimize our search in this case by starting immediately after current
			FilterMounts(msType, gv.rgMountMap[iCurMount].index+1, #gv.rgMountsByType[msType].rgIndices, true);
			
			-- if none were found in that portion of the list, then start new search from the front of the list
			if (cTotalRanks == 0) then FilterMounts(msType, 1, gv.rgMountMap[iCurMount].index, true); end
		else
			FilterMounts(msType, 1, #gv.rgMountsByType[msType].rgIndices, fNext);
		end
		
		if (#rgiFiltered ~= 0 or fSkippedHot or fSkippedCur) then 
			break;
		end
	end

	-- if we skipped the hot mount while building a list, nows the time for its heat check
	if (fSkippedHot) then
		local iHeatCheck = math.random(1,100);
		if (self.db.profile.iHotMountPref >= iHeatCheck) then
			if (DC.MOUNTS >= DL.BASIC) then self:Printf("mount %i %s passed heat check (rolled %i, needed %i or less) and will be summoned", gv.iHotMount, self.db.profile.rgMountInfo[gv.iHotMount].name, iHeatCheck, self.db.profile.iHotMountPref); end
			self:SummonPet("MOUNT", gv.iHotMount, fNext, fOther);
			return;
		end

		if (DC.MOUNTS >= DL.BASIC) then self:Printf("mount %i %s skipped for failing heat check (rolled %i, needed %i or less) as hot mount", gv.iHotMount, self.db.profile.rgMountInfo[gv.iHotMount].name, iHeatCheck, self.db.profile.iHotMountPref); end
	end

	-- selection returned 0 mounts to choose from	
	if (#rgiFiltered == 0 or cTotalRanks == 0) then 
		-- both values should be in sync
		if (#rgiFiltered ~= cTotalRanks) then self:Print(L["ERROR: only one of #rgiFiltered and cTotalRanks was zero"]); end

		if (fSkippedHot) then
			if (DC.MOUNTS >= DL.BASIC) then self:Printf("hot mount %i %s failed heat check but is apparently only one summonable", gv.iHotMount, self.db.profile.rgMountInfo[gv.iHotMount].name); end
			self:SummonPet("MOUNT", gv.iHotMount, fNext, fOther);
			return
		end

		if (fSkippedCur) then
			if (DC.MOUNTS >= DL.BASIC) then self:Printf("current mount %i %s is apparently only one summonable; doing nothing", iCurMount, self.db.profile.rgMountInfo[iCurMount].name); end
			return; -- only summonable mount is already summoned
		end

		self:Print(L["ERROR: You have no summonable mounts."]);
		return;
	end

	
	-- only one mount to choose from
	if (#rgiFiltered == 1) then
		if (DC.MOUNTS >= DL.BASIC) then self:Printf("mount %i %s is apparently only one summonable", rgiFiltered[1], self.db.profile.rgMountInfo[rgiFiltered[1]].name); end
		self:SummonPet("MOUNT", rgiFiltered[1], fNext, fOther);
		return;
	end		

	-- multiple mounts
	local cRank = math.random(1,cTotalRanks);
	if (DC.MOUNTS >= DL.BASIC) then self:Printf("random roll from 1 to %i produced %i", cTotalRanks, cRank); end

	for _, iNew in ipairs(rgiFiltered) do
		cRank = cRank - self.db.profile.rgMountInfo[iNew].rank;
		if (DC.MOUNTS >= DL.AV) then self:Printf("mount %i %s's rank of %i brings total down to %i", iNew, self.db.profile.rgMountInfo[iNew].name, self.db.profile.rgMountInfo[iNew].rank, cRank); end
		if (cRank <= 0) then -- found our slot
			self:SummonPet("MOUNT", iNew, fNext, fOther);
			return;
		end
	end

	if (cRanks > 0) then self:Print(L["ERROR: selection error"]); end
end


-- Hooking CallCompanion and DismissCompanion ensures we'll usually know what 
-- the current state is, but if the user dismisses the mount by clicking off 
-- the buff or casting a spell, we may not get the update, so always get/set 
-- current pet through these functions.
-- TODO: find if there's a way in lua I could scope this variable better.
-- TODO: persist last companion across sessions so that Next starts where you left off
local gr_iLastMountSeen = 0;

function Pokedex:SetCurrentMount(iMount)
	if (DC.MOUNTS >= DL.BASIC) then self:Printf("Current mount set to: %i %s", iMount, self.db.profile.rgMountInfo[iMount].name); end
	gr_iLastMountSeen = iMount;
	self:SetMountForRanking(gr_iLastMountSeen);
end

function Pokedex:GetCurrentMount()
	if (gr_iLastMountSeen ~= 0) then
		local _, _, _, _, fActive = GetCompanionInfo("MOUNT", gr_iLastMountSeen);
		if (not fActive) then 
			gr_iLastMountSeen = 0; -- might not have an active mount 
		end 
	end

	if (gr_iLastMountSeen == 0) then
		for index = 1, GetNumCompanions("MOUNT"), 1 do
			local _, _, _, _, fActive = GetCompanionInfo("MOUNT", index);
			if (fActive) then 
				gr_iLastMountSeen = index;
				break;
			end
		end
	end

	self:SetMountForRanking(gr_iLastMountSeen);
	return gr_iLastMountSeen;
end


function Pokedex:SetMountForRanking(iMount) 
	if (iMount ~= 0) then
		gv.iMountType   = gv.rgMountMap[iMount].speed;
		gv.iMountOfType = gv.rgMountMap[iMount].index;
	elseif (#self.db.profile.rgMountInfo == 0) then
		gv.iMountType   = 0;
		gv.iMountOfType = 0;
	else -- pick first mount of first non-empty category
		for i = 1, MS.Unknown, 1 do
			if (gv.rgMountsByType[i] ~= nil and #gv.rgMountsByType[i]) then
				gv.iMountType   = i;
				gv.iMountOfType = 1;
				break;
			end
		end
	end
end


function Pokedex:FUpdateMountInfo()
	Pokedex:DecomposeMountSpeeds();

	gv.rgstrMountTypes = {};
	gv.iMountType = 0;
	gv.rgMountsByType = {};
	gv.iMountOfType = 0;
	gv.rgstrHotMountNames =  { [0] = L["no hot mount"] };
	gv.iHotMount = 0;
	gv.rgMountMap = { [0] = { speed = 0, index = 0 } };

	-- assumption is that order doesn't change except for insertions of new mounts
	-- so we can speed up searching saved data for rankings by starting the search 
	-- at a predicted index
	local iMatch = 1;
	local iNewMount = 0;
	local iActive = 0;
	local rgNew = { [0] = { name = "NONE", id = 0, rank = gc.iDefaultRank } };

	for index = 1, GetNumCompanions("MOUNT"), 1 do
		local _, _, idSpell, _, fActive = GetCompanionInfo("MOUNT", index);
		local strMountName = GetSpellInfo(idSpell);
		if (strMountName == nil) then
			if (gv.InitState == IS.UNINITIALIZED) then
				if (DC.MISC >= DL.BASIC) then self:Print("unable to initialize, missing mount names"); end
			else
				self:Print(L["ERROR: mount name not available"]);
			end
			return false;
		end

		local fMatchMade, iRank = self:GetMountRankFromSavedData(iMatch, idSpell);
		local dms = gv.rgDMS[self:GetMountType(idSpell)];

		if (not gv.fHas310 and dms.flying == MS.Flyer310) then
			-- first 310 we've seen this session, start over with this new info
			if (DC.MOUNTS >= DL.EXCEP) then self:Print("310% speed mount found, must start over"); end
			gv.fHas310 = true;
			return Pokedex:FUpdateMountInfo();
		end

		if (DC.MOUNTS >= DL.AV) then self:Printf("%s  rank: %i  flying: %s  running: %s  special: %s", strMountName, iRank, gc.rgstrMountSpeeds[dms.flying], gc.rgstrMountSpeeds[dms.running], gc.rgstrMountSpeeds[dms.special]); end

		if (fMatchMade) then 
			iMatch = iMatch + 1;
		elseif (not self.db.profile.fFirstBoot) then
			self:Printf(L["New mount added: %s"], strMountName);
			iNewMount = index;
			if (self.db.profile.fEnableHotness and self.db.profile.fNewHotness) then
				self.db.profile.idHotMount = idSpell;
			end
		end

		if (fActive) then iActive = index; end
		if (idSpell == self.db.profile.idHotMount) then gv.iHotMount = index; end
		if (idSpell == gc.idSpellTravelersTundraMammothAlliance or idSpell == gc.idSpellTravelersTundraMammothHorde) then 
			gv.iTravelersMammoth = index ;
		end

		rgNew[index] = { name = strMountName, id = idSpell, rank = iRank };
		gv.rgstrHotMountNames[index] = strMountName;

		-- add mount to type categories for which it has a movement mode
		local function AddMountByType(ms)
			if (ms ~= MS.None) then
				if (gv.rgMountsByType[ms] == nil) then gv.rgMountsByType[ms] = { rgIndices = {}, rgNames = {} }; end
				local iNew = 1 + #gv.rgMountsByType[ms].rgIndices;

				gv.rgMountsByType[ms].rgIndices[iNew] = index;
				gv.rgMountsByType[ms].rgNames[iNew] = strMountName;

				gv.rgMountMap[index] = { ["speed"] = ms, ["index"] = iNew };
			end
		end

		AddMountByType(dms.running);
		AddMountByType(dms.flying);
		AddMountByType(dms.special);
	end

	-- now that we've read everything in, blow away old saved ranking with new list
	self.db.profile.rgMountInfo = rgNew;

	-- if they have no mounts, then we need to make some text available for the drop downs
	if (#self.db.profile.rgMountInfo == 0) then
		gv.rgstrMountTypes = { [0] = L["no mounts available"] }
		gv.rgMountsByType = { [0] = { rgIndices = { [0] = 0 }, rgNames = { [0] = L["no mounts available"] } } }
	-- else, create list of mount types based on those found
	else
		for ms = MS.Unknown, 1, -1 do
			if (gv.rgMountsByType[ms] ~= nil) then
				gv.rgstrMountTypes[ms] = gc.rgstrMountSpeedDescs[ms];
				gv.iMountType = ms;
			end
		end
	end

	-- iActive will be either 0 from when we inited, or was set when we found 
	-- an active mount. Calling SetCurrentCompanion ensures our cached value 
	-- for last active mount is correct, as well as correctly tweaking the 
	-- selected drop down items for the no active mount case.
	-- A brand new mount, though, will trump the active mount for selection.
	self:SetCurrentMount(iActive);
	if (iNewMount ~= 0) then self:SetMountForRanking(iNewMount); end

	return true;
end


-- return values - fMatchMade, iRank
function Pokedex:GetMountRankFromSavedData(iStart, iID)
	local cLimit = #self.db.profile.rgMountInfo;

	if (iStart <= cLimit) then
		for index = iStart, cLimit, 1 do
			if (self.db.profile.rgMountInfo[index].id == iID) then
				return true, self.db.profile.rgMountInfo[index].rank;
			end
		end
		
		for index = 1, iStart - 1, 1 do
			if (self.db.profile.rgMountInfo[index].id == iID) then
				return true, self.db.profile.rgMountInfo[index].rank;
			end
		end
	end

	return false, gc.iDefaultRank;
end


function Pokedex:DecomposeMountSpeeds()

	local function Flyer310()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllFlyers end
		if (self.db.profile.fCombineAllFastMounts) then return MS.FastFlyers end
		return MS.Flyer310
	end
	local function Flyer280()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllFlyers end
		if (self.db.profile.fCombineAllFastMounts) then return MS.FastFlyers end
		return MS.Flyer280
	end
	local function Flyer150()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllFlyers end
		return MS.Flyer150
	end
	local function Skill_310()
		if (gv.rsRidingSkill >= SL.Artisan) then return Flyer310() end
		if (gv.rsRidingSkill >= SL.Expert)  then return Flyer150() end
		return MS.None
	end
	local function Skill_280()
		if (gv.rsRidingSkill >= SL.Artisan) then return Flyer280() end
		if (gv.rsRidingSkill >= SL.Expert)  then return Flyer150() end
		return MS.None
	end
	local function Skill_EoV()
		if (gv.fHas310) then return Skill_310() else return Skill_280() end
	end


	local function Runner100()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllRunners end
		return MS.Runner100
	end
	local function Runner60()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllRunners end
		return MS.Runner60
	end
	local function Runner0()
		if (self.db.profile.fCombineFastAndSlowMounts) then return MS.AllRunners end
		return MS.Runner0
	end
	local function Skill_100()
		if (gv.rsRidingSkill >= SL.Journeyman) then return Runner100() end
		if (gv.rsRidingSkill >= SL.Apprentice) then return Runner60()  end
		return MS.None
	end


	-- self:Print("DecomposeMountSpeeds");
	gv.rgDMS = {};
	gv.rgDMS[MS.None]          = { flying = MS.None,      running = MS.None,       special = MS.Unknown };
	gv.rgDMS[MS.Flyer310]      = { flying = Flyer310(),   running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Flyer280]      = { flying = Flyer280(),   running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Flyer150]      = { flying = Flyer150(),   running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Runner100]     = { flying = MS.None,      running = Runner100(),   special = MS.None    };
	gv.rgDMS[MS.Runner60]      = { flying = MS.None,      running = Runner60(),    special = MS.None    };
	gv.rgDMS[MS.Runner0]       = { flying = MS.None,      running = Runner0(),     special = MS.None    };
	gv.rgDMS[MS.Swimmer]       = { flying = MS.None,      running = MS.None,       special = MS.Swimmer };
	gv.rgDMS[MS.Vashjir]       = { flying = MS.None,      running = MS.None,       special = MS.Vashjir };
	gv.rgDMS[MS.Qiraji]        = { flying = MS.None,      running = MS.None,       special = MS.Qiraji  };
	gv.rgDMS[MS.Unknown]       = { flying = MS.None,      running = MS.None,       special = MS.Unknown };
	gv.rgDMS[MS.Black_Scarab]  = { flying = MS.None,      running = Runner100(),   special = MS.Qiraji  };
	gv.rgDMS[MS.Sea_Turtle]    = { flying = MS.None,      running = Runner0(),     special = MS.Swimmer };
	gv.rgDMS[MS.Skill_EoV_60]  = { flying = Skill_EoV(),  running = Skill_100(),   special = MS.None    };
	gv.rgDMS[MS.Skill_EoV_150] = { flying = Skill_EoV(),  running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Skill_310_60]  = { flying = Skill_310(),  running = Skill_100(),   special = MS.None    };
	gv.rgDMS[MS.Skill_280_60]  = { flying = Skill_280(),  running = Skill_100(),   special = MS.None    };
	gv.rgDMS[MS.Skill_310_150] = { flying = Skill_310(),  running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Skill_280_150] = { flying = Skill_280(),  running = MS.None,       special = MS.None    };
	gv.rgDMS[MS.Skill_100_60]  = { flying = MS.None,      running = Skill_100(),   special = MS.None    };
end


function Pokedex:GetMountType(idSpell)
	if (not gc.rgMountAttributes[idSpell]) then
		return Pokedex:GetMountTypeFromTooltip(idSpell);
	end

	return gc.rgMountAttributes[idSpell].speed;
end

function Pokedex:GetMountTypeFromTooltip(idSpell)
	if (0 == idSpell) then 
		self:Print("ERROR - GetMountTypeFromTooltip: bad param");
		return MS.None;
	end

	local fExtremelyFast, fVeryFast, fSlow, fRidingSkill, fFlyerOnly, fLocation, fRideable;

	PokedexScanningTooltip:ClearLines();
	PokedexScanningTooltip:SetHyperlink("spell:" .. idSpell);

	for iLines=1,PokedexScanningTooltip:NumLines() do
		local TipTextObject = getglobal("PokedexScanningTooltipTextLeft" .. iLines);
		local strText = TipTextObject:GetText();
		-- if (DC.MOUNTS >= DL.AV) then self:Print(strText); end

		-- these strings indicate diferent speed types
		if (strfind(strText, L["extremely fast"])) then 
			fExtremelyFast = true;
		elseif (strfind(strText, L["very fast"])) then 
			fVeryFast = true;
		elseif (strfind(strText, L["slow"])) then 
			fSlow = true;
		elseif (strfind(strText, L["Riding skill"])) then 
			fRidingSkill = true;
		end

		-- these strings indicate which areas a mount can be used in
		fLocation = strfind(strText, L["location"]);
		fFlyerOnly = strfind(strText, L["only"]) and 
		             strfind(strText, BZ["Outland"]) and
		             strfind(strText, BZ["Northrend"]);

		-- ride (also in the form of rideable) and mount are last resorts 
		-- to try to confirm that an item in the tooltip is even a mount
		fMount = strfind(strText, L["ride"]) or 
		         strfind(strText, L["rideable"]) or 
		         strfind(strText, L["mount"]);
	end

	if (fRidingSkill) then
		if (fLocation) then 
			-- "This mount changes depending on your Riding skill and location." 
			-- mounts like Big Love Rocket and Celestial Steed
			return MS.Skill_310_60;
		elseif (fFlyerOnly) then
			-- "This mount can only be summoned in Outland or Northrend. This 
			-- mount changes speed depending on your Riding skill."
			-- mounts like Winged Steed of the Ebon Blade
			return MS.Skill_280_150;
		else
			-- "This mount changes depending on your Riding skill."
			-- mounts like the Big Blizzard Bear
			return MS.Skill_100_60;
		end
	end


	if (fFlyerOnly) then
		if (fExtremelyFast) then 
			return MS.Flyer310;
		elseif (fVeryFast) then 
			return MS.Flyer280;
		elseif (fMount)then
			return MS.Flyer150;
		end
	else
		if (fVeryFast) then 
			return MS.Runner100;
		elseif (fSlow) then
			return MS.Runner0;
		elseif (fMount) then
			return MS.Runner60;
		end
	end

	return MS.Unknown; 
end


--=========================================================================--
--=========================================================================--
--
-- COMPANION FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:ToggleCompanion()
	if (self:GetCurrentCompanion() == 0) then
		self:SummonCompanion();
	else
		DismissCompanion("CRITTER");
	end
end

function Pokedex:SummonCompanion(fNext)
	local iCurPet = self:GetCurrentCompanion();

	if (iCurPet ~= 0) then
		local _, duration = GetCompanionCooldown("CRITTER", iCurPet)
		if (duration ~= 0) then
			if (DC.PETS >= DL.EXCEP) then self:Print("in cooldown, ignore this summons attempt"); end
			return
		end
	end

	local fHasSnowballs = (GetItemCount(gc.idItemSnowball) > 0);
	local rgiFiltered = {};
	local cTotalRanks = 0;
	local fSkippedCur = false;
	local fSkippedHot = false;

	--=====================================================================--
	-- FilterCompanions -- Local function that builds list of pets elligible
	-- for summoning as well as providing a sum of the ranks of those pets.
	-- Best done as seperate function to support different ways of calling,
	-- next pet versus random pet, and as local function we can reference 
	-- and modify variables in the scope of the calling function.
	-- NOTE: appends to rgiFiltered, so multiple calls can build bigger list
	--=====================================================================--
	local function FilterCompanions(iStart, iEnd, fFirstOnly)
		if (iStart == 0 or iStart > iEnd) then
			if (DC.PETS >= DL.EXCEP) then self:Print("invalid search range"); end
			return;
		end 

		if (DC.PETS >= DL.EXCEP) then self:Print("building list of eligible pets ..."); end
		for iCompanion = iStart, iEnd, 1 do
			-- if its ranked as 0, then it gets skipped
			if (self.db.profile.rgCompanionInfo[iCompanion].rank == 0) then
				if (DC.PETS >= DL.EXCEP) then self:Printf("companion %i %s skipped for having rank of 0", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
			else
				-- if we don't have snowballs and this pet requires one, then it is skipped
				if (not fHasSnowballs and gc.rgNeedsSnowball[self.db.profile.rgCompanionInfo[iCompanion].id]) then
					if (DC.PETS >= DL.EXCEP) then self:Printf("companion %i %s skipped for lack of snowballs", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
				else
					-- if its the current companion, then it is skipped
					if (iCompanion == iCurPet) then
						if (DC.PETS >= DL.EXCEP) then self:Printf("companion %i %s skipped for being current companion", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
						fSkippedCur = true;
					else
						if (fFirstOnly) then
							-- if looking for first good value, then this is it
							rgiFiltered[#rgiFiltered + 1] = iCompanion;
							cTotalRanks = cTotalRanks + self.db.profile.rgCompanionInfo[iCompanion].rank;
							if (DC.PETS >= DL.BASIC) then self:Printf("companion %i %s is Next eligible pet", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
							return;
						-- if hot pet and hotness is enabled then don't add to list, it will be handled seperately
						elseif (self.db.profile.fEnableHotness and iCompanion == gv.iHotCompanion) then
							if (DC.PETS >= DL.EXCEP) then self:Printf("companion %i %s skipped for being hot companion", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
							fSkippedHot = true;
						-- else its put into the pool of summonables
						else
							rgiFiltered[#rgiFiltered + 1] = iCompanion;
							cTotalRanks = cTotalRanks + self.db.profile.rgCompanionInfo[iCompanion].rank;
							if (DC.PETS >= DL.AV) then self:Printf("companion %i %s added to list of summonable pets with a rank of %i. Total rank count is %i", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name, self.db.profile.rgCompanionInfo[iCompanion].rank, cTotalRanks); end
						end
					end
				end
			end
		end

		if (DC.PETS >= DL.BASIC) then self:Printf("list built: %i pets with a total rank of %i", #rgiFiltered, cTotalRanks); end
	end
	--=====================================================================--
	-- end of local function FilterCompanions
	-- resumption of parent function SummonCompanion
	--=====================================================================--

	-- generate filtered list of elligible pets and total ranks for list
	if (fNext and iCurPet ~= 0) then
		-- We can optimize our search in this case by starting immediately after current
		FilterCompanions(iCurPet+1, #self.db.profile.rgCompanionInfo, true);

		-- if none were found in that portion of the list, then start new search from the front of the list
		if (cTotalRanks == 0) then FilterCompanions(1, iCurPet, true); end
	else
		FilterCompanions(1, #self.db.profile.rgCompanionInfo, fNext);
	end


	-- if we skipped the hot pet while building a list, nows the time for its heat check
	if (fSkippedHot) then
		local iHeatCheck = math.random(1,100);
		if (self.db.profile.iHotCompanionPref >= iHeatCheck) then
			if (DC.PETS >= DL.BASIC) then self:Printf("companion %i %s passed heat check (rolled %i, needed %i or less) and will be summoned", gv.iHotCompanion, self.db.profile.rgCompanionInfo[gv.iHotCompanion].name, iHeatCheck, self.db.profile.iHotCompanionPref); end
			self:SummonPet("CRITTER", gv.iHotCompanion, fNext);
			return;
		end

		if (DC.PETS >= DL.BASIC) then self:Printf("companion %i %s skipped for failing heat check (rolled %i, needed %i or less) as hot pet", gv.iHotCompanion, self.db.profile.rgCompanionInfo[gv.iHotCompanion].name, iHeatCheck, self.db.profile.iHotCompanionPref); end
	end

	-- selection returned 0 pets to choose from	
	if (#rgiFiltered == 0 or cTotalRanks == 0) then 
		-- both values should be in sync
		if (#rgiFiltered ~= cTotalRanks) then self:Print(L["ERROR: only one of #rgiFiltered and cTotalRanks was zero"]); end

		if (fSkippedHot) then
			if (DC.PETS >= DL.BASIC) then self:Printf("hot companion %i %s failed heat check but is apparently only one summonable", gv.iHotCompanion, self.db.profile.rgCompanionInfo[gv.iHotCompanion].name); end
			self:SummonPet("CRITTER", gv.iHotCompanion, fNext);
			return
		end

		if (fSkippedCur) then
			if (DC.PETS >= DL.BASIC) then self:Printf("current companion %i %s is apparently only one summonable; doing nothing", iCurPet, self.db.profile.rgCompanionInfo[iCurPet].name); end
			return; -- only summonable pet is already summoned
		end

		self:Print(L["ERROR: You have no summonable companions."]);
		return;
	end


	-- only one pet to choose from
	if (#rgiFiltered == 1) then
		if (DC.PETS >= DL.BASIC) then self:Printf("companion %i %s is apparently only one summonable", rgiFiltered[1], self.db.profile.rgCompanionInfo[rgiFiltered[1]].name); end
		self:SummonPet("CRITTER", rgiFiltered[1], fNext);
		return;
	end

	-- multiple pets
	local cRank = math.random(1,cTotalRanks);
	if (DC.PETS >= DL.BASIC) then self:Printf("random roll from 1 to %i produced %i", cTotalRanks, cRank); end

	for _, iNew in ipairs(rgiFiltered) do
		cRank = cRank - self.db.profile.rgCompanionInfo[iNew].rank;
		if (DC.PETS >= DL.AV) then self:Printf("companion %i %s's rank of %i brings total down to %i", iNew, self.db.profile.rgCompanionInfo[iNew].name, self.db.profile.rgCompanionInfo[iNew].rank, cRank); end
		if (cRank <= 0) then -- found our slot
			self:SummonPet("CRITTER", iNew, fNext);
			return;
		end  
	end

	if (cRanks > 0) then self:Print(L["ERROR: selection error"]); end
end


-- Hooking CallCompanion and DismissCompanion should ensure that we'll usually
-- know what the current state is.
-- TODO: find out if trying to cast spell by ID can summon dismiss pets bypassing these checks
-- TODO: find if there's a way in lua I could scope this variable better.
-- TODO: persist last companion across sessions so that Next starts where you left off
local gr_iLastCompanionSeen = 0;

function Pokedex:SetCurrentCompanion(iCompanion)
	if (DC.PETS >= DL.BASIC) then self:Printf("Current companion set to: %i %s", iCompanion, self.db.profile.rgCompanionInfo[iCompanion].name); end
	gr_iLastCompanionSeen = iCompanion;
	self:SetCompanionForRanking(gr_iLastCompanionSeen);
end

function Pokedex:GetCurrentCompanion()
	if (gr_iLastCompanionSeen ~= 0) then
		local _, _, _, _, fActive = GetCompanionInfo("CRITTER", gr_iLastCompanionSeen);
		if (not fActive) then 
			gr_iLastCompanionSeen = 0; -- might not have an active companion 
		end 
	end

	if (gr_iLastCompanionSeen == 0) then
		for index = 1, GetNumCompanions("CRITTER"), 1 do
			local _, _, _, _, fActive = GetCompanionInfo("CRITTER", index);
			if (fActive) then 
				gr_iLastCompanionSeen = index;
				break;
			end
		end
	end

	self:SetCompanionForRanking(gr_iLastCompanionSeen);
	return gr_iLastCompanionSeen;
end


function Pokedex:SetCompanionForRanking(iCompanion) 
	if (iCompanion ~= 0) then
		gv.iCompanionForRanking = iCompanion;
	elseif (#gv.rgstrCompanionNames ~= 0) then
		gv.iCompanionForRanking = 1;
	else
		gv.iCompanionForRanking = 0;
	end
end


function Pokedex:FUpdateCompanionInfo()
	gv.rgstrCompanionNames = {};
	gv.iCompanionForRanking = 0;
	gv.rgstrHotCompanionNames = { [0] = L["no hot companion"] };
	gv.iHotCompanion = 0;

	-- assumption is that order doesn't change except for insertions of new pets
	-- so we can speed up searching saved data for rankings by starting the search 
	-- at a predicted index
	local iMatch = 1;
	local iNewPet = 0;
	local rgNew = { [0] = { name = "NONE", id = 0, rank = gc.iDefaultRank } };

	for index = 1, GetNumCompanions("CRITTER"), 1 do
		local _, _, idSpell, _, fActive = GetCompanionInfo("CRITTER", index);
		local strPetName = GetSpellInfo(idSpell);
		if (strPetName == nil) then
			if (gv.InitState == IS.UNINITIALIZED) then
				if (DC.MISC >= DL.BASIC) then self:Print("unable to initialize, missing companion names"); end
			else
				self:Print(L["ERROR: companion name not available"]);
			end
			return false;
		end

		local fMatchMade, iRank = self:GetCompanionRankFromSavedData(iMatch, idSpell);

		if (fMatchMade) then 
			iMatch = iMatch + 1;
		elseif (not self.db.profile.fFirstBoot) then
			self:Printf(L["New companion added: %s"], strPetName);
			iNewPet = index;
			if (self.db.profile.fEnableHotness and self.db.profile.fNewHotness) then
				self.db.profile.idHotCompanion = idSpell;
			end
		end

		if (fActive) then gv.iCompanionForRanking = index; end
		if (idSpell == self.db.profile.idHotCompanion) then gv.iHotCompanion = index; end
		if (idSpell == gc.idSpellArgentSquire or idSpell == gc.idSpellArgentGruntling) then 
			gv.iArgentSquire = index;
		end

		gv.rgstrCompanionNames[index] = strPetName;
		gv.rgstrHotCompanionNames[index] = strPetName;
		rgNew[index] = { name = strPetName, id = idSpell, rank = iRank };
	end

	-- now that we've read everything in, blow away old saved ranking with new list
	self.db.profile.rgCompanionInfo = rgNew;

	-- if they have no pets, then we need to make some text available for the drop down
	if (#gv.rgstrCompanionNames == 0) then
		gv.rgstrCompanionNames = { [0] = L["no companions available"] };
	end

	-- gv.iCompanionForRanking will be either 0 from when we inited, or was set
	-- when we found an active pet. Calling SetCurrentCompanion ensures our 
	-- cached value for last active pet is correct, as well as correctly 
	-- tweaking the selected drop down item for the no active pet case.
	-- A brand new pet, though, will trump the active pet for selection.
	self:SetCurrentCompanion(gv.iCompanionForRanking);
	if (iNewPet ~= 0) then self:SetCompanionForRanking(iNewPet); end

	return true;
end


-- return values - fMatchMade, iRank
function Pokedex:GetCompanionRankFromSavedData(iStart, iID)
	local cLimit = #self.db.profile.rgCompanionInfo;

	if (iStart <= cLimit) then
		for index = iStart, cLimit, 1 do
			if (self.db.profile.rgCompanionInfo[index].id == iID) then
				return true, self.db.profile.rgCompanionInfo[index].rank;
			end
		end
		
		for index = 1, iStart - 1, 1 do
			if (self.db.profile.rgCompanionInfo[index].id == iID) then
				return true, self.db.profile.rgCompanionInfo[index].rank;
			end
		end
	end

	return false, gc.iDefaultRank;
end


--=========================================================================--
--=========================================================================--
--
-- TITLE FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:ChangeTitle()
	local iCurTitle = gv.rgTitleMap[self:GetCurrentTitle()];

	local rgiFiltered = {};
	local cTotalRanks = 0;
	local fSkippedCur = false;
	local fSkippedHot = false;

	-- Builds list of elligible titles for change. For mounts and pets, this
	-- is a local function; but we have no plans for NextTitle option or any
	-- other scenarios where we have to make multiple passes at the data.
	if (DC.TITLES >= DL.EXCEP) then self:Print("building list of eligible titles ..."); end
	for iTitle = 1, #self.db.profile.rgTitleInfo, 1 do
		-- if its ranked as 0, then it gets skipped
		if (self.db.profile.rgTitleInfo[iTitle].rank == 0) then
			if (DC.TITLES >= DL.EXCEP) then self:Printf("title %i %s skipped for having rank of 0", iTitle, self.db.profile.rgTitleInfo[iTitle].name); end
		else
			-- if its the current title, then it is skipped
			if (iTitle == iCurTitle) then
				if (DC.TITLES >= DL.EXCEP) then self:Printf("title %i %s skipped for being current title", iTitle, self.db.profile.rgTitleInfo[iTitle].name); end
				fSkippedCur = true;
			else
				-- if hot title and hotness is enabled then don't add to list, it will be handled seperately
				if (self.db.profile.fEnableHotness and iTitle == gv.iHotTitle) then
					if (DC.TITLES >= DL.EXCEP) then self:Printf("title %i %s skipped for being hot title", iTitle, self.db.profile.rgTitleInfo[iTitle].name); end
					fSkippedHot = true;
				-- else its put into the pool of summonables
				else
					rgiFiltered[#rgiFiltered + 1] = iTitle;
					cTotalRanks = cTotalRanks + self.db.profile.rgTitleInfo[iTitle].rank;
					if (DC.TITLES >= DL.AV) then self:Printf("title %i %s added to list of possible titles with a rank of %i. Total rank count is %i", iTitle, self.db.profile.rgTitleInfo[iTitle].name, self.db.profile.rgTitleInfo[iTitle].rank, cTotalRanks); end
				end
			end
		end
	end

	if (DC.TITLES >= DL.BASIC) then self:Printf("list built: %i titles with a total rank of %i", #rgiFiltered, cTotalRanks); end


	-- if we skipped the hot title while building a list, nows the time for its heat check
	if (fSkippedHot) then
		local iHeatCheck = math.random(1,100);
		if (self.db.profile.iHotTitlePref >= iHeatCheck) then
			if (DC.PETS >= DL.BASIC) then self:Printf("hot title %i %s passed heat check (rolled %i, needed %i or less) and will be selected", gv.iHotTitle, self.db.profile.rgTitleInfo[gv.iHotTitle].name, iHeatCheck, self.db.profile.iHotTitlePref); end
			SetCurrentTitle(self.db.profile.idHotTitle);
			return;
		end

		if (DC.PETS >= DL.BASIC) then self:Printf("hot title %i %s failed heat check (rolled %i, needed %i or less) and will not be selected", gv.iHotTitle, self.db.profile.rgTitleInfo[gv.iHotTitle].name, iHeatCheck, self.db.profile.iHotTitlePref); end
	end

	-- selection returned 0 titles to choose from	
	if (#rgiFiltered == 0 or cTotalRanks == 0) then 
		-- both values should be in sync
		if (#rgiFiltered ~= cTotalRanks) then self:Print(L["ERROR: only one of #rgiFiltered and cTotalRanks was zero"]); end

		if (fSkippedHot) then
			if (DC.PETS >= DL.BASIC) then self:Printf("hot title %i %s failed heat check but is only eligible title", gv.iHotTitle, self.db.profile.rgTitleInfo[gv.iHotTitle].name); end
			SetCurrentTitle(self.db.profile.idHotTitle);
			return
		end

		if (fSkippedCur) then
			if (DC.PETS >= DL.BASIC) then self:Printf("current title %i %s is only one eligible; doing nothing", iCurTitle, self.db.profile.rgTitleInfo[iCurTitle].name); end
			return; -- only summonable title is already summoned
		end

		self:Print(L["ERROR: You don't have any titles."]);
		return;
	end

	
	-- only one title to choose from
	if (#rgiFiltered == 1) then
		if (DC.PETS >= DL.BASIC) then self:Printf("title %i %s is apparently only one summonable", rgiFiltered[1], self.db.profile.rgTitleInfo[rgiFiltered[1]].name); end
		SetCurrentTitle(self.db.profile.rgTitleInfo[rgiFiltered[1]].id);
		return;
	end

	-- multiple titles
	local cRank = math.random(1,cTotalRanks);
	if (DC.PETS >= DL.BASIC) then self:Printf("random roll from 1 to %i produced %i", cTotalRanks, cRank); end

	for _, iNew in ipairs(rgiFiltered) do
		cRank = cRank - self.db.profile.rgTitleInfo[iNew].rank;
		if (DC.PETS >= DL.AV) then self:Printf("title %i %s's rank of %i brings total down to %i", iNew, self.db.profile.rgTitleInfo[iNew].name, self.db.profile.rgTitleInfo[iNew].rank, cRank); end
		if (cRank <= 0) then -- found our slot
			SetCurrentTitle(self.db.profile.rgTitleInfo[iNew].id);
			return;
		end
	end

	if (cRanks > 0) then self:Print(L["ERROR: selection error"]); end
end


function Pokedex:SetCurrentTitleHook(idTitle)
	if (idTitle < 1) then
		if (DC.TITLES >= DL.BASIC) then self:Printf("No title currently showing"); end
	else
		if (DC.TITLES >= DL.BASIC) then self:Printf("Current title set to: %i %s", idTitle, strtrim(GetTitleName(idTitle))); end
	end
	gv.iTitleForRanking = gv.rgTitleMap[idTitle];
end

-- return first the title ID and then the sorted order index
function Pokedex:GetCurrentTitle()
	local idTitle = GetCurrentTitle();
	gv.iTitleForRanking = gv.rgTitleMap[idTitle];

	return idTitle, gv.iTitleForRanking;
end

function Pokedex:KNOWN_TITLES_UPDATE()
	if (DC.TITLES >= DL.BASIC) then self:Print("KNOWN_TITLES_UPDATE"); end
	self:FUpdateTitleInfo();
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
end

function Pokedex:NEW_TITLE_EARNED(...)
	if (DC.TITLES >= DL.BASIC) then self:Printf("NTE  %s", self:StrFromVarArg(nil, ...)); end
	self:FUpdateTitleInfo();
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
end

function Pokedex:OLD_TITLE_LOST(...)
	if (DC.TITLES >= DL.BASIC) then self:Printf("OTL  %s", self:StrFromVarArg(nil, ...)); end
	self:FUpdateTitleInfo();
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
end

function Pokedex:FUpdateTitleInfo()
	gv.rgstrTitleNames = {};
	gv.iTitleForRanking = 0;
	gv.rgstrHotTitleNames = { [0] = L["no hot title"] };
	gv.iHotTitle = 0;
	gv.rgTitleMap = {};

	local rgNew = {};
	local iNewTitle = 0;

	local cTitlesKnown = 0;
	for idTitle = 1, GetNumTitles(), 1 do
		if (1 == IsTitleKnown(idTitle)) then
			cTitlesKnown = cTitlesKnown + 1;

			local strTitleName = GetTitleName(idTitle);
			if (strTitleName == nil) then
				if (gv.InitState == IS.UNINITIALIZED) then
					if (DC.MISC >= DL.BASIC) then self:Print("unable to initialize, missing title names"); end
				else
					self:Print(L["ERROR: title name not available"]);
				end
				return false;
			end

			rgNew[cTitlesKnown] = { name = strtrim(strTitleName), id = idTitle, rank = gc.iDefaultRank };
		end
	end
	
	-- if there are no titles known
	if (#rgNew == 0) then
		-- dummy entry holding default rank in empty case
		rgNew[0] = { name = "NONE", id = 0, rank = gc.iDefaultRank };
		gv.rgstrTitleNames[0] = L["no titles available"];

	-- otherwise sort the titles, get saved rank values and get index for hot and current titles
	else
		-- sort this table by name to get a nice drop down order
		sort(rgNew, function(a,b) return (a.name < b.name) end);
		if (DC.TITLES >= DL.AV) then self:Print("Updating Titles ..."); end

		-- Now that we're sorted, lets get our saved rank values. Assumption is that 
		-- order doesn't change except for insertions of new titles so we can speed up 
		-- searching saved data for rankings by starting the search at a predicted index
		-- We'll also take advantage of this iteration through to set our drop down lists.
		local iMatch = 1;
		for index = 1, #rgNew, 1 do
			local fMatchMade, iRank = self:GetTitleRankFromSavedData(iMatch, rgNew[index].id);

			-- hack to work around matron/patron swaps, if match 
			-- didn't happen then try again with the other title ID
			if (not fMatchMade) then
				if (rgNew[index].id == gc.idTitleMatron) then
					fMatchMade, iRank = self:GetTitleRankFromSavedData(iMatch, gc.idTitlePatron);
				elseif (rgNew[index].id == gc.idTitlePatron) then
					fMatchMade, iRank = self:GetTitleRankFromSavedData(iMatch, gc.idTitleMatron);
				end
			end

			if (fMatchMade) then
				rgNew[index].rank = iRank;
				iMatch = iMatch + 1;
			elseif (not self.db.profile.fFirstBoot) then
				self:Printf(L["New title added: %s"], rgNew[index].name)
				gv.iTitleForRanking = index;
				if (self.db.profile.fEnableHotness and self.db.profile.fNewHotness) then
					self.db.profile.idHotTitle = rgNew[index].id;
				end
			end

			if (DC.TITLES >= DL.AV) then self:Printf("index: %i  name: %s  id: %i  rank %i", index, rgNew[index].name, rgNew[index].id, rgNew[index].rank); end
			
			-- save index of hot pet
			if (self.db.profile.idHotTitle == rgNew[index].id) then 
				gv.iHotTitle = index; 
			end

			gv.rgstrTitleNames[index] = rgNew[index].name;
			gv.rgstrHotTitleNames[index] = rgNew[index].name;
		end

		rgNew[0] = { name = L["None"], id = -1, rank = 0 };
		gv.rgstrTitleNames[0] = L["None"];
	end

	-- dummy entry holding default rank in empty case
	-- rgNew[0] = { name = "NONE", id = 0, rank = gc.iDefaultRank };

	-- build a table for reverse lookups, to go from title id to sorted order index
	for key, value in pairs(rgNew) do
		gv.rgTitleMap[value.id] = key;
	end

	-- now that the map is set, we can properly init gv.iTitleForRanking if
	-- we haven't already pointed it at a newly acquired title
	if (gv.iTitleForRanking == 0) then self:GetCurrentTitle(); end

	-- now that we've read everything in, blow away old saved ranking with new list
	self.db.profile.rgTitleInfo = rgNew;

	return true;
end


function Pokedex:GetTitleRankFromSavedData(iStart, idTitle)
	local cLimit = #self.db.profile.rgTitleInfo
	local index

	if (iStart <= cLimit) then
		for index = iStart, cLimit, 1 do
			if (self.db.profile.rgTitleInfo[index].id == idTitle) then
				return true, self.db.profile.rgTitleInfo[index].rank
			end
		end

		for index = 1, iStart - 1, 1 do
			if (self.db.profile.rgTitleInfo[index].id == idTitle) then
				return true, self.db.profile.rgTitleInfo[index].rank
			end
		end
	end

	return false, gc.iDefaultRank
end


--=========================================================================--
--=========================================================================--
--
-- AUTO-DISMOUNT FUNCTIONS
--
--=========================================================================--
--=========================================================================--

function Pokedex:CVAR_UPDATE(_, glstr, ...)
	if (DC.DISMOUNT >= DL.EXCEP) then self:Printf("CVAR_UPDATE EVENT:  %s %s", tostring(glstr), self:StrFromVarArg(nil, ...)); end
	if (glstr == L["AUTO_DISMOUNT_FLYING_TEXT"]) then
		self:UpdateDismountSettings();
	end
end


function Pokedex:SetManageAutoDismount(info, value)
	if (gv.iAutoDismountFlying == 1 and value) then
		if (DC.DISMOUNT >= DL.EXCEP) then self:Print("Safe Dismount enabled, disabling Auto Dismount in Flight accordingly."); end
		gv.iAutoDismountFlying = 0;
		SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
	end

	Pokedex.db.profile.fManageAutoDismount = value;
end


function Pokedex:UpdateDismountSettings()
	if (GetCVarBool("autoDismountFlying")) then 
		-- even though we may be reseting it back to 0, our internal state should match reality
		gv.iAutoDismountFlying = 1;

		if (self.db.profile.fManageAutoDismount) then
			if (DC.DISMOUNT >= DL.EXCEP) then self:Print("Safe Dismount is reverting someones change to the Auto Dismount in Flight setting."); end
			SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
		end
	else
		gv.iAutoDismountFlying = 0;
	end
	LibStub("AceConfigRegistry-3.0"):NotifyChange("Pokedex");
end


function Pokedex:MainTooltipShow(...)
	-- if we have gathering skills and the feature is turned on
	-- if we're not currently flying then we don't have to worry about monkeying with the setting at all
	if (self.db.profile.fManageAutoDismount and Pokedex.db.profile.fDismountForGathering and IsFlying()) then
		-- if dismount was turned on for a different condition, tooltip scraping will only cause errors
		if ((not self.db.profile.fDismountForCombat or not gv.fCanDismountForCombat) and
		    (not self.db.profile.fDismountForAttack or not gv.fCanDismountForAttack)) then

			local fGatherable = false;
			for i=1,GameTooltip:NumLines() do
				local mytext = getglobal("GameTooltipTextLeft" .. i);
				local text = mytext:GetText();
				fGatherable = (gv.fMiner     and strfind(text, L["Requires"]) and strfind(text, L["Mining"])) or
				              (gv.fHerbalist and strfind(text, L["Requires"]) and strfind(text, L["Herbalism"])) or
				              (gv.fSkinner   and strfind(text, L["Skinnable"]));
			end

			if (fGatherable and gv.iAutoDismountFlying == 0) then
				if (DC.DISMOUNT >= DL.BASIC) then self:Print("turning on dismount, mousing over gatherable"); end
				gv.iAutoDismountFlying = 1;
				SetCVar("autoDismountFlying", 1); --, "AUTO_DISMOUNT_FLYING_TEXT")
			elseif (fGatherable and gv.iAutoDismountFlying == 1) then
				if (DC.DISMOUNT >= DL.EXCEP) then self:Print("WEIRD - new show, but can already dismount"); end
			elseif (not fGatherable and gv.iAutoDismountFlying == 1) then
				if (DC.DISMOUNT >= DL.BASIC) then self:Print("ERROR - can dismount, but tooltip doesn't match"); end
				gv.iAutoDismountFlying = 0;
				SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
			end
		end
	end
end


function Pokedex:MainTooltipHide(...)
	-- we only care if gathering feature is turned on
	if (self.db.profile.fManageAutoDismount and Pokedex.db.profile.fDismountForGathering) then
		-- if dismount is already off, we don't have to do anything
		if (gv.iAutoDismountFlying == 1) then
			-- if dismount was turned on for a different condition, tooltip scraping will only cause errors
			if ((not self.db.profile.fDismountForCombat or not gv.fCanDismountForCombat) and
			    (not self.db.profile.fDismountForAttack or not gv.fCanDismountForAttack)) then
				if (DC.DISMOUNT >= DL.BASIC) then self:Print("dismount turned off, not mousing over gatherable"); end
				gv.iAutoDismountFlying = 0;
				SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
			end
		end
	end	
end


function Pokedex:PLAYER_TARGET_CHANGED()
	-- if feature is turned on
	if (self.db.profile.fManageAutoDismount and self.db.profile.fDismountForAttack) then
		-- if we had an attackable target
		if (gv.fCanDismountForAttack) then
			-- then only need to change if we lost one
			if (not UnitCanAttack("player", "target") or UnitIsDead("target")) then
				gv.fCanDismountForAttack = false;

				-- if in combat, don't clear based on target
				if (not self.db.profile.fDismountForCombat or not gv.fCanDismountForCombat) then
					if (DC.DISMOUNT >= DL.BASIC) then self:Print("dismount turned off, target not attackable"); end
					gv.iAutoDismountFlying = 0;
					SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
				end
			end
		-- if not already tracking, then don't start unless we're mounted - hopeful optimization for instances
		elseif (IsMounted()) then
			-- if we have an attackable target
			if (UnitCanAttack("player", "target") and not UnitIsDead("target")) then
				gv.fCanDismountForAttack = true;
				
				-- don't need to set if already done for being in combat
				if (not self.db.profile.fDismountForCombat or not gv.fCanDismountForCombat) then
					if (DC.DISMOUNT >= DL.BASIC) then self:Print("turning on dismount, attackable target"); end
					gv.iAutoDismountFlying = 1;
					SetCVar("autoDismountFlying", 1); --, "AUTO_DISMOUNT_FLYING_TEXT")
				end
			end
		end
	end
end


function Pokedex:PLAYER_REGEN_DISABLED()
	-- if feature is turned on
	-- if we're not currently mounted then we don't have to worry about monkeying with the setting at all
	if (self.db.profile.fManageAutoDismount and self.db.profile.fDismountForCombat and IsMounted()) then
		gv.fCanDismountForCombat = true;

		if (gv.iAutoDismountFlying == 0) then
			if (DC.DISMOUNT >= DL.BASIC) then self:Print("turning on dismount, in combat"); end
			gv.iAutoDismountFlying = 1;
			SetCVar("autoDismountFlying", 1); --, "AUTO_DISMOUNT_FLYING_TEXT")
		end
	end
end


function Pokedex:PLAYER_REGEN_ENABLED()
	-- if feature is turned on
	if (self.db.profile.fManageAutoDismount and self.db.profile.fDismountForCombat) then
		-- out of combat, so this will no longer be the reason why we can dismount
		gv.fCanDismountForCombat = false;

		-- if can dismount is already 0, then there's nothing left to change
		if (gv.iAutoDismountFlying == 1) then
			-- if dismount can occur for attackable target, don't clear for out of combat
			if (not self.db.profile.fDismountForAttack or not gv.fCanDismountForAttack) then
				if (DC.DISMOUNT >= DL.BASIC) then self:Print("dismount turned off, out of combat"); end
				gv.iAutoDismountFlying = 0;
				SetCVar("autoDismountFlying", 0); --, "AUTO_DISMOUNT_FLYING_TEXT")
			end
		end
	end	
end
