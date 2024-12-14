local L = LibStub("AceLocale-3.0"):NewLocale("MyAddon", "esES")
if not L then return end

-- you can update incorrect or untranslated phrases through the localization tool on
-- the webpage for this addon: http://www.wowace.com/addons/pokedex/localization/

-- L["%s, I choose you!"] = "%s, I choose you!"
-- L["(on|off) let everyone know who *you* choose"] = "(on|off) let everyone know who *you* choose"
-- L["AUTO_DISMOUNT_FLYING_TEXT"] = "AUTO_DISMOUNT_FLYING_TEXT"
-- L["All Flyers"] = "All Flyers"
-- L["All Runners"] = "All Runners"
-- L["Change Title"] = "Change Title"
-- L["Change title on mount"] = "Change title on mount"
-- L["Change title when a mount is summoned"] = "Change title when a mount is summoned"
-- L["Companions"] = "Companions"
-- L["Dismiss Companion"] = "Dismiss Companion"
-- L["Dismiss Mount"] = "Dismiss Mount"
-- L["Dismount for Combat"] = "Dismount for Combat"
-- L["Dismount for Gathering"] = "Dismount for Gathering"
-- L["Dismount to Attack"] = "Dismount to Attack"
-- L["ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."] = "ERROR: Pokedex failed to initialize correctly. This is usually caused when WoW has invalidated its cache and hasn't finished rebuilding it. Please try this action again later."
-- L["ERROR: You cannot summon your mammoth in this area"] = "ERROR: You cannot summon your mammoth in this area"
-- L["ERROR: You don't have any titles."] = "ERROR: You don't have any titles."
-- L["ERROR: You have no mounts or pets with vendor capabilities"] = "ERROR: You have no mounts or pets with vendor capabilities"
-- L["ERROR: You have no summonable companions."] = "ERROR: You have no summonable companions."
-- L["ERROR: You have no summonable mounts."] = "ERROR: You have no summonable mounts."
-- L["ERROR: category selected that appears to have no mounts"] = "ERROR: category selected that appears to have no mounts"
-- L["ERROR: companion name not available"] = "ERROR: companion name not available"
-- L["ERROR: mount name not available"] = "ERROR: mount name not available"
-- L["ERROR: only one of Total Ranks and Summonable List was zero"] = "ERROR: only one of Total Ranks and Summonable List was zero"
-- L["ERROR: selection error"] = "ERROR: selection error"
-- L["ERROR: title name not available"] = "ERROR: title name not available"
-- L["ERROR: type error"] = "ERROR: type error"
-- L["Enables Auto Dismount when gathering a resource with mining, herbalism or skinning"] = "Enables Auto Dismount when gathering a resource with mining, herbalism or skinning"
-- L["Enables Auto Dismount when in combat"] = "Enables Auto Dismount when in combat"
-- L["Enables Auto Dismount when targeting something attackable"] = "Enables Auto Dismount when targeting something attackable"
-- L["Enables Pokedex's management of the Auto Dismount in Flight option"] = "Enables Pokedex's management of the Auto Dismount in Flight option"
-- L["Extremely Fast Flyers"] = "Extremely Fast Flyers"
-- L["Fast Flyers"] = "Fast Flyers"
-- L["Flyers"] = "Flyers"
-- L["Herbalism"] = "Herbalism"
-- L["Manage Auto Dismount"] = "Manage Auto Dismount"
-- L["Mining"] = "Mining"
-- L["Mounts"] = "Mounts"
-- L["New companion added: %s"] = "New companion added: %s"
-- L["New mount added: %s"] = "New mount added: %s"
-- L["New title added: %s"] = "New title added: %s"
-- L["None"] = "None"
-- L["Please see the README.TXT file in the Pokedex addon folder for more information on how to use Pokedex"] = "Please see the README.TXT file in the Pokedex addon folder for more information on how to use Pokedex"
-- L["Pokedex"] = "Pokedex"
-- L["Qiraji Scarabs"] = "Qiraji Scarabs"
-- L["Requires"] = "Requires"
-- L["Riding skill"] = "Riding skill"
-- L["Runners"] = "Runners"
-- L["Safe Dismount"] = "Safe Dismount"
-- L["Skinnable"] = "Skinnable"
-- L["Slow Runners"] = "Slow Runners"
-- L["Summon Companion"] = "Summon Companion"
-- L["Summon Mount"] = "Summon Mount"
-- L["Summon Next Companion"] = "Summon Next Companion"
-- L["Summon Next Mount"] = "Summon Next Mount"
-- L["Summon Other Mount"] = "Summon Other Mount"
-- L["Summon Vendor"] = "Summon Vendor"
-- L["Super Toggle"] = "Super Toggle"
-- L["Swimmers"] = "Swimmers"
-- L["This feature works with and manages the games Auto Dismount in Flight setting to improve your experience with flying mounts. Auto dismount will be disabled unless in one of the selected conditions."] = "This feature works with and manages the games Auto Dismount in Flight setting to improve your experience with flying mounts. Auto dismount will be disabled unless in one of the selected conditions."
-- L["Titles"] = "Titles"
-- L["Toggle Companion"] = "Toggle Companion"
-- L["Toggle Mount"] = "Toggle Mount"
-- L["Unidentified Mounts"] = "Unidentified Mounts"
-- L["Very Fast Flyers"] = "Very Fast Flyers"
-- L["Very Fast Runners"] = "Very Fast Runners"
-- L["always make newest mount or companion the hot one"] = "always make newest mount or companion the hot one"
-- L["announce"] = "announce"
-- L["change title"] = "change title"
-- L["channel"] = "channel"
-- L["channel to announce selection in"] = "channel to announce selection in"
-- L["companion heat"] = "companion heat"
-- L["companion rank"] = "companion rank"
-- L["companion to become hot one"] = "companion to become hot one"
-- L["companion whose rank you can set"] = "companion whose rank you can set"
-- L["dismiss companion"] = "dismiss companion"
-- L["dismiss mount"] = "dismiss mount"
-- L["dismisses current companion"] = "dismisses current companion"
-- L["dismisses current mount"] = "dismisses current mount"
-- L["echoes out current speed"] = "echoes out current speed"
-- L["echoes out test info relevant to current feature in development"] = "echoes out test info relevant to current feature in development"
-- L["echoes out zone info"] = "echoes out zone info"
-- L["emote"] = "emote"
-- L["enable hot pets"] = "enable hot pets"
-- L["extremely fast"] = "extremely fast"
-- L["if summon mount would summon flyer, will summon ground mount and vice versa"] = "if summon mount would summon flyer, will summon ground mount and vice versa"
-- L["keeping it real (slow)"] = "keeping it real (slow)"
-- L["lets %s know that they have been chosen."] = "lets %s know that they have been chosen."
-- L["lets your turn on|off the hot pet subfeatures"] = "lets your turn on|off the hot pet subfeatures"
-- L["location"] = "location"
-- L["mount"] = "mount"
-- L["mount heat"] = "mount heat"
-- L["mount rank"] = "mount rank"
-- L["mount to become hot one"] = "mount to become hot one"
-- L["mount whose rank you can set"] = "mount whose rank you can set"
-- L["name not yet available"] = "name not yet available"
-- L["new hotness"] = "new hotness"
-- L["no companions available"] = "no companions available"
-- L["no hot companion"] = "no hot companion"
-- L["no hot mount"] = "no hot mount"
-- L["no hot title"] = "no hot title"
-- L["no mounts available"] = "no mounts available"
-- L["no titles available"] = "no titles available"
-- L["only"] = "only"
-- L["party"] = "party"
-- L["pd"] = "pd"
-- L["personal"] = "personal"
-- L["pokedex"] = "pokedex"
-- L["raid"] = "raid"
-- L["rank of current companion"] = "rank of current companion"
-- L["rank of current mount"] = "rank of current mount"
-- L["rank of current title"] = "rank of current title"
-- L["retry initialization"] = "retry initialization"
-- L["ride"] = "ride"
-- L["rideable"] = "rideable"
-- L["say"] = "say"
-- L["select companion for ranking"] = "select companion for ranking"
-- L["select hot companion"] = "select hot companion"
-- L["select hot mount"] = "select hot mount"
-- L["select hot title"] = "select hot title"
-- L["select mount for ranking"] = "select mount for ranking"
-- L["select mount type"] = "select mount type"
-- L["select title for ranking"] = "select title for ranking"
-- L["set hotness as a percentage - 100% means the hot mount is the only one that will be chosen"] = "set hotness as a percentage - 100% means the hot mount is the only one that will be chosen"
-- L["set hotness as a percentage - 100% means the hot pet is the only one that will be chosen"] = "set hotness as a percentage - 100% means the hot pet is the only one that will be chosen"
-- L["set hotness as a percentage - 100% means the hot title is the only one that will be chosen"] = "set hotness as a percentage - 100% means the hot title is the only one that will be chosen"
-- L["slow"] = "slow"
-- L["style over substance"] = "style over substance"
-- L["summon companion"] = "summon companion"
-- L["summon mount"] = "summon mount"
-- L["summon next companion"] = "summon next companion"
-- L["summon next mount"] = "summon next mount"
-- L["summon other mount"] = "summon other mount"
-- L["summon vendor"] = "summon vendor"
-- L["summons a companion"] = "summons a companion"
-- L["summons a mount"] = "summons a mount"
-- L["summons a mount or companion with vendor capabilities"] = "summons a mount or companion with vendor capabilities"
-- L["summons next companion in collection"] = "summons next companion in collection"
-- L["summons next mount in collection"] = "summons next mount in collection"
-- L["title heat"] = "title heat"
-- L["title rank"] = "title rank"
-- L["title to become hot one"] = "title to become hot one"
-- L["title whose rank you can set"] = "title whose rank you can set"
-- L["toggle companion"] = "toggle companion"
-- L["toggle mount"] = "toggle mount"
-- L["toggle mount or companion"] = "toggle mount or companion"
-- L["toggles a companion"] = "toggles a companion"
-- L["toggles a mount"] = "toggles a mount"
-- L["toggles mount or companion"] = "toggles mount or companion"
-- L["very fast"] = "very fast"
-- L["when summoning, combine extremely fast (310%) and very fast (280%) flying mounts into one group"] = "when summoning, combine extremely fast (310%) and very fast (280%) flying mounts into one group"
-- L["when summoning, combine fast and slow mounts into one group"] = "when summoning, combine fast and slow mounts into one group"
-- L["yell"] = "yell"

