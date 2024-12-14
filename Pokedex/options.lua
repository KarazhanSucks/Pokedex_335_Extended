local Pokedex = Pokedex
local L = LibStub("AceLocale-3.0"):GetLocale("Pokedex")

local IS = Pokedex.Globals.Types.InitStates;     -- Initialization States
local SL = Pokedex.Globals.Types.SkillLevels;    -- minimum skill level to hold that rank of profession
local DL = Pokedex.Globals.Types.DebugLevels;    -- Debug Levels
local gc = Pokedex.Globals.Constants;
local gv = Pokedex.Globals.Variables;


-- saved settings and default values
local tblSavedSettings = {
	PokedexDB = {
		db = {},
		defaults = {
			global = {
				rgDebugInfo = { MISC     = 0,
								MOUNTS   = 0,
								PETS     = 0,
								TITLES   = 0,
								DISMOUNT = 0
				},
			},
			char = {
				idHotMount = 0,
				idHotCompanion = 0,
				idHotTitle = 0,
			},
			profile = {
				iDataFormat = 0,
				fFirstBoot = true,
				fManageAutoDismount = false,
				fDismountForGathering = false,
				fDismountForCombat = false,
				fDismountForAttack = false,
				fCombineAllFastMounts = false,
				fCombineFastAndSlowMounts = false,
				fAnnounce = true,
				iChannel = 1,
				fChangeTitleOnMount = false,
				fEnableHotness = true,
				fNewHotness = true,
				iHotMountPref = 50,
				iHotCompanionPref = 50,
				iHotTitlePref = 50,
				rgMountInfo = {},        -- { name, id, rank }
				rgCompanionInfo = {},    -- { name, id, rank }
				rgTitleInfo = {}         -- { name, id, rank }  -- index matches the index of the trimmed name after sorting
			},
		},
	},
}

function Pokedex.LoadSavedSettings()
	for setname, tables in pairs(tblSavedSettings) do
		tables.db = LibStub("AceDB-3.0"):New(setname, tables.defaults)
	end
	return tblSavedSettings.PokedexDB.db
end

-- As the addon develops and ages, there may be changes to the structure 
-- and contents of the saved data. This function migrates data between
-- data format versions to preserve the users settings.
function Pokedex:MigrateSavedData()
	local DC = self.db.global.rgDebugInfo;

	-- if already up to date, exit
	if (self.db.profile.iDataFormat == gv.iCurDataFormat) then
		return;
	end

	-- if its first boot, theres no data to migrate
	if (not self.db.profile.fFirstBoot) then

		-- rename of critter to companion
		if self.db.profile.iDataFormat < 1 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 1"); end

			if self.db.profile.idHotCritter ~= nil then
				self.db.profile.idHotCompanion = self.db.profile.idHotCritter;
				self.db.profile.idHotCritter = nil;
			end
			if self.db.profile.idHotCritterPref ~= nil then
				self.db.profile.iHotCompanionPref = self.db.profile.idHotCritterPref;
				self.db.profile.idHotCritterPref = nil;
			end
			if self.db.profile.rgCritterInfo ~= nil then
				self.db.profile.rgCompanionInfo = self.db.profile.rgCritterInfo;
				self.db.profile.rgCritterInfo = nil;
			end
		end

		-- change of how we characterize mount performance
		if self.db.profile.iDataFormat < 2 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 2"); end
			for index = 1, #self.db.profile.rgMountInfo, 1 do
				self.db.profile.rgMountInfo[index][4] = nil;
			end
		end

		-- we'll no longer try to change title on load, instead when mounting
		-- change to the way we save mount, companion and title info
		if self.db.profile.iDataFormat < 3 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 3"); end

			self.db.profile.fChangeTitleOnMount = self.db.profile.fChangeTitleOnLoad;
			self.db.profile.fChangeTitleOnLoad = nil;

			local rgNew;
			
			-- migrate mount info
			rgNew = {};
			for i = 1, #self.db.profile.rgMountInfo, 1 do
				rgNew[i] = { name = self.db.profile.rgMountInfo[i][1], 
				               id = self.db.profile.rgMountInfo[i][2],
				             rank = self.db.profile.rgMountInfo[i][3] };
			end
			self.db.profile.rgMountInfo = rgNew;

			-- migrate companion info
			rgNew = {};
			for i = 1, #self.db.profile.rgCompanionInfo, 1 do
				rgNew[i] = { name = self.db.profile.rgCompanionInfo[i][1],
				               id = self.db.profile.rgCompanionInfo[i][2],
				             rank = self.db.profile.rgCompanionInfo[i][3],
				         snowball = self.db.profile.rgCompanionInfo[i][4] };
			end
			self.db.profile.rgCompanionInfo = rgNew;

			-- migrate title info
			rgNew = {};
			for i = 1, #self.db.profile.rgTitleInfo, 1 do
				rgNew[i] = { name = self.db.profile.rgTitleInfo[i][1],
				               id = self.db.profile.rgTitleInfo[i][2],
				             rank = self.db.profile.rgTitleInfo[i][3] };
			end
			self.db.profile.rgTitleInfo = rgNew;
		end

		-- users should have right to choose to opt in to safe dismount code
		if self.db.profile.iDataFormat < 4 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 4"); end

			self.db.profile.fManageAutoDismount = false;
			self.db.profile.fDismountForGathering = false;
			self.db.profile.fDismountForCombat = false;
			self.db.profile.fDismountForAttack = false;
		end

		-- save spellId and spellName, not npcId and npcName
		if self.db.profile.iDataFormat < 5 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 5"); end
			local iMatch, rgNew

			iMatch, rgNew = 1, { [0] = { name = "NONE", id = 0, rank = gc.iDefaultRank } };
			for index = 1, GetNumCompanions("MOUNT"), 1 do
				local idMount, _, idSpell = GetCompanionInfo("MOUNT", index);
				local strMountName = GetSpellInfo(idSpell);
				local fMatchMade, iRank = self:GetMountRankFromSavedData(iMatch, idMount);
				if (fMatchMade) then iMatch = iMatch + 1; end
				rgNew[index] = { name = strMountName, id = idSpell, rank = iRank };
			end
			self.db.profile.rgMountInfo = rgNew;

			iMatch, rgNew = 1, { [0] = { name = "NONE", id = 0, rank = gc.iDefaultRank } };
			for index = 1, GetNumCompanions("CRITTER"), 1 do
				local idPet, _, idSpell = GetCompanionInfo("CRITTER", index);
				local strPetName = GetSpellInfo(idSpell);
				local fMatchMade, iRank = self:GetCompanionRankFromSavedData(iMatch, idPet);
				if (fMatchMade) then iMatch = iMatch + 1; end
				rgNew[index] = { name = strPetName, id = idSpell, rank = iRank };
			end
			self.db.profile.rgCompanionInfo = rgNew;
		end		

		-- debug level information changed structure and location
		if self.db.profile.iDataFormat < 6 then
			if (DC.MISC >= DL.BASIC) then self:Print("migrating to data format 6"); end
			if (self.db.profile.rgDebugInfo) then
				for k,v in pairs(self.db.profile.rgDebugInfo) do
					if (v.level > self.db.global.rgDebugInfo[k]) then
						self.db.global.rgDebugInfo[k] = v.level;
					end
				end
			end
			self.db.profile.rgDebugInfo = nil;
		end
			
	end

	self.db.profile.iDataFormat = gv.iCurDataFormat;
end


--=========================================================================--
-- Options UI definition
--=========================================================================--

function Pokedex.GetUIOptions()
	if (gv.InitState ~= IS.INITIALIZED and Pokedex:Initialize("GetUIOptions") == IS.UNINITIALIZED) then
		return {
			name = gv.strVersionedTitle,
			handler = Pokedex,
			type = 'group',
			childGroups = "tab",
			args = {
				CtrlInitError = {
					order = 1,
					type = "description",
					name = L["ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."],
				},
				Padding_InitError = {
					order = 2,
					type = "description",
					name = "",
				},
				CtrlRetryInit = {
					order = 3,
					type = "execute",
					name = L["retry initialization"],
					desc = L["retry initialization"],
					func = function() InterfaceOptionsFrame_OpenToCategory(Pokedex.optionsFrame); end,
				}
			}
		}
	end

	if (not Pokedex.options) then
		Pokedex.options = {
			name = gv.strVersionedTitle,
			handler = Pokedex,
			type = 'group',
			childGroups = "tab",
			args = {
				test = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["echoes out test info relevant to current feature in development"],
					desc = L["echoes out test info relevant to current feature in development"],
					func = function(info) Pokedex:EchoTest() end,
				},
				debug = {
					hidden = true,
					order = 0,
					type = "input",
					name = L["echoes out test info relevant to current feature in development"],
					desc = L["echoes out test info relevant to current feature in development"],
					get = function(info) return "" end,
					set = "SetDebug",
				},
				speed = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["echoes out current speed"],
					desc = L["echoes out current speed"],
					func = function(info) Pokedex:EchoSpeed() end,
				},
				zone = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["echoes out zone info"],
					desc = L["echoes out zone info"],
					func = function(info) Pokedex:EchoZone() end,
				},
				SuperToggle = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["toggle mount or companion"],
					desc = L["toggles mount or companion"],
					func = function(info) Pokedex:SuperToggle() end,
				},
				SummonMount = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon mount"],
					desc = L["summons a mount"],
					func = function(info) Pokedex:SummonMount(false, false) end,
				},
				sm = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon mount"],
					desc = L["summons a mount"],
					func = function(info) Pokedex:SummonMount(false, false) end,
				},
				DismissMount = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["dismiss mount"],
					desc = L["dismisses current mount"],
					func = function(info) Pokedex:DismissMount() end,
				},
				dm = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["dismiss mount"],
					desc = L["dismisses current mount"],
					func = function(info) Pokedex:DismissMount() end,
				},
				ToggleMount = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["toggle mount"],
					desc = L["toggles a mount"],
					func = function(info) Pokedex:ToggleMount() end,
				},
				tm = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["toggle mount"],
					desc = L["toggles a mount"],
					func = function(info) Pokedex:ToggleMount() end,
				},
				SummonNextMount = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon next mount"],
					desc = L["summons next mount in collection"],
					func = function(info) Pokedex:SummonMount(true, false) end,
				},
				snm = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon next mount"],
					desc = L["summons next mount in collection"],
					func = function(info) Pokedex:SummonMount(true, false) end,
				},
				SummonOtherMount = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon other mount"],
					desc = L["if summon mount would summon flyer, will summon ground mount and vice versa"],
					func = function(info) Pokedex:SummonMount(false, true) end,
				},
				som = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon other mount"],
					desc = L["if summon mount would summon flyer, will summon ground mount and vice versa"],
					func = function(info) Pokedex:SummonMount(false, true) end,
				},
				SummonCompanion = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon companion"],
					desc = L["summons a companion"],
					func = function(info) Pokedex:SummonCompanion(false) end,
				},
				sc = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon companion"],
					desc = L["summons a companion"],
					func = function(info) Pokedex:SummonCompanion(false) end,
				},
				DismissCompanion = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["dismiss companion"],
					desc = L["dismisses current companion"],
					func = function(info) DismissCompanion("CRITTER") end,
				},
				dc = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["dismiss companion"],
					desc = L["dismisses current companion"],
					func = function(info) DismissCompanion("CRITTER") end,
				},
				ToggleCompanion = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["toggle companion"],
					desc = L["toggles a companion"],
					func = function(info) Pokedex:ToggleCompanion() end,
				},
				tc = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["toggle companion"],
					desc = L["toggles a companion"],
					func = function(info) Pokedex:ToggleCompanion() end,
				},
				SummonNextCompanion = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon next companion"],
					desc = L["summons next companion in collection"],
					func = function(info) Pokedex:SummonCompanion(true) end,
				},
				snc = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon next companion"],
					desc = L["summons next companion in collection"],
					func = function(info) Pokedex:SummonCompanion(true) end,
				},
				vendor = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["summon vendor"],
					desc = L["summons a mount or companion with vendor capabilities"],
					func = function(info) Pokedex:SummonVendor() end,
				},
				ChangeTitle = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["change title"],
					desc = L["change title"],
					func = function() Pokedex:ChangeTitle() end,
				},
				ct = {
					hidden = true,
					order = 0,
					type = "execute",
					name = L["change title"],
					desc = L["change title"],
					func = function() Pokedex:ChangeTitle() end,
				},

				CtrlReadMe = {
					order = 5,
					type = "description",
					name = L["Please see the README.TXT file in the Pokedex addon folder for more information on how to use Pokedex"],
				},
				
				CtrlAnnounce = {
					order = 10,
					type = "toggle",
					name = L["announce"],
					desc = L["(on|off) let everyone know who *you* choose"],
					get = function(info) return Pokedex.db.profile.fAnnounce end,
					set = function(info, value) Pokedex.db.profile.fAnnounce = value end,
				},
				CtrlChannel = {
					order = 11,
					type = "select",
					name = L["channel"],
					desc = L["channel to announce selection in"],
					values = gc.rgstrChannelDescs,
					get = function(info) return Pokedex.db.profile.iChannel end,
					set = function(info, value) Pokedex.db.profile.iChannel = value end,
				},
				Padding_Announcements = {
					order = 12,
					type = "description",
					name = "",
				},
				CtrlEnableHotness = {
					order = 15,
					type = "toggle",
					name = L["enable hot pets"],
					desc = L["lets your turn on|off the hot pet subfeatures"],
					get = function(info) return Pokedex.db.profile.fEnableHotness end,
					set = function(info, value) Pokedex.db.profile.fEnableHotness = value end,
				},
				CtrlNewHotness = {
					order = 16,
					type = "toggle",
					name = L["new hotness"],
					desc = L["always make newest mount or companion the hot one"],
					disabled = function(info) return not Pokedex.db.profile.fEnableHotness end,
					get = function(info) return Pokedex.db.profile.fNewHotness end,
					set = function(info, value) Pokedex.db.profile.fNewHotness = value end,
				},
				Padding_Hotness = {
					order = 17,
					type = "description",
					name = "",
				},

				CtrlGroupMounts = {
					order = 20,
					name = L["Mounts"],
					handler = Pokedex,
					type = 'group',
					args = {
						CtrlSummonMount = {
							order = 1,
							type = "execute",
							name = L["summon mount"],
							desc = L["summons a mount"],
							func = function(info) Pokedex:SummonMount(false, false) end,
						},
						CtrlDismissMount = {
							order = 2,
							type = "execute",
							name = L["dismiss mount"],
							desc = L["dismisses current mount"],
							func = function(info) Pokedex:DismissMount() end,
						},
						Padding_MountButtons = {
							order = 3,
							type = "description",
							name = "",
						},
						CtrlMountTypes = {
							order = 5,
							type = "select",
							name = L["select mount type"],
							desc = L["select mount type"],
							values = function(info) return gv.rgstrMountTypes end,
							disabled = function(info) return (gv.iMountType == 0) end,
							get = function(info) return gv.iMountType end,
							set = function(info, value) 
								gv.iMountType = value 
								gv.iMountOfType = 1
							end,
						},
						Padding_MountTypes = {
							order = 6,
							type = "description",
							name = "",
						},
						CtrlMountsOfType = {
							order = 10,
							type = "select",
							name = L["select mount for ranking"],
							desc = L["mount whose rank you can set"],
							values = function(info) return gv.rgMountsByType[gv.iMountType].rgNames end,
							disabled = function(info) return (gv.iMountOfType == 0) end,
							get = function(info) return gv.iMountOfType end,
							set = function(info, value) gv.iMountOfType = value end,
						},
						CtrlRankingForMount = {
							order = 11,
							type = "range",
							name = L["mount rank"],
							desc = L["rank of current mount"],
							min = 0,
							max = 10,
							step = 1,
							disabled = function(info) return (gv.iMountType == 0 or gv.iMountOfType == 0) end,
							get = function(info) 
								local iMount = gv.rgMountsByType[gv.iMountType].rgIndices[gv.iMountOfType]
								return Pokedex.db.profile.rgMountInfo[iMount].rank
							end,
							set = function(info, value) 
								local iMount = gv.rgMountsByType[gv.iMountType].rgIndices[gv.iMountOfType]
								Pokedex.db.profile.rgMountInfo[iMount].rank = value
							end,
						},
						Padding_MountRankings = {
							order = 12,
							type = "description",
							name = "",
						},
						CtrlHotMount = {
							order = 15,
							type = "select",
							name = L["select hot mount"],
							desc = L["mount to become hot one"],
							values = function(info) return gv.rgstrHotMountNames end,
							disabled = function(info) return (not Pokedex.db.profile.fEnableHotness or #gv.rgstrHotMountNames == 0) end,
							get = function(info) return gv.iHotMount end,
							set = function(info, value) 
								gv.iHotMount = value
								Pokedex.db.profile.idHotMount = Pokedex.db.profile.rgMountInfo[value].id
							end,
						},
						CtrlMountHeat = {
							order = 16,
							type = "range",
							name = L["mount heat"],
							desc = L["set hotness as a percentage - 100% means the hot mount is the only one that will be chosen"],
							min = 0,
							max = 100,
							step = 5,
							disabled = function(info) return not Pokedex.db.profile.fEnableHotness end,
							get = function(info) return Pokedex.db.profile.iHotMountPref end,
							set = function(info, value) Pokedex.db.profile.iHotMountPref = value end,
						},
						Padding_HotMounts = {
							order = 17,
							type = "description",
							name = "",
						},
						
						CtrlCombineAllFastMounts = {
							order = 20,
							type = "toggle",
							name = L["style over substance"],
							desc = L["when summoning, combine extremely fast (310%) and very fast (280%) flying mounts into one group"],
							get = function(info) return Pokedex.db.profile.fCombineAllFastMounts end,
							set = function(info, value) 
								Pokedex.db.profile.fCombineAllFastMounts = value 
								Pokedex:FUpdateMountInfo()
							end,
						},
						CtrlCombineFastAndSlowMounts = {
							order = 21,
							type = "toggle",
							name = L["keeping it real (slow)"],
							desc = L["when summoning, combine fast and slow mounts into one group"],
							get = function(info) return Pokedex.db.profile.fCombineFastAndSlowMounts end,
							set = function(info, value) 
								Pokedex.db.profile.fCombineFastAndSlowMounts = value 
								Pokedex:FUpdateMountInfo()
							end,
						},
						Padding_CombineSpeeds = {
							order = 22,
							type = "description",
							name = "",
						},

					},
				},

				CtrlGroupCompanions = {
					order = 40,
					name = L["Companions"],
					handler = Pokedex,
					type = 'group',
					args = {
						CtrlSummonCompanion = {
							order = 1,
							type = "execute",
							name = L["summon companion"],
							desc = L["summons a companion"],
							func = function() Pokedex:SummonCompanion(false) end,
						},
						CtrlDismissCompanion = {
							order = 2,
							type = "execute",
							name = L["dismiss companion"],
							desc = L["dismisses current companion"],
							func = function() DismissCompanion("CRITTER") end,
						},
						Padding_CompanionButtons = {
							order = 3,
							type = "description",
							name = "",
						},
						CtrlCompanionForRanking = {
							order = 5,
							type = "select",
							name = L["select companion for ranking"],
							desc = L["companion whose rank you can set"],
							values = function(info) return gv.rgstrCompanionNames end,
							disabled = function(info) return (#gv.rgstrCompanionNames == 0) end,
							get = function(info) return gv.iCompanionForRanking end,
							set = function(info, value) gv.iCompanionForRanking = value end,
						},
						CtrlRankingForCompanion = {
							order = 6,
							type = "range",
							name = L["companion rank"],
							desc = L["rank of current companion"],
							min = 0,
							max = 10,
							step = 1,
							disabled = function(info) return (#gv.rgstrCompanionNames == 0) end,
							get = function(info) return Pokedex.db.profile.rgCompanionInfo[gv.iCompanionForRanking].rank end,
							set = function(info, value) Pokedex.db.profile.rgCompanionInfo[gv.iCompanionForRanking].rank = value end,
						},
						Padding_CompanionRankings = {
							order = 7,
							type = "description",
							name = "",
						},
						CtrlHotCompanion = {
							order = 10,
							type = "select",
							name = L["select hot companion"],
							desc = L["companion to become hot one"],
							values = function(info) return gv.rgstrHotCompanionNames end,
							disabled = function(info) return (not Pokedex.db.profile.fEnableHotness or #gv.rgstrHotCompanionNames == 0) end,
							get = function(info) return gv.iHotCompanion end,
							set = function(info, value)
								gv.iHotCompanion = value
								Pokedex.db.profile.idHotCompanion = Pokedex.db.profile.rgCompanionInfo[value].id
							end,
						},
						CtrlCompanionHeat = {
							order = 11,
							type = "range",
							name = L["companion heat"],
							desc = L["set hotness as a percentage - 100% means the hot pet is the only one that will be chosen"],
							min = 0,
							max = 100,
							step = 5,
							disabled = function(info) return not Pokedex.db.profile.fEnableHotness end,
							get = function(info) return Pokedex.db.profile.iHotCompanionPref end,
							set = function(info, value) Pokedex.db.profile.iHotCompanionPref = value end,
						},
						Padding_HotCompanions = {
							order = 12,
							type = "description",
							name = "",
						},
					},
				},

				CtrlGroupTitles = {
					order = 60,
					name = L["Titles"],
					handler = Pokedex,
					type = 'group',
					args = {
						CtrlChangeTitleOnMount = {
							order = 1,
							type = "toggle",
							name = L["Change title on mount"],
							desc = L["Change title when a mount is summoned"],
							get = function(info) return Pokedex.db.profile.fChangeTitleOnMount end,
							set = function(info, value) Pokedex.db.profile.fChangeTitleOnMount = value end,
						},
						CtrlChangeTitle = {
							order = 2,
							type = "execute",
							name = L["change title"],
							desc = L["change title"],
							func = function() Pokedex:ChangeTitle() end,
						},
						Padding_TitleButtons = {
							order = 3,
							type = "description",
							name = "",
						},
						CtrlTitleForRanking = {
							order = 5,
							type = "select",
							name = L["select title for ranking"],
							desc = L["title whose rank you can set"],
							values = function(info) return gv.rgstrTitleNames end,
							disabled = function(info) return (#gv.rgstrTitleNames == 0) end,
							get = function(info) return gv.iTitleForRanking end,
							set = function(info, value) gv.iTitleForRanking = value end,
						},
						CtrlRankingForTitle = {
							order = 6,
							type = "range",
							name = L["title rank"],
							desc = L["rank of current title"],
							min = 0,
							max = 10,
							step = 1,
							disabled = function(info) return (#gv.rgstrTitleNames == 0) end,
							get = function(info) return Pokedex.db.profile.rgTitleInfo[gv.iTitleForRanking].rank end,
							set = function(info, value) Pokedex.db.profile.rgTitleInfo[gv.iTitleForRanking].rank = value end,
						},
						Padding_TitleRankings = {
							order = 7,
							type = "description",
							name = "",
						},
						CtrlHotTitle = {
							order = 10,
							type = "select",
							name = L["select hot title"],
							desc = L["title to become hot one"],
							values = function(info) return gv.rgstrHotTitleNames end,
							disabled = function(info) return (not Pokedex.db.profile.fEnableHotness or #gv.rgstrHotTitleNames == 0) end,
							get = function(info) return gv.iHotTitle end,
							set = function(info, value) 
								gv.iHotTitle = value
								Pokedex.db.profile.idHotTitle = Pokedex.db.profile.rgTitleInfo[value].id
							end,
						},
						CtrlTitleHeat = {
							order = 11,
							type = "range",
							name = L["title heat"],
							desc = L["set hotness as a percentage - 100% means the hot pet is the only one that will be chosen"],
							min = 0,
							max = 100,
							step = 5,
							disabled = function(info) return not Pokedex.db.profile.fEnableHotness end,
							get = function(info) return Pokedex.db.profile.iHotTitlePref end,
							set = function(info, value) Pokedex.db.profile.iHotTitlePref = value end,
						},
						Padding_HotTitles = {
							order = 12,
							type = "description",
							name = "",
						},
					},
				},

				CtrlGroupAutoDismount = {
					order = 80,
					name = L["Safe Dismount"],
					handler = Pokedex,
					type = 'group',
					-- hidden = function(info) return (gv.rsRidingSkill < SL.Expert) end,
					args = {
						CtrlDismountFeatureDesc = {
							order = 1,
							type = "description",
							name = L["This feature works with and manages the games Auto Dismount in Flight setting to improve your experience with flying mounts. Auto dismount will be disabled unless in one of the selected conditions."],
						},
						CtrlAutoDismount = {
							order = 2,
							type = "toggle",
							width = "full",
							name = L["Manage Auto Dismount"],
							desc = L["Enables Pokedex's management of the Auto Dismount in Flight option"],
							get = function(info) return Pokedex.db.profile.fManageAutoDismount end,
							set = "SetManageAutoDismount",
						},
						Padding_Dismount1 = {
							order = 3,
							type = "description",
							width = "full",
							name = "",
						},
						Padding_Dismount2 = {
							order = 4,
							type = "description",
							width = "full",
							name = "",
						},
						Padding_Dismount3 = {
							order = 5,
							type = "description",
							width = "full",
							name = "",
						},
						CtrlDismountCombat = {
							order = 10,
							type = "toggle",
							width = "full",
							name = L["Dismount for Combat"],
							desc = L["Enables Auto Dismount when in combat"],
							disabled = function(info) return (not Pokedex.db.profile.fManageAutoDismount) end,
							get = function(info) return Pokedex.db.profile.fDismountForCombat end,
							set = function(info, value) Pokedex.db.profile.fDismountForCombat = value end,
						},
						CtrlDismountAttack = {
							order = 15,
							type = "toggle",
							width = "full",
							name = L["Dismount to Attack"],
							desc = L["Enables Auto Dismount when targeting something attackable"],
							disabled = function(info) return (not Pokedex.db.profile.fManageAutoDismount) end,
							get = function(info) return Pokedex.db.profile.fDismountForAttack end,
							set = function(info, value) Pokedex.db.profile.fDismountForAttack = value end,
						},
						CtrlDismountGathering = {
							order = 20,
							type = "toggle",
							width = "full",
							name = L["Dismount for Gathering"],
							desc = L["Enables Auto Dismount when gathering a resource with mining, herbalism or skinning"],
							hidden = function(info) return not (gv.fMiner or gv.fHerbalist or gv.fSkinner) end,
							disabled = function(info) return (not Pokedex.db.profile.fManageAutoDismount) end,
							get = function(info) return Pokedex.db.profile.fDismountForGathering end,
							set = function(info, value) Pokedex.db.profile.fDismountForGathering = value end,
						},
					},
				},
			},
		}
	end

	return Pokedex.options;
end
