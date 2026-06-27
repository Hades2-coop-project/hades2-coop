//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "pch.h"

#include "MagnetismHook.h"
#include "FunctionHook.h"
#include "CoopContext.h"

#include <hades2/Projectile.h>
#include <hades2/Obstacle.h>

#include "lua.hpp"

// This hook fixes magnetism for the "Lob" weapon type.
// The issue is that the magnetism system uses only the first player unit for magnetism attraction.
// In coop, each player has their own unit, so we need to adjust the magnetism

void MagnetismHook::Install(IModApi::GetSymbolAddress_t GetSymbolAddress) {
    static FunctionHook<"sgg::MagnetismSystem::UpdateThing", char, void *, sgg::Thing *, float>
        MagnetismSystem_UpdateThing{};

    void *funcAddr = reinterpret_cast<void *>(GetSymbolAddress("sgg::MagnetismSystem::UpdateThing"));
    if (!funcAddr) {
        // This symbol can be missing in some environments (e.g. a different game
        // executable / storefront build). The sibling hooks (AnimSwapHook,
        // AllyModelLimitsAssertHooh) all degrade gracefully when a symbol is absent.
        // Throwing here propagates out of HadesModInit and crashes the game on load
        // instead of just disabling the Lob magnetism fix, which is a likely cause of
        // the Steam-only "crash on load" while the Epic build works (#37). Degrade
        // gracefully to match the other hooks.
        return;
    }

    static auto& playerManager = CoopContext::GetInstance()->GetPlayerManager();
    MagnetismSystem_UpdateThing.Install(funcAddr, 12);

    MagnetismSystem_UpdateThing.onPreFunction = [](char &ret, void *, sgg::Thing *thing, float) {
        if (!thing->IsObstacle()) {
            return true;
        }
        // TODO optimize
        auto state = thing->GetLuaTable().state;
        if (!state) {
            return true;
        }
        auto ref = thing->GetLuaTable().ref;

        lua_rawgeti(state, LUA_REGISTRYINDEX, ref);
        lua_getfield(state, -1, "PlayerIndexC");

        if (lua_isnumber(state, -1)) {
            size_t playerIndex = static_cast<size_t>(lua_tointeger(state, -1));
            playerManager.SetCurrentMainPlayer(static_cast<size_t>(playerIndex));
        }

        lua_pop(state, 2);

        return true;
    };

    MagnetismSystem_UpdateThing.onPostFunction = [](char ret) {
        playerManager.ResetCurrentMainPlayer();
        return ret;
    };
}
