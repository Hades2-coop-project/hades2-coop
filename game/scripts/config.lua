--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class CoopModConfig
local Config = {
    -- Choose loot delivery type here
    -- Possible values: "Shared"
    --
    -- Shared - rooms generate one reward. Only one player can pick it up.
    -- The game has a query that select a player context for a reward.
    -- E.g. Player 1 boon room, meta progress room, Player 2 boon room, Player 1 boon room...
    LootDelivery = "Shared",
    Player1HasOutline = true;
    Player1Outline = {
        R = 0,
        G = 0,
        B = 200,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    -- Set Player 1 costume here
    -- Possible values:
    --     "Models/Melinoe/Melinoe_ArachneArmorA" (Emerald)
    --     "Models/Melinoe/Melinoe_ArachneArmorB" (Azure)
    --     "Models/Melinoe/Melinoe_ArachneArmorC" (Lavender)
    --     "Models/Melinoe/Melinoe_ArachneArmorD" (Fuchsia)
    --     "Models/Melinoe/Melinoe_ArachneArmorE" (Gilded)
    --     "Models/Melinoe/Melinoe_ArachneArmorF" (Onyx)
    --     "Models/Melinoe/Melinoe_ArachneArmorG" (Moonlight)
    --     "Models/Melinoe/Melinoe_ArachneArmorH" (Crimson)
    --     "" (None)
    Player1Skin = "Models/Melinoe/Melinoe_ArachneArmorH";
    Player2HasOutline = true,
    Player2Outline = {
        R = 0,
        G = 200,
        B = 0,
        Opacity = 0.6,
        Thickness = 2,
        Threshold = 0.6,
    };
    -- Set Player 2 costume here
    Player2Skin = "Models/Melinoe/Melinoe_ArachneArmorB";
    TextAbovePlayersEnabled = false;
    TextAbovePlayersParams = {
        -- CreateTextBox params
        OffsetX = 0,
        OffsetY = -150,
        FontSize = 28,
        Color = { 255, 255, 255, 255 },
        ShadowColor = { 0, 0, 0, 240 },
        ShadowOffset = { 0, 2 },
        ShadowBlur = 0,
        OutlineThickness = 3,
        OutlineColor = { 0, 0, 0, 1 },
        Font = "LatoMedium",
        Justification = "Center"
    },
    Debug = {
        OneHit = false,
        P1GodMode = false,
        P2GodMode = false,
    }
}

return Config
