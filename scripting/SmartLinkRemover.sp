#pragma semicolon 1

#define PLUGIN_VERSION "1.6.2"

#include <sourcemod>
#include <sdktools>
#include <regex>

#pragma newdecls required

Regex urlPattern;
RegexError theError;
bool locked[MAXPLAYERS + 1];
StringMap simpleWhitelist;

ConVar cEmptyName;
ConVar cKeepHalf;

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
	cEmptyName = CreateConVar("sm_smarturlremover_emptyname", "URL Removed", "The name to replace full name urls with.");
	cKeepHalf = CreateConVar("sm_smarturlremover_keephalf", "1", "Attempt to keep partial url as the player's name when full url (Google.com -> Google)");
	
	AutoExecConfig(true, "SmartLinkRemover");

	HookEvent("player_changename", onPlayerNameChange, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("SayText2"), SayText2, true);
	
	char error[256];
	char pattern[256] = "((http:[/]{2}|https:[/]{2}|www[.])?([-a-zA-Z0-9]{2,}[.][a-zA-Z]{2,5})([a-zA-Z0-9]*?[.][a-zA-Z0-9]{2,5})?([/][a-zA-Z0-9]*)*(?=[^a-zA-Z0-9]|$))";
	urlPattern = CompileRegex(pattern, PCRE_CASELESS, error, sizeof(error), theError);
	if (theError != REGEX_ERROR_NONE)
		LogError(error);
}

public void OnMapStart()
{
	loadWhitelist();
}

public void OnClientPostAdminCheck(int client)
{
	locked[client] = false;
	if (!IsClientInGame(client) || checkImmunity(client))
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
		bool replaced = false;
		for (int i = 0; i < matchCount; i++)
		{
			//Substrings start at 0
			GetRegexSubString(urlPattern, i, match, sizeof(match));
			if (name[0] && match[0] && !inWhitelist(client, match))
			{
				replaced = true;
				if (cKeepHalf.BoolValue && StrEqual(match, name))
				{
					char tempBuffer[MAX_NAME_LENGTH];
					if(SplitString(match, ".", tempBuffer, sizeof(tempBuffer)) >= 0)
					{
						//Attempt to keep some of the url.
						Format(name, sizeof(name), tempBuffer);
						continue;
					}
				} 
				ReplaceString(name, sizeof(name), match, "", false);
			}
		}

		if (!replaced)
		{ //User had whitelisted urls.
			return false;
		}

		if (!name[0])
		{
			cEmptyName.GetString(name, sizeof(name));
		}
		
		//Thanks to https://forums.alliedmods.net/showpost.php?p=2497716&postcount=9
		char alias[32];
		Format(alias, sizeof(alias), "\t#%i", client);
		SetClientName(client, alias);
		
		DataPack packName = new DataPack();
		packName.WriteCell(GetClientUserId(client));
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
	int client = GetClientOfUserId(packName.ReadCell());
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		delete packName;
		return;
	}
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

public void loadWhitelist()
{
	simpleWhitelist = clearStringMap(simpleWhitelist);
	char tempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, tempPath, sizeof(tempPath), "configs/SmartLink_whitelist.cfg");
	
	static SMCParser parser = null;
	if (parser == null)
	{
		parser = new SMCParser();
		parser.OnKeyValue = whitelistKeyValue;
	}
	parser.ParseFile(tempPath);
}

public SMCResult whitelistKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	simpleWhitelist.SetValue(key, ReadFlagString(value));
}

public StringMap clearStringMap(StringMap stringMap)
{
	if (stringMap != null)
	{
		delete stringMap;
	}
	return new StringMap();
}

public bool inWhitelist(int client, char[] url)
{
	if (simpleWhitelist == null)
	{
		LogError("Something went wrong with the whitelist StringMap!");
	}

	int flagBit;
	if (simpleWhitelist.GetValue(url, flagBit))
	{ //Match to the user if they have flag, or if the flag is an empty string.
		return flagBit == 0 || GetUserFlagBits(client) & flagBit;
	}

	return false; //No matches in the whitelist.
}
