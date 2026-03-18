--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type CoopModConfig
local Config = ModRequire "../config.lua"

---@class PlayerVisibilityHelper
local PlayerVisibilityHelper = {}

---@param playerId number
---@param unit number
function PlayerVisibilityHelper.AddPlayerMarkers(playerId, unit)
    PlayerVisibilityHelper.TriggerOutline(playerId, unit)
    PlayerVisibilityHelper.TriggerText(playerId, unit)
    PlayerVisibilityHelper.TriggerCostume(playerId, unit)
end

function PlayerVisibilityHelper.TriggerOutline(playerId, unit)
    if Config["Player" .. playerId .. "HasOutline"] then
        AddOutline(
            MergeTables(Config["Player" .. playerId .. "Outline"], { Id = unit })
        )
    end
end

function PlayerVisibilityHelper.TriggerText(playerId, unit)
    if Config.TextAbovePlayersEnabled then
        CreateTextBox(
            MergeTables(Config.TextAbovePlayersParams,
                {
                    Id = unit,
                    Text = "P" .. playerId,
                })
        )
    end
end

function PlayerVisibilityHelper.TriggerCostume(playerId, unit)
    SetThingProperty({Property = "GrannyTexture", Value = Config["Player"..playerId.."Skin"], DestinationId = unit})
end

return PlayerVisibilityHelper
