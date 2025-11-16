local L = LibStub("AceLocale-3.0"):NewLocale("Pokedex", "enUS", true)

-- Keybinding
L["Pokedex"] = true
L["Super Toggle"] = true
L["Summon Mount"] = true
L["Dismiss Mount"] = true
L["Summon Next Mount"] = true
L["Summon Other Mount"] = true
L["Toggle Mount"] = true
L["Summon Companion"] = true
L["Dismiss Companion"] = true
L["Toggle Companion"] = true
L["Summon Next Companion"] = true
L["Summon Vendor"] = true
L["Change Title"] = true

-- Chat commands
L["pokedex"] = true
L["pd"] = true

-- Announcement channels names
L["personal"] = true
L["party"] = true
L["raid"] = true
L["emote"] = true
L["say"] = true
L["yell"] = true

-- Announcement messages, %s is name of companion or mount
L["%s, I choose you!"] = true
L["lets %s know that they have been chosen."] = true

-- mount types
L["Unidentified Mounts"] = true
L["Extremely Fast Flyers"] = true
L["Very Fast Flyers"] = true
L["Flyers"] = true
L["Very Fast Runners"] = true
L["Runners"] = true
L["Slow Runners"] = true
L["Swimmers"] = true
L["Vashj'ir Seahorses"] = true
L["Qiraji Scarabs"] = true
L["All Flyers"] = true
L["Fast Flyers"] = true
L["All Runners"] = true
L["Naxx Horses"] = true

-- Mount property tooltip clues
L["very fast"] = true
L["extremely fast"] = true
L["Riding skill"] = true
L["slow"] = true
L["location"] = true
L["only"] = true
L["ride"] = true
L["rideable"] = true
L["mount"] = true

-- Update messages
L["New mount added: %s"] = true
L["New companion added: %s"] = true
L["New title added: %s"] = true

-- drop down strings for nil cases
L["name not yet available"] = true
L["no mounts available"] = true
L["no companions available"] = true
L["no titles available"] = true
L["no hot mount"] = true
L["no hot companion"] = true
L["no hot title"] = true
L["None"] = true

-- tooltip strings checked for gathering
L["Requires"] = true
L["Mining"] = true
L["Herbalism"] = true
L["Skinnable"] = true


-- commands and options
L["retry initialization"] = true
L["Mounts"] = true
L["Companions"] = true
L["Titles"] = true
L["Safe Dismount"] = true
L["Please see the README.TXT file in the Pokedex addon folder for more information on how to use Pokedex"] = true
L["echoes out test info relevant to current feature in development"] = true
L["echoes out current speed"] = true
L["echoes out zone info"] = true
L["announce"] = true
L["(on|off) let everyone know who *you* choose"] = true
L["channel"] = true
L["channel to announce selection in"] = true
L["summon companion"] = true
L["summons a companion"] = true
L["summon next companion"] = true
L["summons next companion in collection"] = true
L["dismiss companion"] = true
L["dismisses current companion"] = true
L["select companion for ranking"] = true
L["companion whose rank you can set"] = true
L["companion rank"] = true
L["rank of current companion"] = true
L["summon mount"] = true
L["summons a mount"] = true
L["summon next mount"] = true
L["summons next mount in collection"] = true
L["dismiss mount"] = true
L["dismisses current mount"] = true
L["select mount type"] = true
L["select mount for ranking"] = true
L["mount whose rank you can set"] = true
L["mount rank"] = true
L["rank of current mount"] = true
L["enable hot pets"] = true
L["lets your turn on|off the hot pet subfeatures"] = true
L["new hotness"] = true
L["always make newest mount or companion the hot one"] = true
L["select hot companion"] = true
L["companion to become hot one"] = true
L["companion heat"] = true
L["set hotness as a percentage - 100% means the hot pet is the only one that will be chosen"] = true
L["select hot mount"] = true
L["mount to become hot one"] = true
L["mount heat"] = true
L["set hotness as a percentage - 100% means the hot mount is the only one that will be chosen"] = true
L["style over substance"] = true
L["when summoning, combine extremely fast (310%) and very fast (280%) flying mounts into one group"] = true
L["keeping it real (slow)"] = true
L["when summoning, combine fast and slow mounts into one group"] = true
L["Change title on mount"] = true
L["Change title when a mount is summoned"] = true
L["change title"] = true
L["select title for ranking"] = true
L["title whose rank you can set"] = true
L["title rank"] = true
L["rank of current title"] = true
L["select hot title"] = true
L["title to become hot one"] = true
L["title heat"] = true
L["set hotness as a percentage - 100% means the hot title is the only one that will be chosen"] = true
L["toggle companion"] = true
L["toggles a companion"] = true
L["toggle mount"] = true
L["toggles a mount"] = true
L["toggle mount or companion"] = true
L["toggles mount or companion"] = true
L["summon other mount"] = true
L["if summon mount would summon flyer, will summon ground mount and vice versa"] = true
L["summon vendor"] = true
L["summons a mount or companion with vendor capabilities"] = true
L["This feature works with and manages the games Auto Dismount in Flight setting to improve your experience with flying mounts. Auto dismount will be disabled unless in one of the selected conditions."] = true
L["Manage Auto Dismount"] = true
L["Enables Pokedex's management of the Auto Dismount in Flight option"] = true
L["Dismount for Combat"] = true
L["Enables Auto Dismount when in combat"] = true
L["Dismount to Attack"] = true
L["Enables Auto Dismount when targeting something attackable"] = true
L["Dismount for Gathering"] = true
L["Enables Auto Dismount when gathering a resource with mining, herbalism or skinning"] = true


-- ERRORS
L["ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."] = true
L["ERROR: only one of Total Ranks and Summonable List was zero"] = true
L["ERROR: category selected that appears to have no mounts"] = true
L["ERROR: You have no summonable mounts."] = true
L["ERROR: mount name not available"] = true
L["ERROR: You have no summonable companions."] = true
L["ERROR: companion name not available"] = true
L["ERROR: You don't have any titles."] = true
L["ERROR: title name not available"] = true
L["ERROR: selection error"] = true
L["ERROR: type error"] = true
L["ERROR: You cannot summon your mammoth in this area"] = true
L["ERROR: You have no mounts or pets with vendor capabilities"] = true

-- CVAR text not sure if this actually needs updating
L["AUTO_DISMOUNT_FLYING_TEXT"] = true
