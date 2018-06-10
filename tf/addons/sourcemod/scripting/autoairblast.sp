#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#define PLUGIN_VERSION 		"1.0.0"

public Plugin myinfo = 
{
	name = "[TF2] Auto-Airblast",
	author = "Scag/Ragenewb",
	description = "Dodgeball God",
	version = PLUGIN_VERSION,
	url = "https://github.com/Scags"
};

Handle hWorldSpaceCenter;
Handle hSecondaryAttack;
Handle hCanPerformSecondaryAttack;

bool bDodgeballGod[MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateConVar("sm_autoairblast_version", PLUGIN_VERSION, "Auto-Airblast plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	RegAdminCmd("sm_airblast", CmdAirblast, ADMFLAG_ROOT);

	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);


	// 150 L; 149 W
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(149);
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if ((hWorldSpaceCenter = EndPrepSDKCall()) == null)
		SetFailState("Failed to load CBaseEntity::WorldSpaceCenter");

	// 286 L; 280 W
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(280);
	if ((hSecondaryAttack = EndPrepSDKCall()) == null)
		SetFailState("Failed to load CTFFlameThrower::SecondaryAttack");

	// 276 L; 270 W
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(270);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((hCanPerformSecondaryAttack = EndPrepSDKCall()) == null)
		SetFailState("Failed to load CTFWeaponBase::CanPerformSecondaryAttack");
}

public Action CmdAirblast(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (TF2_GetPlayerClass(client) != TFClass_Pyro)
	{
		PrintToChat(client, "[SM] You must be a Pyro in order to do this.");
		return Plugin_Handled;
	}

	bDodgeballGod[client] = true;
	PrintToChat(client, "[SM] You have %sabled auto airblasting.", (bDodgeballGod[client] ? "en" : "dis"));
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, OnThink);
	bDodgeballGod[client] = false;
}

public void OnThink(int client)
{
	if (!bDodgeballGod[client])
		return;

	if (!IsPlayerAlive(client))
		return;

	int wep = GetPlayerWeaponSlot(client, 0);
	if (wep != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
		return;

	if (!SDKCall(hCanPerformSecondaryAttack, wep))
		return;

	int ent = -1;
	char classname[32];
	float vecLoc[3], vecMyLoc[3];
	GetClientEyePosition(client, vecMyLoc);		// Logic comes from the eyes or the player screen. GetClientAbsOrigin() wouldn't apply here
	while ((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
	{
		GetEntityClassname(ent, classname, sizeof(classname));
		if (!strcmp(classname, "tf_projectile_syringe", false))	// Can't reflect syringes, sad day
			continue;

		SDKCall(hWorldSpaceCenter, ent, vecLoc);

		if (GetVectorDistance(vecMyLoc, vecLoc) < 198)	// https://github.com/VSES/SourceEngine2007/blob/master/se2007/game/shared/tf/tf_weapon_flamethrower.h#L107
		{
			float vecRunningOutOfNames[3];
			MakeVectorFromPoints(vecLoc, vecMyLoc, vecRunningOutOfNames);

			float vecAng[3];
			GetVectorAngles(vecRunningOutOfNames, vecAng);
			vecAng[0] = -vecAng[0];
			vecAng[1] += 180.0;

			TeleportEntity(client, NULL_VECTOR, vecAng, NULL_VECTOR);
			SDKCall(hSecondaryAttack, wep);
		}
	}
}
