--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class RunEx
local RunEx = {}

---@return boolean
function RunEx.IsRunEnded()
    -- The game sets RunResult when the run ends
    -- So we can use this value to check if the run was finished
    return CurrentRun.RunResult and true
end

---@return boolean
function RunEx.WasTheFirstRunStarted()
    return not GameState or (not CurrentRun and IsEmpty(GameState.RunHistory))
end

---@return boolean
function RunEx.IsFirstRun(run)
    return not GameState or IsEmpty(GameState.RunHistory)
end

---@return boolean
function RunEx.IsShopRoomName(name)
    error("Not implementated")
    return false
end

---@return boolean
function RunEx.IsStoryRoomName(name)
    error("Not implementated")
    return false
end

function RunEx.IsDoorSpecial(door)
    error("Not implementated")
    return false
end

---@return boolean
function RunEx.IsFinalBossDoor(door)
    error("Not implementated")
    return door.ForceRoomName == "D_Boss01"
end

---@return boolean
function RunEx.IsDefaultDoorsLeadToRunProgress()
    error("Not implementated")
    return false
end

function RunEx.RemoveDoorReward(door)
    error("Not implementated")
    return false
end

function RunEx.IsHubRoom(name)
    return name == "Hub_Main" or name == "Hub_PreRun"
end

local META_STORY_ROOMS = {
    I_PostBoss01 = true,
    I_DeathAreaRestored = true,
    I_ChronosFlashback01 = true,
    EndCredits01 = true,
    Q_PostBoss01 = true
}

---@return boolean
function RunEx.IsMetaStoryRoom(name)
    return META_STORY_ROOMS[name] or false
end

function RunEx.GetCurrentRoom()
    return CurrentHubRoom or CurrentRun.CurrentRoom
end

function RunEx.RemoveRewardFromAllDefaultDoors()
    for _, door in pairs(MapState.OfferedExitDoors) do
        if door.IsDefaultDoor then
            RunEx.RemoveDoorReward(door)
        end
    end
end

function RunEx.RefreshEnemyAI()
    for _, enemy in pairs(ActiveEnemies) do
        if not enemy.IsDead then
            -- Staged-AI enemies (bosses like Hecate) drive invulnerability/shield phases from
            -- inside their stage thread: the stage sets the unit invulnerable on entry and only
            -- clears it when that same thread completes. Tearing the thread down mid-phase strands
            -- the invuln flag forever (permanent shield, boss stops attacking) -> co-op softlock
            -- when player 1 dies during the shield phase. Bosses already re-acquire the surviving
            -- player through the GetTargetId/getNearestHero hook, so they don't need a hard AI
            -- restart. Only clear the stale target for them; leave the stage machine intact.
            if enemy.AIStages ~= nil then
                enemy.TargetId = nil
            else
                killTaggedThreads(enemy.AIThreadName)
                killWaitUntilThreads(enemy.AINotifyName)
                Stop({ Id = enemy.ObjectId })
                StopAnimation({ DestinationId = enemy.ObjectId })

                enemy.TargetId = nil
                thread(function()
                    local aiBehavior = enemy.AIBehavior
                    if aiBehavior ~= nil then
                        thread(SetAI, aiBehavior, enemy, CurrentRun)
                    end
                end)
            end
        end
    end
end

return RunEx
