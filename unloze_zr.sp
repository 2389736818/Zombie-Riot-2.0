#pragma semicolon 1
#define PLUGIN_AUTHOR "jenz, https://steamcommunity.com/id/type_moon/"
#define PLUGIN_VERSION "1.3"
#define g_dIndexes 128
#define g_dLength 256
#define CSGO_KNOCKBACK_BOOST        251.0
#define CSGO_KNOCKBACK_BOOST_MAX    350.0
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <dhooks>
#include <clientprefs>
#include <smlib>
#pragma newdecls required
//#pragma dynamic 131072 
static char g_cPathsClassHuman[PLATFORM_MAX_PATH];
static char g_cPathsClassZM[PLATFORM_MAX_PATH];
static char g_cPathsDownload[PLATFORM_MAX_PATH];
static char g_cPathsWaveSettings[PLATFORM_MAX_PATH];
static char g_cPathsWeapons[PLATFORM_MAX_PATH];
static char g_cPathsExtra[PLATFORM_MAX_PATH];
char g_cUniqueName[g_dIndexes][g_dLength];
char g_cZMRoundClasses[g_dIndexes][g_dLength];
char g_cHumanClasses[g_dIndexes][g_dLength];
char g_cTeam[g_dIndexes][g_dLength];
char g_cGroup[g_dIndexes][g_dLength];
char g_cSMFLAGS[g_dIndexes][g_dLength];
char g_cModelPath[g_dIndexes][g_dLength];
char g_cNoFallDmg[g_dIndexes][g_dLength];
char g_cHealth[g_dIndexes][g_dLength];
char g_cSpeed[g_dIndexes][g_dLength];
char g_cKnockback[g_dIndexes][g_dLength];
char g_cJumpHeight[g_dIndexes][g_dLength];
char g_cJumpDistance[g_dIndexes][g_dLength];
char g_cAdminGroups[g_dIndexes][g_dIndexes][g_dLength];
char g_cZMSounds[g_dIndexes][g_dLength];
char g_cWeaponEntity[g_dIndexes][g_dLength];
char g_cWeaponNames[g_dIndexes][g_dLength];
char g_cWeaponCommand[g_dIndexes][g_dLength];
int g_iLength = g_dLength - 1;
int g_iWave;
int g_iZMScaleability;
int g_iZMCount;
int g_iToolsVelocity; //from zombie reloaded
int g_iClientZMClasses[g_dIndexes];
int g_iClientHumanClasses[g_dIndexes];
int g_iClientRespawnCount[g_dIndexes];
int g_iSpeedIndex[g_dIndexes];
int g_iWeaponSlot[g_dIndexes];
int g_iWeaponPrice[g_dIndexes];
int g_iBotStuckindex[g_dIndexes];
int g_iClientRespawnCountNum;
int g_iLoadClassesIndex;
int g_iZMBeginindex;
int g_iSoundIndexes;
int g_iWeaponIndex;
int g_iBotStuckCounts;
float g_fKnockBackIndex[g_dIndexes];
float g_fJumpHeightIndex[g_dIndexes];
float g_fJumpDistanceIndex[g_dIndexes];
float g_fSwitchingTimer;
float g_fZMSpawnProtection;
float g_fHumanSpawnProtection;
float g_fZMHealthScaleability;
float g_fRespawnTimer;
float g_fZMSounds;
float g_fBotStuckPush;
bool g_bSwitchingIndex;
bool g_bRoundInProgress;
bool g_bShouldBeHuman[g_dIndexes];
bool g_bShouldBeZM[g_dIndexes];
bool g_bFallDamage[g_dIndexes];
bool g_bClientProtection[g_dIndexes];
Handle g_hGetPlayerMaxSpeed = INVALID_HANDLE;
Handle g_hClientZMCookie;
Handle g_hClientHumanCookie;
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Plugin myinfo = 
{
	name = "Unloze Zombie Riot",
	author = PLUGIN_AUTHOR,
	description = "Zombie Riot mod for CSGO",
	version = PLUGIN_VERSION,
	url = "www.unloze.com"
};
public void OnPluginStart()
{
	//gamedata
	if (LibraryExists("dhooks")) 
	{
		Handle hGameData = LoadGameConfigFile("zombieriot");
		if (hGameData != null) 
		{
			int iOffset = GameConfGetOffset(hGameData, "GetPlayerMaxSpeed");
			if (iOffset != -1)
				g_hGetPlayerMaxSpeed = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, DHook_GetPlayerMaxSpeed);
			delete hGameData;
		}
	}
	//processstring
	LoadTranslations("common.phrases.txt");
	//cookies
	if (g_hClientZMCookie == null)
		g_hClientZMCookie = RegClientCookie("unloze_zr_classprefZM", "Cookie for ZM classes", CookieAccess_Protected);
	if (g_hClientHumanCookie == null)
		g_hClientHumanCookie = RegClientCookie("unloze_zr_classprefHuman", "Cookie for Human classes", CookieAccess_Protected);
	BuildPath(Path_SM, g_cPathsClassZM, sizeof(g_cPathsClassZM), "configs/unloze_zr/classeszm.txt");
	BuildPath(Path_SM, g_cPathsClassHuman, sizeof(g_cPathsClassHuman), "configs/unloze_zr/classeshuman.txt");
	BuildPath(Path_SM, g_cPathsExtra, sizeof(g_cPathsExtra), "configs/unloze_zr/extra.txt");
	BuildPath(Path_SM, g_cPathsDownload, sizeof(g_cPathsDownload), "configs/unloze_zr/download.txt");
	BuildPath(Path_SM, g_cPathsWaveSettings, sizeof(g_cPathsWaveSettings), "configs/unloze_zr/wavesettings.txt");
	BuildPath(Path_SM, g_cPathsWeapons, sizeof(g_cPathsWeapons), "configs/unloze_zr/weapons.txt");
	//hooks
	HookEvent("player_spawn", ApplySettings, EventHookMode_Post);
	HookEvent("round_start", Event_roundStart, EventHookMode_Post);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
	HookEvent("player_connect_full", Event_OnFullConnect, EventHookMode_Pre); 
	HookEvent("player_hurt", EventPlayerHurt, EventHookMode_Pre);
	HookEvent("player_jump", EventPlayerJump, EventHookMode_Post);
	//commands
	RegConsoleCmd("say", Cmd_Say);
	RegConsoleCmd("sm_zclass", Cmd_Zclass, "Class Prefferences"); //named like zombiereloaded for ease of use
	RegConsoleCmd("sm_zmarket", Cmd_zmarket, "weapon Prefferences"); //named like zombiereloaded for ease of use
	RegAdminCmd("sm_LoadClasses", Cmd_LoadManually, ADMFLAG_RCON);
	RegAdminCmd("sm_wave", Cmd_ChangeWave, ADMFLAG_RCON);
	RegAdminCmd("sm_human", Cmd_Humanize, ADMFLAG_BAN);
	RegAdminCmd("sm_infect", Cmd_Zombienize, ADMFLAG_BAN);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_LoadManually(int client, int args)
{	
	//LoadClasses();
	AddDownloadContent();
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_zmarket(int client, int args)
{
	Zmarket(client);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_Humanize(int client, int args)
{
	InfectionSlashHumanHandling(client, args, 0);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_Zombienize(int client, int args)
{
	InfectionSlashHumanHandling(client, args, 1);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_Zclass(int client, int args)
{
	Zclass(client);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_ChangeWave(int client, int args)
{
	char l_cChangeWave[4];
	int l_iWave;
	GetCmdArg(1, l_cChangeWave, sizeof(l_cChangeWave));
	l_iWave = StringToInt(l_cChangeWave);
	if (l_iWave > 0)
	{
		g_iWave = l_iWave;
		PrintToChatAll("Admin %N Changing wave to: %i", client, g_iWave);
		CS_TerminateRound(4.0, CSRoundEnd_Draw, false);
	}
	else
	{
		ReplyToCommand(client, "Incorrect input");
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Cmd_Say(int client, int args)
{
	/*
	getclientteam might be checked unnecesarily this way because its also checking in ZmarketGetWeapon
	but this way most can be stopped to interferre from triggering cmd_say
	*/
	if (client < 1)
		return Plugin_Continue;
		
	if (GetClientTeam(client) != CS_TEAM_CT || !IsPlayerAlive(client))
		return Plugin_Continue;
	char l_cBuffer[g_dLength];
	char l_cBuffer2[g_dLength];
	GetCmdArgString(l_cBuffer, sizeof(l_cBuffer));
	if (StrContains(l_cBuffer, "!") == -1 && StrContains(l_cBuffer, "/") == -1)
		return Plugin_Continue;
	ReplaceString(l_cBuffer, sizeof(l_cBuffer), "\"", "");
	ReplaceString(l_cBuffer, sizeof(l_cBuffer), "/", "");
	ReplaceString(l_cBuffer, sizeof(l_cBuffer), "!", "");
	if (StrContains(l_cBuffer, "sm_") == -1)
	{
		Format(l_cBuffer2, sizeof(l_cBuffer2), "sm_");
		StrCat(l_cBuffer2, sizeof(l_cBuffer2), l_cBuffer);
	}
	for (int i = 0; i <= g_iWeaponIndex; i++)
	{
		if (strlen(g_cWeaponCommand[i][g_iLength]) < 1)
			continue;
		if (StrEqual(l_cBuffer, g_cWeaponCommand[i][g_iLength], false) || StrEqual(l_cBuffer2, g_cWeaponCommand[i][g_iLength], false))
		{
			//PrintToChatAll("SUCCESS: %s", l_cBuffer);
			ZmarketGetWeapon(client, i);
			break;
		}
	}
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action InfectionSlashHumanHandling(int client, int args, int state)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_human <#userid|name>");
		ReplyToCommand(client, "[SM] Usage: sm_infect <#userid|name>");
		return Plugin_Handled;
	}
	findTarget(client, state);
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void findTarget(int client, int state)
{
	//state 0 human, state 1 zm
	char target[MAX_NAME_LENGTH]; 
	char targetname[MAX_NAME_LENGTH];
	int targets[g_dLength];
	int result;
	bool tn_is_ml;
	GetCmdArg(1, target, sizeof(target));
	// Find a target.
	result = ProcessTargetString(target, client, targets, sizeof(targets), COMMAND_FILTER_ALIVE , targetname, sizeof(targetname), tn_is_ml);
	// Check if there was a problem finding a client.
	if (result != 1)
	{
		PrintToChat(client, "Found no specific Target!");
		return;
	}
	if (state == 0)
	{
		PrintToChat(client, "Humanized: %N", targets[0]);
		g_bShouldBeHuman[targets[0]] = true;
		SelectWavebasedHuman(targets[0]);
	}
	else
	{
		PrintToChat(client, "Infected: %N", targets[0]);
		g_bShouldBeZM[targets[0]] = true;
		SelectWaveBasedZM(targets[0], 1);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void Zmarket(int client)
{
	Menu ZmarketMenu = CreateMenu(Zmarket_menu);
	ZmarketMenu.SetTitle("Weapon Selection");
	for (int i = 0; i < g_iWeaponIndex; i++)
	{
		ZmarketMenu.AddItem("", g_cWeaponNames[i][g_iLength]);
	}
	ZmarketMenu.ExitButton = true;
	ZmarketMenu.ExitBackButton = true;
	ZmarketMenu.Display(client, 0);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
static void Zclass(int client)
{
	char l_cHuman[g_dLength];
	char l_cZM[g_dLength];
	int l_iZMIndex = g_iClientZMClasses[client];
	int l_iHumanIndex = g_iClientHumanClasses[client];
	Menu ZclassMenu = CreateMenu(Zclass_Menu);
	if (strlen(g_cZMRoundClasses[l_iZMIndex][g_iLength]) < 1)
	{
		for (int i = 0; i < g_dIndexes; i++)
		{
			if (strlen(g_cZMRoundClasses[i][g_iLength]) < 1)
				continue;
			l_iZMIndex = i;
			break;
		}
	}
	if (strlen(g_cHumanClasses[l_iHumanIndex][g_iLength]) < 1)
	{
		for (int i = 0; i < g_dIndexes; i++)
		{
			if (strlen(g_cHumanClasses[i][g_iLength]) < 1)
				continue;
			l_iHumanIndex = i;
			break;
		}
	}
	Format(l_cZM, sizeof(l_cZM), "Active Zombie Class: %s", g_cZMRoundClasses[l_iZMIndex][g_iLength]);
	Format(l_cHuman, sizeof(l_cHuman), "Active Human Class: %s", g_cHumanClasses[l_iHumanIndex][g_iLength]);
	ZclassMenu.SetTitle("TeamClass Selection");
	ZclassMenu.AddItem("", "Human Classes");
	ZclassMenu.AddItem("", l_cHuman, ITEMDRAW_DISABLED);
	ZclassMenu.AddItem("", "Zombie Classes");
	ZclassMenu.AddItem("",  l_cZM, ITEMDRAW_DISABLED);
	ZclassMenu.ExitButton = true;
	ZclassMenu.ExitBackButton = true;
	ZclassMenu.Display(client, 0);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public int Zmarket_menu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		ZmarketGetWeapon(client, selection);
	}
	else if (action == MenuAction_End) 
	{
		delete(menu);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public int Zclass_Menu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		ZclassTeamMenu(client, selection);
	}
	else if (action == MenuAction_End) 
	{
		delete(menu);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: //https://forums.alliedmods.net/showthread.php?t=305092
//----------------------------------------------------------------------------------------------------
public void ZmarketGetWeapon(int client, int index)
{
	if (GetClientTeam(client) != CS_TEAM_CT || !IsPlayerAlive(client))
	{
		PrintToChat(client, "You have to be Human for obtaining weapons");
		return;
	}
	int l_iClientCash = GetEntProp(client, Prop_Send, "m_iAccount");
	int l_iEntity;
	int l_iWeapon;
	float l_fClientPos[3];
	if (g_iWeaponPrice[index] <= l_iClientCash)
	{
		l_iEntity = CreateEntityByName(g_cWeaponEntity[index][g_iLength]);
		if (l_iEntity == -1)
		{
			ReplyToCommand(client, "Error occured");
			return;
		}
		GetClientAbsOrigin(client, l_fClientPos);
		l_iWeapon = GetPlayerWeaponSlot(client, g_iWeaponSlot[index]);
		if (IsValidEntity(l_iWeapon))
		{
			if (GetEntPropEnt(l_iWeapon, Prop_Send, "m_hOwnerEntity") != client)
			{
				SetEntPropEnt(l_iWeapon, Prop_Send, "m_hOwnerEntity", client);
			}
			CS_DropWeapon(client, l_iWeapon, false, true);
			AcceptEntityInput(l_iWeapon, "Kill");
		}
		TeleportEntity(l_iEntity, l_fClientPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(l_iEntity);
		SetEntProp(client, Prop_Send, "m_iAccount", l_iClientCash - g_iWeaponPrice[index]);
		PrintToChat(client, "you purchased: %s", g_cWeaponNames[index][g_iLength]);
	}
	else
	{
		PrintToChat(client, "Not enough money, requires: %i", g_iWeaponPrice[index]);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
static void ZclassTeamMenu(int client, int state)
{
	//0 human, 2 zm
	Menu zclassMenu;
	AdminId l_AdminID = GetUserAdmin(client);
	int l_iAdminGroupCount = GetAdminGroupCount(l_AdminID);
	int l_iFound;
	int l_iFlags;
	if (state == 2)
	{
		zclassMenu = CreateMenu(Zombieclass_Menu);
		zclassMenu.SetTitle("Playerclass Zombie Selection");
		for (int i = 0; i < g_dIndexes; i++)
		{
			if (strlen(g_cZMRoundClasses[i][g_iLength]) < 1)
				continue;
				
			if (strlen(g_cGroup[i][g_iLength]) < 1 && strlen(g_cSMFLAGS[i][g_iLength]) < 1)
			{
				zclassMenu.AddItem("", g_cZMRoundClasses[i][g_iLength]);
				l_iFound++;
			}
			else
			{
				l_iFound = 0;
				if (strlen(g_cGroup[i][g_iLength]) > 0)
				{
					for (int j = 0; j < l_iAdminGroupCount; j++)
					{
						if (StrEqual(g_cGroup[i][g_iLength], g_cAdminGroups[client][j][g_iLength]))
						{
							zclassMenu.AddItem("", g_cZMRoundClasses[i][g_iLength]);
							l_iFound++;
							break;
						}
					}
				}
			}
			l_iFlags = ReadFlagString(g_cSMFLAGS[i][g_iLength]);
			if (GetUserFlagBits(client) & l_iFlags && l_iFound < 1 && strlen(g_cSMFLAGS[i][g_iLength]) > 0)
			{
				zclassMenu.AddItem("", g_cZMRoundClasses[i][g_iLength]);
				l_iFound++;
			}
			if (l_iFound == 0)
			{
				zclassMenu.AddItem("", g_cZMRoundClasses[i][g_iLength], ITEMDRAW_DISABLED);
			}
			
		}
	}
	else
	{
		zclassMenu = CreateMenu(Humanclass_Menu);
		zclassMenu.SetTitle("Active Playerclass Human Selection");
		for (int i = 0; i < g_dIndexes; i++)
		{
			if (strlen(g_cHumanClasses[i][g_iLength]) < 1)
				continue;
			
			if (strlen(g_cGroup[i][g_iLength]) < 1 && strlen(g_cSMFLAGS[i][g_iLength]) < 1)
			{
				zclassMenu.AddItem("", g_cHumanClasses[i][g_iLength]);	
				l_iFound++;
			}
			else
			{
				l_iFound = 0;
				if (strlen(g_cGroup[i][g_iLength]) > 0)
				{
					for (int j = 0; j < l_iAdminGroupCount; j++)
					{
						if (StrEqual(g_cGroup[i][g_iLength], g_cAdminGroups[client][j][g_iLength]))
						{
							zclassMenu.AddItem("", g_cHumanClasses[i][g_iLength]);
							l_iFound++;
							break;
						}
					}
				}
			}
			l_iFlags = ReadFlagString(g_cSMFLAGS[i][g_iLength]);
			if (GetUserFlagBits(client) & l_iFlags && l_iFound < 1 && strlen(g_cSMFLAGS[i][g_iLength]) > 0)
			{
				zclassMenu.AddItem("", g_cHumanClasses[i][g_iLength]);
				l_iFound++;
			}
			if (l_iFound == 0)
			{
				zclassMenu.AddItem("", g_cHumanClasses[i][g_iLength], ITEMDRAW_DISABLED);
			}
		}
	}
	zclassMenu.ExitButton = true;
	zclassMenu.ExitBackButton = true;
	zclassMenu.Display(client, 0);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public int Zombieclass_Menu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		char l_cInfo[4];
		g_iClientZMClasses[client] = selection + g_iZMBeginindex;
		IntToString(g_iClientZMClasses[client], l_cInfo, sizeof(l_cInfo));
		SetClientCookie(client, g_hClientZMCookie, l_cInfo);
		if (g_bSwitchingIndex && GetClientTeam(client) == CS_TEAM_T)
		{
			SelectWaveBasedZM(client, 1);
		}
	}
	else if (action == MenuAction_End) 
	{
		delete(menu);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public int Humanclass_Menu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		char l_cInfo[4];
		IntToString(selection, l_cInfo, sizeof(l_cInfo));
		SetClientCookie(client, g_hClientHumanCookie, l_cInfo);
		g_iClientHumanClasses[client] = selection;
		if (g_bSwitchingIndex && GetClientTeam(client) == CS_TEAM_CT)
		{
			SelectWavebasedHuman(client);
		}
	}
	else if (action == MenuAction_End) 
	{
		delete(menu);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action AddDownloadContent()
{
	Handle l_hFile = INVALID_HANDLE;
	char l_cLine[g_dLength];
	l_hFile = OpenFile(g_cPathsDownload, "r");
	if (l_hFile == INVALID_HANDLE)
	{
		Handle l_kv = CreateKeyValues("DownloadTable");
		KeyValuesToFile(l_kv, g_cPathsDownload);
		CloseHandle(l_kv);
		delete l_hFile;
		return Plugin_Handled;
	}
	while (!IsEndOfFile(l_hFile) && ReadFileLine(l_hFile, l_cLine, sizeof(l_cLine)))
	{
		TrimString(l_cLine);
		if (strlen(l_cLine) > 0 && StrContains(l_cLine, "//") == -1 && StrContains(l_cLine, "\"") == -1 && StrContains(l_cLine, "{") == -1 &&
		StrContains(l_cLine, "}") == -1)
		{
			AddFileToDownloadsTable(l_cLine);
		}
	}
	delete l_hFile;
	return Plugin_Handled;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void LoadExtraSettings()
{
	Handle l_hFile = INVALID_HANDLE;
	char l_cLine[g_dLength];
	if (!FileExists(g_cPathsExtra))
	{
		CreateDefaultExtraFile();
	}
	l_hFile = OpenFile(g_cPathsExtra, "r");
	while (!IsEndOfFile(l_hFile) && ReadFileLine(l_hFile, l_cLine, sizeof(l_cLine)))
	{
		if (StrContains(l_cLine, "Respawn Time") > -1)
		{
			ReplaceStrings(l_cLine, "Respawn Time");
			if (StringToFloat(l_cLine) > 0.0)
				g_fRespawnTimer = StringToFloat(l_cLine);
			else
				g_fRespawnTimer = 5.0;
		}
		if (StrContains(l_cLine, "Global command") > -1)
		{
			ReplaceStrings(l_cLine, "Global command");
			if (strlen(l_cLine) > 1)
				ServerCommand(l_cLine);
		}
		if (StrContains(l_cLine, "round start zclass time") > -1)
		{
			ReplaceStrings(l_cLine, "round start zclass time");
			if (StringToFloat(l_cLine) > 0.0)
				g_fSwitchingTimer = StringToFloat(l_cLine);
			else
				g_fSwitchingTimer = 15.0;
		}
		if (StrContains(l_cLine, "zm spawn protection") > -1)
		{
			ReplaceStrings(l_cLine, "zm spawn protection");
			if (StringToFloat(l_cLine) > 0.0)
				g_fZMSpawnProtection = StringToFloat(l_cLine);
			else
				g_fZMSpawnProtection = 1.0;
		}
		if (StrContains(l_cLine, "human spawn protection") > -1)
		{
			ReplaceStrings(l_cLine, "human spawn protection");
			if (StringToFloat(l_cLine) > 0.0)
				g_fHumanSpawnProtection = StringToFloat(l_cLine);
			else
				g_fHumanSpawnProtection = 4.0;
		}
		if (StrContains(l_cLine, "zmsoundInterval") > -1)
		{
			ReplaceStrings(l_cLine, "zmsoundInterval");
			if (StringToFloat(l_cLine) > 0.0)
				g_fZMSounds = StringToFloat(l_cLine);
			else
				g_fZMSounds = 15.0;
		}
		if (StrContains(l_cLine, "botStuckCount") > -1)
		{
			ReplaceStrings(l_cLine, "botStuckCount");
			if (StringToInt(l_cLine) > 1)
				g_iBotStuckCounts = StringToInt(l_cLine);
			else
				g_iBotStuckCounts = 3;
		}
		if (StrContains(l_cLine, "botStuckPush") > -1)
		{
			ReplaceStrings(l_cLine, "botStuckPush");
			if (StringToInt(l_cLine) > 1)
				g_fBotStuckPush = StringToFloat(l_cLine);
			else
				g_fBotStuckPush = 250.0;
		}
		if (StrContains(l_cLine, "zmsoundsFile") > -1)
		{
			ReplaceStrings(l_cLine, "zmsoundsFile");
			ReplaceString(l_cLine, sizeof(l_cLine), "sound/", "*/");
			Format(g_cZMSounds[g_iSoundIndexes][g_iLength], sizeof(g_cZMSounds), l_cLine);
			FakePrecacheSound(g_cZMSounds[g_iSoundIndexes][g_iLength]);
			g_iSoundIndexes++;
		}
	}
	delete l_hFile;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void loadWeapons()
{
	KeyValues kv = CreateKeyValues("Weapons");
	if (!FileExists(g_cPathsWeapons))
	{
		CreateBackUpWeapons();
	}
	kv.ImportFromFile(g_cPathsWeapons);
	kv.GotoFirstSubKey();
	kv.GetString("weaponentity", g_cWeaponEntity[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponEntity));
	kv.GetString("zmarketname", g_cWeaponNames[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponNames));
	g_iWeaponSlot[g_iWeaponIndex] = kv.GetNum("weaponslot");
	g_iWeaponPrice[g_iWeaponIndex] = kv.GetNum("zmarketprice");
	kv.GetString("zmarketcommand", g_cWeaponCommand[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponCommand));
	g_iWeaponIndex++;
	while (kv.GotoNextKey())
	{
		kv.GetString("weaponentity", g_cWeaponEntity[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponEntity));
		kv.GetString("zmarketname", g_cWeaponNames[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponNames));
		g_iWeaponSlot[g_iWeaponIndex] = kv.GetNum("weaponslot");
		g_iWeaponPrice[g_iWeaponIndex] = kv.GetNum("zmarketprice");
		kv.GetString("zmarketcommand", g_cWeaponCommand[g_iWeaponIndex][g_iLength], sizeof(g_cWeaponCommand));
		g_iWeaponIndex++;
	}
	delete kv;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action LoadClasses()
{
	Handle l_hFile = INVALID_HANDLE;
	Handle l_hFileZM = INVALID_HANDLE;
	char l_cLine[g_dLength];
	g_iLoadClassesIndex = 0;
	l_hFile = OpenFile(g_cPathsClassHuman, "r");
	l_hFileZM = OpenFile(g_cPathsClassZM, "r");
	if (!FileExists(g_cPathsClassHuman) && !FileExists(g_cPathsClassZM))
	{
		//PrintToChatAll("File does not exist g_cPathsClassHuman: %s", g_cPathsClassHuman);
		//PrintToChatAll("File does not exist g_cPathsClassZM: %s", g_cPathsClassZM);
		CreateBackUpClassHuman(g_iLoadClassesIndex);
		CreateBackUpClassZM(g_iLoadClassesIndex);
		delete l_hFile;
		delete l_hFileZM;
		return Plugin_Handled;
	}
	else if (!FileExists(g_cPathsClassHuman))
	{
		CreateBackUpClassHuman(g_iLoadClassesIndex);
		delete l_hFile;
		delete l_hFileZM;
		return Plugin_Handled;
	}
	else if (!FileExists(g_cPathsClassZM))
	{
		CreateBackUpClassZM(g_iLoadClassesIndex);
		delete l_hFile;
		delete l_hFileZM;
		return Plugin_Handled;
	}
	//first indexes go to human classes, all afterfollowing to zms
	while (!IsEndOfFile(l_hFile) && ReadFileLine(l_hFile, l_cLine, sizeof(l_cLine)))
	{
		ReadingClassValuesFromFile(g_iLoadClassesIndex, l_cLine);
	}
	g_iZMBeginindex = g_iLoadClassesIndex;
	while (!IsEndOfFile(l_hFileZM) && ReadFileLine(l_hFileZM, l_cLine, sizeof(l_cLine)))
	{
		ReadingClassValuesFromFile(g_iLoadClassesIndex, l_cLine);
	}
	delete l_hFileZM;
	delete l_hFile;
	return Plugin_Handled;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
	g_iToolsVelocity = FindDataMapInfo(0, "m_vecAbsVelocity");
	g_iWave = 1;
	//load content
	AddDownloadContent();
	LoadClasses();
	LoadExtraSettings();
	loadWeapons();
	CreateTimer(0.5, Timer_restrictWeapons, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, Timer_CheckIfBotsStuck, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(g_fZMSounds, Timer_zombieSounds, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void OnClientPostAdminCheck(int client) 
{
	g_bClientProtection[client] = false;
	g_bFallDamage[client] = false;
	g_bShouldBeHuman[client] = false;
	g_bShouldBeZM[client] = false;
	g_fKnockBackIndex[client] = 1.0;
	g_fJumpHeightIndex[client] = 1.0;
 	g_fJumpDistanceIndex[client] = 1.0;
	g_iClientRespawnCount[client] = 0;
	char sCookieValue[12];
	GetClientCookie(client, g_hClientZMCookie, sCookieValue, sizeof(sCookieValue));
	if (sCookieValue[0])
	{
		g_iClientZMClasses[client] = StringToInt(sCookieValue);
	}
	else 
	{
		g_iClientZMClasses[client] = g_iZMBeginindex;
	}
	GetClientCookie(client, g_hClientHumanCookie, sCookieValue, sizeof(sCookieValue));
	if (sCookieValue[0])
	{
		g_iClientHumanClasses[client] = StringToInt(sCookieValue);
	}
	else 
	{
		g_iClientHumanClasses[client] = 0;
	}
 	SetAdminGroups(client);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void SetAdminGroups(int client)
{
	AdminId l_AdminID = GetUserAdmin(client);
	int l_iAdminGroupCount = GetAdminGroupCount(l_AdminID);
	char l_cbuffer[g_dLength];
	for (int j = 0; j < l_iAdminGroupCount; j++)
	{
		GetAdminGroup(l_AdminID, j, l_cbuffer, sizeof(l_cbuffer));
		Format(g_cAdminGroups[client][j][g_iLength], sizeof(g_cAdminGroups), l_cbuffer);
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	g_bClientProtection[client] = false;
	g_bFallDamage[client] = false;
	g_bShouldBeHuman[client] = false;
	g_bShouldBeZM[client] = false;
	g_fKnockBackIndex[client] = 1.0;
	g_fJumpHeightIndex[client] = 1.0;
 	g_fJumpDistanceIndex[client] = 1.0;
 	g_iClientRespawnCount[client] = 0;
 	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public MRESReturn DHook_GetPlayerMaxSpeed(int client, Handle hReturn) 
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return MRES_Ignored;

	DHookSetReturn(hReturn, StringToFloat(g_cSpeed[g_iSpeedIndex[client]][g_iLength]));
	return MRES_Override;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void Event_roundStart(Handle event, const char[] name, bool dontBroadcast)
{
	int l_iHumanPlayers;
	g_bRoundInProgress = false;
	g_bSwitchingIndex = true;
	CreateTimer(g_fSwitchingTimer, Timer_switchingModel, INVALID_HANDLE);
	RetrieveWaveSettings(g_iWave);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsClientSourceTV(i))
		{
			if (IsFakeClient(i))
			{
				SelectWaveBasedZM(i, 0);
			}
			else if (GetClientTeam(i) > CS_TEAM_SPECTATOR)
			{
				g_iClientRespawnCount[i] = g_iClientRespawnCountNum;
				SelectWavebasedHuman(i);
				l_iHumanPlayers++;
			}
		}
	}
	if (l_iHumanPlayers < 1)
		ServerCommand("bot_kick");
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action RetrieveWaveSettings(int wave)
{
	Handle l_hWave = INVALID_HANDLE;
	l_hWave = OpenFile(g_cPathsWaveSettings, "r");
	if (l_hWave == INVALID_HANDLE)
	{
		CreateDefaultWave();
		delete l_hWave;
		return Plugin_Handled;
	}
	PrintToChatAll("WAVE: %i", wave);
	LoadWave(wave);
	delete l_hWave;
	return Plugin_Handled;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Timer_switchingModel(Handle timer, any data)
{
	g_bSwitchingIndex = false;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void LoadWave(int wave)
{
	KeyValues kv = CreateKeyValues("Waves");
	int l_iBotQuote;
	char l_cJumptokey[16];
	char l_cJumptokey1[16];
	char l_cLine[g_dLength];
	bool l_bKeyIndex = false;
	Handle l_hFile = INVALID_HANDLE;
	l_hFile = OpenFile(g_cPathsWaveSettings, "r");
	Format(l_cJumptokey, sizeof(l_cJumptokey), "Wave %i", wave);
	Format(l_cJumptokey1, sizeof(l_cJumptokey1), "Wave %i", wave +1);
	for (int i = 0; i < g_dIndexes; i++)
	{
		Format(g_cHumanClasses[i][g_iLength], sizeof(g_cHumanClasses), "");
		Format(g_cZMRoundClasses[i][g_iLength], sizeof(g_cZMRoundClasses), "");
	}
	kv.ImportFromFile(g_cPathsWaveSettings);
	if (kv.JumpToKey(l_cJumptokey, false))
	{
		g_bRoundInProgress = true;
		g_iZMScaleability = kv.GetNum("PlayerScaleAbility", 5);
		g_fZMHealthScaleability = kv.GetFloat("HealthScaleAbility", 1.0);
		g_iZMCount = kv.GetNum("Zombie Count", 5);
		if (g_iZMScaleability > 0)
		{
			g_iZMCount *= g_iZMScaleability;
		}
		g_iClientRespawnCountNum = kv.GetNum("Respawns", 5);
		l_iBotQuote = kv.GetNum("bot_scaling", 1);
		SettingBotQoute(l_iBotQuote);
		while (!IsEndOfFile(l_hFile) && ReadFileLine(l_hFile, l_cLine, sizeof(l_cLine)))
		{
			if (StrContains(l_cLine, l_cJumptokey) == -1 && !l_bKeyIndex)
			{
				continue;
			}
			l_bKeyIndex = true;
			if (StrContains(l_cLine, "wavecommand") > -1)
			{
				ReplaceStrings(l_cLine, "wavecommand");
				if (strlen(l_cLine) > 0)
					ServerCommand(l_cLine);
			}
			else if (StrContains(l_cLine, "Zombie Class") > -1)
			{
				ReplaceStrings(l_cLine, "Zombie Class");
				if (StrContains(l_cLine, "@all") > -1)
				{
					for (int i = g_iZMBeginindex; i < g_iLoadClassesIndex; i++)
					{
						Format(g_cZMRoundClasses[i][g_iLength], sizeof(g_cZMRoundClasses), g_cUniqueName[i][g_iLength]);
					}
				}
				else if (StrContains(l_cLine, "@groups") > -1)
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if ((strlen(g_cGroup[i][g_iLength]) > 0) && StrEqual(g_cTeam[i][g_iLength], "ZM"))
						{
							Format(g_cZMRoundClasses[i][g_iLength], sizeof(g_cZMRoundClasses), g_cUniqueName[i][g_iLength]);
						}
					}
				}
				else if (StrContains(l_cLine, "@flags") > -1)
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if (strlen(g_cSMFLAGS[i][g_iLength]) > 0 && StrEqual(g_cTeam[i][g_iLength], "ZM"))
						{
							Format(g_cZMRoundClasses[i][g_iLength], sizeof(g_cZMRoundClasses), g_cUniqueName[i][g_iLength]);
						}
					}
				}
				else
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if (StrEqual(l_cLine, g_cUniqueName[i][g_iLength], false))
						{
							//PrintToChatAll("l_cLine ZM SUCCESS: %s \n%i", l_cLine, i);
							Format(g_cZMRoundClasses[i][g_iLength], sizeof(g_cZMRoundClasses), g_cUniqueName[i][g_iLength]);
							break;
						}
					}
				}
			}
			else if (StrContains(l_cLine, "Human Class") > -1)
			{
				ReplaceStrings(l_cLine, "Human Class");
				if (StrContains(l_cLine, "@all") > -1)
				{	
					for (int i = 0; i < g_iZMBeginindex; i++)
					{
						Format(g_cHumanClasses[i][g_iLength], sizeof(g_cHumanClasses), g_cUniqueName[i][g_iLength]);
					}
				}
				else if (StrContains(l_cLine, "@groups") > -1)
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if (strlen(g_cGroup[i][g_iLength]) > 0 && StrEqual(g_cTeam[i][g_iLength], "Human"))
						{
							Format(g_cHumanClasses[i][g_iLength], sizeof(g_cHumanClasses), g_cUniqueName[i][g_iLength]);
						}
					}
				}
				else if (StrContains(l_cLine, "@flags") > -1)
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if (strlen(g_cSMFLAGS[i][g_iLength]) > 0 && StrEqual(g_cTeam[i][g_iLength], "Human"))
						{
							Format(g_cHumanClasses[i][g_iLength], sizeof(g_cHumanClasses), g_cUniqueName[i][g_iLength]);
							//PrintToChatAll("SUCCESS: g_cTeam[i][g_iLength]: %s", g_cTeam[i][g_iLength]);
							//PrintToChatAll("g_cHumanClasses[i][g_iLength]: %s", g_cHumanClasses[i][g_iLength]);
						}
					}
				}
				else
				{
					for (int i = 0; i < g_dIndexes; i++)
					{
						if (skipIndex(i))
						{
							continue;
						}
						if (StrEqual(l_cLine, g_cUniqueName[i][g_iLength], false))
						{
							//PrintToChatAll("l_cLine SUCCESS: %s \n%i", l_cLine, i);
							Format(g_cHumanClasses[i][g_iLength], sizeof(g_cHumanClasses), g_cUniqueName[i][g_iLength]);
							break;
						}
					}
				}
			}
			if (StrContains(l_cLine, l_cJumptokey1) > -1)
			{
				break;
			}
		}
	}
	else
	{
		g_iWave = 1;
		PrintToChatAll("Finished last Wave! Restarting...");
		CS_TerminateRound(5.0, CSRoundEnd_Draw, false);
	}
	delete kv;
	delete l_hFile;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void SettingBotQoute(int botscale)
{
	if (botscale < 1)
	{
		return;
	}
	int l_iPlayers;
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			l_iPlayers++;
		}
	}
	addBots(l_iPlayers * botscale);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void addBots(int botcount)
{
	ServerCommand("bot_kick");
	for (int i = 0; i < botcount; i++)
	{
		if (i > 32)
			continue;
		ServerCommand("bot_add_t");
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public bool skipIndex(int index)
{
	if (strlen(g_cTeam[index][g_iLength]) < 1 || strlen(g_cUniqueName[index][g_iLength]) < 1)
	{
		return true;
	}
	return false;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void CreateDefaultExtraFile()
{
	KeyValues kv = CreateKeyValues("ExtraSettings");
	kv.JumpToKey("Extras", true);
	kv.SetFloat("Respawn Time", 9.0);
	kv.SetFloat("round start zclass time", 15.0);
	kv.SetFloat("zm spawn protection", 1.0);
	kv.SetFloat("human spawn protection", 4.0);
	kv.SetFloat("zmsoundInterval", 15.0);
	kv.SetNum("botStuckCount", 3);
	kv.SetFloat("botStuckPush", 250.0);
	kv.SetString("zmsoundsFile", " ");
	kv.SetString("Global command", "mp_afterroundmoney 16000");
	kv.Rewind();
	kv.ExportToFile(g_cPathsExtra);
	delete kv;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void CreateDefaultWave()
{
	Handle l_hFile = INVALID_HANDLE;
	Handle l_hFileZM = INVALID_HANDLE;
	char l_cLine[g_dLength];
	char l_cHuman[g_dLength];
	char l_cZM[g_dLength];
	l_hFileZM = OpenFile(g_cPathsClassZM, "r");
	l_hFile = OpenFile(g_cPathsClassHuman, "r");
	while (!IsEndOfFile(l_hFileZM) && ReadFileLine(l_hFileZM, l_cLine, sizeof(l_cLine)))
	{
		if (StrContains(l_cLine, "unique name") > -1)
		{
			ReplaceStrings(l_cLine, "unique name");
			Format(l_cHuman, sizeof(l_cHuman), l_cLine);
			break;
		}
	}
	while (!IsEndOfFile(l_hFile) && ReadFileLine(l_hFile, l_cLine, sizeof(l_cLine)))
	{
		if (StrContains(l_cLine, "unique name") > -1)
		{
			ReplaceStrings(l_cLine, "unique name");
			Format(l_cZM, sizeof(l_cZM), l_cLine);
			break;
		}
	}
	KeyValues kv = CreateKeyValues("Waves");
	kv.JumpToKey("Wave 1", true);
	g_iZMScaleability = 5;
	g_fZMHealthScaleability = 1.0;
	g_iZMCount = 2;
	kv.SetNum("PlayerScaleAbility", g_iZMScaleability);
	kv.SetFloat("HealthScaleAbility", g_fZMHealthScaleability);
	kv.SetNum("Zombie Count", g_iZMCount); //creates 10 zombies per player
	kv.SetNum("Respawns", 5);
	kv.SetNum("bot_scaling", 1);
	kv.SetString("wavecommand", "mp_roundtime 14");
	//hopefully creates now
	kv.SetString("Zombie Class", l_cHuman); //Selects backup classes
	kv.SetString("Human Class", l_cZM);
	kv.Rewind();
	kv.ExportToFile(g_cPathsWaveSettings);
	delete kv;
	delete l_hFileZM;
	delete l_hFile;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void CreateBackUpClassZM(int index)
{
	KeyValues kv = CreateKeyValues("Classes");
	Format(g_cUniqueName[index][g_iLength], sizeof(g_cUniqueName), "Zombie Backup Class");
	kv.JumpToKey(g_cUniqueName[index][g_iLength], true);
	kv.SetString("unique name", g_cUniqueName[index][g_iLength]);
	Format(g_cTeam[index][g_iLength], sizeof(g_cTeam), "ZM");
	kv.SetString("team", g_cTeam[index][g_iLength]);
	Format(g_cGroup[index][g_iLength], sizeof(g_cGroup), " ");
	kv.SetString("group", g_cGroup[index][g_iLength]);
	Format(g_cSMFLAGS[index][g_iLength], sizeof(g_cSMFLAGS), " ");
	kv.SetString("sm_flags", g_cSMFLAGS[index][g_iLength]);
	Format(g_cModelPath[index][g_iLength], sizeof(g_cModelPath), "models/player/tm_pirate_varianta.mdl");
	kv.SetString("model path", g_cModelPath[index][g_iLength]);
	Format(g_cNoFallDmg[index][g_iLength], sizeof(g_cNoFallDmg), "YES");
	kv.SetString("no_fall_damage", g_cNoFallDmg[index][g_iLength]);
	Format(g_cHealth[index][g_iLength], sizeof(g_cHealth), "250");
	kv.SetString("health", g_cHealth[index][g_iLength]);
	Format(g_cSpeed[index][g_iLength], sizeof(g_cSpeed), "250.0");
	kv.SetString("speed", g_cSpeed[index][g_iLength]);
	Format(g_cKnockback[index][g_iLength], sizeof(g_cKnockback), "2.5");
	kv.SetString("knockback", g_cKnockback[index][g_iLength]);
	Format(g_cJumpHeight[index][g_iLength], sizeof(g_cJumpHeight), "1.0");
	kv.SetString("jump_height", g_cJumpHeight[index][g_iLength]);
	Format(g_cJumpDistance[index][g_iLength], sizeof(g_cJumpDistance), "1.0");
	kv.SetString("jump_distance", g_cJumpDistance[index][g_iLength]);
	kv.Rewind();
	kv.ExportToFile(g_cPathsClassZM);
	delete kv;
}
public void CreateBackUpClassHuman(int index)
{
	KeyValues kv = CreateKeyValues("Classes");
	Format(g_cUniqueName[index][g_iLength], sizeof(g_cUniqueName), "Human Backup Class");
	kv.JumpToKey(g_cUniqueName[index][g_iLength], true);
	kv.SetString("unique name", g_cUniqueName[index][g_iLength]);
	Format(g_cTeam[index][g_iLength], sizeof(g_cTeam), "Human");
	kv.SetString("team", g_cTeam[index][g_iLength]);
	Format(g_cGroup[index][g_iLength], sizeof(g_cGroup), " ");
	kv.SetString("group", g_cGroup[index][g_iLength]);
	Format(g_cSMFLAGS[index][g_iLength], sizeof(g_cSMFLAGS), " ");
	kv.SetString("sm_flags", g_cSMFLAGS[index][g_iLength]);
	Format(g_cModelPath[index][g_iLength], sizeof(g_cModelPath), "models/player/tm_pirate_varianta.mdl");
	kv.SetString("model path", g_cModelPath[index][g_iLength]);
	Format(g_cNoFallDmg[index][g_iLength], sizeof(g_cNoFallDmg), "NO");
	kv.SetString("no_fall_damage", g_cNoFallDmg[index][g_iLength]);
	Format(g_cHealth[index][g_iLength], sizeof(g_cHealth), "100");
	kv.SetString("health", g_cHealth[index][g_iLength]);
	Format(g_cSpeed[index][g_iLength], sizeof(g_cSpeed), "250.0");
	kv.SetString("speed", g_cSpeed[index][g_iLength]);
	Format(g_cKnockback[index][g_iLength], sizeof(g_cKnockback), "1.0");
	kv.SetString("knockback", g_cKnockback[index][g_iLength]);
	Format(g_cJumpHeight[index][g_iLength], sizeof(g_cJumpHeight), "1.0");
	kv.SetString("jump_height", g_cJumpHeight[index][g_iLength]);
	Format(g_cJumpDistance[index][g_iLength], sizeof(g_cJumpDistance), "1.0");
	kv.SetString("jump_distance", g_cJumpDistance[index][g_iLength]);
	kv.Rewind();
	kv.ExportToFile(g_cPathsClassHuman);
	delete kv;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void CreateBackUpWeapons()
{
	KeyValues kv = CreateKeyValues("Weapons");
	kv.JumpToKey("Glock", true);
	kv.SetString("weaponentity", "weapon_glock");
	kv.SetString("zmarketname", "Glock");
	kv.SetNum("weaponslot", 1);
	kv.SetNum("zmarketprice", 200);
	kv.SetString("zmarketcommand", "sm_glock");
	kv.Rewind();
	kv.ExportToFile(g_cPathsWeapons);
	delete kv;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public void ReadingClassValuesFromFile(int index, char[] Line)
{
	char li_c[g_dLength];
	Format(li_c, sizeof(li_c), Line);
	if (StrContains(Line, "unique name") > -1)
	{
		ReplaceStrings(li_c, "unique name");
		Format(g_cUniqueName[index][g_iLength], sizeof(g_cUniqueName), li_c);
	}
	else if (StrContains(Line, "team") > -1)
	{
		ReplaceStrings(li_c, "team");
		Format(g_cTeam[index][g_iLength], sizeof(g_cTeam), li_c);
	}
	else if (StrContains(Line, "group") > -1)
	{
		ReplaceStrings(li_c, "group");
		Format(g_cGroup[index][g_iLength], sizeof(g_cGroup), li_c);
	}
	else if (StrContains(Line, "sm_flags") > -1)
	{
		ReplaceStrings(li_c, "sm_flags");
		Format(g_cSMFLAGS[index][g_iLength], sizeof(g_cSMFLAGS), li_c);
	}
	else if (StrContains(Line, "model path") > -1)
	{
		ReplaceStrings(li_c, "model path");
		Format(g_cModelPath[index][g_iLength], sizeof(g_cModelPath), li_c);
		PrecacheModel(li_c);
	}
	else if (StrContains(Line, "no_fall_damage") > -1)
	{
		ReplaceStrings(li_c, "no_fall_damage");
		Format(g_cNoFallDmg[index][g_iLength], sizeof(g_cNoFallDmg), li_c);
	}
	else if (StrContains(Line, "health") > -1)
	{
		ReplaceStrings(li_c, "health");
		Format(g_cHealth[index][g_iLength], sizeof(g_cHealth), li_c);
	}
	else if (StrContains(Line, "speed") > -1)
	{
		ReplaceStrings(li_c, "speed");
		Format(g_cSpeed[index][g_iLength], sizeof(g_cSpeed), li_c);
	}
	else if (StrContains(Line, "knockback") > -1)
	{
		ReplaceStrings(li_c, "knockback");
		Format(g_cKnockback[index][g_iLength], sizeof(g_cKnockback), li_c);
	}
	else if (StrContains(Line, "jump_height") > -1)
	{
		ReplaceStrings(li_c, "jump_height");
		Format(g_cJumpHeight[index][g_iLength], sizeof(g_cJumpHeight), li_c);
	}
	else if (StrContains(Line, "jump_distance") > -1)
	{
		ReplaceStrings(li_c, "jump_distance");
		Format(g_cJumpDistance[index][g_iLength], sizeof(g_cJumpDistance), li_c);
		g_iLoadClassesIndex++;
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action Event_OnFullConnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid")); 
	if (!client || !IsClientInGame(client)) 
		return Plugin_Continue; 
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
		{
			ChangeClientTeam(client, CS_TEAM_T);
			if (!IsPlayerAlive(client))
				CS_RespawnPlayer(client);
			else
				ApplySettingsEvent(client);
			return Plugin_Continue;
		}
	}
	ChangeClientTeam(client, CS_TEAM_CT);
	ServerCommand("mp_restartgame 1");
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action ApplySettings(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ApplySettingsEvent(client);
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action ApplySettingsEvent(int client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (g_bShouldBeHuman[client])
	{
		SelectWavebasedHuman(client);
		g_bShouldBeHuman[client] = false;
	}
	else if (g_bShouldBeZM[client])
	{
		SelectWaveBasedZM(client, 1);
		g_bShouldBeZM[client] = false;
	}
	else if (IsFakeClient(client))
	{
		SelectWaveBasedZM(client, 0);
	}
	else if (g_iClientRespawnCount[client] > 0)
	{
		SelectWavebasedHuman(client);
	}
	else
	{
		SelectWaveBasedZM(client, 1);
	}
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public bool shouldApplySettings(int client, int team, int teamDest)
{
	if (team != teamDest)
	{
		ChangeClientTeam(client, teamDest);
		if (!IsPlayerAlive(client))
			CS_RespawnPlayer(client);
		else
			ApplySettingsEvent(client);
		return false;
	}
	return true;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action SelectWavebasedHuman(int client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	int l_iTeam = GetClientTeam(client);
	if (shouldApplySettings(client, l_iTeam, CS_TEAM_CT))
	{
		ModelSelection(client, 2, g_iClientHumanClasses[client]);
	}
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action SelectWaveBasedZM(int client, int state)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	int l_iTeam = GetClientTeam(client);
	int l_iZMIndex;
	int l_ibotIndex;
	if (shouldApplySettings(client, l_iTeam, CS_TEAM_T))
	{
		if (state == 0)
		{
			for (int i = 0; i < g_dIndexes; i++)
			{
				if (strlen(g_cZMRoundClasses[i][g_iLength]) > 0 && strlen(g_cGroup[i][g_iLength]) < 1 && strlen(g_cSMFLAGS[i][g_iLength]) < 1)
				{
					l_iZMIndex++;
				}
			}
			l_ibotIndex = GetRandomInt(0, l_iZMIndex -1);
			l_iZMIndex = 0;
			for (int i = 0; i < g_dIndexes; i++)
			{
				if (strlen(g_cZMRoundClasses[i][g_iLength]) > 0 && strlen(g_cGroup[i][g_iLength]) < 1 && strlen(g_cSMFLAGS[i][g_iLength]) < 1)
				{
					if (l_ibotIndex == l_iZMIndex)
					{
						g_iClientZMClasses[client] = i;
						break;
					}
					else
						l_iZMIndex++;
				}
			}
		}
		else if (strlen(g_cZMRoundClasses[g_iClientZMClasses[client]][g_iLength]) < 1)
		{
			for (int i = 0; i < g_dIndexes; i++)
			{
				if (strlen(g_cZMRoundClasses[i][g_iLength]) > 0)
				{
					g_iClientZMClasses[client] = i;
					break;
				}	
			}
		}
		ModelSelection(client, state, g_iClientZMClasses[client]);
	}
	return Plugin_Handled;
}
//----------------------------------------------------------------------------------------------------
// Purpose: 
//----------------------------------------------------------------------------------------------------
public Action ModelSelection(int client, int state, int modelIndex)
{
	//state 0 = zombie bots, state 1 = zombie players, state 2 = human players
	char l_cUniqueModel[g_dLength];
	int l_iModelIndex;
	l_iModelIndex = modelIndex;
	if (state < 2)
	{
		Format(l_cUniqueModel, sizeof(l_cUniqueModel), g_cZMRoundClasses[l_iModelIndex][g_iLength]);
	}
	else if (state == 2)
	{
		Format(l_cUniqueModel, sizeof(l_cUniqueModel), g_cHumanClasses[l_iModelIndex][g_iLength]);
	}
	for (int i = 0; i < g_dIndexes; i++)
	{
		if (strlen(g_cUniqueName[i][g_iLength]) < 1)
		{
			continue;
		}
		if (StrContains(g_cUniqueName[i][g_iLength], l_cUniqueModel, false) > -1)
		{
			if (StrContains(g_cModelPath[i][g_iLength], "mdl") == -1)
			{
				//incorrect modelpaths crash at SetEntityModel
				LoadClasses();
				ForcePlayerSuicide(client);
				return Plugin_Continue;
			}
			SetEntityModel(client, g_cModelPath[i][g_iLength]);
			SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			g_bClientProtection[client] = true;
			if (StrContains(g_cNoFallDmg[i][g_iLength], "YES") > -1)
				g_bFallDamage[client] = true;
			else
				g_bFallDamage[client] = false;
			if (state < 2)
			{
				CreateTimer(g_fZMSpawnProtection, Timer_StopProtection, client);
				Client_SetActiveWeapon(client, GetPlayerWeaponSlot(client, 2));
			}
			else
			{
				CreateTimer(g_fHumanSpawnProtection, Timer_StopProtection, client);
				Client_SetActiveWeapon(client, GetPlayerWeaponSlot(client, 1));
			}
			if (state < 2 && RoundFloat(g_fZMHealthScaleability * 10.0) > 0.0)
				SetEntityHealth(client, StringToInt(g_cHealth[i][g_iLength]) * RoundFloat(g_fZMHealthScaleability * 10.0) / 10);
			else
				SetEntityHealth(client, StringToInt(g_cHealth[i][g_iLength]));
			g_iSpeedIndex[client] = i;
			DHookEntity(g_hGetPlayerMaxSpeed, true, client);
			g_fKnockBackIndex[client] = StringToFloat(g_cKnockback[i][g_iLength]);
			g_fJumpHeightIndex[client] = StringToFloat(g_cJumpHeight[i][g_iLength]);
 			g_fJumpDistanceIndex[client] = StringToFloat(g_cJumpDistance[i][g_iLength]);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_restrictWeapons(Handle timer, any userid) 
{
	int l_iWeapon;
	for(int j = 1; j <= MaxClients; j++)
	{
		if (IsValidClient(j) && GetClientTeam(j) == CS_TEAM_T)
		{
			for (int i = 0; i < 5; i++)
			{
				l_iWeapon = GetPlayerWeaponSlot(j, i);
				if (l_iWeapon != -1 && i != 2)
				{
					RemovePlayerItem(j, l_iWeapon);
				}	
			}
		}
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_CheckIfBotsStuck(Handle timer, any userid)
{
	float l_fClientVelocity[3];
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsValidClient(i) && IsFakeClient(i) && IsPlayerAlive(i))
		{
			GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", l_fClientVelocity);
			if (l_fClientVelocity[0] < 30.0 && l_fClientVelocity[0] > -30.0 &&
			l_fClientVelocity[1] < 30.0 && l_fClientVelocity[1] > -30.0)
			{
				g_iBotStuckindex[i]++;
			}
			else
			{
				g_iBotStuckindex[i] = 0;
			}
			if (g_iBotStuckindex[i] > g_iBotStuckCounts)
			{
				l_fClientVelocity[0] -= GetRandomInt(50, 250);
				l_fClientVelocity[1] -= GetRandomInt(50, 250);
				l_fClientVelocity[2] = g_fBotStuckPush * 5;
				Entity_SetAbsVelocity(i, l_fClientVelocity);
				g_iBotStuckindex[i] = 0;
			}
		}
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_zombieSounds(Handle timer, any userid) 
{
	int[] l_clients = new int[MaxClients + 1];
	int l_client;
	int l_iclientCount;
	int l_iSoundIndexes;
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == CS_TEAM_T)
		{
			l_clients[l_iclientCount++] = i;
		}
	}
	l_client = l_clients[GetRandomInt(0, l_iclientCount - 1)];
	l_iSoundIndexes = GetRandomInt(0, g_iSoundIndexes - 1);
	/*
	PrintToChatAll("emitting sound from client: %N", l_client);
	PrintToChatAll("with l_iSoundIndexes: %i", l_iSoundIndexes);
	PrintToChatAll("g_cZMSounds[l_iSoundIndexes][g_iLength]: %s", g_cZMSounds[l_iSoundIndexes][g_iLength]);
	EmitSound(l_clients, l_iclientCount, g_cZMSounds[l_iSoundIndexes][g_iLength], l_client, SNDCHAN_BODY, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.45, SNDPITCH_NORMAL);
	EmitSoundToAll(g_cZMSounds[l_iSoundIndexes][g_iLength]);
	*/
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			EmitSoundToClient(i, g_cZMSounds[l_iSoundIndexes][g_iLength], l_client);
		}
	}
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_Respawn(Handle timer, any userid) 
{ 
	int client = GetClientOfUserId(userid); 
	if (client == 0) 
		return Plugin_Continue; 
	
	if (!IsValidClient(client) || IsPlayerAlive(client) || GetClientTeam(client) <= CS_TEAM_SPECTATOR)
	{
		return Plugin_Continue;
	}
	UpdateWaveCount(client);
	if (!IsFakeClient(client) && g_iClientRespawnCount[client] < 1)
	{
		ChangeClientTeam(client, CS_TEAM_T);
	}
	else if (IsFakeClient(client) && GetClientTeam(client) != CS_TEAM_T)
	{
		ChangeClientTeam(client, CS_TEAM_T);
	}
	else if (!IsFakeClient(client) && GetClientTeam(client) != CS_TEAM_CT)
	{
		ChangeClientTeam(client, CS_TEAM_CT);
	}
	CS_RespawnPlayer(client);
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Timer_StopProtection(Handle timer, int client)
{
	if (IsValidClient(client))
		g_bClientProtection[client] = false;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid")); 
	if(!client || !IsClientInGame(client)) 
		return Plugin_Continue; 
	
	if (IsFakeClient(client))
	{
		CreateTimer(1.0, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);	
	}
	else
	{
		CreateTimer(g_fRespawnTimer, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue; 
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action UpdateWaveCount(int client)
{
	//PrintToChatAll("Player %N died", client);
	char l_cCount[g_dIndexes];
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		g_iClientRespawnCount[client]--;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
			{
				return Plugin_Handled;
			}
		}
		PrintToChatAll("All Humans died!");
		CS_TerminateRound(4.0, CSRoundEnd_TerroristWin, false);
		return Plugin_Handled;
	}
	else if (GetClientTeam(client) == CS_TEAM_T)
	{
		g_iZMCount--;
		SetHudTextParams(-0.5, 0.8, 10.0, 255, 0, 255, 255, 1, 0.1, 0.1, 0.1);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				Format(l_cCount, sizeof(l_cCount), "Remaining Zombies: %i", g_iZMCount);
				ShowHudText(i, 3, l_cCount);
			}
		}
	}
	if (g_iZMCount == 0 && g_bRoundInProgress)
	{
		PrintToChatAll("Won Round!");
		CS_TerminateRound(4.0, CSRoundEnd_CTWin, false);
		g_iWave++;
		g_bRoundInProgress = false;
	}
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype) 
{
	if (g_bClientProtection[client])
		return Plugin_Handled;
	else if (damagetype & DMG_FALL && g_bFallDamage[client])
		return Plugin_Handled;
	return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: zombie reloaded copied knockback
//----------------------------------------------------------------------------------------------------
public Action EventPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
    // Get all required event info.
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int l_iDmg_health = GetEventInt(event, "dmg_health");
    char l_cWeapon[g_dIndexes];
    if (client < 1 || attacker < 1)
    {
   		return Plugin_Continue;
  	}
    if (GetClientTeam(client) != CS_TEAM_T || GetClientTeam(attacker) != CS_TEAM_CT)
    {
   		return Plugin_Continue;
  	}
    GetEventString(event, "weapon", l_cWeapon, sizeof(l_cWeapon));
    KnockbackOnClientHurt(client, attacker, l_cWeapon, l_iDmg_health);
    return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose: zombie reloaded copy paste
//----------------------------------------------------------------------------------------------------
public void KnockbackOnClientHurt(int client, int attacker, const char[] weapon, int dmg_health)
{
    float l_fKnockback = g_fKnockBackIndex[client];
    float l_fClientloc[3];
    float l_fAttackerloc[3];
    GetClientAbsOrigin(client, l_fClientloc);
    if (StrEqual(weapon, "hegrenade"))
    {
        if (KnockbackFindExplodingGrenade(l_fAttackerloc) == -1)
        {
            return;
        }
    }
    else
    {
        GetClientEyePosition(attacker, l_fAttackerloc);
        float l_fAttackerange[3];
        GetClientEyeAngles(attacker, l_fAttackerange);
        TR_TraceRayFilter(l_fAttackerloc, l_fAttackerange, MASK_ALL, RayType_Infinite, KnockbackTRFilter);
        TR_GetEndPosition(l_fClientloc);
    }
    l_fKnockback *= float(dmg_health);
    KnockbackSetVelocity(client, l_fAttackerloc, l_fClientloc, l_fKnockback);
}
//----------------------------------------------------------------------------------------------------
// Purpose: Zombie reloaded knockback
//----------------------------------------------------------------------------------------------------
public void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude)
{
    float vector[3];
    MakeVectorFromPoints(startpoint, endpoint, vector);
    NormalizeVector(vector, vector);
    ScaleVector(vector, magnitude);
    if (GetEngineVersion() == Engine_CSGO)
    {
        int flags = GetEntityFlags(client);
        float velocity[3];
        //tools_functions.inc
        ToolsGetClientVelocity(client, velocity);
        if (velocity[2] > CSGO_KNOCKBACK_BOOST_MAX)
        {
            vector[2] = 0.0;
        }
        else if (flags & FL_ONGROUND && vector[2] < CSGO_KNOCKBACK_BOOST)
        {
            vector[2] = CSGO_KNOCKBACK_BOOST;
        }
    }
    // ADD the given vector to the client's current velocity. tools_functions.inc
    ToolsClientVelocity(client, vector);
}
//----------------------------------------------------------------------------------------------------
// Purpose: Zombie reloaded trfilter
//----------------------------------------------------------------------------------------------------
public bool KnockbackTRFilter(int entity, int contentsMask)
{
    if (entity > 0 && entity < MAXPLAYERS)
    {
        return false;
    }
    return true;
}
//----------------------------------------------------------------------------------------------------
// Purpose: Zombie reloaded applying grenades
//----------------------------------------------------------------------------------------------------
public int KnockbackFindExplodingGrenade(float heLoc[3])
{
    char l_cClassname[g_dIndexes];
    // Find max entities and loop through all of them.
    int l_iMaxentities = GetMaxEntities();
    for (int x = MaxClients; x <= l_iMaxentities; x++)
    {
        // If entity is invalid, then stop.
        if (!IsValidEdict(x))
        {
            continue;
        }
        // If entity isn't a grenade, then stop.
        GetEdictClassname(x, l_cClassname, sizeof(l_cClassname));
        if (!StrEqual(l_cClassname, "hegrenade_projectile", false))
        {
            continue;
        }
        // If m_takedamage is set to 0, we found our grenade.
        int takedamage = GetEntProp(x, Prop_Data, "m_takedamage");
        if (takedamage == 0)
        {
            // Return its location.
            GetEntPropVector(x, Prop_Send, "m_vecOrigin", heLoc);
            // Return its entity index.
            return x;
        }
    }
    // Didn't find the grenade.
    return -1;
}
//----------------------------------------------------------------------------------------------------
// Purpose: zombie reloaded jump height
//----------------------------------------------------------------------------------------------------
public Action EventPlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
    // Get all required event info.
    int index = GetClientOfUserId(GetEventInt(event, "userid"));
    // Fire post player_jump event.
    CreateTimer(0.0, EventPlayerJumpPost, index);
}
public Action EventPlayerJumpPost(Handle timer, int client)
{
    // If client isn't in-game, then stop.
    if (!IsClientInGame(client))
    {
        return Plugin_Handled;
    }
	// Get class jump multipliers.
    float distancemultiplier = g_fJumpDistanceIndex[client];
    float heightmultiplier = g_fJumpHeightIndex[client];

    // If both are set to 1.0, then stop here to save some work.
    if (distancemultiplier == 1.0 && heightmultiplier == 1.0)
    {
        return Plugin_Continue;
    }
    float vecVelocity[3];
    // Get client's current velocity.
    ToolsClientVelocity(client, vecVelocity, false);
    //maybe check JumpBoostIsBHop here
    
    // Apply height multiplier to jump vector.
    vecVelocity[2] *= heightmultiplier;
    // Set new velocity.
    ToolsClientVelocity(client, vecVelocity, true, false);
    return Plugin_Continue;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	return false;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void ToolsGetClientVelocity(int client, float vecVelocity[3])
{
    GetEntDataVector(client, g_iToolsVelocity, vecVelocity);
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void ToolsClientVelocity(int client, float vecVelocity[3], bool apply = true, bool stack = true)
{
    // If retrieve is true, then get client's velocity.
    if (!apply)
    {
        ToolsGetClientVelocity(client, vecVelocity);
        // Stop here.
        return;
    }
    // If stack is true, then add client's velocity.
    if (stack)
    {
        // Get client's velocity.
        float vecClientVelocity[3];
        ToolsGetClientVelocity(client, vecClientVelocity);
        AddVectors(vecClientVelocity, vecVelocity, vecVelocity);
    }
    // Apply velocity on client.
    SetEntDataVector(client, g_iToolsVelocity, vecVelocity);
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void ReplaceStrings(char[] str, char[] strReplace)
{
	char l_cstrFix[g_dLength];
	Format(l_cstrFix, sizeof(l_cstrFix), str);
	ReplaceString(l_cstrFix, sizeof(l_cstrFix), "\"", "");
	ReplaceString(l_cstrFix, sizeof(l_cstrFix), strReplace, "");
	TrimString(l_cstrFix);
	Format(str, sizeof(l_cstrFix), l_cstrFix);
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}
