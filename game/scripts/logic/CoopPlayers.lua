--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type HeroContext
local HeroContext = ModRequire "HeroContext.lua"
---@type CoopControl
local CoopControl = ModRequire "CoopControl.lua"
---@type HeroEx
local HeroEx = ModRequire "HeroEx.lua"
---@type RunEx
local RunEx = ModRequire "RunEx.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "PlayerVisibilityHelper.lua"

---@class CoopPlayers
local CoopPlayers = {}

---@private
---@type table<number, table>
CoopPlayers.PlayerUnitIdToHero = {}
---@private
---@type table[]
CoopPlayers.CoopHeroes = {}

---@type number | nil
--- Player id that most recently started the fishing minigame. Used to bind the
--- "FishingInput" control notify to the right controller (#18).
CoopPlayers.FishingPlayerId = nil

function CoopPlayers.IsPlayerHero(t)
    for i = 1, #CoopPlayers.CoopHeroes do
        if CoopPlayers.CoopHeroes[i] == t then
            return true
        end
    end
    return false
end

function CoopPlayers.GetMainHero()
    return CoopPlayers.CoopHeroes[1]
end

---@return number
function CoopPlayers.GetPlayersCount()
    return CoopGetPlayersCount()
end

---@param unitId integer
---@return boolean
function CoopPlayers.IsPlayerUnit(unitId)
    return CoopPlayers.PlayerUnitIdToHero[unitId] and true
end

function CoopPlayers.SetMainHero(hero)
    DebugPrint{Text = "Set main hero: " .. tostring(hero) }
    CoopPlayers.CoopHeroes[1] = hero
    if hero.ObjectId then
        CoopPlayers.PlayerUnitIdToHero[hero.ObjectId] = hero
    end
end

function CoopPlayers.GetHero(playerId)
    return CoopPlayers.CoopHeroes[playerId]
end

function CoopPlayers.SetHero(playerId, hero)
    CoopPlayers.CoopHeroes[playerId] = hero
end

function CoopPlayers.PlayersIterator()
    return ipairs(CoopPlayers.CoopHeroes)
end

function CoopPlayers.AdditionalHeroesIterator()
    local interator, t, prevKey = ipairs(CoopPlayers.CoopHeroes)
    prevKey = 1
    return interator, t, prevKey
end

---@param hero table
function CoopPlayers.GetPlayerByHero(hero)
    for playerId = 1, #CoopPlayers.CoopHeroes do
        if CoopPlayers.CoopHeroes[playerId] == hero then
            return playerId
        end
    end
end

---@return number
function CoopPlayers.GetCurrentPlayerId()
    return CoopPlayers.GetPlayerByHero(CurrentRun.Hero)
end

function CoopPlayers.GetHeroByUnit(unitId)
    return CoopPlayers.PlayerUnitIdToHero[unitId]
end

---@return table<number>
function CoopPlayers.GetUnits()
    local out = {}
    for unit in pairs(CoopPlayers.PlayerUnitIdToHero) do
        table.insert(out, unit)
    end
    return out
end

---@return boolean
function CoopPlayers.HasAlivePlayers()
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            return true
        end
    end

    return false
end

function CoopPlayers.OnAllPlayersDead()
    -- The main player can changed when Player 1 is dead
    -- We should reset the player after death
    HeroContext.SetDefaultHero(CoopPlayers.GetMainHero())

    -- Heal all players in the Hades home
    for _, hero in CoopPlayers.PlayersIterator() do
        hero.Health = hero.MaxHealth or 50
    end

    -- Sometimes we change control schemas during the run
    -- We need reset it whe the run is finished
    CoopControl.ResetAllPlayers("UserDefined")
end

---@return table[]
function CoopPlayers.GetAliveHeroes()
    local out = {}
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            table.insert(out, hero)
        end
    end

    return out
end

---@return table?
function CoopPlayers.GetFirstAliveHero()
    for _, hero in CoopPlayers.PlayersIterator() do
        if hero and not hero.IsDead then
            return hero
        end
    end
end

function CoopPlayers.RestoreSavedHero(playerId)
    local hero = CurrentRun["Hero" .. playerId]
    DebugPrint { Text = "Restore player hero" .. tostring(playerId) .. " " .. tostring(hero) }
    if hero then
        CoopPlayers.CoopHeroes[playerId] = hero
        if not hero.IsDead then
            CoopPlayers.InitCoopUnit(playerId)
        end
    end
end

function CoopPlayers.InitCoopUnit(playerId)
    local unit = CoopCreatePlayerUnit(playerId)

    if not unit then
        return false
    end

    local hero = CoopPlayers.CoopHeroes[playerId]
    if not hero then
        hero = HeroEx.CreateFreshHero{
            keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId],
            familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId],
            weaponName = WeaponSets.HeroPrimaryWeapons[1];
            weaponVariant = 1;
        }
    end

    DebugPrint { Text = "Create hero for player " .. tostring(playerId) }

    CoopPlayers.PlayerUnitIdToHero[unit] = hero
    CoopPlayers.CoopHeroes[playerId] = hero
    CurrentRun["Hero" .. playerId] = hero

    PlayerVisibilityHelper.AddPlayerMarkers(playerId, unit)

    HeroEx.SetupAdditional(RunEx.GetCurrentRoom(), nil, hero, unit)

    SetUntargetable { Id = hero.ObjectId }
    -- Disables bow arrow bounces
    SetUnitProperty { DestinationId = unit, Property = "FriendlyToPlayer", Value = true }

    Teleport { Id = hero.ObjectId, DestinationId = CoopPlayers.GetMainHero().ObjectId }

    return hero
end

---@param playerId number
function CoopPlayers.RecreateFreshHeroWithCurrentMeta(playerId)
    local hero = CoopPlayers.CoopHeroes[playerId]
    local currentUnit = hero.ObjectId
    local weaponName, weaponIndex = HeroEx.GetHeroWeaponFull(hero)

    weaponName = weaponName or WeaponSets.HeroPrimaryWeapons[1]
    weaponIndex = weaponIndex or 1

    hero = HeroEx.CreateFreshHero{
        keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId];
        familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId];
        weaponName = weaponName;
        weaponVariant = weaponIndex;
    }

    if currentUnit then
        CoopPlayers.PlayerUnitIdToHero[currentUnit] = hero
    end
    CoopPlayers.CoopHeroes[playerId] = hero
    CurrentRun["Hero" .. playerId] = hero
end

function CoopPlayers.RecreateAllAdditionalPlayers()
    for playerIndex = 2, CoopPlayers.GetPlayersCount() do
        CoopPlayers.RecreateFreshHeroWithCurrentMeta(playerIndex)
    end
end

function CoopPlayers.UpdateMainHero()
    local hero = CoopPlayers.GetMainHero()
    CoopPlayers.PlayerUnitIdToHero[hero.ObjectId] = hero
    SetUntargetable { Id = hero.ObjectId }
end

function CoopPlayers.HealAllAdditionalPlayers()
    for playerIndex = 2, CoopPlayers.GetPlayersCount() do
        local hero = CoopPlayers.CoopHeroes[playerIndex]
        if hero then
            hero.IsDead = nil
            hero.Health = hero.MaxHealth
        end
    end
end

function CoopPlayers.CoopInit()
    CoopControl.InitControlSchemas()

    if RunEx.WasTheFirstRunStarted() then
        return
    end

    CoopPlayers.CoopHeroes[1] = CurrentRun.Hero

    if RunEx.IsRunEnded() then
        -- Create fresh hero for all players
        for playerId = 2, CoopPlayers.GetPlayersCount() do
            CoopPlayers.CoopHeroes[playerId] = HeroEx.CreateFreshHero {
                keepsake = GameState["LastAwardTraitCoopPlayer" .. playerId],
                familiar = GameState["EquippedFamiliarCoopPlayer" .. playerId],
                weaponName = WeaponSets.HeroPrimaryWeapons[1],
                weaponVariant = 1,
            }
        end
    else
        -- Load saved heroes
        for playerId = 2, CoopPlayers.GetPlayersCount() do
            CoopPlayers.CoopHeroes[playerId] = CurrentRun["Hero" .. playerId]
        end
    end
end

function CoopPlayers.IsHeroShouldBeHidden(hero)
    return hero.IsDead and not RunEx.IsRunEnded()
end

return CoopPlayers
