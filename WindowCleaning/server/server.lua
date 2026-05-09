local lobbies = {}
local invites = {}
local sessionCounter = 17 + math.random(1, 1000)
local windowLocks = {}
local windowStates = {}
local callbacks = {}
local maxPartySize = 3

local nativeGetPlayerIdentifierByType = GetPlayerIdentifierByType
function GetPlayerIdentifierByType(source, identifierType)
    if source == nil then
        return 0
    end
    if nativeGetPlayerIdentifierByType ~= nil then
        return nativeGetPlayerIdentifierByType(source, identifierType)
    else
        return GetPlayerIdentifier(source, 1)
    end
end

local nativeGetPlayerPing = GetPlayerPing
function GetPlayerPing(source, ...)
    if source ~= nil then
        return nativeGetPlayerPing(source, ...)
    end
    return 0
end

local nativeTriggerClientEvent = TriggerClientEvent
function TriggerClientEvent(eventName, target, ...)
    if target ~= nil then
        nativeTriggerClientEvent(eventName, target, ...)
    end
end

function RegisterServerCallback(callbackName, callback)
    callbacks[callbackName] = callback
end

function RecalculateRewards(hostId)
    local lobbyIndex = 0
    for idx, lobby in pairs(lobbies) do
        if lobby.host == hostId then
            lobbyIndex = idx
        end
    end
    
    local lobby = lobbies[lobbyIndex]
    lobby.rewardsOptions = {}
    
    local partySize = #lobby.clients + 1
    local rewardPercent = math.floor(100 / partySize)
    
    for i = 1, partySize - 1 do
        local clientId = lobby.clients[i]
        lobby.rewardsOptions[clientId] = rewardPercent
    end
    
    lobby.rewardsOptions[hostId] = rewardPercent
    
    TriggerForAllMembers(hostId, "17mov_Cleaner:SetMyReward", math.floor(100 / partySize))
    TriggerClientEvent("17mov_Cleaner:UpdateHostPercentages", hostId, math.floor(100 / partySize))
end

local callbackEventName = "17mov_Callbacks:GetResponse" .. GetCurrentResourceName()
RegisterNetEvent(callbackEventName)

AddEventHandler(callbackEventName, function(callbackName, requestId, ...)
    if Config.Debug ~= nil then
        print("CALLBACK REQUEST: ", callbackName)
    end
    
    if callbacks[callbackName] == nil then
        return
    end
    
    local sourceId = source
    
    if Config.Debug ~= nil then
        print("CALLING: ", callbacks[callbackName])
    end
    
    local result, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11 = callbacks[callbackName](sourceId, ...)
    
    if Config.Debug ~= nil then
        print("CALLBACK RESPONSE: ", result, result2)
    end
    
    local responseEventName = "17mov_Callbacks:receiveData" .. GetCurrentResourceName()
    TriggerClientEvent(responseEventName, sourceId, callbackName, requestId, result, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11)
end)

Citizen.CreateThread(function()
    RegisterServerCallback("17mov_Cleaner:GetPlayersNames", function(source, playerIds)
        local result = {}
        for i = 1, #playerIds do
            table.insert(result, {
                id = playerIds[i],
                name = GetPlayerIdentity(playerIds[i])
            })
        end
        return result
    end)
    
    RegisterServerCallback("17mov_Cleaner:IfPlayerIsHost", function(source)
        local isHost = true
        local lobbyIndex = 0
        
        for idx, lobby in pairs(lobbies) do
            for i = 1, #lobby.clients do
                if lobby.clients[i] == source then
                    isHost = false
                    lobbyIndex = idx
                    break
                end
            end
        end
        
        if not isHost then
            local hostPing = GetPlayerPing(lobbies[lobbyIndex].host)
            if hostPing == 0 then
                isHost = true
                lobbies[lobbyIndex].host = source
            end
        end
        
        return isHost
    end)
    
    RegisterServerCallback("17mov_cleaner:isThisWindowisFree", function(source, windowIndex)
        local lobbyIndex = 0
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == source then
                lobbyIndex = idx
                break
            end
            for i = 1, #lobby.clients do
                if lobby.clients[i] == source then
                    lobbyIndex = idx
                    break
                end
            end
        end
        
        if windowStates[lobbyIndex] == nil then
            windowStates[lobbyIndex] = {}
        end
        
        if windowStates[lobbyIndex][windowIndex] == true then
            return false
        else
            windowLocks[source] = true
            windowStates[lobbyIndex][windowIndex] = true
            return true
        end
    end)
    
    RegisterServerCallback("17mov_Cleaner:init", function(source)
        return {
            name = GetPlayerIdentity(source),
            source = source
        }
    end)
    
    RegisterServerCallback("17mov_Cleaner:GetLobbyMembers", function(source, hostId)
        if hostId == nil then
            return {}
        end
        
        local result = {}
        result[1] = hostId
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == hostId then
                for i = 1, #lobby.clients do
                    table.insert(result, lobby.clients[i])
                end
            end
        end
        
        return result
    end)
    
    RegisterServerCallback("17mov_Cleaner:GetLobbyVehicleId", function(source, hostId)
        local vehNetId = 0
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == hostId then
                if lobby.vehNetId ~= nil then
                    vehNetId = lobby.vehNetId
                end
            end
        end
        
        return vehNetId
    end)
    
    RegisterServerCallback("17mov_Cleaner:CheckThisReward", function(source, rewardPercent, playerId)
        local lobbyIndex = 0
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == source then
                lobbyIndex = idx
                break
            end
            for i = 1, #lobby.clients do
                if lobby.clients[i] == source then
                    lobbyIndex = idx
                    break
                end
            end
        end
        
        local totalPercent = 0
        for playerIdKey, percent in pairs(lobbies[lobbyIndex].rewardsOptions) do
            if playerIdKey ~= playerId then
                totalPercent = totalPercent + percent
            end
        end
        
        if totalPercent + rewardPercent > 100 then
            return false
        else
            lobbies[lobbyIndex].rewardsOptions[playerId] = rewardPercent
            TriggerClientEvent("17mov_Cleaner:SetMyReward", playerId, rewardPercent)
            return true
        end
    end)
    
    RegisterServerCallback("17mov_Cleaner:IfPlayerOwnsTeam", function(source)
        local isOwner = false
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == source then
                isOwner = true
                break
            end
        end
        
        return isOwner
    end)
end)

RegisterNetEvent("17mov_Cleaner:enableThisWindow")
AddEventHandler("17mov_Cleaner:enableThisWindow", function(windowIndex)
    local lobbyIndex = 0
    local sourceId = source
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            lobbyIndex = idx
            break
        end
        for i = 1, #lobby.clients do
            if lobby.clients[i] == sourceId then
                lobbyIndex = idx
                break
            end
        end
    end
    
    if windowStates[lobbyIndex] ~= nil then
        windowStates[lobbyIndex][windowIndex] = nil
    end
end)

RegisterNetEvent("17mov_Cleaner:SendRequestToClient_sv")
AddEventHandler("17mov_Cleaner:SendRequestToClient_sv", function(targetId)
    local sourceId = source
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == targetId then
            Notify(sourceId, Config.Lang.isAlreadyHost)
            return
        else
            for i = 1, #lobby.clients do
                if lobby.clients[i] == targetId then
                    Notify(sourceId, Config.Lang.isBusy)
                    return
                end
            end
        end
    end
    
    for idx, invite in pairs(invites) do
        if invite.client == targetId then
            Notify(sourceId, Config.Lang.hasActiveInvite)
            return
        end
        if invite.host == sourceId and invite.client ~= nil then
            Notify(sourceId, Config.Lang.HaveActiveInvite)
            return
        end
    end
    
    local clients = {}
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            clients = lobby.clients
        end
    end
    
    if #clients + 1 >= maxPartySize then
        Notify(sourceId, Config.Lang.partyIsFull)
        return
    end
    
    table.insert(invites, {
        host = sourceId,
        client = targetId
    })
    
    Notify(sourceId, Config.Lang.inviteSent)
    TriggerClientEvent("17mov_Cleaner:SendRequestToClient_cl", targetId, GetPlayerIdentity(sourceId))
end)

RegisterNetEvent("17mov_Cleaner:ClientReactRequest")
AddEventHandler("17mov_Cleaner:ClientReactRequest", function(accepted)
    local sourceId = source
    local hostId = nil
    local joined = false
    
    for idx, invite in pairs(invites) do
        if invite.client == sourceId then
            hostId = invite.host
            invites[idx] = nil
            break
        end
    end
    
    if accepted then
        if hostId ~= nil and sourceId ~= nil then
            for idx, lobby in pairs(lobbies) do
                if lobby.host == hostId then
                    if lobby.clients ~= nil then
                        table.insert(lobby.clients, sourceId)
                        joined = true
                    end
                end
            end
            
            if not joined then
                table.insert(lobbies, {
                    host = hostId,
                    clients = {sourceId},
                    bags = 0,
                    hamperNetId = 0,
                    readyIndexes = {},
                    lastHamperCoords = vec3(0, 0, 0)
                })
            end
            
            if Config.useModernUI then
                RecalculateRewards(hostId)
            end
            
            Notify(hostId, Config.Lang.InviteAccepted)
            local mugs = GetAllPartyMugs(hostId)
            TriggerForAllMembers(hostId, "17mov_Cleaner:RefreshMugs", mugs)
        else
            Notify(sourceId, Config.Lang.error)
            Notify(hostId, Config.Lang.error)
        end
    else
        Notify(hostId, Config.Lang.InviteDeclined)
    end
end)

RegisterNetEvent("17mov_Cleaner:KickPlayerFromLobby")
AddEventHandler("17mov_Cleaner:KickPlayerFromLobby", function(playerId, notifyPlayer, kickerId)
    local kickedPlayerId = playerId
    local hostId = nil
    
    if kickerId == nil then
        hostId = source
        for idx, lobby in pairs(lobbies) do
            for i = 1, #lobby.clients do
                if lobby.host == hostId then
                    if lobby.clients[i] == kickedPlayerId then
                        lobby.clients[i] = nil
                        break
                    end
                end
            end
        end
    else
        for idx, lobby in pairs(lobbies) do
            for i = 1, #lobby.clients do
                if lobby.clients[i] == kickerId then
                    hostId = lobby.host
                    lobby.clients[i] = nil
                    break
                end
            end
        end
    end
    
    if notifyPlayer then
        Notify(kickedPlayerId, Config.Lang.kickedOut)
    end
    
    if Config.useModernUI then
        local soloPlayerData = {}
        table.insert(soloPlayerData, {
            id = kickedPlayerId,
            name = GetPlayerIdentity(kickedPlayerId),
            isHost = true
        })
        
        TriggerClientEvent("17mov_Cleaner:RefreshMugs", kickedPlayerId, soloPlayerData, kickedPlayerId)
        TriggerClientEvent("17mov_Cleaner:clearMyLobby", kickedPlayerId)
        TriggerClientEvent("17mov_Cleaner:SetMyReward", kickedPlayerId, 100)
        
        local mugs = GetAllPartyMugs(hostId)
        TriggerForAllMembers(hostId, "17mov_Cleaner:RefreshMugs", mugs)
        RecalculateRewards(hostId)
        
        for idx, lobby in pairs(lobbies) do
            if #lobby.clients == 0 then
                if lobby.host == hostId then
                    lobbies[idx] = nil
                    TriggerClientEvent("17mov_Cleaner:clearMyLobby", hostId)
                end
            end
        end
    else
        local soloPlayerData = {}
        table.insert(soloPlayerData, {
            id = kickedPlayerId,
            name = GetPlayerIdentity(kickedPlayerId),
            isHost = true
        })
        
        TriggerClientEvent("17mov_Cleaner:RefreshMugs", kickedPlayerId, soloPlayerData, kickedPlayerId)
        
        local mugs = GetAllPartyMugs(hostId)
        TriggerForAllMembers(hostId, "17mov_Cleaner:RefreshMugs", mugs)
        
        for idx, lobby in pairs(lobbies) do
            if #lobby.clients == 0 then
                if lobby.host == hostId then
                    lobbies[idx] = nil
                end
            end
        end
    end
end)

RegisterNetEvent("17mov_Cleaner:endJob_sv")
AddEventHandler("17mov_Cleaner:endJob_sv", function(hasVehicle)
    local sourceId = source
    TriggerForAllMembers(sourceId, "17mov_Cleaner:endJob_cl", 0)
    
    local totalBags = nil
    local partyMembers = nil
    local lobbyIndex = nil
    local totalReward = nil
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            lobby.working = false
            totalBags = lobby.bags
            lobby.bags = 0
            lobby.cleanedWindows = {}
            windowStates[idx] = nil
            
            partyMembers = {}
            for i = 1, #lobby.clients do
                table.insert(partyMembers, lobby.clients[i])
            end
            table.insert(partyMembers, lobby.host)
            
            totalReward = totalBags * Config.Price
            if Config.multiplyRewardWhileWorkingInGroup then
                totalReward = math.floor((#lobby.clients + 1) * totalReward)
            end
            
            if Config.useModernUI then
                if #lobby.clients == 0 then
                    RecalculateRewards(sourceId)
                end
            end
            
            local paidPlayers = {}
            for i = 1, #partyMembers do
                local playerReward = 0
                
                if Config.useModernUI then
                    if Config.letBossSplitReward then
                        playerReward = math.floor((lobby.rewardsOptions[partyMembers[i]] / 100) * totalReward)
                    end
                else
                    if Config.useModernUI == false then
                        if Config.splitReward then
                            playerReward = math.floor(totalReward / (#lobby.clients + 1))
                        end
                    else
                        playerReward = totalReward
                    end
                end
                
                if not hasVehicle then
                    PayPenalty(partyMembers[i], Config.PenaltyAmount)
                    Notify(partyMembers[i], Config.Lang.penalty .. Config.PenaltyAmount)
                end
                
                if not hasVehicle then
                    if hasVehicle then
                        goto skip_payment
                    end
                    if Config.DontPayRewardWithoutVehicle ~= false then
                        goto skip_payment
                    end
                end
                
                if not paidPlayers[partyMembers[i]] then
                    paidPlayers[partyMembers[i]] = true
                    Pay(partyMembers[i], playerReward, #partyMembers, totalBags, lobby.location)
                    Notify(partyMembers[i], Config.Lang.reward .. playerReward)
                end
                
                ::skip_payment::
            end
            
            if #lobby.clients == 0 then
                lobbies[idx] = nil
                TriggerClientEvent("17mov_Cleaner:clearMyLobby", sourceId)
            end
            
            break
        end
    end
end)

local cooldownsTable = {}

RegisterNetEvent("17mov_Cleaner:StartJob_sv")
AddEventHandler("17mov_Cleaner:StartJob_sv", function()
    local sourceId = source
    local clients = nil
    local lobbyIndex = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            clients = lobby.clients
            lobbyIndex = idx
            windowStates[idx] = nil
            break
        end
    end
    
    if Config.RequireJobAlsoForFriends then
        if Config.RequiredJob ~= "none" and clients ~= nil then
            for i = 1, #clients do
                if GetPlayerJob(clients[i]) ~= Config.RequiredJob then
                    Notify(sourceId, Config.Lang.notEverybodyHasRequiredJob)
                    return
                end
            end
        end
    end
    
    if not isHaveRequiredItem(sourceId) then
        Notify(sourceId, Config.Lang.dontHaveReqItem)
        return
    end
    
    if Config.RequireItemFromWholeTeam and clients ~= nil then
        for i = 1, #clients do
            if not isHaveRequiredItem(clients[i]) then
                Notify(sourceId, Config.Lang.dontHaveReqItem)
                return
            end
        end
    end
    
    if Config.JobCooldown > 0 then
        if CooldownsTime == nil then
            CooldownsTime = {}
        end
        
        local currentTime = os.time()
        local licenseId = GetPlayerIdentifierByType(sourceId, "license")
        
        if cooldownsTable[licenseId] then
            local timePassed = currentTime - CooldownsTime[licenseId]
            if timePassed >= Config.JobCooldown then
                cooldownsTable[licenseId] = nil
                CooldownsTime[licenseId] = nil
            else
                local remainingTime = Config.JobCooldown - timePassed
                local hours = math.floor(remainingTime / 3600)
                local minutes = math.floor((remainingTime % 3600) / 60)
                local seconds = remainingTime % 60
                
                local timeString = ""
                if hours > 0 then
                    timeString = timeString .. hours .. Config.Lang.hours .. " "
                end
                if minutes > 0 then
                    timeString = timeString .. minutes .. Config.Lang.minutes .. " "
                end
                timeString = timeString .. seconds .. Config.Lang.seconds
                
                Notify(sourceId, string.format(Config.Lang.someoneIsOnCooldown, GetPlayerIdentity(sourceId), timeString))
                return
            end
        end
        
        if clients ~= nil then
            for i = 1, #clients do
                local clientLicense = GetPlayerIdentifierByType(clients[i], "license")
                if cooldownsTable[clientLicense] then
                    local timePassed = currentTime - CooldownsTime[clientLicense]
                    if timePassed >= Config.JobCooldown then
                        cooldownsTable[clientLicense] = nil
                        CooldownsTime[clientLicense] = nil
                    else
                        local remainingTime = Config.JobCooldown - timePassed
                        local hours = math.floor(remainingTime / 3600)
                        local minutes = math.floor((remainingTime % 3600) / 60)
                        local seconds = remainingTime % 60
                        
                        local timeString = ""
                        if hours > 0 then
                            timeString = timeString .. hours .. Config.Lang.hours .. " "
                        end
                        if minutes > 0 then
                            timeString = timeString .. minutes .. Config.Lang.minutes .. " "
                        end
                        timeString = timeString .. seconds .. Config.Lang.seconds
                        
                        Notify(sourceId, string.format(Config.Lang.someoneIsOnCooldown, GetPlayerIdentity(clients[i]), timeString))
                        return
                    end
                end
            end
        end
        
        cooldownsTable[licenseId] = true
        CooldownsTime[licenseId] = currentTime
        
        if clients ~= nil then
            for i = 1, #clients do
                local clientLicense = GetPlayerIdentifierByType(clients[i], "license")
                cooldownsTable[clientLicense] = true
                CooldownsTime[clientLicense] = currentTime
            end
        end
    end
    
    if Config.RequireOneFriendMinimum then
        if clients ~= nil then
            if #clients > 0 then
                local locationIndex = math.random(1, #Config.JobLocations)
                TriggerForAllMembers(sourceId, "17mov_Cleaner:StartJob_cl", sourceId)
                TriggerForAllMembers(sourceId, "17mov_Cleaner:takeNewJob", locationIndex)
                lobbies[lobbyIndex].working = true
                lobbies[lobbyIndex].location = locationIndex
            end
        else
            Notify(sourceId, Config.Lang.RequireOneFriend)
        end
    else
        if clients == nil then
            table.insert(lobbies, {
                host = sourceId,
                clients = {},
                bags = 0,
                hamperNetId = 0,
                readyIndexes = {}
            })
        end
        
        for idx, lobby in pairs(lobbies) do
            if lobby.host == sourceId then
                lobbyIndex = idx
                break
            end
        end
        
        local locationIndex = math.random(1, #Config.JobLocations)
        TriggerForAllMembers(sourceId, "17mov_Cleaner:StartJob_cl", sourceId)
        TriggerForAllMembers(sourceId, "17mov_Cleaner:takeNewJob", locationIndex)
        lobbies[lobbyIndex].working = true
        lobbies[lobbyIndex].location = locationIndex
    end
end)

RegisterNetEvent("17mov_Cleaner:StartSession")
AddEventHandler("17mov_Cleaner:StartSession", function(locationIndex)
    local sourceId = source
    
    if Config.Debug ~= nil then
        print("SESSION CHECK 1")
    end
    
    local partyMembers = {}
    sessionCounter = sessionCounter + 1
    local sessionBucket = sessionCounter
    local vehicleNetId = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            for i = 1, #lobby.clients do
                table.insert(partyMembers, lobby.clients[i])
            end
            lobby.bucket = sessionBucket
            lobby.readyIndexes = {}
            vehicleNetId = lobby.vehNetId
        end
    end
    
    table.insert(partyMembers, sourceId)
    
    if Config.Debug ~= nil then
        print("SESSION CHECK 2", json.encode(partyMembers))
    end
    
    for i = 1, #partyMembers do
        if Config.DisableCoordsCheck ~= true then
            local playerPed = GetPlayerPed(partyMembers[i])
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - Config.JobLocations[locationIndex].enterCoords)
            if not (distance < 100.0) then
                if NotWorkingLogFunc ~= nil then
                    NotWorkingLogFunc(partyMembers[i])
                end
                goto continue_loop
            end
        end
        
        SetPlayerRoutingBucket(partyMembers[i], sessionBucket)
        TriggerClientEvent("17mov_Cleaner:TeleportToPlatform", partyMembers[i], sourceId, partyMembers[i], locationIndex)
        
        if Config.Debug ~= nil then
            print("TRIGGERING FOR: ", partyMembers[i])
        end
        
        ::continue_loop::
    end
    
    if vehicleNetId ~= 0 then
        local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNetId)
        SetEntityRoutingBucket(vehicleEntity, sessionBucket)
    end
end)

RegisterNetEvent("17mov_Cleaner:exitSession")
AddEventHandler("17mov_Cleaner:exitSession", function(locationIndex, emergencyExit, tooFar, coords)
    local sourceId = source
    local partyMembers = {}
    local hostId = 0
    local sessionBucket = nil
    local vehicleNetId = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            for i = 1, #lobby.clients do
                table.insert(partyMembers, lobby.clients[i])
            end
            hostId = lobby.host
            sessionBucket = lobby.bucket
            vehicleNetId = lobby.vehNetId
            break
        end
        
        for i = 1, #lobby.clients do
            if lobby.clients[i] == sourceId then
                for j = 1, #lobby.clients do
                    table.insert(partyMembers, lobby.clients[j])
                end
                hostId = lobby.host
                sessionBucket = lobby.bucket
                vehicleNetId = lobby.vehNetId
                break
            end
        end
    end
    
    if sessionBucket == nil then
        return
    end
    
    table.insert(partyMembers, hostId)
    
    if vehicleNetId ~= 0 then
        local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNetId)
        SetEntityRoutingBucket(vehicleEntity, Config.DefaultBucket)
    end
    
    for i = 1, #partyMembers do
        TriggerClientEvent("17mov_Cleaner:exitPlatform", partyMembers[i], hostId, partyMembers[i], locationIndex, sourceId, coords)
        SetPlayerRoutingBucket(partyMembers[i], Config.DefaultBucket)
        
        if emergencyExit then
            if not tooFar then
                Notify(partyMembers[i], Config.Lang.emergencyStop)
            else
                Notify(partyMembers[i], Config.Lang.tooFar)
            end
        end
    end
end)

function GetLobbyIndex(playerId)
    local lobbyIndex = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == playerId then
            lobbyIndex = idx
            break
        end
        for i = 1, #lobby.clients do
            if lobby.clients[i] == playerId then
                lobbyIndex = idx
                break
            end
        end
    end
    
    return lobbyIndex
end

RegisterNetEvent("17mov_cleaner:StartHamperTop")
AddEventHandler("17mov_cleaner:StartHamperTop", function()
    local lobbyIndex = GetLobbyIndex(source)
    local hostId = lobbies[lobbyIndex].host
    TriggerForAllMembers(hostId, "17mov_cleaner:startHamperTop")
end)

RegisterNetEvent("17mov_cleaner:StartHamperBottom")
AddEventHandler("17mov_cleaner:StartHamperBottom", function()
    local lobbyIndex = GetLobbyIndex(source)
    local hostId = lobbies[lobbyIndex].host
    TriggerForAllMembers(hostId, "17mov_cleaner:startHamperBottom")
end)

RegisterNetEvent("17mov_cleaner:StopHamperBottom")
AddEventHandler("17mov_cleaner:StopHamperBottom", function(coords)
    local lobbyIndex = GetLobbyIndex(source)
    lobbies[lobbyIndex].lastHamperCoords = coords
    local hostId = lobbies[lobbyIndex].host
    TriggerForAllMembers(hostId, "17mov_cleaner:stopHamperBottom", coords)
    Citizen.Wait(100)
    TriggerForAllMembers(hostId, "17mov_cleaner:stopHamperBottom", coords)
end)

RegisterNetEvent("17mov_cleaner:StopHamperTop")
AddEventHandler("17mov_cleaner:StopHamperTop", function(coords)
    local lobbyIndex = GetLobbyIndex(source)
    lobbies[lobbyIndex].lastHamperCoords = coords
    local hostId = lobbies[lobbyIndex].host
    TriggerForAllMembers(hostId, "17mov_cleaner:stopHamperTop", coords)
    Citizen.Wait(100)
    TriggerForAllMembers(hostId, "17mov_cleaner:stopHamperTop", coords)
end)

RegisterNetEvent("17mov_cleaner:refreshCoords")
AddEventHandler("17mov_cleaner:refreshCoords", function(coords)
    local lobbyIndex = GetLobbyIndex(source)
    local hostId = lobbies[lobbyIndex].host
    TriggerForAllMembers(hostId, "17mov_cleaner:refreshCoords_cl", coords)
end)

function CalculateDistance2D(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
end

local windowCooldowns = {}

RegisterNetEvent("17mov_cleaner:ThisWindowReady")
AddEventHandler("17mov_cleaner:ThisWindowReady", function(locationIndex, windowIndex)
    local sourceId = source
    
    if not windowLocks[sourceId] then
        return
    end
    
    if windowCooldowns[sourceId] then
        local timePassed = os.time() - windowCooldowns[sourceId]
        if timePassed < 1 then
            return
        end
    end
    
    local windowConfig = Config.JobLocations[locationIndex]
    if windowConfig then
        windowConfig = windowConfig.windowsLocations
    end
    windowConfig = windowConfig[windowIndex]
    windowConfig = windowConfig.coords
    
    if not windowConfig then
        return
    end
    
    local playerPed = GetPlayerPed(sourceId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = CalculateDistance2D(playerCoords, windowConfig)
    
    if distance > 5.0 then
        return
    end
    
    windowCooldowns[sourceId] = os.time()
    windowLocks[sourceId] = nil
    
    local partyMembers = {}
    local hostId = 0
    local bagsCount = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            for i = 1, #lobby.clients do
                table.insert(partyMembers, lobby.clients[i])
            end
            table.insert(lobby.readyIndexes, windowIndex)
            hostId = lobby.host
            lobby.bags = lobby.bags + 1
            bagsCount = lobby.bags
            break
        end
        
        for i = 1, #lobby.clients do
            if lobby.clients[i] == sourceId then
                for j = 1, #lobby.clients do
                    table.insert(partyMembers, lobby.clients[j])
                end
                table.insert(lobby.readyIndexes, windowIndex)
                hostId = lobby.host
                lobby.bags = lobby.bags + 1
                bagsCount = lobby.bags
                break
            end
        end
    end
    
    if hostId ~= nil then
        table.insert(partyMembers, hostId)
        TriggerEvent("17mov_Cleaner:PlayerCleanedWindow", sourceId)
        
        for i = 1, #partyMembers do
            TriggerClientEvent("17mov_Cleaner:disableWindow", partyMembers[i], windowIndex, bagsCount)
        end
    end
end)

RegisterNetEvent("playerDropped")
AddEventHandler("playerDropped", function()
    local sourceId = source
    
    for idx, lobby in pairs(lobbies) do
        if lobby.controller == nil then
            lobby.controller = lobby.host
        end
        
        if lobby.controller == sourceId then
            local candidates = {}
            table.insert(candidates, lobby.host)
            for i = 1, #lobby.clients do
                table.insert(candidates, lobby.clients[i])
            end
            
            for i = 1, #candidates do
                if candidates[i] ~= sourceId then
                    local ping = GetPlayerPing(candidates[i])
                    if ping ~= 0 then
                        lobby.controller = candidates[i]
                        TriggerClientEvent("17mov_Cleaner:StartHostPlatformCode", candidates[i])
                        return
                    end
                end
            end
        end
    end
end)

function GetAllPartyMugs(hostId)
    local result = {}
    local clients = {}
    local lobbyIndex = 0
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == hostId then
            clients = lobby.clients
            lobbyIndex = idx
        end
    end
    
    if Config.useModernUI then
        for i = 1, #clients do
            table.insert(result, {
                id = clients[i],
                name = GetPlayerIdentity(clients[i]),
                isHost = false,
                rewardPercent = lobbies[lobbyIndex].rewardsOptions[clients[i]]
            })
        end
        
        if #clients == 0 then
            table.insert(result, {
                id = hostId,
                name = GetPlayerIdentity(hostId),
                isHost = true,
                rewardPercent = lobbies[lobbyIndex].rewardsOptions[hostId]
            })
        else
            table.insert(result, {
                id = hostId,
                name = GetPlayerIdentity(hostId),
                isHost = true,
                rewardPercent = lobbies[lobbyIndex].rewardsOptions[hostId]
            })
        end
    else
        for i = 1, #clients do
            table.insert(result, {
                id = clients[i],
                name = GetPlayerIdentity(clients[i]),
                isHost = false
            })
        end
        
        if #clients == 0 then
            table.insert(result, {
                id = hostId,
                name = GetPlayerIdentity(hostId),
                isHost = true
            })
        else
            table.insert(result, {
                id = hostId,
                name = GetPlayerIdentity(hostId),
                isHost = true
            })
        end
    end
    
    return result
end

function TriggerForAllMembers(hostId, eventName, arg1, arg2)
    local clients = {}
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == hostId then
            clients = lobby.clients
        end
    end
    
    for i = 1, #clients + 1 do
        local playerId = clients[i]
        if i > #clients then
            playerId = hostId
        end
        
        if playerId ~= nil then
            if type(playerId) == "number" then
                if eventName == "17mov_Cleaner:RefreshMugs" or eventName == "17mov_Cleaner:StartJob_cl" then
                    TriggerClientEvent(eventName, playerId, arg1, playerId)
                else
                    TriggerClientEvent(eventName, playerId, arg1, arg2)
                end
            end
        end
    end
end

RegisterNetEvent("17mov_Cleaner:UploadVehicleNetId")
AddEventHandler("17mov_Cleaner:UploadVehicleNetId", function(vehicleNetId)
    local sourceId = source
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            lobby.vehNetId = vehicleNetId
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    
    for idx, lobby in pairs(lobbies) do
        if lobby.bucket ~= nil then
            for i = 1, #lobby.clients do
                SetPlayerRoutingBucket(lobby.clients[i], Config.DefaultBucket)
            end
            SetPlayerRoutingBucket(lobby.host, Config.DefaultBucket)
            
            if lobby.vehNetId ~= 0 then
                local vehicleEntity = NetworkGetEntityFromNetworkId(lobby.vehNetId)
                SetEntityRoutingBucket(vehicleEntity, Config.DefaultBucket)
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local sourceId = source
    local lobbyIndex = "waiting"
    
    for idx, lobby in pairs(lobbies) do
        if lobby.host == sourceId then
            for i = 1, #lobby.clients do
                local ping = GetPlayerPing(lobby.clients[i])
                if ping ~= 0 then
                    lobby.host = lobby.clients[i]
                    Notify(lobby.clients[i], Config.Lang.newBoss)
                    lobby.clients[i] = nil
                    break
                end
            end
            lobbyIndex = idx
            break
        end
        
        for i = 1, #lobby.clients do
            if lobby.clients[i] == sourceId then
                lobby.clients[i] = nil
                lobbyIndex = idx
                break
            end
        end
    end
    
    if lobbyIndex == "waiting" then
        return
    end
    
    local hostId = lobbies[lobbyIndex].host
    local isWorking = lobbies[lobbyIndex].working
    
    if isWorking then
        if #lobbies[lobbyIndex].clients == 0 then
            TriggerClientEvent("17mov_Cleaner:clearMyLobby", hostId)
        else
            local mugs = GetAllPartyMugs(hostId)
            TriggerForAllMembers(hostId, "17mov_Cleaner:RefreshMugs", mugs)
            if Config.useModernUI then
                RecalculateRewards(hostId)
            end
        end
    else
        if #lobbies[lobbyIndex].clients == 0 then
            TriggerClientEvent("17mov_Cleaner:clearMyLobby", hostId)
            lobbies[lobbyIndex] = nil
        end
    end
end)
