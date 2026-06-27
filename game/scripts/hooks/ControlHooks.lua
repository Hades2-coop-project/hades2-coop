--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type HeroContextNative
local HeroContextNative = ModRequire "../logic/HeroContextNative.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"

local ControlHooks = SimpleHook.New()

function ControlHooks.wrap.OnControlPressed(baseFun, args)
    baseFun {
        args[1],
        function(triggerArgs)
            local hero = CoopPlayers.GetHeroByUnit(triggerArgs.triggeredById)
            if hero then
                HeroContext.RunWithHeroContext(hero, args[2], triggerArgs)
            else
                DebugAssert({ Condition = false, Text = "Controll was pressed without right hero context " .. args[1], Owner = "Uladzislau" })
                args[2](triggerArgs)
            end
        end
    }
end

function ControlHooks.wrap.AddInputBlock(baseFun, argumenst)
    if argumenst.PlayerIndex then
        baseFun(argumenst)
    else
        for playerId = 1, CoopPlayers.GetPlayersCount() do
            argumenst.PlayerIndex = playerId
            baseFun(argumenst)
        end
    end
end

function ControlHooks.wrap.RemoveInputBlock(baseFun, argumenst)
    if argumenst.PlayerIndex then
        baseFun(argumenst)
    else
        for playerId = 1, CoopPlayers.GetPlayersCount() do
            argumenst.PlayerIndex = playerId
            baseFun(argumenst)
        end
    end
end

function ControlHooks.wrap.NotifyOnControlPressed(baseFun, argumenst)
    if argumenst.PlayerIndex then
        baseFun(argumenst)
    elseif argumenst.Notify == "FishingInput" then
        -- Prefer the player we recorded when fishing was started; the notify is
        -- registered from a thread without the right hero context, so falling back to
        -- CurrentRun.Hero alone binds the catch to the main player and breaks fishing
        -- for everyone else (#18).
        local playerId = CoopPlayers.FishingPlayerId
            or CoopPlayers.GetPlayerByHero(CurrentRun.Hero)
            or 1
        argumenst.PlayerIndex = playerId
        baseFun(argumenst)
    else
        baseFun(argumenst)
    end
end

function ControlHooks.wrap.ToggleMove(ToggleMove, argumenst)
    -- Custom argument
    if argumenst.PlayerIndex then
        HeroContextNative.RunWithNativeHeroContext(argumenst.PlayerIndex, ToggleMove, argumenst)
    else
        for playerId = 1, CoopPlayers.GetPlayersCount() do
            HeroContextNative.RunWithNativeHeroContext(playerId, ToggleMove, argumenst)
        end
    end
end

return ControlHooks
