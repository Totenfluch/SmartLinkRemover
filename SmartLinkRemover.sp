#pragma semicolon 1

#define PLUGIN_VERSION "1.5.7"

#include <sourcemod>
#include <sdktools>
#include <regex>

#pragma newdecls required

Regex urlPattern;
RegexError theError;
bool locked[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Smart URL Remover", 
	author = "Totenfluch [Fix by Agent Wesker]", 
	description = "Removes all Links from Player Names", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	CreateConVar("sm_smarturlremover_version", PLUGIN_VERSION, "Smart URL Remover Version", FCVAR_REPLICATED|FCVAR_DONTRECORD);

	HookEvent("player_changename", onPlayerNameChange, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("SayText2"), SayText2, true);
	
	char error[256];
	char pattern[256] = "((http:[/]{2}|https:[/]{2}|www[.])?([-a-zA-Z0-9]{2,}[.][a-zA-Z]{2,5})([a-zA-Z0-9]*?[.][a-zA-Z0-9]{2,5})?([/][a-zA-Z0-9]*)*(?=[^a-zA-Z0-9]|$))";
	urlPattern = CompileRegex(pattern, PCRE_CASELESS, error, sizeof(error), theError);
	if (theError != REGEX_ERROR_NONE)
		LogError(error);
}

public void OnClientPostAdminCheck(int client)
{
	locked[client] = false;
	if (checkImmunity(client))
	{
		return;
	}
	char cname[MAX_NAME_LENGTH];
	GetClientName(client, cname, sizeof(cname));
	checkNameURL(client, cname);
}

static bool checkNameURL(int client, char name[MAX_NAME_LENGTH])
{
	char match[MAX_NAME_LENGTH];
	int matchCount = MatchRegex(urlPattern, name, theError);
	if (matchCount > 0)
	{
		locked[client] = true;
		for (int i = 0; i < matchCount; i++)
		{
			//Substrings start at 0
			GetRegexSubString(urlPattern, i, match, sizeof(match));
			if (name[0] && match[0])
				ReplaceString(name, sizeof(name), match, "", false);
		}
		if (!name[0])
			strcopy(name, sizeof(name), "URLRemoved");
		
		//Thanks to https://forums.alliedmods.net/showpost.php?p=2497716&postcount=9
		char alias[32];
		Format(alias, sizeof(alias), "\t#%i", client);
		SetClientName(client, alias);
		
		DataPack packName = new DataPack();
		packName.WriteCell(client);
		packName.WriteString(name);
		RequestFrame(delayedNameChange, packName); 
		
		locked[client] = false;
		return true;
	}
	return false;
}

static void delayedNameChange(any data)
{
	DataPack packName = data;
	packName.Reset();
	int client = packName.ReadCell();
	char name[MAX_NAME_LENGTH];
	packName.ReadString(name, sizeof(name));
	SetClientName(client, name);
	delete packName;
}

public Action onPlayerNameChange(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (locked[client] || checkImmunity(client))
		return Plugin_Handled;
		
	char newname[MAX_NAME_LENGTH];
	GetEventString(event, "newname", newname, sizeof(newname));
	if (checkNameURL(client, newname))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

// BY https://forums.alliedmods.net/member.php?u=67162
public Action SayText2(UserMsg msg_id, Handle bf, int[] players, int playersNum, bool reliable, bool init)
{
	if (!reliable)
		return Plugin_Continue;
	
	char buffer[25];
	
	if (GetUserMessageType() == UM_Protobuf) {
		PbReadString(bf, "msg_name", buffer, sizeof(buffer));
		if (StrEqual(buffer, "#Cstrike_Name_Change"))
			return Plugin_Handled;
		
	} else {
		BfReadChar(bf);
		BfReadChar(bf);
		BfReadString(bf, buffer, sizeof(buffer));
		
		if (StrEqual(buffer, "#Cstrike_Name_Change"))
			return Plugin_Handled;
		
	}
	return Plugin_Continue;
} 


public bool checkImmunity(int client)
{
	return (IsFakeClient(client) || IsClientReplay(client) || IsClientSourceTV(client) || CheckCommandAccess(client, "sm_smartlinkremover", ADMFLAG_ROOT, false));
}
