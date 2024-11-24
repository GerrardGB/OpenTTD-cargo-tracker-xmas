/*
 * This file is part of a game script for OpenTTD: Cargo Tracker - Xmas
 */

require("version.nut");

class FMainClass extends GSInfo {
	function GetAuthor()		{ return "Gerard"; }
	function GetName()			{ return "Cargo Tracker - Xmas"; }
	function GetDescription() 	{ return "Tracks two types of cargoes for a Xmas competition."; }
	function GetVersion()		{ return SELF_VERSION; }
	function GetDate()			{ return SELF_DATE; }
	function CreateInstance()	{ return "MainClass"; }
	function GetShortName()		{ return "CTRK"; }
	function GetAPIVersion()	{ return "1.3"; }
	function GetUrl()			{ return "None"; }

	function GetSettings() {
		AddSetting({
				name = "cargo_tracker_1",
				description = "Cargo ID 1 to track",
				min_value = 1, max_value = 32,
				easy_value = 12, medium_value = 12, hard_value = 12, custom_value = 12,
				flags = CONFIG_NONE,
			});
		AddSetting({
				name = "cargo_tracker_2",
				description = "Cargo ID 2 to track",
				min_value = 1, max_value = 32,
				easy_value = 13, medium_value = 13, hard_value = 13, custom_value = 13,
				flags = CONFIG_NONE,
			});
		AddSetting({
				name = "cargo_tracker_supply",
				description = "Track supplies to the above cargoes",
				min_value = 0, max_value = 1,
				easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1,
				flags = CONFIG_NONE,
			});
		AddLabels("cargo_tracker_supply", {_0 = "No", _1 = "Yes"});
	}
}

RegisterGS(FMainClass());
