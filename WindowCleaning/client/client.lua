local jobVehicle, playerData, currentLocationIndex, onPlatform, hamperEntity, handleEntity, hamperMovingDown, hamperMovingUp, currentWindowIndex, hamperControlEnabled, uiInitialized, lobbyMembers, scriptReady, callbackRequests, requestCounter, lobbyData, tutorialResourceName, driverLoaded, nuiLoaded, soundHandle
jobVehicle = nil
playerData = nil
currentLocationIndex = -1
onPlatform = false
hamperEntity = nil
handleEntity = nil
hamperMovingDown = false
hamperMovingUp = false
currentWindowIndex = 0
hamperControlEnabled = false
OnDuty = false
JobVehicleNetId = nil
uiInitialized = false
lobbyMembers = {}
scriptReady = false
callbackRequests = {}
requestCounter = 0
lobbyData = {}
local playerId = PlayerId()
local playerServerId = GetPlayerServerId(playerId)
menuOpen = true
tutorialResourceName = ""
driverLoaded = false
nuiLoaded = false
soundHandle = nil
RegisterNUICallback("driverLoaded", function()
  driverLoaded = true
end)
RegisterNUICallback("nuiLoaded", function()
  nuiLoaded = true
end)
CreateThread(function()
  while not driverLoaded do
    Citizen.Wait(100)
  end
  if Config.useModernUI then
    SendNUIMessage({ui = "new"})
  else
    SendNUIMessage({ui = "old"})
    nuiLoaded = true
    Citizen.Wait(500)
  end
  while not nuiLoaded do
    Citizen.Wait(100)
  end
  SendNUIMessage({
    action = "setProgressBarAlign",
    align = Config.ProgressBarAlign,
    offset = Config.ProgressBarOffset
  })
  if not Config.EnableCloakroom then
    SendNUIMessage({action = "hideCloakroom"})
  end
end)
RegisterNUICallback("tutorialClosed", function()
  SetNuiFocus(false, false)
  tutorialResourceName = ""
end)
RegisterNetEvent("17mov_Cleaner:UpdateHostPercentages")
AddEventHandler("17mov_Cleaner:UpdateHostPercentages", function(value)
  SendNUIMessage({
    action = "updateHostRewards",
    value = value
  })
end)
RegisterNUICallback("menuClosed", function()
  menuOpen = false
  SetNuiFocus(false, false)
end)
RegisterNUICallback("dontShowTutorialAgain", function()
  SetResourceKvpInt("17mov_Tutorials:Cleaner:" .. tutorialResourceName, 1)
end)
RegisterNetEvent("17mov_Cleaner:SetMyReward")
AddEventHandler("17mov_Cleaner:SetMyReward", function(reward)
  SendNUIMessage({
    action = "updateMyReward",
    reward = reward
  })
end)
if Config.letBossSplitReward then
  RegisterNUICallback("checkIfThisRewardIsFine", function(data, cb)
    local rewardValue = math.floor(data.value)
    local playerId = data.plyId
    if rewardValue > 100 or rewardValue < 0 then
      Notify(Config.Lang.wrongReward1)
      cb(false)
      return
    end
    TriggerServerCallback("17mov_Cleaner:CheckThisReward", function(isValid)
      if isValid then
        cb(true)
      else
        cb(false)
        Notify(Config.Lang.wrongReward2)
      end
    end, rewardValue, playerId)
  end)
else
  CreateThread(function()
    while not nuiLoaded do
      Citizen.Wait(100)
    end
    SendNUIMessage({action = "hideManageRewards"})
  end)
end
RegisterNetEvent("17mov_Cleaner:clearMyLobby")
AddEventHandler("17mov_Cleaner:clearMyLobby", function()
  lobbyData = {}
  TriggerServerCallback("17mov_Cleaner:init", function(data)
    SendNUIMessage({
      action = "Init",
      name = data.name,
      myId = data.source
    })
    uiInitialized = true
  end)
end)
function TriggerServerCallback(callbackName, callback, ...)
  requestCounter = requestCounter + 1
  local requestId = requestCounter
  if not callbackRequests[callbackName] then
    callbackRequests[callbackName] = {}
  end
  callbackRequests[callbackName][requestId] = callback
  if Config.Debug then
    print("SENDING REQUEST: ", callbackName, requestId)
  end
  TriggerServerEvent("17mov_Callbacks:GetResponse" .. GetCurrentResourceName(), callbackName, requestId, ...)
end
local callbackEventName = "17mov_Callbacks:receiveData" .. GetCurrentResourceName()
RegisterNetEvent(callbackEventName)
AddEventHandler(callbackEventName, function(callbackName, requestId, ...)
  if Config.Debug then
    print("ROOT RESPONSE FROM: ", callbackName, requestId)
  end
  if callbackRequests[callbackName] and callbackRequests[callbackName][requestId] then
    local callback = callbackRequests[callbackName][requestId]
    callback(...)
    callbackRequests[callbackName][requestId] = nil
    if #callbackRequests[callbackName] == 0 then
      callbackRequests[callbackName] = nil
    end
  end
end)
local soundPlaying = false
local lastSoundCoords = nil
local garageDoorSoundId = nil
function PlaySoundAtCoord(soundId, soundName, coords, soundSet)
  return PlaySoundFromCoord(soundId, soundName, coords.x, coords.y, coords.z, soundSet, false, 0, false)
end
function PlayGarageDoorSound()
  if not soundPlaying then
    lastSoundCoords = GetEntityCoords(PlayerPedId())
    garageDoorSoundId = PlaySoundAtCoord(-1, "OPENING", lastSoundCoords, "DOOR_GARAGE")
    soundPlaying = true
  end
end
function StopGarageDoorSound(coords)
  if soundPlaying then
    if garageDoorSoundId then
      StopSound(garageDoorSoundId)
    end
    PlaySoundAtCoord(-1, "CLOSED", coords, "MP_PROPERTIES_ELEVATOR_DOORS")
    garageDoorSoundId = nil
    soundPlaying = false
  end
end
local markersActive = false

function DrawLocationMarker(coord, scale, isActive)
  local color = isActive and Config.MarkerSettings.Active or Config.MarkerSettings.UnActive
  DrawMarker(6, coord.x, coord.y, coord.z - 1, 0.0, 0.0, 0.0, -90.0, 0.0, 0.0, scale.x, scale.y, scale.z, color.r, color.g, color.b, color.a, false, false, 2, false, false, false, false)
end

function StartMarkers(playerData)
  if markersActive then
    return
  end
  if Config.RequiredJob ~= "none" then
    if playerData.job.name ~= Config.RequiredJob then
      markersActive = false
      return
    end
  end
  markersActive = true
  if Config.UseTarget then
    SpawnStartingPed()
    Config.Locations2 = {FinishJob = Config.Locations.FinishJob}
    while true do
      if not markersActive then
        break
      end
      Citizen.Wait(0)
      local playerCoords = GetEntityCoords(PlayerPedId())
      local hasFoundMarker = false
      local hasExitedMarker = false
      local shouldShowMarker = true
      local currentStation = nil
      local currentPart = nil
      local currentPartNum = nil
      local jobCheck = Config.RequiredJob
      if Config.RequiredJob ~= "none" then
        if playerData.job.name == Config.RequiredJob then
          goto lbl_63
        end
      end
      ::lbl_63::
      if jobCheck == "none" then
        for locationType, locationData in pairs(Config.Locations2) do
          if locationData.grade then
            if playerData.job.grade < locationData.grade then
              goto lbl_198
            end
          end
          if not OnDuty then
            if locationData.type ~= "duty" then
              goto lbl_198
            end
          end
          for coordIndex, coord in pairs(locationData.Coords) do
            local distance = #(playerCoords - coord)
            if distance < 20 then
              local scaleX = locationData.scale.x
              if distance > scaleX then
                DrawLocationMarker(coord, locationData.scale, false)
                shouldShowMarker = false
              else
                if distance < scaleX then
                  DrawLocationMarker(coord, locationData.scale, true)
                  hasFoundMarker = true
                  currentStation = locationType
                  currentPart = locationType
                  currentPartNum = Iterator
                  shouldShowMarker = false
                end
              end
            end
          end
          ::lbl_198::
        end
        if hasFoundMarker then
          if not HasAlreadyEnteredMarker then
            goto lbl_217
          end
          if LastStation == currentStation and LastPart == currentPart and LastPartNum == currentPartNum then
            goto lbl_250
          end
          ::lbl_217::
          if LastStation and LastPart and LastPartNum then
            if LastStation == currentStation and LastPart == currentPart and LastPartNum == currentPartNum then
              goto lbl_242
            end
            TriggerEvent("17mov_Cleaner:ExitedMarker", LastStation, LastPart, LastPartNum)
            hasExitedMarker = true
          end
          ::lbl_242::
          HasAlreadyEnteredMarker = true
          LastStation = currentStation
          LastPart = currentPart
          LastPartNum = currentPartNum
          TriggerEvent("17mov_Cleaner:EnteredMarker", currentPart)
          ::lbl_250::
        end
        if not hasExitedMarker and not hasFoundMarker then
          if HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = false
            TriggerEvent("17mov_Cleaner:ExitedMarker", LastStation, LastPart, LastPartNum)
          end
        end
        if shouldShowMarker then
          Citizen.Wait(500)
        end
      end
    end
    DeleteEntity(spawnedPed)
  else
    while markersActive do
      Citizen.Wait(0)
      local playerCoords = GetEntityCoords(PlayerPedId())
      local hasFoundMarker = false
      local hasExitedMarker = false
      local shouldShowMarker = true
      local currentStation = nil
      local currentPart = nil
      local currentPartNum = nil
      local jobCheck = Config.RequiredJob
      if Config.RequiredJob ~= "none" then
        if playerData.job.name == Config.RequiredJob then
          goto lbl_304
        end
      end
      ::lbl_304::
      if jobCheck == "none" then
        for locationType, locationData in pairs(Config.Locations) do
          if locationData.grade then
            if playerData.job.grade < locationData.grade then
              goto lbl_439
            end
          end
          if not OnDuty then
            if locationData.type ~= "duty" then
              goto lbl_439
            end
          end
          for coordIndex, coord in pairs(locationData.Coords) do
            local distance = #(playerCoords - coord)
            if distance < 20 then
              local scaleX = locationData.scale.x
              if distance > scaleX then
                DrawLocationMarker(coord, locationData.scale, false)
                shouldShowMarker = false
              else
                if distance < scaleX then
                  DrawLocationMarker(coord, locationData.scale, true)
                  hasFoundMarker = true
                  currentStation = locationType
                  currentPart = locationType
                  currentPartNum = Iterator
                  shouldShowMarker = false
                end
              end
            end
          end
          ::lbl_439::
        end
        if hasFoundMarker then
          if not HasAlreadyEnteredMarker then
            goto lbl_458
          end
          if LastStation == currentStation and LastPart == currentPart and LastPartNum == currentPartNum then
            goto lbl_491
          end
          ::lbl_458::
          if LastStation and LastPart and LastPartNum then
            if LastStation == currentStation and LastPart == currentPart and LastPartNum == currentPartNum then
              goto lbl_483
            end
            TriggerEvent("17mov_Cleaner:ExitedMarker", LastStation, LastPart, LastPartNum)
            hasExitedMarker = true
          end
          ::lbl_483::
          HasAlreadyEnteredMarker = true
          LastStation = currentStation
          LastPart = currentPart
          LastPartNum = currentPartNum
          TriggerEvent("17mov_Cleaner:EnteredMarker", currentPart)
          ::lbl_491::
        end
        if not hasExitedMarker and not hasFoundMarker then
          if HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = false
            TriggerEvent("17mov_Cleaner:ExitedMarker", LastStation, LastPart, LastPartNum)
          end
        end
        if shouldShowMarker then
          Citizen.Wait(500)
        end
      end
    end
  end
end
CreateThread(function()
  Citizen.Wait(5000)
  if not scriptReady then
    InitalizeScript()
  end
  playerData = GetPlayerData()
  while playerData == nil or playerData.job == nil do
    playerData = GetPlayerData()
    Citizen.Wait(1000)
  end
  if Config.RestrictBlipToRequiredJob then
    if Config.RequiredJob ~= playerData.job.name then
      goto lbl_30
    end
  end
  MakeBlip()
  ::lbl_30::
  Citizen.Wait(5000)
  StartMarkers(playerData)
end)
local blipsCreated = false
function MakeBlip()
  if blipsCreated then
    return
  end
  blipsCreated = true
  for _, blipData in pairs(Config.Blips) do
    local blip = AddBlipForCoord(blipData.Pos.x, blipData.Pos.y, blipData.Pos.z)
    blipData.blip = blip
    SetBlipSprite(blip, blipData.Sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipData.Scale)
    SetBlipColour(blip, blipData.Color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipData.Label)
    EndTextCommandSetBlipName(blip)
  end
end
function DeleteBlip()
  blipsCreated = false
  for _, blipData in pairs(Config.Blips) do
    RemoveBlip(blipData.blip)
    blipData.blip = nil
  end
end
function InitalizeScript(force)
  if scriptReady and not force then
    return
  end
  if Config.useModernUI then
    while not nuiLoaded do
      Citizen.Wait(100)
    end
  else
    Citizen.Wait(5500)
  end
  playerData = GetPlayerData()
  if not force then
    Citizen.Wait(5500)
  end
  scriptReady = true
  if Config.RequiredJob ~= "none" then
    if Config.RestrictBlipToRequiredJob then
      while playerData == nil or playerData.job == nil do
        playerData = GetPlayerData()
        Citizen.Wait(100)
      end
      if playerData.job.name ~= Config.RequiredJob then
        if not Config.RestrictBlipToRequiredJob then
          MakeBlip()
        end
      end
    end
  else
    MakeBlip()
  end
  TriggerServerCallback("17mov_Cleaner:init", function(initData)
    SendNUIMessage({
      action = "Init",
      name = initData.name,
      myId = initData.source
    })
    uiInitialized = true
  end)
end
RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
  InitalizeScript()
end)
RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function()
  InitalizeScript()
end)
RegisterNetEvent("QBCore:Client:OnJobUpdate")
AddEventHandler("QBCore:Client:OnJobUpdate", function(jobData)
  playerData = GetPlayerData()
  if Config.RequiredJob ~= "none" then
    if Config.RestrictBlipToRequiredJob then
      if playerData.job.name == Config.RequiredJob then
        goto lbl_22
      end
    end
  end
  ::lbl_22::
  if not Config.RestrictBlipToRequiredJob then
    MakeBlip()
  else
    DeleteBlip()
  end
  if Config.RequiredJob == "none" or playerData.job.name == Config.RequiredJob then
    StartMarkers(playerData)
  else
    markersActive = false
  end
end)
RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(newJob)
  while playerData == nil or playerData.job == nil do
    playerData = GetPlayerData()
    Citizen.Wait(1000)
  end
  playerData.job = newJob
  if Config.RequiredJob ~= "none" then
    if Config.RestrictBlipToRequiredJob then
      if playerData.job.name == Config.RequiredJob then
        goto lbl_34
      end
    end
  end
  ::lbl_34::
  if not Config.RestrictBlipToRequiredJob then
    MakeBlip()
  else
    DeleteBlip()
  end
  if Config.RequiredJob == "none" or playerData.job.name == Config.RequiredJob then
    StartMarkers(playerData)
  else
    markersActive = false
  end
end)
AddEventHandler("17mov_Cleaner:EnteredMarker", function(locationName)
  CurrentAction = Config.Locations[locationName].CurrentAction
  CurrentActionMsg = Config.Locations[locationName].CurrentActionMsg
  CurrentActionStation = locationName
  for i = 0, 500 do
    Citizen.Wait(0)
    ShowHelpNotification(CurrentActionMsg)
  end
end)
AddEventHandler("17mov_Cleaner:ExitedMarker", function()
  CurrentAction = nil
  CurrentActionMsg = nil
  CurrentActionStation = nil
end)
RegisterCommand("+WindowCleanerStartMarkerAction", function()
end, false)
RegisterCommand("-WindowCleanerStartMarkerAction", function()
  if CurrentAction then
    if CurrentAction == "open_dutyToggle" then
      OpenDutyMenu()
    elseif CurrentAction == "finish_job" then
      TriggerServerCallback("17mov_Cleaner:IfPlayerIsHost", function(isHost)
        if isHost then
          EndJob()
        else
          Notify(Config.Lang.no_permission)
        end
      end)
    end
  end
end, false)
TriggerEvent("chat:removeSuggestion", "/+WindowCleanerStartMarkerAction")
TriggerEvent("chat:removeSuggestion", "/-WindowCleanerStartMarkerAction")
RegisterKeyMapping("+WindowCleanerStartMarkerAction", Config.Lang.keybind, "keyboard", "E")
local nearbyPlayersCache = {}
if Config.useModernUI then
  function OpenDutyMenu()
    if not scriptReady then
      print("SCRIPT NOT READY - WAIT UNTIL SCRIPT PROPERLY LOAD")
      InitalizeScript(true)
      return
    end
    if not uiInitialized then
      TriggerServerCallback("17mov_Cleaner:init", function(initData)
        SendNUIMessage({
          action = "Init",
          name = initData.name,
          myId = initData.source
        })
        uiInitialized = true
      end)
      print("SCRIPT NOT READY - WAIT UNTIL SCRIPT PROPERLY LOAD")
      return
    end
    SendNUIMessage({action = "OpenWorkMenu"})
    SetNuiFocus(true, true)
    menuOpen = true
    CreateThread(function()
      local shouldHideTab = false
      local isShowingTab = false
      while menuOpen do
        local activePlayers = GetActivePlayers()
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearbyPlayerIds = {}
        for _, playerId in pairs(activePlayers) do
          if PlayerId() ~= playerId then
            local ped = GetPlayerPed(playerId)
            local pedCoords = GetEntityCoords(ped)
            if #(playerCoords - pedCoords) < 10.0 then
              table.insert(nearbyPlayerIds, GetPlayerServerId(playerId))
            end
          end
        end
        if #nearbyPlayerIds == 0 then
          if not shouldHideTab then
            goto lbl_53
          end
        end
        TriggerServerCallback("17mov_Cleaner:GetPlayersNames", function(players)
          local hasNewPlayer = false
          for playerIndex, player in pairs(players) do
            if lobbyData[player.id] == nil then
              hasNewPlayer = true
              if nearbyPlayersCache[player.id] == nil then
                nearbyPlayersCache[player.id] = {
                  id = player.id,
                  name = player.name
                }
                CreateThread(function()
                  while not isShowingTab do
                    Citizen.Wait(10)
                  end
                  SendNUIMessage({
                    action = "addNewNearbyPlayer",
                    id = player.id,
                    name = player.name
                  })
                end)
              end
            else
              players[playerIndex] = nil
            end
          end
          for cacheIndex, cachedPlayer in pairs(nearbyPlayersCache) do
            local foundInPlayers = false
            for _, player in pairs(players) do
              if player.id == cachedPlayer.id then
                foundInPlayers = true
                break
              end
            end
            if not foundInPlayers then
              nearbyPlayersCache[cacheIndex] = nil
              shouldHideTab = true
              SendNUIMessage({
                action = "DeleteNearbyPlayer",
                id = cachedPlayer.id
              })
              CreateThread(function()
                Citizen.Wait(250)
                shouldHideTab = false
              end)
            end
          end
          if not hasNewPlayer then
            if isShowingTab then
              CreateThread(function()
                while shouldHideTab do
                  Citizen.Wait(10)
                end
                SendNUIMessage({action = "hideNearbyPlayersTab"})
                CreateThread(function()
                  Citizen.Wait(250)
                  isShowingTab = false
                end)
              end)
            end
          else
            if hasNewPlayer then
              if not isShowingTab then
                SendNUIMessage({action = "showNearbyPlayersTab"})
                CreateThread(function()
                  Citizen.Wait(250)
                  isShowingTab = true
                end)
              end
            end
          end
        end, nearbyPlayerIds)
        ::lbl_53::
        Citizen.Wait(2500)
      end
    end)
  end
else
  function OpenDutyMenu()
    if not scriptReady then
      InitalizeScript(true)
      print("SCRIPT NOT READY - WAIT UNTIL SCRIPT PROPERLY LOAD")
      return
    end
    if not uiInitialized then
      TriggerServerCallback("17mov_Cleaner:init", function(initData)
        SendNUIMessage({
          action = "Init",
          name = initData.name,
          myId = initData.source
        })
        uiInitialized = true
      end)
      print("SCRIPT NOT READY - WAIT UNTIL SCRIPT PROPERLY LOAD")
      return
    end
    TriggerServerCallback("17mov_Cleaner:IfPlayerIsHost", function(isHost)
      SendNUIMessage({
        action = "HostStatusUpdate",
        status = isHost
      })
      SendNUIMessage({action = "OpenWorkMenu"})
      SetNuiFocus(true, true)
    end)
  end
end
local workClothesApplied = false
RegisterNUICallback("changeClothes", function(data)
  if data.type == "work" then
    workClothesApplied = true
    ChangeClothes("work")
  else
    workClothesApplied = false
    ChangeClothes("citizen")
  end
end)
RegisterNUICallback("GetClosestPlayers", function(data, cb)
  local activePlayers = GetActivePlayers()
  local playerCoords = GetEntityCoords(PlayerPedId())
  local nearbyPlayerIds = {}
  for _, playerId in pairs(activePlayers) do
    if PlayerId() ~= playerId then
      local ped = GetPlayerPed(playerId)
      local pedCoords = GetEntityCoords(ped)
      if #(playerCoords - pedCoords) < 20.0 then
        table.insert(nearbyPlayerIds, GetPlayerServerId(playerId))
      end
    end
  end
  TriggerServerCallback("17mov_Cleaner:IfPlayerIsHost", function(isHost)
    if isHost then
      TriggerServerCallback("17mov_Cleaner:GetPlayersNames", function(players)
        cb(players)
        if #players == 0 then
          Notify(Config.Lang.nobodyNearby)
        end
      end, nearbyPlayerIds)
    else
      Notify(Config.Lang.no_permission)
    end
  end)
end)
RegisterNUICallback("requestReacted", function(data)
  SetNuiFocus(false, false)
  TriggerServerEvent("17mov_Cleaner:ClientReactRequest", data.boolean)
end)
if Config.useModernUI then
  RegisterNUICallback("sendRequest", function(data)
    if OnDuty then
      Notify(Config.Lang.cantInvite)
      return
    end
    TriggerServerEvent("17mov_Cleaner:SendRequestToClient_sv", tonumber(data.id))
  end)
  RegisterNUICallback("kickPlayerFromLobby", function(data)
    local playerId = tonumber(data.id)
    Notify(string.format(Config.Lang.kicked, lobbyData[playerId].name))
    TriggerServerEvent("17mov_Cleaner:KickPlayerFromLobby", playerId, true)
  end)
else
  RegisterNUICallback("sendRequest", function(data)
    if OnDuty then
      Notify(Config.Lang.cantInvite)
      return
    end
    TriggerServerEvent("17mov_Cleaner:SendRequestToClient_sv", data.id)
  end)
  RegisterNUICallback("kickPlayerFromLobby", function(data)
    Notify(string.format(Config.Lang.kicked, data.name))
    TriggerServerEvent("17mov_Cleaner:KickPlayerFromLobby", data.id, true)
  end)
end
RegisterNUICallback("focusOff", function()
  SetNuiFocus(false, false)
end)
RegisterNUICallback("notify", function(data)
  Notify(data.msg)
end)
RegisterNetEvent("17mov_Cleaner:SendRequestToClient_cl")
AddEventHandler("17mov_Cleaner:SendRequestToClient_cl", function(playerName, playerId)
  SendNUIMessage({
    action = "ShowInviteBox",
    name = playerName
  })
  SetNuiFocus(true, true)
end)
if Config.useModernUI then
  RegisterNetEvent("17mov_Cleaner:RefreshMugs")
  AddEventHandler("17mov_Cleaner:RefreshMugs", function(mugsData, mugsMax)
    while not uiInitialized do
      Citizen.Wait(100)
    end
    for _, mugData in pairs(mugsData) do
      SendNUIMessage({
        action = "DeleteNearbyPlayer",
        id = mugData.id
      })
      if lobbyData[mugData.id] == nil then
        lobbyData[mugData.id] = {
          name = mugData.name,
          id = mugData.id,
          isHost = mugData.isHost,
          rewardPercent = mugData.rewardPercent,
          itsMe = playerServerId == mugData.id
        }
        SendNUIMessage({
          action = "addNewMember",
          name = mugData.name,
          id = mugData.id,
          isHost = mugData.isHost,
          rewardPercent = mugData.rewardPercent,
          showQuitBtn = lobbyData[mugData.id].itsMe
        })
      end
    end
    local memberCount = 0
    for memberId, memberData in pairs(lobbyData) do
      local foundInMugs = false
      for _, mugData in pairs(mugsData) do
        if mugData.id == memberData.id then
          foundInMugs = true
          break
        end
      end
      if not foundInMugs then
        lobbyData[memberId] = nil
        SendNUIMessage({
          action = "DeletePlayer",
          id = memberData.id
        })
      else
        memberCount = memberCount + 1
      end
    end
    if memberCount == 1 then
      TriggerServerCallback("17mov_Cleaner:init", function(initData)
        SendNUIMessage({
          action = "Init",
          name = initData.name,
          myId = initData.source
        })
        uiInitialized = true
      end)
    end
    TriggerServerCallback("17mov_Cleaner:IfPlayerOwnsTeam", function(ownsTeam)
      SendNUIMessage({
        action = "ToggleHostHUD",
        boolean = ownsTeam
      })
    end)
  end)
else
  RegisterNetEvent("17mov_Cleaner:RefreshMugs")
  AddEventHandler("17mov_Cleaner:RefreshMugs", function(namesData, myId)
    while not uiInitialized do
      Citizen.Wait(100)
    end
    Citizen.Wait(100)
    SendNUIMessage({
      action = "refreshMugs",
      names = namesData,
      myId = myId
    })
    TriggerServerCallback("17mov_Cleaner:IfPlayerIsHost", function(isHost)
      SendNUIMessage({
        action = "HostStatusUpdate",
        status = isHost
      })
    end)
  end)
end
function IsSpawnPointClear()
  local spawnPointVec = vec3(Config.SpawnPoint.x, Config.SpawnPoint.y, Config.SpawnPoint.z)
  local vehicles = GetGamePool("CVehicle")
  if vehicles == nil then
    print("FAILED TO FETCH GAMEPOOL - Returning CLEAR")
    return true
  end
  if type(vehicles) ~= "table" then
    print("FAILED TO FETCH GAMEPOOL - Returning CLEAR")
    return true
  end
  for _, vehicle in pairs(vehicles) do
    local vehicleCoords = GetEntityCoords(vehicle)
    if #(vehicleCoords - spawnPointVec) < 6.0 then
      return false
    end
  end
  return true
end
RegisterNUICallback("startJob", function()
  if not OnDuty then
    if IsSpawnPointClear() then
      TriggerServerEvent("17mov_Cleaner:StartJob_sv")
    else
      Notify(Config.Lang.spawnpointOccupied)
    end
  else
    Notify(Config.Lang.alreadyWorking)
  end
end)
RegisterNUICallback("leaveLobby", function(data)
  if OnDuty then
    Notify(Config.Lang.cantLeaveLobby)
    return
  end
  local playerId = tonumber(data.id)
  TriggerServerEvent("17mov_Cleaner:KickPlayerFromLobby", playerId, false, GetPlayerServerId(PlayerId()))
  Notify(Config.Lang.quit)
end)
function SpawnVehicle(vehicleModel, spawnPoint)
  PrepeareVehicle()
  local timeout = 100
  RequestModel(vehicleModel)
  while not HasModelLoaded(vehicleModel) and timeout > 0 do
    Citizen.Wait(100)
    timeout = timeout - 1
    RequestModel(vehicleModel)
  end
  local heading = spawnPoint.w or spawnPoint.heading or 0
  local vehicle = CreateVehicle(vehicleModel, spawnPoint.x, spawnPoint.y, spawnPoint.z, heading, true, false)
  SetEntityAsMissionEntity(vehicle, true, true)
  SetVehicleNeedsToBeHotwired(vehicle, false)
  SetVehRadioStation(vehicle, "OFF")
  SetVehicleFuelLevel(vehicle, 100.0)
  if Config.EnableVehicleTeleporting then
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
  end
  SetVehicle(vehicle)
  timeout = 100
  while not DoesEntityExist(vehicle) and timeout > 0 do
    Citizen.Wait(100)
    timeout = timeout - 1
  end
  return vehicle
end
RegisterNetEvent("17mov_Cleaner:StartJob_cl")
AddEventHandler("17mov_Cleaner:StartJob_cl", function(lobbyId, playerServerId, locationId, skipTutorial)
  BagsCounter = 0
  hamperEntity = nil
  OnDuty = true
  if not skipTutorial then
    if GetResourceKvpInt("17mov_Tutorials:Cleaner:cleanerFirstTutorial") == 0 then
      tutorialResourceName = "cleanerFirstTutorial"
      SendNUIMessage({
        action = "showTutorial",
        customText = Config.Lang.tutorial1
      })
      SetNuiFocus(true, true)
    end
  end
  CreateThread(function()
    if not workClothesApplied then
      if Config.RequireWorkClothes then
        workClothesApplied = true
        ChangeClothes("work")
      end
    end
  end)
  if lobbyId == playerServerId then
    if Config.EnableVehicleTeleporting and not skipTutorial then
      DoScreenFadeOut(300)
      Citizen.Wait(1000)
    end
    if not skipTutorial then
      jobVehicle = SpawnVehicle(Config.JobVehicleModel, Config.SpawnPoint)
      Citizen.Wait(2000)
      DoScreenFadeIn(300)
      JobVehicleNetId = VehToNet(jobVehicle)
      TriggerServerEvent("17mov_Cleaner:UploadVehicleNetId", JobVehicleNetId)
    else
      local vehicleReceived = false
      while not vehicleReceived do
        Citizen.Wait(300)
        TriggerServerCallback("17mov_Cleaner:GetLobbyVehicleId", function(vehicleNetId)
          if vehicleNetId ~= nil and vehicleNetId ~= 0 then
            local vehicle = NetToVeh(vehicleNetId)
            if vehicle ~= vehicleNetId and vehicle ~= 0 then
              if DoesEntityExist(vehicle) then
                JobVehicleNetId = vehicleNetId
                jobVehicle = vehicle
                vehicleReceived = true
              end
            end
          end
        end, lobbyId)
        if vehicleReceived then
          break
        end
      end
      SetVehicleHasBeenOwnedByPlayer(jobVehicle, true)
      SetVehicleNeedsToBeHotwired(jobVehicle, false)
      if JobVehicleNetId ~= 0 and JobVehicleNetId ~= nil then
        if NetworkDoesNetworkIdExist(JobVehicleNetId) then
          SetNetworkIdCanMigrate(JobVehicleNetId, true)
        end
      end
    end
    CreateThread(function()
      while OnDuty do
        if not onPlatform then
          if JobVehicleNetId ~= 0 and JobVehicleNetId ~= nil then
            if NetworkDoesNetworkIdExist(JobVehicleNetId) then
              local networkVehicle = NetToVeh(JobVehicleNetId)
              if jobVehicle ~= networkVehicle then
                if networkVehicle ~= JobVehicleNetId and networkVehicle ~= 0 then
                  jobVehicle = NetToVeh(JobVehicleNetId)
                end
              end
            end
          end
        end
        Citizen.Wait(5000)
      end
    end)
  else
    local spawnPoint = Config.SpawnPoint
    while true do
      Citizen.Wait(0)
      local vehicles = GetGamePool("CVehicle")
      local minDistance = 200.0
      local closestVehicle = nil
      for _, vehicle in pairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(vehicleCoords - vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z))
        if minDistance > distance then
          minDistance = distance
          closestVehicle = vehicle
        end
      end
      if closestVehicle ~= nil then
        local spawnCoords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
        local vehicleCoords = GetEntityCoords(closestVehicle)
        local distance = #(spawnCoords - vehicleCoords)
        if distance < 2.0 then
          local vehicleModel = GetEntityModel(closestVehicle)
          local expectedModel = GetHashKey(Config.JobVehicleModel)
          if vehicleModel == expectedModel then
            Citizen.Wait(300)
            while not DoesEntityExist(closestVehicle) do
              Citizen.Wait(100)
            end
            JobVehicleNetId = VehToNet(closestVehicle)
            jobVehicle = closestVehicle
            break
          end
        end
      end
    end
    if Config.GiveKeysToAllLobby then
      SetVehicle(jobVehicle)
    end
  end
  SendNUIMessage({action = "showCounter"})
end)
function CreateTargetBlip(x, y, z)
  if DoesBlipExist(soundHandle) then
    RemoveBlip(soundHandle)
  end
  local zCoord = z or 0
  soundHandle = AddBlipForCoord(x, y, zCoord)
  SetBlipSprite(soundHandle, 1)
  SetBlipDisplay(soundHandle, 6)
  SetBlipScale(soundHandle, 1.0)
  SetBlipColour(soundHandle, 83)
  SetBlipAsShortRange(soundHandle, true)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(Config.Lang.targetLocation or "Target Location")
  EndTextCommandSetBlipName(soundHandle)
end
RegisterNetEvent("17mov_Cleaner:takeNewJob")
AddEventHandler("17mov_Cleaner:takeNewJob", function(locationIndex)
  currentLocationIndex = locationIndex
  local enterCoords = Config.JobLocations[locationIndex].enterCoords
  SetNewWaypoint(enterCoords.x, enterCoords.y)
  CreateTargetBlip(enterCoords.x, enterCoords.y, enterCoords.z)
  CreateThread(function()
    while OnDuty do
      if currentLocationIndex ~= locationIndex then
        break
      end
      Citizen.Wait(0)
      if not onPlatform then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(playerCoords - enterCoords)
        if distance <= 15.0 then
          DrawText3Ds(enterCoords.x, enterCoords.y, enterCoords.z, "~r~[E] | ~s~" .. Config.Lang.enterPlatform)
          if distance <= 1.5 and IsControlJustReleased(0, 38) then
            TriggerServerCallback("17mov_Cleaner:IfPlayerIsHost", function(isHost)
              if isHost then
                if Config.Debug then
                  print("starting:", locationIndex)
                end
                TriggerServerEvent("17mov_Cleaner:StartSession", locationIndex)
              else
                Notify(Config.Lang.no_permission)
              end
            end)
          end
        else
          Citizen.Wait(500)
        end
      else
        Citizen.Wait(2000)
      end
    end
  end)
end)
RegisterNetEvent("17mov_Cleaner:TeleportToPlatform")
AddEventHandler("17mov_Cleaner:TeleportToPlatform", function(playerServerId, hostServerId, locationIndex)
  if Config.Debug then
    print("TELEPORTING:", playerServerId, hostServerId, locationIndex)
  end
  local playerCoords = GetEntityCoords(PlayerPedId())
  local enterCoords = Config.JobLocations[locationIndex].enterCoords
  if #(playerCoords - enterCoords) > 100.0 then
    return
  end
  if Config.Debug then
    print("CHECK 1")
  end
  DoScreenFadeOut(250)
  while not DoesEntityExist(hamperEntity) do
    SpawnHamper(Config.JobLocations[locationIndex], playerServerId, playerServerId == hostServerId)
  end
  local exitCoords = Config.JobLocations[locationIndex].exitCoords
  SetEntityCoords(PlayerPedId(), exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
  FreezeEntityPosition(PlayerPedId(), true)
  onPlatform = true
  Citizen.Wait(2500)
  DoScreenFadeIn(250)
  FreezeEntityPosition(PlayerPedId(), false)
  Citizen.Wait(250)
  if GetResourceKvpInt("17mov_Tutorials:Cleaner:cleanerSecondTutorial") == 0 then
    tutorialResourceName = "cleanerSecondTutorial"
    SendNUIMessage({action = "show2Tutorial"})
    SendNUIMessage({
      action = "showTutorial",
      customText = Config.Lang.tutorial2
    })
    SetNuiFocus(true, true)
  end
  CreateThread(function()
    while onPlatform do
      Citizen.Wait(0)
      local playerCoords = GetEntityCoords(PlayerPedId())
      local exitCoords = Config.JobLocations[locationIndex].exitCoords
      local distance = #(playerCoords - exitCoords)
      if distance <= 15.0 then
        DrawText3Ds(exitCoords.x, exitCoords.y, exitCoords.z, "~r~[E] | ~s~" .. Config.Lang.exitPlatform)
        if distance <= 1.0 and IsControlJustReleased(0, 38) then
          onPlatform = false
          TriggerServerEvent("17mov_Cleaner:exitSession", locationIndex, false, false)
          break
        end
      else
        Citizen.Wait(500)
      end
    end
  end)
  CreateThread(function()
    local lastTime = nil
    while onPlatform do
      Citizen.Wait(0)
      local currentTime = GetGameTimer()
      if lastTime == nil then
        lastTime = currentTime
      end
      local deltaTime = (currentTime - lastTime) / 1000.0
      lastTime = currentTime
      local speed = 1.0 * deltaTime
      local locationConfig = Config.JobLocations[currentLocationIndex]
      local hamperCoords = GetEntityCoords(hamperEntity)
      if hamperMovingDown then
        local newZ = hamperCoords.z - speed
        if newZ < locationConfig.hamperMaxZ and newZ > locationConfig.hamperMinZ then
          SetEntityCoords(hamperEntity, hamperCoords.x, hamperCoords.y, newZ, false, false, false, false)
        end
      elseif hamperMovingUp then
        local newZ = hamperCoords.z + speed
        if newZ < locationConfig.hamperMaxZ and newZ > locationConfig.hamperMinZ then
          SetEntityCoords(hamperEntity, hamperCoords.x, hamperCoords.y, newZ, false, false, false, false)
        end
      end
    end
  end)
  CreateThread(function()
    local maxDistance = Config.MaxHamperDistance or 30.0
    while onPlatform do
      Citizen.Wait(2000)
      local playerCoords = GetEntityCoords(PlayerPedId())
      local hamperCoords = GetEntityCoords(hamperEntity)
      if hamperCoords ~= vector3(0, 0, 0) then
        local distance = #(hamperCoords - playerCoords)
        if distance > maxDistance then
          if onPlatform then
            TriggerServerEvent("17mov_Cleaner:exitSession", locationIndex, true, true)
            return
          end
        end
      end
    end
  end)
  CreateThread(function()
    while onPlatform do
      Citizen.Wait(500)
      if isDeath() then
        TriggerServerEvent("17mov_Cleaner:exitSession", locationIndex, true)
        return
      end
    end
  end)
  CreateThread(function()
    local canInteract = false
    while onPlatform do
      Citizen.Wait(0)
      local playerCoords = GetEntityCoords(PlayerPedId())
      local hasDirtyWindows = false
      local closestWindow = {distance = 100, id = 0}
      local locationConfig = Config.JobLocations[locationIndex]
      for windowId, window in pairs(locationConfig.windowsLocations) do
        if window.dirty then
          hasDirtyWindows = true
          local distance = #(playerCoords - window.coords)
          if distance < closestWindow.distance then
            closestWindow.distance = distance
            closestWindow.id = windowId
          end
          if distance < 30.0 and distance > 1.0 then
            local markerConfig = Config.WindowMarkerSetting
            DrawMarker(
              markerConfig.type,
              window.coords.x, window.coords.y, window.coords.z,
              0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
              markerConfig.scale[1], markerConfig.scale[2], markerConfig.scale[3],
              markerConfig.unActiveColor[1], markerConfig.unActiveColor[2], markerConfig.unActiveColor[3], markerConfig.unActiveColor[4],
              false, true, 2, false, false, false, false
            )
          end
          if distance < 1.0 then
            local markerConfig = Config.WindowMarkerSetting
            DrawMarker(
              markerConfig.type,
              window.coords.x, window.coords.y, window.coords.z,
              0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
              markerConfig.scale[1], markerConfig.scale[2], markerConfig.scale[3],
              markerConfig.acviteColor[1], markerConfig.acviteColor[2], markerConfig.acviteColor[3], markerConfig.acviteColor[4],
              false, true, 2, false, false, false, false
            )
            ShowHelpNotification(Config.Lang.cleanWindowInfo)
            if IsControlJustReleased(0, 38) and not canInteract then
              canInteract = true
              StartCleaning(closestWindow.id)
              Citizen.Wait(100)
            end
          end
        end
      end
      if not hasDirtyWindows then
        TriggerServerEvent("17mov_Cleaner:exitSession", locationIndex, false, false, true)
        break
      end
    end
  end)
end)
local lastCleaningWindowId = nil

function StartCleaning(windowId)
  if lastCleaningWindowId == windowId then
    if Config.Debug then
      print("REJECTING")
    end
    return
  end
  lastCleaningWindowId = windowId
  if Config.Debug then
    print("STARTING CLEANING ID: ", windowId, ", Last ID is: ", lastCleaningWindowId)
  end
  local cleaningReady = false
  TriggerServerCallback("17mov_cleaner:isThisWindowisFree", function(isFree)
    if Config.Debug then
      print("CALLBACK RESPONSE: ", isFree)
    end
    if isFree then
      currentWindowIndex = windowId
      SendNUIMessage({action = "startCleaning"})
      SetNuiFocus(true, true)
      TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_MAID_CLEAN", 0, true)
      Citizen.Wait(300)
      local objects = GetGamePool("CObject")
      if objects ~= nil then
        if type(objects) == "table" then
          for _, object in pairs(GetGamePool("CObject")) do
            if object ~= nil then
              if GetEntityModel(object) == 679927467 then
                SetEntityAsMissionEntity(object, true, true)
                DeleteObject(object)
                DeleteEntity(object)
              end
            end
          end
        end
      end
    else
      Notify(Config.Lang.someoneIsAlreadyCleaning)
    end
    if Config.Debug then
      print("SETTING READY AS TRUE: ", isFree)
    end
    cleaningReady = true
  end, windowId)
  CreateThread(function()
    Citizen.Wait(1500)
    lastCleaningWindowId = nil
  end)
end
RegisterNUICallback("stopCleaning", function()
  TriggerServerEvent("17mov_Cleaner:enableThisWindow", currentWindowIndex)
  StopCleaningAnim()
end)
function StopCleaningAnim()
  SetNuiFocus(false, false)
  ClearPedTasksImmediately(PlayerPedId())
  local objects = GetGamePool("CObject")
  if objects ~= nil then
    if type(objects) == "table" then
      for _, object in pairs(GetGamePool("CObject")) do
        if object ~= nil then
          if GetEntityModel(object) == 679927467 then
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            DeleteEntity(object)
          end
        end
      end
    end
  end
end
RegisterNUICallback("endCleaning", function()
  StopCleaningAnim()
  TriggerServerEvent("17mov_cleaner:ThisWindowReady", currentLocationIndex, currentWindowIndex)
  currentWindowIndex = 0
end)
RegisterNetEvent("17mov_Cleaner:disableWindow")
AddEventHandler("17mov_Cleaner:disableWindow", function(windowId, counterValue)
  SendNUIMessage({
    action = "updateCounter",
    value = counterValue
  })
  Config.JobLocations[currentLocationIndex].windowsLocations[windowId].dirty = false
  local objects = GetGamePool("CObject")
  if objects ~= nil then
    if type(objects) == "table" then
      for _, object in pairs(GetGamePool("CObject")) do
        if object ~= nil then
          if GetEntityModel(object) == 679927467 then
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            DeleteEntity(object)
          end
        end
      end
    end
  end
end)
RegisterNetEvent("17mov_Cleaner:exitPlatform")
AddEventHandler("17mov_Cleaner:exitPlatform", function(playerServerId, hostServerId, locationIdx, otherServerId, otherLocationIdx)
  local playerCoords = GetEntityCoords(PlayerPedId())
  local enterCoords = Config.JobLocations[currentLocationIndex].enterCoords
  local distance = #(playerCoords - enterCoords)
  if distance > 350.0 and hostServerId ~= otherServerId then
    return
  end
  DoScreenFadeOut(50)
  Citizen.Wait(250)
  local exitCoords = Config.JobLocations[locationIdx].enterCoords
  SetEntityCoords(PlayerPedId(), exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
  FreezeEntityPosition(PlayerPedId(), true)
  onPlatform = false
  Citizen.Wait(2500)
  DoScreenFadeIn(250)
  FreezeEntityPosition(PlayerPedId(), false)
  Citizen.Wait(250)
  DeleteHamper()
  Citizen.Wait(250)
  local finishCoords = Config.Locations.FinishJob.Coords[1]
  SetNewWaypoint(finishCoords.x, finishCoords.y)
  CreateTargetBlip(finishCoords.x, finishCoords.y, finishCoords.z)
end)
local canEndJob = true

function EndJob()
  if not canEndJob then
    return
  end
  canEndJob = false
  local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
  local driver = GetPedInVehicleSeat(vehicle, -1)
  if driver ~= PlayerPedId() then
    if IsPedInAnyVehicle(PlayerPedId(), false) then
      Notify(Config.Lang.notADriver)
      canEndJob = true
      return
    end
  end
  vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
  local vehicleModel = GetEntityModel(vehicle)
  local jobVehicleHash = GetHashKey(Config.JobVehicleModel)
  if vehicleModel == jobVehicleHash then
    DeleteVehicleByCore(vehicle)
    TriggerServerEvent("17mov_Cleaner:endJob_sv", true)
    canEndJob = true
    return
  end
  SetNuiFocus(true, true)
  SendNUIMessage({action = "openWarning"})
  canEndJob = true
end
RegisterNetEvent("17mov_Cleaner:endJob_cl")
AddEventHandler("17mov_Cleaner:endJob_cl", function()
  if RemoveKeys ~= nil then
    RemoveKeys()
  end
  local playerCoords = GetEntityCoords(PlayerPedId())
  local dutyCoords = Config.Locations.DutyToggle.Coords[1]
  local distance = #(playerCoords - dutyCoords)
  if distance < 40.0 then
    if Config.EnableVehicleTeleporting then
      DoScreenFadeOut(250)
      Citizen.Wait(1000)
      SetEntityCoords(PlayerPedId(), dutyCoords.x, dutyCoords.y, dutyCoords.z, false, false, false, false)
    end
  end
  if Config.RequireWorkClothes then
    if not Config.EnableCloakroom then
      workClothesApplied = false
      ChangeClothes("citizen")
    end
  end
  Citizen.Wait(1000)
  DoScreenFadeIn(300)
  SendNUIMessage({action = "hideCounter"})
  SendNUIMessage({action = "updateCounter", value = 0})
  if currentLocationIndex ~= -1 then
    for _, window in pairs(Config.JobLocations[currentLocationIndex].windowsLocations) do
      window.dirty = true
    end
  end
  OnDuty = false
  currentLocationIndex = -1
  currentWindowIndex = -1
  DestinationBlip = -1
  Citizen.Wait(150)
  if DoesBlipExist(soundHandle) then
    RemoveBlip(soundHandle)
  end
end)
local ropeHandles = {}

function DeleteHamper()
  hamperControlEnabled = false
  DeleteObject(hamperEntity)
  DeleteObject(handleEntity)
  for i = 1, #ropeHandles do
    DeleteRope(ropeHandles[i])
  end
end
function SpawnHamper(locationConfig, playerServerId, isHost)
  for _, location in pairs(Config.JobLocations) do
    location.hamperMaxZ = location.hamperMaxZ - 0.5
    location.exitCoords = vec3(location.exitCoords.x, location.exitCoords.y, location.exitCoords.z - 0.5)
  end
  hamperControlEnabled = true
  while not HasModelLoaded(locationConfig.hamperModel) do
    RequestModel(locationConfig.hamperModel)
    Citizen.Wait(10)
  end
  while not HasModelLoaded(locationConfig.handleModel) do
    RequestModel(locationConfig.handleModel)
    Citizen.Wait(10)
  end
  local handleObj = CreateObject(locationConfig.handleModel, locationConfig.handleCoords.x, locationConfig.handleCoords.y, locationConfig.handleCoords.z, false, true, false)
  SetEntityRotation(handleObj, locationConfig.handleRotation.x, locationConfig.handleRotation.y, locationConfig.handleRotation.z, 0, true)
  FreezeEntityPosition(handleObj, true)
  handleEntity = handleObj
  local hamperBasePos = locationConfig.handleCoords + (GetEntityForwardVector(handleObj) * locationConfig.hamperForwardOffsetFromHandle)
  local hamperSpawnPos = vec3(hamperBasePos.x, hamperBasePos.y, locationConfig.hamperMaxZ)
  hamperEntity = CreateObjectNoOffset(locationConfig.hamperModel, hamperSpawnPos.x, hamperSpawnPos.y, hamperSpawnPos.z, false, true, false)
  lobbyMembers = locationConfig
  if Config.Debug then
    print("hamperObj: ", hamperEntity, GetEntityCoords(hamperEntity))
  end
  while #(GetEntityCoords(hamperEntity) - vec3(hamperBasePos.x, hamperBasePos.y, locationConfig.hamperMaxZ)) > 1.0 do
    Citizen.Wait(100)
    DeleteEntity(hamperEntity)
    hamperEntity = CreateObjectNoOffset(locationConfig.hamperModel, hamperSpawnPos.x, hamperSpawnPos.y, hamperSpawnPos.z, false, true, false)
    print("AWAITING FOR PLATFORM. THIS ISSUE CAN BE CAUSED BY ANTICHEAT OR SOMETHING THAT DELETING PROP")
  end
  local ropeAttachments = {
    {handle = vector3(4.84, 2.96, 3.42), hamper = vector3(4.87, 0.012, 1.4)},
    {handle = vector3(-4.84, 2.96, 3.42), hamper = vector3(-4.87, 0.012, 1.4)}
  }
  RopeLoadTextures()
  for i = 1, #ropeAttachments do
    local handleWorldPos = GetOffsetFromEntityInWorldCoords(handleObj, ropeAttachments[i].handle.x, ropeAttachments[i].handle.y, ropeAttachments[i].handle.z)
    local hamperWorldPos = GetOffsetFromEntityInWorldCoords(hamperEntity, ropeAttachments[i].hamper.x, ropeAttachments[i].hamper.y, ropeAttachments[i].hamper.z)
    local ropeHandle = AddRope(hamperWorldPos.x, hamperWorldPos.y, hamperWorldPos.z, 0.0, 0.0, 0.0, 0.3, 4, 0.5, 0.5, 100.0, false, false, false, 0.0, false)
    ropeHandles[i] = ropeHandle
    AttachEntitiesToRope(ropeHandle, handleObj, hamperEntity, handleWorldPos.x, handleWorldPos.y, handleWorldPos.z, hamperWorldPos.x, hamperWorldPos.y, hamperWorldPos.z, 0.5, true, true, 0, 0)
  end
  SetEntityRotation(hamperEntity, locationConfig.handleRotation.x, locationConfig.handleRotation.y, locationConfig.handleRotation.z, 0, true)
  FreezeEntityPosition(hamperEntity, true)
  SetEntityCoords(hamperEntity, hamperSpawnPos.x, hamperSpawnPos.y, hamperSpawnPos.z, false, false, false, false)
  if isHost then
    local upPressed = false
    local downPressed = false
    CreateThread(function()
      local lastEventTime = 0
      while hamperControlEnabled do
        Citizen.Wait(0)
        if IsControlPressed(0, Config.HamperGoUpControl) then
          local hamperZ = GetEntityCoords(hamperEntity).z + 0.01
          if hamperZ < locationConfig.hamperMaxZ and hamperZ > locationConfig.hamperMinZ then
            if not upPressed and not hamperMovingUp and not hamperMovingDown then
              upPressed = true
              lastEventTime = GetGameTimer()
              TriggerServerEvent("17mov_cleaner:StartHamperTop")
            elseif upPressed then
              if GetGameTimer() - lastEventTime > 200 then
                lastEventTime = GetGameTimer()
                TriggerServerEvent("17mov_cleaner:StartHamperTop")
              end
            end
          end
        else
          if upPressed then
            TriggerServerEvent("17mov_cleaner:StopHamperTop", GetEntityCoords(hamperEntity))
            upPressed = false
          end
        end
      end
    end)
    CreateThread(function()
      local lastEventTime = 0
      while hamperControlEnabled do
        Citizen.Wait(0)
        if IsControlPressed(0, Config.HamperGoDownControl) then
          local hamperZ = GetEntityCoords(hamperEntity).z - 0.01
          if hamperZ < locationConfig.hamperMaxZ and hamperZ > locationConfig.hamperMinZ then
            if not downPressed and not hamperMovingDown and not hamperMovingUp then
              TriggerServerEvent("17mov_cleaner:StartHamperBottom")
              downPressed = true
              lastEventTime = GetGameTimer()
            elseif downPressed then
              if GetGameTimer() - lastEventTime > 200 then
                lastEventTime = GetGameTimer()
                TriggerServerEvent("17mov_cleaner:StartHamperBottom")
              end
            end
          end
        else
          if downPressed then
            downPressed = false
            TriggerServerEvent("17mov_cleaner:StopHamperBottom", GetEntityCoords(hamperEntity))
          end
        end
      end
    end)
  end
end
RegisterNetEvent("17mov_Cleaner:StartHostPlatformCode")
AddEventHandler("17mov_Cleaner:StartHostPlatformCode", function()
  if onPlatform then
    Notify(Config.Lang.youCanControl)
    local upPressed = false
    local downPressed = false
    CreateThread(function()
      local lastEventTime = 0
      local locationConfig = Config.JobLocations[currentLocationIndex]
      while hamperControlEnabled do
        Citizen.Wait(0)
        if IsControlPressed(0, Config.HamperGoUpControl) then
          local hamperZ = GetEntityCoords(hamperEntity).z + 0.01
          if hamperZ < locationConfig.hamperMaxZ and hamperZ > locationConfig.hamperMinZ then
            if not upPressed then
              if not hamperMovingUp then
                if not hamperMovingDown then
                  upPressed = true
                  lastEventTime = GetGameTimer()
                  TriggerServerEvent("17mov_cleaner:StartHamperTop")
                end
              end
            else
              if upPressed then
                local currentTime = GetGameTimer()
                if currentTime - lastEventTime > 200 then
                  lastEventTime = currentTime
                  TriggerServerEvent("17mov_cleaner:StartHamperTop")
                end
              end
            end
          end
        else
          if upPressed then
            TriggerServerEvent("17mov_cleaner:StopHamperTop", GetEntityCoords(hamperEntity))
            upPressed = false
          end
        end
      end
    end)
    CreateThread(function()
      local lastEventTime = 0
      local locationConfig = Config.JobLocations[currentLocationIndex]
      while hamperControlEnabled do
        Citizen.Wait(0)
        if IsControlPressed(0, Config.HamperGoDownControl) then
          local hamperZ = GetEntityCoords(hamperEntity).z - 0.01
          if hamperZ < locationConfig.hamperMaxZ and hamperZ > locationConfig.hamperMinZ then
            if not downPressed then
              if not hamperMovingDown then
                if not hamperMovingUp then
                  TriggerServerEvent("17mov_cleaner:StartHamperBottom")
                  downPressed = true
                  lastEventTime = GetGameTimer()
                end
              end
            else
              if downPressed then
                local currentTime = GetGameTimer()
                if currentTime - lastEventTime > 200 then
                  lastEventTime = currentTime
                  TriggerServerEvent("17mov_cleaner:StartHamperBottom")
                end
              end
            end
          end
        else
          if downPressed then
            downPressed = false
            TriggerServerEvent("17mov_cleaner:StopHamperBottom", GetEntityCoords(hamperEntity))
          end
        end
      end
    end)
  end
end)
local hamperStartTime = nil
local canSyncHamper = false

RegisterNetEvent("17mov_cleaner:startHamperTop")
AddEventHandler("17mov_cleaner:startHamperTop", function()
  hamperMovingUp = true
  hamperStartTime = GetGameTimer()
  Citizen.CreateThread(function()
    PlayGarageDoorSound()
    while hamperMovingUp do
      Citizen.Wait(100)
      if GetGameTimer() - hamperStartTime > 1000 then
        hamperMovingUp = false
        TriggerServerCallback("17mov_Cleaner:GetMyHamperCoords", function(targetZ)
          local currentCoords = GetEntityCoords(hamperEntity)
          if targetZ > currentCoords.z then
            while targetZ > GetEntityCoords(hamperEntity).z do
              Citizen.Wait(0)
              local currentZ = GetEntityCoords(hamperEntity).z
              SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ + 0.01, false, false, false, false)
            end
          else
            while targetZ < GetEntityCoords(hamperEntity).z do
              Citizen.Wait(0)
              local currentZ = GetEntityCoords(hamperEntity).z
              SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ - 0.01, false, false, false, false)
            end
          end
        end)
      end
    end
    StopGarageDoorSound(GetEntityCoords(hamperEntity))
  end)
end)
local canSyncHamperStop = false
RegisterNetEvent("17mov_cleaner:stopHamperTop")
AddEventHandler("17mov_cleaner:stopHamperTop", function(targetCoords)
  hamperMovingUp = false
  local currentCoords = GetEntityCoords(hamperEntity)
  local targetZ = targetCoords.z
  if not canSyncHamperStop then
    canSyncHamperStop = true
    if targetZ > currentCoords.z then
      while targetZ > GetEntityCoords(hamperEntity).z do
        Citizen.Wait(0)
        local currentZ = GetEntityCoords(hamperEntity).z
        SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ + 0.01, false, false, false, false)
      end
    else
      while targetZ < GetEntityCoords(hamperEntity).z do
        Citizen.Wait(0)
        local currentZ = GetEntityCoords(hamperEntity).z
        SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ - 0.01, false, false, false, false)
      end
    end
    canSyncHamperStop = false
  end
end)
local hamperBottomStartTime = nil

RegisterNetEvent("17mov_cleaner:startHamperBottom")
AddEventHandler("17mov_cleaner:startHamperBottom", function()
  hamperMovingDown = true
  hamperBottomStartTime = GetGameTimer()
  Citizen.CreateThread(function()
    PlayGarageDoorSound()
    while hamperMovingDown do
      Citizen.Wait(100)
      if GetGameTimer() - hamperBottomStartTime > 1000 then
        hamperMovingDown = false
        TriggerServerCallback("17mov_Cleaner:GetMyHamperCoords", function(targetZ)
          local currentCoords = GetEntityCoords(hamperEntity)
          if targetZ > currentCoords.z then
            while targetZ > GetEntityCoords(hamperEntity).z do
              Citizen.Wait(0)
              local currentZ = GetEntityCoords(hamperEntity).z
              SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ + 0.01, false, false, false, false)
            end
          else
            while targetZ < GetEntityCoords(hamperEntity).z do
              Citizen.Wait(0)
              local currentZ = GetEntityCoords(hamperEntity).z
              SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ - 0.01, false, false, false, false)
            end
          end
        end)
      end
    end
    StopGarageDoorSound(GetEntityCoords(hamperEntity))
  end)
end)
local canSyncHamperBottomStop = false

RegisterNetEvent("17mov_cleaner:stopHamperBottom")
AddEventHandler("17mov_cleaner:stopHamperBottom", function(targetCoords)
  hamperMovingDown = false
  local currentCoords = GetEntityCoords(hamperEntity)
  local targetZ = targetCoords.z
  if not canSyncHamperBottomStop then
    canSyncHamperBottomStop = true
    if targetZ > currentCoords.z then
      while targetZ > GetEntityCoords(hamperEntity).z do
        Citizen.Wait(0)
        local currentZ = GetEntityCoords(hamperEntity).z
        SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ + 0.01, false, false, false, false)
      end
    else
      while targetZ < GetEntityCoords(hamperEntity).z do
        Citizen.Wait(0)
        local currentZ = GetEntityCoords(hamperEntity).z
        SetEntityCoords(hamperEntity, currentCoords.x, currentCoords.y, currentZ - 0.01, false, false, false, false)
      end
    end
    canSyncHamperBottomStop = false
  end
end)

RegisterNUICallback("acceptWarning", function(data)
  TriggerServerEvent("17mov_Cleaner:endJob_sv", false)
  if Config.DeleteVehicleWithPenalty then
    DeleteVehicleByCore(GetVehiclePedIsIn(PlayerPedId(), false))
  end
end)

