/*
 * ============================================================================
 *
 *  Zombie:Reloaded
 *
 *  File:          zombiereloaded.sp
 *  Type:          Base
 *  Description:   Plugin's base file.
 *
 *  Copyright (C) 2009  Greyscale, Richard Helgeby
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <cstrike>
#define INCLUDED_BY_ZOMBIERELOADED
#include <zombiereloaded>
#undef INCLUDED_BY_ZOMBIERELOADED

#include <emitsoundany>

new bool:rondasurvivor = false;
new bool:rondanemesis = false;
new bool:rondaplague = false;

new nade_infect[MAXPLAYERS+1] = 0;

new g_beamsprite, g_halosprite;



new nade_count[MAXPLAYERS+1] = 0;

#define NADE_COLOR2	{255,255,255,255}


#define PLUGIN_VERSION "2.0"

#define FLASH 0
#define SMOKE 1

#define SOUND_FREEZE	"physics/glass/glass_impact_bullet4.wav"
#define SOUND_FREEZE_EXPLODE	"ui/freeze_cam.wav"

#define FragColor 	{255,75,75,255}
#define FlashColor 	{255,255,255,255}
#define SmokeColor	{75,255,75,255}
#define FreezeColor	{75,75,255,255}

new Float:NULL_VELOCITY[3] = {0.0, 0.0, 0.0};

new Nemesis = 0;

new bool:bIsGoldenGun[2048] = false;


new Handle:h_greneffects_enable, bool:b_enable,
	Handle:h_greneffects_trails, bool:b_trails,
	Handle:h_greneffects_napalm_he, bool:b_napalm_he,
	Handle:h_greneffects_napalm_he_duration, Float:f_napalm_he_duration,
	Handle:h_greneffects_smoke_freeze, bool:b_smoke_freeze,
	Handle:h_greneffects_smoke_freeze_distance, Float:f_smoke_freeze_distance,
	Handle:h_greneffects_smoke_freeze_duration, Float:f_smoke_freeze_duration,
	Handle:h_greneffects_flash_light, bool:b_flash_light,
	Handle:h_greneffects_flash_light_distance, Float:f_flash_light_distance,
	Handle:h_greneffects_flash_light_duration, Float:f_flash_light_duration;

new Handle:h_freeze_timer[MAXPLAYERS+1];

new Handle:h_fwdOnClientFreeze,
	Handle:h_fwdOnClientFreezed,
	Handle:h_fwdOnClientIgnite,
	Handle:h_fwdOnClientIgnited;

new GlowSprite;

new bool:Es_Nemesis[MAXPLAYERS+1] = {false, ...};


#include <sdkhooks>

#define VERSION "3.1"

// Comment this line to exclude version info command. Enable this if you have
// the repository and HG installed (Mercurial or TortoiseHG).
#define ADD_VERSION_INFO

// Header includes.
#include "zr/log.h"
#include "zr/models.h"
#include "franug_z/fuego.sp"
#include "zr/immunityhandler.h"

#if defined ADD_VERSION_INFO
#include "zr/hgversion.h"
#endif

// Core includes.
#include "zr/zombiereloaded"

#if defined ADD_VERSION_INFO
#include "zr/versioninfo"
#endif

#include "zr/translation"
#include "zr/cvars"
#include "zr/admintools"
#include "zr/log"
#include "zr/config"
#include "zr/steamidcache"
#include "zr/sayhooks"
#include "zr/tools"
#include "zr/menu"
#include "zr/cookies"
#include "zr/paramtools"
#include "zr/paramparser"
#include "zr/shoppinglist"
#include "zr/downloads"
#include "zr/overlays"
#include "zr/playerclasses/playerclasses"
#include "zr/models"
#include "zr/weapons/weapons"
#include "zr/hitgroups"
#include "zr/roundstart"
#include "zr/roundend"
#include "zr/infect"
#include "zr/immunityhandler"
#include "zr/damage"
#include "zr/event"
#include "zr/zadmin"
#include "zr/commands"
//#include "zr/global"

// Modules
#include "zr/account"
#include "zr/visualeffects/visualeffects"
#include "zr/soundeffects/soundeffects"
#include "zr/antistick"
#include "zr/knockback"
#include "zr/spawnprotect"
#include "zr/respawn"
#include "zr/napalm"
#include "zr/jumpboost"
#include "zr/zspawn"
#include "zr/ztele/ztele"
#include "zr/zhp"
#include "zr/zcookies"
#include "zr/volfeatures/volfeatures"
#include "zr/debugtools"

#include "zr/api/api"

#include "franug_z/bomb.sp"
#include "franug_z/sm_franug-ZombiePlague.sp"
#include "franug_z/granadas.sp"

new bool:g_bLate = false;
new bool:g_bServerStarted = false;

/**
 * Record plugin info.
 */
public Plugin:myinfo =
{
    name = "Zombie:Reloaded",
    author = "Greyscale | Richard Helgeby",
    description = "Infection/survival style gameplay",
    version = VERSION,
    url = "http://forums.alliedmods.net/forumdisplay.php?f=132"
};

/**
 * Called before plugin is loaded.
 *
 * @param myself    The plugin handle.
 * @param late      True if the plugin was loaded after map change, false on map start.
 * @param error     Error message if load failed.
 * @param err_max   Max length of the error message.
 *
 * @return          APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise.
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Load API.
    h_fwdOnClientFreeze = CreateGlobalForward("ZR_OnClientFreeze", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
    h_fwdOnClientFreezed = CreateGlobalForward("ZR_OnClientFreezed", ET_Ignore, Param_Cell, Param_Cell, Param_Float);

    h_fwdOnClientIgnite = CreateGlobalForward("ZR_OnClientIgnite", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
    h_fwdOnClientIgnited = CreateGlobalForward("ZR_OnClientIgnited", ET_Ignore, Param_Cell, Param_Cell, Param_Float);

    APIInit();

    // Register library
    RegPluginLibrary("zombiereloaded");

    g_bLate = late;

    // Let plugin load.
    return APLRes_Success;
}

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
    UpdateGameFolder();

    // Forward event to modules.
    LogInit();          // Doesn't depend on CVARs.
    TranslationInit();
    CvarsInit();
    CookiesInit();
    CommandsInit();
    WeaponsInit();
    EventInit();
    OnPluginStartZM();
}

/**
 * All plugins have finished loading.
 */
public OnAllPluginsLoaded()
{
    // Forward event to modules.
    RoundEndOnAllPluginsLoaded();
    WeaponsOnAllPluginsLoaded();
    ConfigOnAllPluginsLoaded();
}

/**
 * A library was added.
 */
public OnLibraryAdded(const String:name[])
{
    // Forward event to modules.
    ConfigOnLibraryAdded(name);
}

/**
 * A library was removed.
 */
public OnLibraryRemoved(const String:name[])
{
    ConfigOnLibraryRemoved(name);
}

/**
 * The map is starting.
 */
public OnMapStart()
{
    if(!g_bServerStarted)
    {
        ToolsInit();
        g_bServerStarted = true;
    }
    // Forward event to modules.
    ClassOnMapStart();
    OverlaysOnMapStart();
    RoundEndOnMapStart();
    SEffectsOnMapStart();
    ZSpawnOnMapStart();
    VolInit();
    CountDown();
    OnMapStartZM();

    g_beamsprite = PrecacheModel("materials/sprites/lgtning.vmt");
    g_halosprite = PrecacheModel("materials/sprites/halo01.vmt");
}

/**
 * The map is ending.
 */
public OnMapEnd()
{
    // Forward event to modules.
    InfectOnMapEnd();
    VolOnMapEnd();
    VEffectsOnMapEnd();
    ZombieSoundsOnMapEnd();
    ImmunityOnMapEnd();

    rondanemesis = false;
    rondasurvivor = false;
}

/**
 * Main configs were just executed.
 */
public OnAutoConfigsBuffered()
{
	// Load map configurations.
    ConfigLoad();
}

/**
 * Configs just finished getting executed.
 */
public OnConfigsExecuted()
{
    // Forward event to modules. (OnConfigsExecuted)
    ModelsLoad();
    DownloadsLoad();
    WeaponsLoad();
    HitgroupsLoad();
    InfectLoad();
    DamageLoad();
    VEffectsLoad();
    SEffectsLoad();
    ClassOnConfigsExecuted();
    ClassLoad();
    VolLoad();

    // Forward event to modules. (OnModulesLoaded)
    ConfigOnModulesLoaded();
    ClassOnModulesLoaded();

    // Fake roundstart
    EventRoundStart(INVALID_HANDLE, "", false);

    if(g_bLate)
    {
        new bool:bZombieSpawned = false;
        for(new client = 1; client <= MaxClients; client++)
        {
            if(!IsClientConnected(client))
                continue;

            OnClientConnected(client);

            if(IsClientInGame(client))
            {
                OnClientPutInServer(client);

                if(AreClientCookiesCached(client))
                    OnClientCookiesCached(client);

                if(IsClientAuthorized(client))
                    OnClientPostAdminCheck(client);

                if(IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
                {
                    InfectHumanToZombie(client);
                    bZombieSpawned = true;
                }
            }
        }

        if(bZombieSpawned)
        {
            // Zombies have been infected.
            g_bZombieSpawned = true;
        }

        g_bLate = false;
    }
}

/**
 * Client has just connected to the server.
 */
public OnClientConnected(client)
{
    // Forward event to modules.
    ClassOnClientConnected(client);
}

/**
 * Client is joining the server.
 *
 * @param client    The client index.
 */
public OnClientPutInServer(client)
{
    // Forward event to modules.
    ClassClientInit(client);
    OverlaysClientInit(client);
    WeaponsClientInit(client);
    InfectClientInit(client);
    DamageClientInit(client);
    SEffectsClientInit(client);
    AntiStickClientInit(client);
    SpawnProtectClientInit(client);
    RespawnClientInit(client);
    ZTele_OnClientPutInServer(client);
    ZHPClientInit(client);
    ImmunityClientInit(client);
    OnClientPutInServerD(client);
}

/**
 * Called once a client's saved cookies have been loaded from the database.
 *
 * @param client		Client index.
 */
public OnClientCookiesCached(client)
{
    // Check if client disconnected before cookies were done caching.
    if (!IsClientConnected(client))
    {
        return;
    }

    // Forward "OnCookiesCached" event to modules.
    ClassOnCookiesCached(client);
    WeaponsOnCookiesCached(client);
    ZHPOnCookiesCached(client);
}

/**
 * Called once a client is authorized and fully in-game, and
 * after all post-connection authorizations have been performed.
 *
 * This callback is gauranteed to occur on all clients, and always
 * after each OnClientPutInServer() call.
 *
 * @param client		Client index.
 * @noreturn
 */
public OnClientPostAdminCheck(client)
{
    // Forward authorized event to modules that depend on client admin info.
    ClassOnClientPostAdminCheck(client);
    OnClientPostAdminCheckZM(client);
}

/**
 * Client is leaving the server.
 *
 * @param client    The client index.
 */
public OnClientDisconnect(client)
{
    // Forward event to modules.
    ClassOnClientDisconnect(client);
    WeaponsOnClientDisconnect(client);
    InfectOnClientDisconnect(client);
    DamageOnClientDisconnect(client);
    AntiStickOnClientDisconnect(client);
    ZSpawnOnClientDisconnect(client);
    VolOnPlayerDisconnect(client);
    ImmunityOnClientDisconnect(client);
    ZTele_OnClientDisconnect(client);
    OnClientDisconnectZM(client);
    OnClientDisconnect2(client);
}

/**
 * Called when a clients movement buttons are being processed
 *
 * @param client	Index of the client.
 * @param buttons	Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 * @param impulse	Copyback buffer containing the current impulse command.
 * @param vel		Players desired velocity.
 * @param angles	Players desired view angles.
 * @param weapon	Entity index of the new weapon if player switches weapon, 0 otherwise.
 * @return 			Plugin_Handled to block the commands from being processed, Plugin_Continue otherwise.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    Class_OnPlayerRunCmd(client, vel);
    return Plugin_Continue;
}

