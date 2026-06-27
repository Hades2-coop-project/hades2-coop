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
---@type CoopControl
local CoopControl = ModRequire "../logic/CoopControl.lua"
---@type CoopCamera
local CoopCamera = ModRequire "../logic/CoopCamera.lua"
---@type GameStateEx
local GameStateEx = ModRequire "../logic/GameStateEx.lua"

---@class MenuHooks : SimpleHook
local MenuHooks = SimpleHook.New()

function MenuHooks.InitGameHooks()
    MenuHooks.HookUiControl("OpenKeepsakeRackScreen")
    MenuHooks.HookUiControl("OpenWeaponShopScreen")
    MenuHooks.HookUiControl("OpenCosmeticsShopScreen")
    MenuHooks.HookUiControl("ShowBoonInfoScreen")
    MenuHooks.HookUiControl("OpenBountyBoardScreen")
    MenuHooks.HookUiControl("OpenCodexScreen")
    MenuHooks.HookUiControl("OpenElementalPromptScreen")
    MenuHooks.HookUiControl("OpenFamiliarCostumeScreen")
    MenuHooks.HookUiControl("OpenFamiliarShopScreen")
    MenuHooks.HookUiControl("OpenGameStatsScreen")
    MenuHooks.HookUiControl("OpenGhostAdminScreen")
    MenuHooks.HookUiControl("OpenMailboxScreen")
    MenuHooks.HookUiControl("OpenMarketScreen")
    MenuHooks.HookUiControl("OpenMusicPlayerScreen")
    MenuHooks.HookUiControl("OpenQuestLogScreen")
    MenuHooks.HookUiControl("OpenInventoryScreen")
    MenuHooks.HookUiControl("OpenRunHistoryScreen")
    MenuHooks.HookUiControl("OpenSellTraitMenu")
    MenuHooks.HookUiControl("OpenShrineScreen")
    MenuHooks.HookUiControl("OpenSpellScreen")
    MenuHooks.HookUiControl("ShowStoreScreen")
    MenuHooks.HookUiControl("ShowSurfaceShopScreen")
    MenuHooks.HookUiControl("OpenTalentScreen")
    MenuHooks.HookUiControl("OpenMetaUpgradeCardScreen")
    MenuHooks.HookUiControl("OpenTradeScreen")
    MenuHooks.HookUiControl("OpenTraitTrayScreen")
    MenuHooks.HookUiControl("OpenUpgradeChoiceMenu")
    MenuHooks.HookUiControl("PlayTextLines")
    MenuHooks.HookUiControl("OpenWeaponUpgradeScreen")
end

---@private
---@param funName string
function MenuHooks.HookUiControl(funName)
    HookUtils.wrap(funName, function(originalFun, ...)
        local playerId = CoopPlayers.GetCurrentPlayerId()

        -- If the player that triggered this menu is dead (e.g. they died in the boss
        -- fight that led into this reward/conversation room), their controller can no
        -- longer drive the screen. Bind it to an alive player instead so it can be
        -- advanced/closed (#33).
        local hero = playerId and CoopPlayers.GetHero(playerId)
        if (not hero) or hero.IsDead then
            local aliveHero = CoopPlayers.GetFirstAliveHero()
            local alivePlayerId = aliveHero and CoopPlayers.GetPlayerByHero(aliveHero)
            if alivePlayerId then
                playerId = alivePlayerId
            end
        end

        CoopControl.SwitchControlForMenu(playerId)

        -- The co-op camera re-locks onto every alive hero each tick, so while one player
        -- is busy in a boon/upgrade/reward screen, the OTHER player walking around scrolls
        -- the view. Boon/Tranquil-Gain selection UI is anchored in screen space, so that
        -- scroll drifts the options off and breaks selection (#35, #27). Pin focus to the
        -- menu owner for the duration of the screen so a wandering teammate can't move it.
        local ownerHero = CoopPlayers.GetHero(playerId)
        if ownerHero then
            for _, otherHero in CoopPlayers.PlayersIterator() do
                if otherHero ~= ownerHero then
                    CoopCamera.SetHeroIgnored(otherHero, true)
                end
            end
        end

        HookUtils.onPreFunctionOnce("UnfreezePlayerUnit", function()
            CoopCamera.ResetIgnore()
            CoopControl.ExitMenuControl()
        end)

        return originalFun(...)
    end)
end

function MenuHooks.pre.OpenMetaUpgradeCardScreen()
    GameStateEx.CopyTraitsToMetaUpgrades(CurrentRun.Hero)
end

function MenuHooks.wrap.OpenKeepsakeRackScreen(baseFun, ...)
    local playerId = CoopPlayers.GetCurrentPlayerId()

    if playerId == 1 then
        baseFun(...)
        return
    end

    local key = "LastAwardTraitCoopPlayer" .. playerId
    local prevGift = GameState.LastAwardTrait
    local currentGift = GameState[key]

    GameState.LastAwardTrait = currentGift

    baseFun(...)

    GameState[key] = GameState.LastAwardTrait
    GameState.LastAwardTrait = prevGift
end

function MenuHooks.wrap.OpenSellTraitMenu(base)
    local playerId = CoopPlayers.GetPlayerByHero(HeroContext.GetCurrentHeroContext()) or 1

    local currentRoom = CurrentRun.CurrentRoom
    local backup
    if playerId > 1 then
        backup = currentRoom.SellOptions
        currentRoom.SellOptions = currentRoom["SellOptions" .. playerId]
    end

    base()

    if playerId > 1 then
        currentRoom["SellOptions" .. playerId] = currentRoom.SellOptions
        currentRoom.SellOptions = backup
    end
end

function MenuHooks.wrap.DisplayTextLine(baseFun, screen, source, line, parentLine)
    if line.Choices then
        -- Only this solution works
        SetConfigOption { Name = "AllowControlHotSwap", Value = true }

        HookUtils.onPreFunctionOnce("UnfreezePlayerUnit", function(name)
            if name == "PlayTextLines" then
                SetConfigOption { Name = "AllowControlHotSwap", Value = false }
            end
        end)
    end
    baseFun(screen, source, line, parentLine)
end

function MenuHooks.pre.OnScreenOpened(screen)
    DebugPrint { Text = "OnScreenOpened:  " .. tostring(screen.Name) }
end

return MenuHooks
