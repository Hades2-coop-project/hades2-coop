--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopPlayers
local CoopPlayers = ModRequire "../logic/CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../logic/HeroContext.lua"
---@type SimpleHook
local SimpleHook = ModRequire "../utils/SimpleHook.lua"
---@type Events
local Events = ModRequire "../logic/Events.lua"
---@type TableUtils
local TableUtils = ModRequire "../utils/TableUtils.lua"

local InteractLogicHooks = SimpleHook.New()

local ESCAPE_DOORS = { 420947, 555784, 780651 }

function InteractLogicHooks.wrap.OnUsed(_OnUsed, args)
    if type(args[1]) == "function" then
        _OnUsed { function(triggerArgs)
            local item = triggerArgs.TriggeredByTable
            if item == nil then
                return
            end

            local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)

            if item.UsedByHero and item.UsedByHero ~= hero then
                -- Don't collect LobAmmoPack for by wrong player
                return
            end

            local mainHero = HeroContext.GetDefaultHero()
            if triggerArgs.triggeredById and TableUtils.find(ESCAPE_DOORS, triggerArgs.triggeredById) and hero ~= mainHero then
                -- Pact door
                -- Disable control for a second player
                -- A second player in context resets weapon choice for the first player
                return;
            else
                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        end
        }
    else
        _OnUsed({
            args[1],
            function(triggerArgs)
                HeroContext.RunWithHeroContext(
                    CoopPlayers.GetHeroByUnit(triggerArgs.UserId),
                    args[2],
                    triggerArgs
                )
            end
        })
    end
end

function InteractLogicHooks.wrap.OnActiveUseTarget(baseFun, args)
    if type(args[1]) == "function" then
        baseFun {
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        baseFun(args)
    end
end

function InteractLogicHooks.wrap.OnActiveUseTargetLost(baseFun, args)
    if type(args[1]) == "function" then
        baseFun {
            function(triggerArgs)
                local hero = CoopPlayers.GetHeroByUnit(triggerArgs.UserId)
                local mainHero = HeroContext.GetDefaultHero()
                local functionName = triggerArgs.AttachedTable and triggerArgs.AttachedTable.OnUsedFunctionName
                if functionName == "UseEscapeDoor" and hero ~= mainHero then
                    return;
                end

                HeroContext.RunWithHeroContext(
                    hero,
                    args[1],
                    triggerArgs
                )
            end
        }
    else
        baseFun(args)
    end
end

function InteractLogicHooks.post.UseConsumableItem(consumableItem, args, user)
    if consumableItem.AddAmmo then
        Events.game:trigger("comsumeAmmoItem", consumableItem)
    end
end

return InteractLogicHooks
