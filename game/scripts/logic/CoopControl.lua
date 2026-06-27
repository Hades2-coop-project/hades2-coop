--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class CoopControl
local CoopControl = {}

---@class PlayerDeviceData
---@field Device "Keyboard" | "Gamepad"
---@field ControllerId integer

local UNUSED_GAMEPAD_INDEX = 5

---@alias ControlSchema "Current" | "Default" | "UserDefined"
-- Default - mod default values
-- UserDefined - User values
-- Current - user values updated in runtime
---@private
---@type table<ControlSchema, PlayerDeviceData[]>
CoopControl.Schemas = {
    Default = {
        {
            Device = "Keyboard",
            ControllerId = UNUSED_GAMEPAD_INDEX,
        };
        {
            Device = "Gamepad",
            ControllerId = 0,
        };
    };
    UserDefined = {};
    Current = {};
}

function CoopControl.InitControlSchemas()
    CoopControl.Schemas.UserDefined = eat_true(GetTempRuntimeData("TN_Coop:control"))
    CoopControl.Schemas.Current = DeepCopyTable(CoopControl.Schemas.UserDefined)

    SetConfigOption { Name = "AllowControlHotSwap", Value = false }
    CoopControl.ResetAllPlayers("UserDefined")
end

---@private
---@param playerId integer
---@param shemaName ControlSchema
function CoopControl.SetPlayerControlSchema(playerId, shemaName)
    local shema = CoopControl.Schemas[shemaName][playerId]

    if playerId == 1 then
        local withMouse = shema.Device == "Keyboard"
        SetConfigOption { Name = "UseMouse", Value = withMouse }
    end
    CoopSetPlayerGamepad(playerId, shema.ControllerId)
end

-- We need first change player 1 controller to requested player controller
-- So the player 2 will control the menu
---@param playerId number
function CoopControl.SwitchControlForMenu(playerId)
    local controllerId = CoopControl.Schemas.Current[playerId].ControllerId

    -- Remember who currently drives the open menu/dialog so that, if that player
    -- dies while the screen is up, we can hand control to a survivor (#33).
    CoopControl.ActiveMenuPlayerId = playerId

    SetConfigOption { Name = "AllowControlHotSwap", Value = true }
    CoopSetPlayerGamepad(1, controllerId)
    for playerId = 2, #CoopControl.Schemas.Current do
        CoopSetPlayerGamepad(playerId, UNUSED_GAMEPAD_INDEX)
    end
end

function CoopControl.ExitMenuControl()
    CoopControl.ActiveMenuPlayerId = nil
    SetConfigOption { Name = "AllowControlHotSwap", Value = false }
    CoopControl.ResetAllPlayers()
end

--- Hand control of an open menu/dialog to an alive player when the player who was
--- driving it dies. Without this, a boon/conversation window that player 1 opened (or
--- that opened under player 1's context) stays bound to player 1's controller after
--- they die, so the surviving player cannot advance or close it -> softlock (#33).
--- No-op unless the dying player actually owns the active menu.
---@param deadPlayerId integer?
---@param alivePlayerId integer?
function CoopControl.HandleMenuOwnerDeath(deadPlayerId, alivePlayerId)
    if alivePlayerId and deadPlayerId and CoopControl.ActiveMenuPlayerId == deadPlayerId then
        CoopControl.SwitchControlForMenu(alivePlayerId)
    end
end

---@param schema ControlSchema?
function CoopControl.ResetAllPlayers(schema)
    schema = schema or "Current"
    for playerId in pairs(CoopControl.Schemas.Current) do
        CoopControl.SetPlayerControlSchema(playerId, schema)
    end
end

function CoopControl.Reset(playerId)
    CoopControl.SetPlayerControlSchema(playerId, "Current")
end

return CoopControl
