/*
 * This file is part of a game script for OpenTTD: Cargo Tracker - Xmas
 */

class MainClass extends GSController 
{
	_load_data = null;

	lastGoodGlobal = 0;
	lastBadGlobal = 0;

	goalCompany = array(GSCompany.COMPANY_LAST, {});
	goalGlobal = array(GSCompany.COMPANY_LAST, {});
	lastMonth = 1;
	cargoGood = GSController.GetSetting("cargo_tracker_1");
	cargoBad = GSController.GetSetting("cargo_tracker_2");
	trackSupply = GSController.GetSetting("cargo_tracker_supply");
	game_loaded = 0;
	cargoGoodSupply = GSList();
	cargoBadSupply = GSList();
	leagueTableDelivered = GSLeagueTable();
	leagueTableSupplied = GSLeagueTable();

	constructor()
	{
	}
}

function MainClass::Save()
{
	GSLog.Info("Saving data to savegame");
	return {
		sv_goalGlobal = this.goalGlobal,
		sv_goalCompany = this.goalCompany,
		sv_lastMonth = lastMonth,
		sv_cargoGood = cargoGood,
		sv_cargoBad = cargoBad,
		sv_leagueTableDelivered = leagueTableDelivered,
		sv_leagueTableSupplied = leagueTableSupplied,
	};
}

function MainClass::Load(version, tbl)
{
	GSLog.Info("Loading data from savegame made with version " + version + " of the game script");

	foreach(key, val in tbl)
	{
		if (key == "sv_goalGlobal") this.goalGlobal = val;
		if (key == "sv_goalCompany") this.goalCompany = val;
		if (key == "sv_lastMonth") this.lastMonth = val;
		if (key == "sv_cargoGood") this.cargoGood = val;
		if (key == "sv_cargoBad") this.cargoBad = val;
		if (key == "sv_leagueTableDelivered") this.leagueTableDelivered = val;
		if (key == "sv_leagueTableSupplied") this.leagueTableSupplied = val;
	}
	game_loaded = 1;
}

function max(x1, x2)
{
	return x1 > x2? x1 : x2;
}

function MainClass::Start()
{
	// Wait for the game to start
	this.Sleep(1);

	this.PostInit();

	while (true) {
		local loopStartTick = GSController.GetTick();

		this.HandleEvents();
		this.DoLoop();

		// Sleep for "1 day"
		local ticksPassed = GSController.GetTick() - loopStartTick;
		this.Sleep(max(1, 1 * 74 - ticksPassed));
	}
}

function MainClass::HandleEvents()
{
	while(GSEventController.IsEventWaiting())
	{
		local ev = GSEventController.GetNextEvent();

		if(ev == null)
			return;
	}
}

function MainClass::PostInit()
{
	GSLog.Info("PostInit");
	GSLog.Info("Starting version 1.1");

	local goal = this.goalGlobal[0];

	if (!game_loaded) {

		leagueTableDelivered = GSLeagueTable.New("Delivered Table", "Maximum of either type of cargo delivered", "Updated monthly");
		leagueTableSupplied = GSLeagueTable.New("Supplied Table", "Maximum of either type of cargo supplied", "Updated monthly");
		goal.goalGoodAmount <- GSGoal.GOAL_INVALID;

		goal.goalBadAmount <- GSGoal.GOAL_INVALID;

		goal.lastGoodAmount <- 0;
		goal.lastBadAmount <- 0;

		goal.totalGoodAmount <- 0;
		goal.totalBadAmount <- 0;

		if (goal.goalGoodAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodAmount);
		goal.goalGoodAmount = GSGoal.New(GSCompany.COMPANY_INVALID, GSText(GSText.STR_GOAL_TEXT, 1 << cargoGood, 0, 0), GSGoal.GT_TOWN, 1);

		if (goal.goalBadAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadAmount);
		goal.goalBadAmount = GSGoal.New(GSCompany.COMPANY_INVALID, GSText(GSText.STR_GOAL_TEXT, 1 << cargoBad, 0, 0), GSGoal.GT_TOWN, 1);

	}
	// Get the cargo accepted by the industry that produces the tracked good cargo
	local indListGoodSupply = GSIndustryList_CargoProducing(cargoGood);
	local indType = GSIndustry.GetIndustryType(indListGoodSupply.Begin());
	cargoGoodSupply = GSIndustryType.GetAcceptedCargo(indType);

	// Get the cargo accepted by the industry that produces the tracked bad cargo
	local indListBadSupply = GSIndustryList_CargoProducing(cargoBad);
	indType = GSIndustry.GetIndustryType(indListBadSupply.Begin());
	cargoBadSupply = GSIndustryType.GetAcceptedCargo(indType);
}

function MainClass::DoLoop()
{
	local currentMonth = GSDate.GetMonth(GSDate.GetCurrentDate());
	if (currentMonth != this.lastMonth)
	{
		this.lastMonth = currentMonth;
		lastGoodGlobal = 0;
		lastBadGlobal = 0;
		// Update each company
		for (local cid = GSCompany.COMPANY_FIRST; cid < GSCompany.COMPANY_LAST; cid++)
		{
			if (GSCompany.ResolveCompanyID(cid) != GSCompany.COMPANY_INVALID)
			{
				UpdateMonth(cid);
				UpdateGoals(cid);
			}
		}
		UpdateGlobal();
	}

	// Check for new companies, remove deleted ones
	for (local cid = GSCompany.COMPANY_FIRST; cid < GSCompany.COMPANY_LAST; cid++)
	{
		if (GSCompany.ResolveCompanyID(cid) != GSCompany.COMPANY_INVALID)
		{
			if (this.goalCompany[cid].len() == 0)
			{
				GSLog.Info("Init company " + cid);
				InitNewCompany(cid);
			}
		}
		else if (this.goalCompany[cid].len() != 0)
		{
			GSLog.Info("Clear company " + cid + " ID " + GSCompany.ResolveCompanyID(cid));
			CancelMonitors(cid);
			this.goalCompany[cid] = {};
		}
	}
}

function MainClass::InitNewCompany(cid)
{
	local goal = this.goalCompany[cid];

	// Show welcome screen
	GSGoal.Question(2, cid, GSText(GSText.STR_GOAL_START, 1 << cargoGood, 1 << cargoBad), GSGoal.QT_INFORMATION, GSGoal.BUTTON_GO);

	goal.goalGoodAmount <- GSGoal.GOAL_INVALID;
	goal.goalBadAmount <- GSGoal.GOAL_INVALID;
	goal.goalGoodSupply <- GSGoal.GOAL_INVALID;
	goal.goalBadSupply <- GSGoal.GOAL_INVALID;

	goal.leagueDelivered <- 0;
	goal.leagueSupplied <- 0;
	
	goal.lastGoodAmount <- 0;
	goal.lastBadAmount <- 0;
	goal.lastGoodSupply <- 0;
	goal.lastBadSupply <- 0;
	goal.monitors <- {};

	goal.totalGoodAmount <- 0;
	goal.totalBadAmount <- 0;
	goal.totalGoodSupply <- 0;
	goal.totalBadSupply <- 0;

	goal.start <- GSDate.GetCurrentDate();
	GSLog.Info("Create company " + cid);

	if (goal.goalGoodAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodAmount);
	goal.goalGoodAmount = GSGoal.New(cid, GSText(GSText.STR_GOAL_TEXT, 1 << cargoGood, goal.totalGoodAmount, goal.lastGoodAmount), GSGoal.GT_TOWN, 1);

	if (goal.goalBadAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadAmount);
	goal.goalBadAmount = GSGoal.New(cid,GSText(GSText.STR_GOAL_TEXT, 1 << cargoBad, goal.totalBadAmount, goal.lastBadAmount), GSGoal.GT_TOWN, 1);

	if (trackSupply) {
		if (goal.goalGoodSupply != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodSupply);
		goal.goalGoodSupply = GSGoal.New(cid, GSText(GSText.STR_GOAL_SUPPLY_TEXT, 1 << cargoGood, goal.totalGoodSupply, goal.lastGoodSupply), GSGoal.GT_TOWN, 1);

		if (goal.goalBadSupply != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadSupply);
		goal.goalBadSupply = GSGoal.New(cid, GSText(GSText.STR_GOAL_SUPPLY_TEXT, 1 << cargoBad, goal.totalBadSupply, goal.lastBadSupply), GSGoal.GT_TOWN, 1);
	}

	goal.leagueDelivered = GSLeagueTable.NewElement(leagueTableDelivered, 1, cid, GSCompany.GetName(cid), "0", 4, cid);
	goal.leagueSupplied = GSLeagueTable.NewElement(leagueTableSupplied, 1, cid, GSCompany.GetName(cid), "0", 4, cid);
}

function MainClass::QueryMonitor(ind, cid, cargoType)
{
	return GSCargoMonitor.GetIndustryDeliveryAmount(cid, cargoType, ind, true);
}

function MainClass::QueryMonitorMultiple(ind, cid, cargoType)
{
	// Step through each cargo type and get total delivered
	local totalSupply = GSCargoMonitor.GetIndustryDeliveryAmount(cid, cargoType.Begin(), ind, true);
	foreach(key, val in cargoType)
	{
		totalSupply += GSCargoMonitor.GetIndustryDeliveryAmount(cid, cargoType.Next(), ind, true);
	}
	return totalSupply;
}

function MainClass::UpdateMonth(cid)
{
	local goal = this.goalCompany[cid];

	// Get list of industries that accept the cargo being tracked
	local indListGood = GSIndustryList_CargoAccepting(cargoGood);
	local indListBad = GSIndustryList_CargoAccepting(cargoBad);

	// See how much the company has delivered to each of the industries that accepts the tracked cargo
	indListGood.Valuate(this.QueryMonitor, cid, cargoGood);
	indListBad.Valuate(this.QueryMonitor, cid, cargoBad);

	// Get list of industries that produce the cargo being tracked, to get the supplied numbers
	local indListGoodSupply = GSIndustryList_CargoProducing(cargoGood);
	local indListBadSupply = GSIndustryList_CargoProducing(cargoBad);

	// Get total of amounts supplied to each industry, passing the cargo type supply list
	indListGoodSupply.Valuate(this.QueryMonitorMultiple, cid, cargoGoodSupply);
	indListBadSupply.Valuate(this.QueryMonitorMultiple, cid, cargoBadSupply);

	goal.lastGoodAmount = 0;
	goal.lastBadAmount = 0;
	goal.lastGoodSupply = 0;
	goal.lastBadSupply = 0;

	foreach(key, val in indListGood)
	{
		goal.lastGoodAmount += val;
	}

	foreach(key, val in indListBad)
	{
		goal.lastBadAmount += val;
	}
	goal.totalGoodAmount += goal.lastGoodAmount;
	goal.totalBadAmount += goal.lastBadAmount;

	if (trackSupply) {
		foreach(key, val in indListGoodSupply)
		{
			goal.lastGoodSupply += val;
		}

		foreach(key, val in indListBadSupply)
		{
			goal.lastBadSupply += val;
		}
		goal.totalGoodSupply += goal.lastGoodSupply;
		goal.totalBadSupply += goal.lastBadSupply;
	}

	lastGoodGlobal += goal.lastGoodAmount;
	lastBadGlobal += goal.lastBadAmount;
}

function MainClass::CancelMonitors(cid)
{
	local goal = this.goalCompany[cid];
	foreach(key, val in goal.monitors)
	{
		GSCargoMonitor.GetIndustryDeliveryAmount(cid, goal.cargoType, key, false);
	}
}

function MainClass::UpdateGoals(cid)
{
	local goal = this.goalCompany[cid];

	if (goal.goalGoodAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodAmount);
	goal.goalGoodAmount = GSGoal.New(cid, GSText(GSText.STR_GOAL_TEXT, 1 << cargoGood, goal.totalGoodAmount, goal.lastGoodAmount), GSGoal.GT_TOWN, 1);

	if (goal.goalBadAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadAmount);
	goal.goalBadAmount = GSGoal.New(cid,GSText(GSText.STR_GOAL_TEXT, 1 << cargoBad, goal.totalBadAmount, goal.lastBadAmount), GSGoal.GT_TOWN, 1);

	if (trackSupply) {
		if (goal.goalGoodSupply != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodSupply);
		goal.goalGoodSupply = GSGoal.New(cid, GSText(GSText.STR_GOAL_SUPPLY_TEXT, 1 << cargoGood, goal.totalGoodSupply, goal.lastGoodSupply), GSGoal.GT_TOWN, 1);

		if (goal.goalBadSupply != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadSupply);
		goal.goalBadSupply = GSGoal.New(cid,GSText(GSText.STR_GOAL_SUPPLY_TEXT, 1 << cargoBad, goal.totalBadSupply, goal.lastBadSupply), GSGoal.GT_TOWN, 1);
	}
	GSLog.Info("Update company " + cid + " Good Delivered: " + goal.lastGoodAmount + " Bad Delivered: " + goal.lastBadAmount + " Good Supplied: " + goal.lastGoodSupply + " Bad Supplied: " + goal.lastBadSupply);

	// Update league table to catch company name changes
	GSLeagueTable.UpdateElementData(goal.leagueDelivered, cid, GSCompany.GetName(cid), 4, cid);
	GSLeagueTable.UpdateElementData(goal.leagueSupplied, cid, GSCompany.GetName(cid), 4, cid);

	// Update scores in the league table
	GSLeagueTable.UpdateElementScore(goal.leagueDelivered, max(goal.totalGoodAmount, goal.totalBadAmount), GSText(GSText.STR_LEAGUE_SCORE, max(goal.totalGoodAmount, goal.totalBadAmount)));
	GSLeagueTable.UpdateElementScore(goal.leagueSupplied, max(goal.totalGoodSupply, goal.totalBadSupply), GSText(GSText.STR_LEAGUE_SCORE, max(goal.totalGoodSupply, goal.totalBadSupply)));
}

function MainClass::UpdateGlobal()
{
	local goal = this.goalGlobal[0];

	goal.lastGoodAmount = lastGoodGlobal;
	goal.lastBadAmount = lastBadGlobal;

	goal.totalGoodAmount += lastGoodGlobal;
	goal.totalBadAmount += lastBadGlobal;

	if (goal.goalGoodAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalGoodAmount);
	goal.goalGoodAmount = GSGoal.New(GSCompany.COMPANY_INVALID, GSText(GSText.STR_GOAL_TEXT, 1 << cargoGood, goal.totalGoodAmount, goal.lastGoodAmount), GSGoal.GT_TOWN, 1);

	if (goal.goalBadAmount != GSGoal.GOAL_INVALID) GSGoal.Remove(goal.goalBadAmount);
	goal.goalBadAmount = GSGoal.New(GSCompany.COMPANY_INVALID,GSText(GSText.STR_GOAL_TEXT, 1 << cargoBad, goal.totalBadAmount, goal.lastBadAmount), GSGoal.GT_TOWN, 1);
	GSLog.Info("Update globals: Good: " + goal.lastGoodAmount + " Bad: " + goal.lastBadAmount);
}