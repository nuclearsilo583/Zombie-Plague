/**
 * ============================================================================
 *
 *  Zombie Plague
 *
 *
 *  Copyright (C) 2015-2019 Nikita Ushakov (Ireland, Dublin)
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
 **/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombieplague>

#pragma newdecls required

/**
 * Record plugin info.
 **/
public Plugin myinfo =
{
    name            = "[ZP] Zombie Class: NormalM01",
    author          = "qubka (Nikita Ushakov)",
    description     = "Addon of zombie classses",
    version         = "1.0",
    url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Information about zombie class.
 **/
#define ZOMBIE_CLASS_SKILL_RADIUS       40000.0 // [squared]
#define ZOMBIE_CLASS_SKILL_DAMAGE       1.0  // 10 damage per sec
#define ZOMBIE_CLASS_SKILL_SURVIVOR     false
/**
 * @endsection
 **/

// Sound index
int gSound; ConVar hSoundLevel;
#pragma unused gSound, hSoundLevel

// Initialize vectors
float vGasPostion[MAXPLAYERS+1][3];

// Zombie index
int gZombie;
#pragma unused gZombie

/**
 * Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
    // Classes
    gZombie = ZP_GetZombieClassNameID("normalm01");
    if(gZombie == -1) SetFailState("[ZP] Custom zombie class ID from name : \"normalm01\" wasn't find");
    
    // Sounds
    gSound = ZP_GetSoundKeyID("SMOKE_SKILL_SOUNDS");
    if(gSound == -1) SetFailState("[ZP] Custom sound key ID from name : \"SMOKE_SKILL_SOUNDS\" wasn't find");
    
    // Cvars
    hSoundLevel = FindConVar("zp_game_custom_sound_level");
    if(hSoundLevel == INVALID_HANDLE) SetFailState("[ZP] Custom cvar key ID from name : \"zp_game_custom_sound_level\" wasn't find");
}

/**
    * Called when a client use a skill.
 * 
 * @param clientIndex        The client index.
 *
 * @return                   Plugin_Handled to block using skill. Anything else
 *                              (like Plugin_Continue) to allow use.
 **/
public Action ZP_OnClientSkillUsed(int clientIndex)
{
    // Validate the zombie class index
    if(ZP_IsPlayerZombie(clientIndex) && ZP_GetClientZombieClass(clientIndex) == gZombie)
    {
        // Emit sound
        static char sSound[PLATFORM_MAX_PATH];
        ZP_GetSound(gSound, sSound, sizeof(sSound), 1);
        EmitSoundToAll(sSound, clientIndex, SNDCHAN_VOICE, hSoundLevel.IntValue);

        // Gets the client origin
        GetClientAbsOrigin(clientIndex, vGasPostion[clientIndex]);
        
        // Create an effect
        int iSmoke = FakeCreateParticle(clientIndex, vGasPostion[clientIndex], _, "explosion_smokegrenade_base_green", ZP_GetZombieClassSkillDuration(gZombie));
        
        // Create gas damage task
        CreateTimer(0.1, ClientOnToxicGas, EntIndexToEntRef(iSmoke), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    
    // Allow usage
    return Plugin_Continue;
}

/**
 * Timer for the toxic gas process.
 *
 * @param hTimer            The timer handle.
 * @param referenceIndex    The reference index.
 **/
public Action ClientOnToxicGas(Handle hTimer, const int referenceIndex)
{
    // Gets entity index from reference key
    int entityIndex = EntRefToEntIndex(referenceIndex);

    // Validate entity
    if(entityIndex != INVALID_ENT_REFERENCE)
    {
        // Initialize vectors
        static float vVictimPosition[3];

        // Gets the owner index
        int ownerIndex = GetEntPropEnt(entityIndex, Prop_Send, "m_hOwnerEntity");

        // Validate owner
        if(IsPlayerExist(ownerIndex, false))
        {
            // i = client index
            for(int i = 1; i <= MaxClients; i++)
            {
                // Validate client
                if(IsPlayerExist(i) && ((ZP_IsPlayerHuman(i) && !ZP_IsPlayerSurvivor(i)) || (ZP_IsPlayerSurvivor(i) && ZOMBIE_CLASS_SKILL_SURVIVOR)))
                {
                    // Gets victim origin
                    GetClientAbsOrigin(i, vVictimPosition);

                    // Calculate the distance
                    float flDistance = GetVectorDistance(vGasPostion[ownerIndex], vVictimPosition, true);

                    // Validate distance
                    if(flDistance <= ZOMBIE_CLASS_SKILL_RADIUS)
                    {            
                        // Create the damage for a victim
                        ZP_TakeDamage(i, ownerIndex, ZOMBIE_CLASS_SKILL_DAMAGE, DMG_NERVEGAS);
                    }
                }
            }
        }

        // Allow scream
        return Plugin_Continue;
    }

    // Destroy scream
    return Plugin_Stop;
}