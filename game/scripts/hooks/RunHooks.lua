--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HookUtils
local HookUtils = ModRequire "../utils/HookUtils.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type SecondPlayerUi
local SecondPlayerUi = ModRequire "../logic/SecondPlayerUI.lua"
---@type RunEx
local RunEx = ModRequire "../logic/RunEx.lua"
---@type PlayerVisibilityHelper
local PlayerVisibilityHelper = ModRequire "../logic/PlayerVisibilityHelper.lua"
---@type HeroEx
local HeroEx = ModRequire "../logic/HeroEx.lua"
---@type CoopControl
local CoopControl = ModRequire "../logic/CoopControl.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"

---@class RunHooks : SimpleHook
local RunHooks = SimpleHook.New()

function RunHooks.pre.DeathAreaRoomTransition()
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
    end
end

function RunHooks.wrap.CheckDistanceTrigger(CheckDistanceTriggerFun, ...)
    -- TODO
    -- This hack fixes crashes like Hades 1 #21 when the player 1 is dead.
    -- The crash is caused by invalid reference to the second player.
    -- The game cannot find a player unit and triggers NotifyWithinDistance instantly without result
    HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), CheckDistanceTriggerFun, ...)
end

function RunHooks.wrap.SetupHeroObject(SetupHeroObjectFun, ...)
    local mainHero = CoopPlayers.GetMainHero()

    HeroContext.RunWithHeroContext(mainHero, SetupHeroObjectFun, ...)
    -- Fix unit -> hero table here
    CoopPlayers.UpdateMainHero()

    PlayerVisibilityHelper.AddPlayerMarkers(1, mainHero.ObjectId)

    if mainHero.IsDead and not RunEx.IsRunEnded() then
        HeroEx.HideHero(mainHero)
    end
end

function RunHooks.wrap.StartRoom(StartRoomFun, run, currentRoom)
    -- Fixes mouse disappearing after level transiction
    CoopControl.ResetAllPlayers("Current")

    -- Initialization after save loading when encounter is active
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
        CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())
    end

    if currentRoom.RoomSetName == "Surface" then
        RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    else
        RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleGenericRoom(StartRoomFun, run, currentRoom)
    HookUtils.onPostFunctionOnce("SwitchActiveUnit", function()
        SwitchActiveUnit { PlayerIndex = 1, Id = CoopPlayers.GetMainHero().ObjectId }
    end)

    if RunEx.IsRunEnded() then
        HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), StartRoomFun, run, currentRoom)
    else
        local hero = CoopPlayers.GetAliveHeroes()[1] or CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(hero, StartRoomFun, run, currentRoom)
    end
end

---@private
function RunHooks.HandleSurfaceRoom(StartRoomFun, run, currentRoom)
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = false
    HeroContext.SetDefaultHero(mainHero)

    if mainHero.Health == 0 then
        mainHero.Health = mainHero.MaxHealth
    end

    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end

    HeroContext.RunWithHeroContext(mainHero, StartRoomFun, run, currentRoom)
end

function RunHooks.post.StartNewRun()
    Events.run:trigger("newRunStarted", CurrentRun)
end

--- Bypass IsAlive check with this hook
function RunHooks.wrap.CheckRoomExitsReady(baseFun, ...)
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]
    if aliveHero then
        local result = false
        HeroContext.RunWithHeroContext(aliveHero, function(...)
            result = baseFun(...)
        end, ...)

        return result
    else
        return baseFun(...)
    end
end

function RunHooks.wrap.EndEarlyAccessPresentation(baseFun)
    local mainHero = CoopPlayers.GetMainHero()
    mainHero.IsDead = false
    for playerId, hero in CoopPlayers.AdditionalHeroesIterator() do
        hero.IsDead = true
    end
    HeroContext.RunWithHeroContext(mainHero, baseFun)
end

function RunHooks.wrap.KillHero(baseFun, ...)
    CurrentRun.Hero.IsDead = true
    if not CoopPlayers.HasAlivePlayers() then
        -- Handle death for player 1 only
        local mainHero = CoopPlayers.GetMainHero()
        HeroEx.ShowHero(mainHero, CurrentRun.Hero.ObjectId)
        RemoveOutline({ Id = mainHero.ObjectId })
        HeroContext.RunWithHeroContext(mainHero, baseFun, ...)
        CoopPlayers.OnAllPlayersDead()
        return
    end
    local aliveHero = CoopPlayers.GetAliveHeroes()[1]

    if CurrentRun.Hero == CoopPlayers.GetMainHero() then
        HeroEx.HideHero(CurrentRun.Hero)

        HeroContext.SetDefaultHero(aliveHero)
    else
        local playerId = CoopPlayers.GetPlayerByHero(CurrentRun.Hero)
        if playerId then
            CoopRemovePlayerUnit(playerId)
        end
    end
    -- Unstuck AI
    HeroContext.RunWithHeroContext(aliveHero, RunEx.RefreshEnemyAI, aliveHero)
end

function RunHooks.pre.LeaveRoom(currentRun, door)
    Events.run:trigger("roomPreLeave", currentRun, door)
end

function RunHooks.post.RestoreUnlockRoomExits()
    if not HeroContext.GetDefaultHero() then
        HeroContext.InitRunHook()
    end
    CoopPlayers.SetMainHero(HeroContext.GetDefaultHero())

    local spawnPoint = CurrentRun.CurrentRoom.HeroEndPoint or CoopPlayers.GetMainHero().ObjectId
    for playerId = 2, CoopPlayers.GetPlayersCount() do
        CoopPlayers.RestoreSavedHero(playerId)
        local hero = CoopPlayers.GetHero(playerId)
        if hero and not hero.IsDead then
            Teleport { Id = hero.ObjectId, DestinationId = spawnPoint }
        end
    end

    SecondPlayerUi.Refresh()
end

function RunHooks.wrap.EndEncounterEffects(baseFun, currentRun, currentRoom, currentEncounter)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, currentRun, currentRoom, currentEncounter)
        currentRoom.CodexUpdates = nil
        currentRoom.PendingCodexUpdate = nil
    end
end

function RunHooks.wrap.StartEncounterEffects(baseFun, run)
    for _, hero in ipairs(CoopPlayers.GetAliveHeroes()) do
        HeroContext.RunWithHeroContextAwait(hero, baseFun, run)
    end
end

function RunHooks.post.StartRoomPresentation(run, room)
    Events.run:trigger("roomPresentationFinished", run, room)
end

function RunHooks.pre.OnAllEnemiesDead()
    Events.run:trigger("allEnemiesDead")
end

function RunHooks.pre.StartRoom()
    Events.run:trigger("roomPreStart")
end

--- Fix players positions in the second stage
function RunHooks.post.ChronosPhaseTransition()
    for _, hero in pairs(CoopPlayers.GetAliveHeroes()) do
        Teleport({ Id = hero.ObjectId, DestinationId = 645921 })
    end
end

return RunHooks
