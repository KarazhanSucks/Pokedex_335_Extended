Pokedex = LibStub("AceAddon-3.0"):NewAddon("Pokedex", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Pokedex")

local Pokedex = Pokedex
Pokedex.Globals = {}

--=========================================================================--
-- Keybinding globals --
--=========================================================================--
BINDING_HEADER_POKEDEX = L["Pokedex"]
BINDING_NAME_POKEDEXSUPERTOGGLE = L["Super Toggle"]
BINDING_NAME_POKEDEXSUMMONMOUNT = L["Summon Mount"]
BINDING_NAME_POKEDEXDISMISSMOUNT = L["Dismiss Mount"]
BINDING_NAME_POKEDEXTOGGLEMOUNT = L["Toggle Mount"]
BINDING_NAME_POKEDEXSUMMONNEXTMOUNT = L["Summon Next Mount"]
BINDING_NAME_POKEDEXSUMMONOTHERMOUNT = L["Summon Other Mount"]
BINDING_NAME_POKEDEXSUMMONCOMPANION = L["Summon Companion"]
BINDING_NAME_POKEDEXDISMISSCOMPANION = L["Dismiss Companion"]
BINDING_NAME_POKEDEXTOGGLECOMPANION = L["Toggle Companion"]
BINDING_NAME_POKEDEXSUMMONNEXTCOMPANION = L["Summon Next Companion"]
BINDING_NAME_POKEDEXSUMMONVENDOR = L["Summon Vendor"]
BINDING_NAME_POKEDEXCHANGETITLE = L["Change Title"]

--=========================================================================--
-- (fake) Enum Types		TODO: find a way to make these constants
--=========================================================================--

Pokedex.Globals.Types = {}

local function BuildReverseSet(list)
	local set = {}
	for k, v in pairs(list) do set[v] = k end
	return set
end


-- Initialization States
local IS = {
	INITIALIZED   = 0,
	INITIALIZING  = 1,
	UNINITIALIZED = 2,
}
Pokedex.Globals.Types.InitStates = IS


-- Debug Levels
local DL = {
	NONE   = 0,   -- no debug output
	BASIC  = 1,   -- most basic level of information
	EXCEP  = 2,   -- interesting exceptions and special cases
	AV     = 3,   -- annoyingly verbose
	MAX    = 3,   -- used for range checking
}
Pokedex.Globals.Types.DebugLevels = DL


-- Skill Levels - minimum skill level to hold that rank of profession
local SL = {
	GrandMaster = 350,
	Master      = 275,
	Artisan     = 200,
	Expert      = 125,
	Journeyman  = 50,
	Apprentice  = 1,
	None        = 0
}
Pokedex.Globals.Types.SkillLevels = SL


-- Mount Speeds
local rgstrMountSpeeds = {
	[0] = "None",    -- nil value, nonexistent

-- Combined Mount Speeds - multiple real speeds combined into one group for style over substance (can show in dropdown)
	"AllFlyers",     -- Flyer310 + Flyer280 + Flyer150
	"FastFlyers",    -- Flyer310 + Flyer280
	"AllRunners",    -- Runner100 + Runner60 + Runner0

-- Standard Mount Speeds - these can show up in the dropdown as mount types
	"Flyer310",      -- extremely fast flyers, like the Ashes of Al'ar
	"Flyer280",      -- very fast flyers
	"Flyer150",      -- regular flyers
	"Runner100",     -- very fast running mounts
	"Runner60",      -- regular runners
	"Runner0",       -- running mounts that don't actually increase speed like the Riding Turtle
	"Swimmer",       -- mounts that have faster swim speed like the Sea Turtle
	"Vashjir",       -- Vashj'ir seahorse mounts
	"Qiraji",        -- Qiraji scarab mounts
	"Naxx",          -- FM Naxx Mounts
	"Unknown",       -- mounts we failed to identify

-- Complex Mount Speeds - these will always be decomposed into one or more Standard Speeds
--   EoV refers to mounts that will scale up from 280 if you have 310 mount
	"Black_Scarab",  -- Black Qiraji Battle Tank, MS.Runner100 + MS.Qiraji
	"Sea_Turtle",    -- Sea Turtle, MS.Runner0 + MS.Swimmer
	"Skill_EoV_60",  -- scales with riding skill (upper bound then lower bound)
	"Skill_EoV_150", -- scales with riding skill (upper bound then lower bound)
	"Skill_310_60",  -- scales with riding skill (upper bound then lower bound)
	"Skill_280_60",  -- scales with riding skill (upper bound then lower bound)
	"Skill_310_150", -- scales with riding skill (upper bound then lower bound)
	"Skill_280_150", -- scales with riding skill (upper bound then lower bound)
	"Skill_100_60",  -- scales with riding skill (upper bound then lower bound)
}
local MS = BuildReverseSet(rgstrMountSpeeds)
Pokedex.Globals.Types.MountSpeeds = MS


-- mount families
local rgstrMountFamilies = {
	[0] = "Unsorted",
	"Bear",
	"Carpet",
	"Dragonhawk",
	"Drake",
	"Elekk",
	"FlyingMachine",
	"Gryphon",
	"Hawkstrider",
	"Hippogryph",
	"Horse",
	"Kodo",
	"Mammoth",
	"Mechanostrider",
	"Motorcycle",
	"NetherRay",
	"ProtoDrake",
	"Ram",
	"Raptor",
	"Rocket",
	"Saber",
	"Scarab",
	"Naxx",
	"Seahorse",
	"Talbuk",
	"Turtle",
	"WindRider",
	"Wolf",
}
local MF = BuildReverseSet(rgstrMountFamilies)
Pokedex.Globals.Types.MountFamilies = MF


--=========================================================================--
-- global variables
--=========================================================================--

Pokedex.Globals.Variables = {
-- addon infrastructure
	strVersionedTitle = L["Pokedex"] .. "      v"  .. GetAddOnMetadata("Pokedex", "Version"),
	iCurDataFormat = 6,
	InitState = IS.UNINITIALIZED,
	idLastAchievement = 0,

-- skills
	rsRidingSkill = SL.None,
	fMiner = false,
	fHerbalist = false,
	fSkinner = false,
	rgDMS = {},

-- mounts
	rgstrMountTypes,       -- indexed by mount speed, not contiguously from 0 or 1
	iMountType,            -- current index showing in dropdown, will be 0 or an MS. value
	rgMountsByType,        -- gv.rgMountsByType[MS.speed][rgIndices | rgNames][array]
	iMountOfType,          -- index of mount in its speed group
	rgstrHotMountNames,
	iHotMount,
	rgMountMap,            -- keyed by mount index, values are mount speed and index under gv.rgMountsByType
	iTravelersMammoth = 0,
	fHas310 = false,

-- companions
	rgstrCompanionNames,
	iCompanionForRanking,
	rgstrHotCompanionNames,
	iHotCompanion,
	iArgentSquire = 0,

-- titles
	rgstrTitleNames,
	iTitleForRanking,
	rgstrHotTitleNames,
	iHotTitle,
	rgTitleMap,	-- keyed by id, value is index of corresponding name in sorted order

-- dismount
	iAutoDismountFlying,
	fCanDismountForCombat = false,	-- means dismount is currently turned on because the in combat condition is true
	fCanDismountForAttack = false,	-- means dismount is currently turned on because the can attack condition is true
}



--=========================================================================--
-- "constants"				TODO: find a way to make these constants
--=========================================================================--

Pokedex.Globals.Constants = {
	iDefaultRank = 5,

	rgstrChannelDescs = { L["personal"], L["party"], L["raid"], L["emote"], L["say"], L["yell"] },
	rgstrChannels = { "ERROR", "PARTY", "RAID", "EMOTE", "SAY", "YELL" }, -- CHATID types, not localized, ERROR is just placeholder

	-- reverse look up for the MS and MF enum types
	rgstrMountSpeeds = rgstrMountSpeeds,
	rgstrMountFamilies = rgstrMountFamilies,

	rgstrMountSpeedDescsShort = { "Flyers", "280+", "Runners", "310", "280", "150", "100", "60", "0", L["Swimmers"], L["Vashj'ir Seahorses"], L["Qiraji Scarabs"], L["Naxx Horses"], L["Unidentified Mounts"] },
	rgstrMountSpeedDescs = { L["All Flyers"], L["Fast Flyers"], L["All Runners"], L["Extremely Fast Flyers"], L["Very Fast Flyers"], L["Flyers"], L["Very Fast Runners"], L["Runners"], L["Slow Runners"], L["Swimmers"], L["Vashj'ir Seahorses"], L["Qiraji Scarabs"], L["Naxx Horses"], L["Unidentified Mounts"] },

	rgstrSkillRankName = { [SL.GrandMaster] = "Grand Master", [SL.Master] = "Master", [SL.Artisan] = "Artisan", [SL.Expert] = "Expert", [SL.Journeyman] = "Journyeman", [SL.Apprentice] = "Apprentice", [SL.None] = "None" },
	rgRidingIds = { [892] = SL.Artisan, [890] = SL.Expert, [889] = SL.Journeyman, [891] = SL.Apprentice }, -- key is associated achievement

	idItemSnowball = 17202,
	idTitleMatron = 104,
	idTitlePatron = 105,
	idSpellColdWeatherFlying = 54197,
	idSpellFindMinerals = 2580,
	idSpellFindHerbs = 2383,
	idSpellTravelersTundraMammothAlliance = 61425,
	idSpellTravelersTundraMammothHorde = 61447,
	idSpellArgentSquire = 62609,
	idSpellArgentGruntling = 62746,


	-- there's no Find Skins, so we should look for specific spells
	rgSkinningIds = { [50305] = SL.GrandMaster, [32678] = SL.Master, [10768] = SL.Artisan, [8618] = SL.Expert, [8617] = SL.Journeyman, [8613] = SL.Apprentice }, -- key is spell id 

	-- array by spellId of every companion that requires a snowball to summon
	rgNeedsSnowball = { [26533] = true, [26045] = true, [26529] = true, [26541] = true },

	-- array by spellId of every mount with table of attributes for each
	-- [spellId] = { name=str, family=MF, speed=MS, passengers=bool }
	rgMountAttributes = {
		[40192] = { name="Ashes of Al'ar",                     family=MF.Unsorted,        speed=MS.Flyer310,       passengers=false },
		[80910] = { name="Dark Phoenix",         	           family=MF.Unsorted,        speed=MS.Skill_310_60,   passengers=false }, --Whitemane Frostmourne
		[65917] = { name="Magic Rooster",                      family=MF.Unsorted,        speed=MS.Runner100,      passengers=false },
		[63796] = { name="Mimiron's Head",                     family=MF.Unsorted,        speed=MS.Flyer310,       passengers=false },
		[41252] = { name="Raven Lord",                         family=MF.Unsorted,        speed=MS.Runner100,      passengers=false },
		[49322] = { name="Swift Zhevra",                       family=MF.Unsorted,        speed=MS.Runner100,      passengers=false },

		[43688] = { name="Amani War Bear",                     family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[60114] = { name="Armored Brown Bear",                 family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[60116] = { name="Armored Brown Bear",                 family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[51412] = { name="Big Battle Bear",                    family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[58983] = { name="Big Blizzard Bear",                  family=MF.Bear,            speed=MS.Skill_100_60,   passengers=false },
		[60118] = { name="Black War Bear",                     family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[60119] = { name="Black War Bear",                     family=MF.Bear,            speed=MS.Runner100,      passengers=false },
		[54753] = { name="White Polar Bear",                   family=MF.Bear,            speed=MS.Runner100,      passengers=false },

		[61451] = { name="Flying Carpet",                      family=MF.Carpet,          speed=MS.Flyer150,       passengers=false },
		[75596] = { name="Frosty Flying Carpet",               family=MF.Carpet,          speed=MS.Flyer280,       passengers=false },
		[61309] = { name="Magnificent Flying Carpet",          family=MF.Carpet,          speed=MS.Flyer280,       passengers=false },

		[61996] = { name="Blue Dragonhawk",                    family=MF.Dragonhawk,      speed=MS.Flyer280,       passengers=false },
		[61997] = { name="Red Dragonhawk",                     family=MF.Dragonhawk,      speed=MS.Flyer280,       passengers=false },
		[66088] = { name="Sunreaver Dragonhawk",               family=MF.Dragonhawk,      speed=MS.Flyer280,       passengers=false },

		[60025] = { name="Albino Drake",                       family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[59567] = { name="Azure Drake",                        family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[59650] = { name="Black Drake",                        family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[59568] = { name="Blue Drake",                         family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[59569] = { name="Bronze Drake",                       family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[69395] = { name="Onyxian Drake",                      family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[59570] = { name="Red Drake",                          family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[59571] = { name="Twilight Drake",                     family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[80920] = { name="Festering Emerald Drake",            family=MF.Drake,           speed=MS.Skill_310_60,   passengers=false }, --Whitemane Frostmourne

		[41514] = { name="Azure Netherwing Drake",             family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[41515] = { name="Cobalt Netherwing Drake",            family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[41513] = { name="Onyx Netherwing Drake",              family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[41516] = { name="Purple Netherwing Drake",            family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[41517] = { name="Veridian Netherwing Drake",          family=MF.Drake,           speed=MS.Flyer280,       passengers=false },
		[41518] = { name="Violet Netherwing Drake",            family=MF.Drake,           speed=MS.Flyer280,       passengers=false },

		[58615] = { name="Brutal Nether Drake",                family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[44744] = { name="Merciless Nether Drake",             family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[37015] = { name="Swift Nether Drake",                 family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[49193] = { name="Vengeful Nether Drake",              family=MF.Drake,           speed=MS.Flyer310,       passengers=false },

		[72808] = { name="Bloodbathed Frostbrood Vanquisher",  family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[72807] = { name="Icebound Frostbrood Vanquisher",     family=MF.Drake,           speed=MS.Flyer310,       passengers=false },
		[64927] = { name="Deadly Gladiator's Frost Wyrm",      family=MF.Drake,           speed=MS.Flyer310,       passengers=false },

		[48027] = { name="Black War Elekk",                    family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[34406] = { name="Brown Elekk",                        family=MF.Elekk,           speed=MS.Runner60,       passengers=false },
		[63639] = { name="Exodar Elekk",                       family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[35710] = { name="Gray Elekk",                         family=MF.Elekk,           speed=MS.Runner60,       passengers=false },
		[35713] = { name="Great Blue Elekk",                   family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[35712] = { name="Great Green Elekk",                  family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[35714] = { name="Great Purple Elekk",                 family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[65637] = { name="Great Red Elekk",                    family=MF.Elekk,           speed=MS.Runner100,      passengers=false },
		[35711] = { name="Purple Elekk",                       family=MF.Elekk,           speed=MS.Runner60,       passengers=false },

		[44153] = { name="Flying Machine",                     family=MF.FlyingMachine,   speed=MS.Flyer150,       passengers=false },
		[44151] = { name="Turbo-Charged Flying Machine",       family=MF.FlyingMachine,   speed=MS.Flyer280,       passengers=false },

		[61229] = { name="Armored Snowy Gryphon",              family=MF.Gryphon,         speed=MS.Flyer280,       passengers=false },
		[32239] = { name="Ebon Gryphon",                       family=MF.Gryphon,         speed=MS.Flyer150,       passengers=false },
		[32235] = { name="Golden Gryphon",                     family=MF.Gryphon,         speed=MS.Flyer150,       passengers=false },
		[32240] = { name="Snowy Gryphon",                      family=MF.Gryphon,         speed=MS.Flyer150,       passengers=false },
		[32242] = { name="Swift Blue Gryphon",                 family=MF.Gryphon,         speed=MS.Flyer280,       passengers=false },
		[32290] = { name="Swift Green Gryphon",                family=MF.Gryphon,         speed=MS.Flyer280,       passengers=false },
		[32292] = { name="Swift Purple Gryphon",               family=MF.Gryphon,         speed=MS.Flyer280,       passengers=false },
		[32289] = { name="Swift Red Gryphon",                  family=MF.Gryphon,         speed=MS.Flyer280,       passengers=false },
		[54729] = { name="Winged Steed of the Ebon Blade",     family=MF.Gryphon,         speed=MS.Skill_280_150,  passengers=false },

		[35022] = { name="Black Hawkstrider",                  family=MF.Hawkstrider,     speed=MS.Runner60,       passengers=false },
		[35020] = { name="Blue Hawkstrider",                   family=MF.Hawkstrider,     speed=MS.Runner60,       passengers=false },
		[35018] = { name="Purple Hawkstrider",                 family=MF.Hawkstrider,     speed=MS.Runner60,       passengers=false },
		[34795] = { name="Red Hawkstrider",                    family=MF.Hawkstrider,     speed=MS.Runner60,       passengers=false },
		[63642] = { name="Silvermoon Hawkstrider",             family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[66091] = { name="Sunreaver Hawkstrider",              family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[35025] = { name="Swift Green Hawkstrider",            family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[33660] = { name="Swift Pink Hawkstrider",             family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[35027] = { name="Swift Purple Hawkstrider",           family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[65639] = { name="Swift Red Hawkstrider",              family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[35028] = { name="Swift Warstrider",                   family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },
		[46628] = { name="Swift White Hawkstrider",            family=MF.Hawkstrider,     speed=MS.Runner100,      passengers=false },

		[63844] = { name="Argent Hippogryph",                  family=MF.Hippogryph,      speed=MS.Flyer280,       passengers=false },
		[74856] = { name="Blazing Hippogryph",                 family=MF.Hippogryph,      speed=MS.Skill_310_60,   passengers=false },
		[43927] = { name="Cenarion War Hippogryph",            family=MF.Hippogryph,      speed=MS.Flyer280,       passengers=false },
		[66087] = { name="Silver Covenant Hippogryph",         family=MF.Hippogryph,      speed=MS.Flyer280,       passengers=false },
		[80899] = { name="Corrupted Hippogryph",         	   family=MF.Hippogryph,      speed=MS.Skill_310_60,   passengers=false }, --Whitemane Frostmourne

		[48778] = { name="Acherus Deathcharger",               family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[66906] = { name="Argent Charger",                     family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[67466] = { name="Argent Warhorse",                    family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[470]   = { name="Black Stallion",                     family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[22717] = { name="Black War Steed",                    family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[458]   = { name="Brown Horse",                        family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[75614] = { name="Celestial Steed",                    family=MF.Horse,           speed=MS.Skill_EoV_60,   passengers=false },
		[23214] = { name="Charger",                            family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[6648]  = { name="Chestnut Mare",                      family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[73313] = { name="Crimson Deathcharger",               family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[68188] = { name="Crusader's Black Warhorse",          family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[68187] = { name="Crusader's White Warhorse",          family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[23161] = { name="Dreadsteed",                         family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[5784]  = { name="Felsteed",                           family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[36702] = { name="Fiery Warhorse",                     family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[72286] = { name="Invincible",                         family=MF.Horse,           speed=MS.Skill_310_60,   passengers=false },
		[16082] = { name="Palomino",                           family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[472]   = { name="Pinto",                              family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[66090] = { name="Quel'dorei Steed",                   family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[17481] = { name="Rivendare's Deathcharger",           family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[63232] = { name="Stormwind Steed",                    family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[34767] = { name="Summon Charger",                     family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[34769] = { name="Summon Warhorse",                    family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[68057] = { name="Swift Alliance Steed",               family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[23229] = { name="Swift Brown Steed",                  family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[65640] = { name="Swift Gray Steed",                   family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[23227] = { name="Swift Palomino",                     family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[23228] = { name="Swift White Steed",                  family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[48025] = { name="Headless Horseman's Mount",          family=MF.Horse,           speed=MS.Skill_280_60,   passengers=false },
		[13819] = { name="Warhorse",                           family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[16083] = { name="White Stallion",                     family=MF.Horse,           speed=MS.Runner100,      passengers=false },

		[64977] = { name="Black Skeletal Horse",               family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[17463] = { name="Blue Skeletal Horse",                family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[64656] = { name="Blue Skeletal Warhorse",             family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[17464] = { name="Brown Skeletal Horse",               family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[63643] = { name="Forsaken Warhorse",                  family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[17465] = { name="Green Skeletal Warhorse",            family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[66846] = { name="Ochre Skeletal Warhorse",            family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[17462] = { name="Red Skeletal Horse",                 family=MF.Horse,           speed=MS.Runner60,       passengers=false },
		[23246] = { name="Purple Skeletal Warhorse",           family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[22722] = { name="Red Skeletal Warhorse",              family=MF.Horse,           speed=MS.Runner100,      passengers=false },
		[65645] = { name="White Skeletal Warhorse",            family=MF.Horse,           speed=MS.Runner100,      passengers=false },

		[22718] = { name="Black War Kodo",                     family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[50869] = { name="Brewfest Kodo",                      family=MF.Kodo,            speed=MS.Runner60,       passengers=false },
		[18990] = { name="Brown Kodo",                         family=MF.Kodo,            speed=MS.Runner60,       passengers=false },
		[18989] = { name="Gray Kodo",                          family=MF.Kodo,            speed=MS.Runner60,       passengers=false },
		[49379] = { name="Great Brewfest Kodo",                family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[23249] = { name="Great Brown Kodo",                   family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[65641] = { name="Great Golden Kodo",                  family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[23248] = { name="Great Gray Kodo",                    family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[23247] = { name="Great White Kodo",                   family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[18991] = { name="Green Kodo",                         family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[18992] = { name="Teal Kodo",                          family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[63641] = { name="Thunder Bluff Kodo",                 family=MF.Kodo,            speed=MS.Runner100,      passengers=false },
		[64657] = { name="White Kodo",                         family=MF.Kodo,            speed=MS.Runner60,       passengers=false },

		[59785] = { name="Black War Mammoth",                  family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[59788] = { name="Black War Mammoth",                  family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[61465] = { name="Grand Black War Mammoth",            family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[61467] = { name="Grand Black War Mammoth",            family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[61469] = { name="Grand Ice Mammoth",                  family=MF.Mammoth,         speed=MS.Runner100,      passengers=true  },
		[61470] = { name="Grand Ice Mammoth",                  family=MF.Mammoth,         speed=MS.Runner100,      passengers=true  },
		[59797] = { name="Ice Mammoth",                        family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[59799] = { name="Ice Mammoth",                        family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[61425] = { name="Traveler's Tundra Mammoth",          family=MF.Mammoth,         speed=MS.Runner100,      passengers=true  },
		[61447] = { name="Traveler's Tundra Mammoth",          family=MF.Mammoth,         speed=MS.Runner100,      passengers=true  },
		[59791] = { name="Wooly Mammoth",                      family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },
		[59793] = { name="Wooly Mammoth",                      family=MF.Mammoth,         speed=MS.Runner100,      passengers=false },

		[22719] = { name="Black Battlestrider",                family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[10969] = { name="Blue Mechanostrider",                family=MF.Mechanostrider,  speed=MS.Runner60,       passengers=false },
		[17458] = { name="Fluorescent Green Mechanostrider",   family=MF.Mechanostrider,  speed=MS.Runner60,       passengers=false },
		[63638] = { name="Gnomeregan Mechanostrider",          family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[17453] = { name="Green Mechanostrider",               family=MF.Mechanostrider,  speed=MS.Runner60,       passengers=false },
		[17459] = { name="Icy Blue Mechanostrider Mod A",      family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[10873] = { name="Red Mechanostrider",                 family=MF.Mechanostrider,  speed=MS.Runner60,       passengers=false },
		[23225] = { name="Swift Green Mechanostrider",         family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[23223] = { name="Swift White Mechanostrider",         family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[23222] = { name="Swift Yellow Mechanostrider",        family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[65642] = { name="Turbostrider",                       family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },
		[17454] = { name="Unpainted Mechanostrider",           family=MF.Mechanostrider,  speed=MS.Runner60,       passengers=false },
		[15779] = { name="White Mechanostrider Mod B",         family=MF.Mechanostrider,  speed=MS.Runner100,      passengers=false },

		[55531] = { name="Mechano-hog",                        family=MF.Motorcycle,      speed=MS.Runner100,      passengers=true  },
		[60424] = { name="Mekgineer's Chopper",                family=MF.Motorcycle,      speed=MS.Runner100,      passengers=true  },

		[39803] = { name="Blue Riding Nether Ray",             family=MF.NetherRay,      speed=MS.Flyer280,      passengers=false },
		[39798] = { name="Green Riding Nether Ray",            family=MF.NetherRay,      speed=MS.Flyer280,      passengers=false },
		[39801] = { name="Purple Riding Nether Ray",           family=MF.NetherRay,      speed=MS.Flyer280,      passengers=false },
		[39800] = { name="Red Riding Nether Ray",              family=MF.NetherRay,      speed=MS.Flyer280,      passengers=false },
		[39802] = { name="Silver Riding Nether Ray",           family=MF.NetherRay,      speed=MS.Flyer280,      passengers=false },

		[59976] = { name="Black Proto-Drake",                  family=MF.ProtoDrake,     speed=MS.Flyer310,      passengers=false },
		[59996] = { name="Blue Proto-Drake",                   family=MF.ProtoDrake,     speed=MS.Flyer280,      passengers=false },
		[61294] = { name="Green Proto-Drake",                  family=MF.ProtoDrake,     speed=MS.Flyer280,      passengers=false },
		[63956] = { name="Ironbound Proto-Drake",              family=MF.ProtoDrake,     speed=MS.Flyer310,      passengers=false },
		[60021] = { name="Plagued Proto-Drake",                family=MF.ProtoDrake,     speed=MS.Flyer310,      passengers=false },
		[59961] = { name="Red Proto-Drake",                    family=MF.ProtoDrake,     speed=MS.Flyer280,      passengers=false },
		[63963] = { name="Rusted Proto-Drake",                 family=MF.ProtoDrake,     speed=MS.Flyer310,      passengers=false },
		[60002] = { name="Time-Lost Proto-Drake",              family=MF.ProtoDrake,     speed=MS.Flyer280,      passengers=false },
		[60024] = { name="Violet Proto-Drake",                 family=MF.ProtoDrake,     speed=MS.Flyer310,      passengers=false },

		[17461] = { name="Black Ram",                          family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[22720] = { name="Black War Ram",                      family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[43899] = { name="Brewfest Ram",                       family=MF.Ram,             speed=MS.Runner60,       passengers=false },
		[6899]  = { name="Brown Ram",                          family=MF.Ram,             speed=MS.Runner60,       passengers=false },
		[17460] = { name="Frost Ram",                          family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[6777]  = { name="Gray Ram",                           family=MF.Ram,             speed=MS.Runner60,       passengers=false },
		[63636] = { name="Ironforge Ram",                      family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[23510] = { name="Stormpike Battle Charger",           family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[43900] = { name="Swift Brewfest Ram",                 family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[23238] = { name="Swift Brown Ram",                    family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[23239] = { name="Swift Gray Ram",                     family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[65643] = { name="Swift Violet Ram",                   family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[23240] = { name="Swift White Ram",                    family=MF.Ram,             speed=MS.Runner100,      passengers=false },
		[6898]  = { name="White Ram",                          family=MF.Ram,             speed=MS.Runner60,       passengers=false },

		[22721] = { name="Black War Raptor",                   family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[63635] = { name="Darkspear Raptor",                   family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[8395] =  { name="Emerald Raptor",                     family=MF.Raptor,          speed=MS.Runner60,       passengers=false },
		[17450] = { name="Ivory Raptor",                       family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[16084] = { name="Mottled Red Raptor",                 family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[23241] = { name="Swift Blue Raptor",                  family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[23242] = { name="Swift Olive Raptor",                 family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[23243] = { name="Swift Orange Raptor",                family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[65644] = { name="Swift Purple Raptor",                family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[24242] = { name="Swift Razzashi Raptor",              family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[10796] = { name="Turquoise Raptor",                   family=MF.Raptor,          speed=MS.Runner60,       passengers=false },
		[64659] = { name="Venomhide Ravasaur",                 family=MF.Raptor,          speed=MS.Runner100,      passengers=false },
		[10799] = { name="Violet Raptor",                      family=MF.Raptor,          speed=MS.Runner60,       passengers=false },

		[71342] = { name="Big Love Rocket",                    family=MF.Rocket,          speed=MS.Skill_310_60,   passengers=false },
		[46197] = { name="X-51 Nether-Rocket",                 family=MF.Rocket,          speed=MS.Flyer150,       passengers=false },
		[46199] = { name="X-51 Nether-Rocket X-TREME",         family=MF.Rocket,          speed=MS.Flyer280,       passengers=false },
		[75973] = { name="X-53 Touring Rocket",                family=MF.Rocket,          speed=MS.Skill_EoV_150,  passengers=true  },

		[16056] = { name="Ancient Frostsaber",                 family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[16055] = { name="Black Nightsaber",                   family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[22723] = { name="Black War Tiger",                    family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[63637] = { name="Darnassian Nightsaber",              family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[42776] = { name="Spectral Tiger",                     family=MF.Saber,           speed=MS.Runner60 ,      passengers=false },
		[10789] = { name="Spotted Frostsaber",                 family=MF.Saber,           speed=MS.Runner60,       passengers=false },
		[66847] = { name="Striped Dawnsaber",                  family=MF.Saber,           speed=MS.Runner60 ,      passengers=false },
		[8394]  = { name="Striped Frostsaber",                 family=MF.Saber,           speed=MS.Runner60,       passengers=false },
		[10793] = { name="Striped Nightsaber",                 family=MF.Saber,           speed=MS.Runner60,       passengers=false },
		[23221] = { name="Swift Frostsaber",                   family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[23219] = { name="Swift Mistsaber",                    family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[65638] = { name="Swift Moonsaber",                    family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[42777] = { name="Swift Spectral Tiger",               family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[23338] = { name="Swift Stormsaber",                   family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[24252] = { name="Swift Zulian Tiger",                 family=MF.Saber,           speed=MS.Runner100,      passengers=false },
		[17229] = { name="Winterspring Frostsaber",            family=MF.Saber,           speed=MS.Runner100,      passengers=false },

		[26656] = { name="Black Qiraji Battle Tank",           family=MF.Scarab,          speed=MS.Black_Scarab,   passengers=false },
		[25953] = { name="Blue Qiraji Battle Tank",            family=MF.Scarab,          speed=MS.Qiraji,         passengers=false },
		[26056] = { name="Green Qiraji Battle Tank",           family=MF.Scarab,          speed=MS.Qiraji,         passengers=false },
		[26054] = { name="Red Qiraji Battle Tank",             family=MF.Scarab,          speed=MS.Qiraji,         passengers=false },
		[26055] = { name="Yellow Qiraji Battle Tank",          family=MF.Scarab,          speed=MS.Qiraji,         passengers=false },
		[29059] = { name="Naxxramas Deathcharger",             family=MF.Naxx,            speed=MS.Naxx,           passengers=false },

		[75207] = { name="Abyssal Seahorse",                   family=MF.Seahorse,        speed=MS.Vashjir,        passengers=false },

		[39315] = { name="Cobalt Riding Talbuk",               family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[34896] = { name="Cobalt War Talbuk",                  family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[39316] = { name="Dark Riding Talbuk",                 family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[34790] = { name="Dark War Talbuk",                    family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[39317] = { name="Silver Riding Talbuk",               family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[34898] = { name="Silver War Talbuk",                  family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[39318] = { name="Tan Riding Talbuk",                  family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[34899] = { name="Tan War Talbuk",                     family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[39319] = { name="White Riding Talbuk",                family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },
		[34897] = { name="White War Talbuk",                   family=MF.Talbuk,          speed=MS.Runner100,      passengers=false },

		[30174] = { name="Riding Turtle",                      family=MF.Turtle,          speed=MS.Runner0,        passengers=false },
		[64731] = { name="Sea Turtle",                         family=MF.Turtle,          speed=MS.Sea_Turtle,     passengers=false },

		[61230] = { name="Armored Blue Wind Rider",            family=MF.WindRider,       speed=MS.Flyer280,       passengers=false },
		[32244] = { name="Blue Wind Rider",                    family=MF.WindRider,       speed=MS.Flyer150,       passengers=false },
		[32245] = { name="Green Wind Rider",                   family=MF.WindRider,       speed=MS.Flyer150,       passengers=false },
		[32295] = { name="Swift Green Wind Rider",             family=MF.WindRider,       speed=MS.Flyer280,       passengers=false },
		[32297] = { name="Swift Purple Wind Rider",            family=MF.WindRider,       speed=MS.Flyer280,       passengers=false },
		[32246] = { name="Swift Red Wind Rider",               family=MF.WindRider,       speed=MS.Flyer280,       passengers=false },
		[32296] = { name="Swift Yellow Wind Rider",            family=MF.WindRider,       speed=MS.Flyer280,       passengers=false },
		[32243] = { name="Tawny Wind Rider",                   family=MF.WindRider,       speed=MS.Flyer150,       passengers=false },

		[22724] = { name="Black War Wolf",                     family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[64658] = { name="Black Wolf",                         family=MF.Wolf,            speed=MS.Runner60,       passengers=false },
		[6654]  = { name="Brown Wolf",                         family=MF.Wolf,            speed=MS.Runner60,       passengers=false },
		[6653]  = { name="Dire Wolf",                          family=MF.Wolf,            speed=MS.Runner60,       passengers=false },
		[23509] = { name="Frostwolf Howler",                   family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[63640] = { name="Orgrimmar Wolf",                     family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[16080] = { name="Red Wolf",                           family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[23250] = { name="Swift Brown Wolf",                   family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[65646] = { name="Swift Burgundy Wolf",                family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[23252] = { name="Swift Gray Wolf",                    family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[68056] = { name="Swift Horde Wolf",                   family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[23251] = { name="Swift Timber Wolf",                  family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
		[580]   = { name="Timber Wolf",                        family=MF.Wolf,            speed=MS.Runner60,       passengers=false },
		[16081] = { name="Winter Wolf",                        family=MF.Wolf,            speed=MS.Runner100,      passengers=false },
	}
}
