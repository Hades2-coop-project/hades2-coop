--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "../logic/PlayerVisibilityHelper.lua"

---@class PlayerVisibilityHooks : SimpleHook
local PlayerVisibilityHooks = SimpleHook.New()

---@private
function PlayerVisibilityHooks.post.SetPlayerUnDarkside()
    if IsEmpty(SessionMapState.DarkSide) then
        local hero = HeroContext.GetCurrentHeroContext()
        PlayerVisibilityHelper.TriggerOutline(CoopPlayers.GetPlayerByHero(hero), hero.ObjectId)
        PlayerVisibilityHelper.TriggerCostume(CoopPlayers.GetPlayerByHero(hero), hero.ObjectId)
    end
end

return PlayerVisibilityHooks
