state("GunsOfEschaton-Win64-Shipping") {}

startup
{
	Assembly.Load(File.ReadAllBytes("Components/uhara10")).CreateInstance("Main");

	vars.Uhara.AlertLoadless();
	vars.Uhara.EnableDebug();

	#region setting creation
	dynamic[,] _settings =
	{
	{ "Splits", true, "Splits", null },
		{ "Bosses", true, "Bosses", "Splits" },
			{ "HollowLawman",								true,	"Hollow Lawman",		"Bosses" },
			{ "EyeAngel",									false,	"Eye Angel",			"Bosses" },
		{ "Cutscenes", true, "Cutscenes", "Splits" },
			{ "DA_DesertVista_TutorialEnd",					true,	"Tutorial End",			"Cutscenes" },
			{ "DA_WormRaisesHead",							true,	"Worm",					"Cutscenes" },
			{ "DA_EyeAngelIntro",							true,	"Eye Angel Intro",		"Cutscenes" },
			{ "DA_EyeAngelOutro",							true,	"Eye Angel Outro",		"Cutscenes" },
		{ "Weapons", true, "Weapons", "Splits" },
			{ "W3m_Kanati",									true,	"Burden of Choice (Rifle)",	"Weapons" },
	{ "Debug", false, "Debug", null },
		{ "World",					false,	"World",					"Debug" },
		{ "PlayerController",		false,	"Player controller",		"Debug" },
		{ "LoadingScreen",			false,	"Loading screen",			"Debug" },
		{ "RespawnWait",			false,	"Respawn streaming wait",	"Debug" },
		{ "Cutscene",				false,	"Cutscene",					"Debug" },
		{ "RifleLooted",			false,	"Rifle looted",				"Debug" },
		{ "LawmanKilled",			false,	"Hollow Lawman killed",		"Debug" },
		{ "EyeAngelKilled",			false,	"Eye Angel killed",			"Debug" },
	};
	vars.Uhara.Settings.Create(_settings);
	#endregion

	#region TextComponent
	vars.lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();
	vars.SetText = (Action<string, object>)((text1, text2) =>
	{
		const string FileName = "LiveSplit.Text.dll";
		LiveSplit.UI.Components.ILayoutComponent lc;

		if (!vars.lcCache.TryGetValue(text1, out lc))
		{
			lc = timer.Layout.LayoutComponents.Reverse().Cast<dynamic>()
				.FirstOrDefault(llc => llc.Path.EndsWith(FileName) && llc.Component.Settings.Text1 == text1)
				?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent(FileName, timer);

			vars.lcCache.Add(text1, lc);
		}

		if (!timer.Layout.LayoutComponents.Contains(lc)) timer.Layout.LayoutComponents.Add(lc);
		dynamic tc = lc.Component;
		tc.Settings.Text1 = text1;
		tc.Settings.Text2 = text2.ToString();
	});
	vars.RemoveText = (Action<string>)(text1 =>
	{
		LiveSplit.UI.Components.ILayoutComponent lc;
		if (vars.lcCache.TryGetValue(text1, out lc))
		{
			timer.Layout.LayoutComponents.Remove(lc);
			vars.lcCache.Remove(text1);
		}
	});
	#endregion

	vars.CompletedSplits = new HashSet<string>();
}

init
{
	vars.Events = vars.Uhara.CreateTool("UnrealEngine", "Events");
	vars.Utils = vars.Uhara.CreateTool("UnrealEngine", "Utils");

	vars.Resolver.Watch<ulong>("WorldFName", vars.Utils.GWorld, 0x18);
	// GameEngine.GameInstance(1248) -> LocalPlayers[0](38, 0) -> PlayerController(30) -> class(10) -> name(18)
	vars.Resolver.Watch<ulong>("PCFName", vars.Utils.GEngine, 0x1248, 0x38, 0x0, 0x30, 0x10, 0x18);
	// GameInstance subsystem map(108), entry 4 (68) is CommonLoadingScreen's LoadingScreenManager -> bCurrentlyShowingLoadingScreen(A1)
	vars.Resolver.Watch<byte>("LoadingScreen", vars.Utils.GEngine, 0x1248, 0x108, 0x68, 0xA1);
	// World.AuthorityGameMode(1A8) -> CampfireManager(340) -> LevelStreaming(F8) -> WaitForStreamingTask(D0): set while a respawn waits for World Partition streaming
	vars.Resolver.Watch<ulong>("RespawnWait", vars.Utils.GWorld, 0x1A8, 0x340, 0xF8, 0xD0);
	vars.Resolver["RespawnWait"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	// World.GameState(1B0) -> CutsceneSystemV2(300) -> PlayingCutscene(158) -> CutsceneData(28) -> name(18)
	vars.Resolver.Watch<ulong>("CutsceneFName", vars.Utils.GWorld, 0x1B0, 0x300, 0x158, 0x28, 0x18);
	vars.Resolver["CutsceneFName"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	// InstancePtr(BP_LootActorBase_C_UAID_BCFCE708DFCC32B602) -> bSavedIsLooted(380)
	// DG_LootActorStatic.bSavedIsLooted(380) goes 0 to 1 when it is picked up
	vars.Resolver.Watch<byte>("RifleLooted", vars.Events.InstancePtr("BP_LootActorBase_C", "BP_LootActorBase_C_UAID_BCFCE708DFCC32B602*"), 0x380);
	vars.Resolver["RifleLooted"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	// InstancePtr(BP_Script_BossBattle_C_UAID_BCFCE708DFCC4FFB02) -> bBossKilled(368) | InstancePtr(BP_Script_BossBattle_Eye_C_UAID_60CF845F63148BFD02) -> bBossKilled(368)
	// BP_Script_BossBattle_C.bBossKilled(368) goes 0 to 1 when the boss dies
	vars.Resolver.Watch<byte>("LawmanKilled", vars.Events.InstancePtr("BP_Script_BossBattle_C", "BP_Script_BossBattle_C_UAID_BCFCE708DFCC4FFB02*"), 0x368);
	vars.Resolver["LawmanKilled"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	vars.Resolver.Watch<byte>("EyeAngelKilled", vars.Events.InstancePtr("BP_Script_BossBattle_EyeDemo_C", "BP_Script_BossBattle_Eye_C_UAID_60CF845F63148BFD02*"), 0x368);
	vars.Resolver["EyeAngelKilled"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	// Quest events are commented out everywhere: unreliable. Needs more testing.
	// World.GameState(1B0) -> QuestEvents_OnlineSyncComponent(330) -> ReplicatedQuestEvents.Items data(1C0), Num(1C8); 0x14 per item, tag FName at C
	//vars.Resolver.Watch<ulong>("QuestItems", vars.Utils.GWorld, 0x1B0, 0x330, 0x1C0);
	//vars.Resolver.Watch<int>("QuestCount", vars.Utils.GWorld, 0x1B0, 0x330, 0x1C8);
	//vars.Resolver["QuestCount"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	#region Text Component
	vars.SetTextIfEnabled = (Action<string, object>)((text1, text2) =>
	{
		if (settings[text1]) vars.SetText(text1, text2);
		else vars.RemoveText(text1);
	});
	#endregion

	current.World = "";
	current.PC = "";
	current.Cutscene = "";
}

update
{
	vars.Uhara.Update();

	var world = vars.Utils.FNameToString((uint)(current.WorldFName & 0xFFFFFFFF));
	if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
	var pc = vars.Utils.FNameToString((uint)(current.PCFName & 0xFFFFFFFF));
	if (!string.IsNullOrEmpty(pc) && pc != "None") current.PC = pc;
	current.Cutscene = current.World == "Demo_Persist_WP" ? vars.Utils.FNameToString((uint)(current.CutsceneFName & 0xFFFFFFFF)) ?? "" : "None";
	
	//if (current.QuestCount > 0 && current.QuestCount != old.QuestCount)
	//	current.Quest = vars.Utils.FNameToString(game.ReadValue<uint>((IntPtr)(long)(current.QuestItems + (ulong)(current.QuestCount * 0x14 - 8)))) ?? "";

	#region Debug Prints
	if (settings["Debug"])
	{
		if (old.World != current.World)                                  { vars.SetTextIfEnabled("World", current.World);                         print("World? " + current.World); }
		if (old.PC != current.PC)                                        { vars.SetTextIfEnabled("PlayerController", current.PC);                 print("PlayerController? " + current.PC); }
		if (old.LoadingScreen != current.LoadingScreen)                  { vars.SetTextIfEnabled("LoadingScreen", current.LoadingScreen != 0);    print("LoadingScreen? " + (current.LoadingScreen != 0).ToString()); }
		if ((old.RespawnWait != 0UL) != (current.RespawnWait != 0UL))    { vars.SetTextIfEnabled("RespawnWait", current.RespawnWait != 0UL);      print("RespawnWait? " + (current.RespawnWait != 0UL).ToString()); }
		if (old.Cutscene != current.Cutscene)                            { vars.SetTextIfEnabled("Cutscene", current.Cutscene);                   print("Cutscene? " + current.Cutscene); }
		if (old.RifleLooted != current.RifleLooted)                      { vars.SetTextIfEnabled("RifleLooted", current.RifleLooted);             print("RifleLooted? " + current.RifleLooted); }
		if (old.LawmanKilled != current.LawmanKilled)                    { vars.SetTextIfEnabled("LawmanKilled", current.LawmanKilled);           print("LawmanKilled? " + current.LawmanKilled); }
		if (old.EyeAngelKilled != current.EyeAngelKilled)                { vars.SetTextIfEnabled("EyeAngelKilled", current.EyeAngelKilled);       print("EyeAngelKilled? " + current.EyeAngelKilled); }
	}
	#endregion
}

onStart
{
	vars.CompletedSplits.Clear();
}

start
{
	// first control after a New Game
	return old.Cutscene == "DA_StartGame_LS" && current.Cutscene != "DA_StartGame_LS";
}

isLoading
{
	return current.LoadingScreen != 0 || current.RespawnWait != 0UL;
}

split
{
	// several signals can change in one tick (the Eye Angel kill and its outro cutscene are 2 ms apart), so check every one
	if (current.World != "Demo_Persist_WP") return false;
	var keys = new List<string>();
	if (old.Cutscene != current.Cutscene && current.Cutscene != "None") keys.Add(current.Cutscene);
	if (old.RifleLooted == 0 && current.RifleLooted == 1) keys.Add("W3m_Kanati");
	if (old.LawmanKilled == 0 && current.LawmanKilled == 1) keys.Add("HollowLawman");
	if (old.EyeAngelKilled == 0 && current.EyeAngelKilled == 1) keys.Add("EyeAngel");
	bool split = false;
	foreach (string key in keys)
	{
		print("Split? " + key);
		split |= vars.CompletedSplits.Add(key) && settings[key];
	}
	return split;
}

exit
{
	timer.IsGameTimePaused = true;
}
