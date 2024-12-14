Allows random summoning of mounts and companions using preference values set by user to influence selection. Will summon appropriate mount based on what zone supports.  Can also randomly set character title based on same user ranking principles.  Can also manage Auto Dismount in Flight option to improve flying mount user experience in a safe way.

The chance of a particular item (mount, companion or title) being selected is equal to the preference value you have assinged to it divided by the total of the preference values for all other elligible items in the draw. If all items are still set to the default value, then they all have an equal chance of being selected. An item which you have assigned a value of 0 will never be selected.


Pokedex provides a number of commands that can be executed from the chat command, placed inside a macro or even called through keybinding; a Pokedex section will be added to the games Key Bindings UI found in the Game Menu.  The three most commonly used and useful commands are:
/pd - this will bring up the options ui for the addon, allowing you enable/disable features as well as set preferences for your mounts, companions and titles

/pd ToggleMount - this will randomly summon the fastest mount suitable for a zone or, if already mounted, dismount you or exit you from a vehicle

/pd SummonCompanion - randomly summons a companion



The New Hotness - The idea behind this feature is that your most recently acquired pet/mount/title is something you're probably excited about and what to see more often than the rest of your collection. Or maybe you want to flaunt it in front of the all the people who are still trying to get, for example, their Sinister Squashling. When dealing with large numbers of pets or mounts, even setting it to ten will not cause it to show up very often. So rather than make you downrank every other item, the hotness feature acts as a way to get that one pet out more often. If there is a hot pet, we'll first do a percentile roll against the heat of hot item. If the heat is set to 50, then 50 percent of the time we would summon that hot pet. The other 50 percent of the time, we'll do the usual random selection out of the weighted pet pool.

Safe Dismount - This feature is disabled by default but can be turned on in Pokedex's options ui. This feature allows you to keep as a default behavior that of having the Auto Dismount in Flight option turned off, so that accidently casting trying to cast a spell in flight won't send you plummeting to your death, but allows you to choose override scenarios where you do want actions to dismount you automatically so that they can be executed.  The scenarios you can opt into are 1) when you are in combat, 2) targeting something attackable or 3) attempting to gather a resource via mining, herbalism or skinning.



This is the full list of commands that can be used with Pokedex.I personally bind Toggle Mount to H (for horse, of course) and SummonOtherMount to both Alt-H and Ctrl-H for example.

/pd     or /pokedex                 - brings up the options UI 

/pd sm  or /pd SummonMount          - summon random mount
/pd snm or /pd SummonNextMount      - summon next mount in collection based on current mount
/pd dm  or /pd DismissMount         - dismiss current mount, will also exit a vehicle
/pd tm  or /pd ToggleMount          - calls SummonMount or DismissMount depending on whether you're currently mounted
/pd som or /pd SummonOtherMount     - if SummonMount would summon flying mount, this will summon a ground mount or vice versa (useful for example on Krasus' Landing if you want a ground mount because you're going into the city) 

/pd sc  or /pd SummonCompanion      - summon random companion
/pd snc or /pd SummonNextCompanion  - will summon next companion in collection based on current companion 
/pd dc  or /pd DismissCompanion     - dismiss current companion
/pd tc  or /pd ToggleCompanion      - calls SummonCompanion of DismissCompanion depending on whether you currently have one out 

/pd ct  or /pd ChangeTitle          - randomly change title 

/pd Vendor      - will summon a mount or companion with vendor capabilities (Traveler's Tundra Mammoth, Argent Squire or Argent Gruntling) 

/pd SuperToggle - will do ToggleMount or ToggleCompanion depending on whether you are outside or inside, lets you have just one button for both pets and mounts



DRUIDS - I don't have druid forms integrated into the addon, but this macro does a pretty good job of picking the right option for the right scenario:
/cast [swimming,nostance:2] Aquatic Form; [combat,nostance:4] Travel Form; [flyable,nostance:5] Swift Flight Form
/pd ToggleMount
/cancelform

Please note that you have to replace stance:5 with stance:6 in this macro if your spec has access to either Moonkin or Tree of Life forms.  If, for example, you are dual-specced Feral (Primary) and Restoration (Secondary), the macro would be:
/cast [swimming,nostance:2] Aquatic Form; [combat,nostance:4] Travel Form; [spec:1,flyable,nostance:5][spec:2,flyable,nostance:6] Swift Flight Form
/pd ToggleMount
/cancelform
