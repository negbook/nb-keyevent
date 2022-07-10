local _M_ = {}
do 

    local totalThread = 0
    local debugMode = false
    local e = {} setmetatable(e,{__call = function(t,...) end})
    local newLoopThread = function(t,k)  
        CreateThread(function()
            totalThread = totalThread + 1
            local o = t[k]
            repeat 
                local tasks = (o or e)
                local n = #tasks
                if n==0 then 
                    goto end_loop 
                end 
                for i=1,n do 
                    (tasks[i] or e)()
                end 
            until n == 0 or Wait(k) 
            ::end_loop::
            totalThread = totalThread - 1
            t[k] = nil

            return 
        end)
    end   

    local Loops = setmetatable({[e]=e}, {__newindex = function(t, k, v)
        rawset(t, k, v)
        newLoopThread(t, k)
    end})

    local newLoopObject = function(t,selff,f)
        local fns = t.fns
        local fnsbreak = t.fnsbreak
        local f = f 
        local selff = selff
        local ref = function(act,val)
            if act == "break" or act == "kill" then 
                local n = fns and #fns or 0
                if n > 0 then 
                    for i=1,n do 
                        if fns[i] == f then 
                            table.remove(fns,i)
                            if fnsbreak and fnsbreak[i] then fnsbreak[i]() end
                            table.remove(fnsbreak,i)
                            if #fns == 0 then 
                                table.remove(Loops[t.duration],i)
                            end
                            break
                        end
                    end
                else 
                    return t:delete(fbreak)
                end
            elseif act == "set" or act == "transfer" then 
                return t:transfer(val) 
            elseif act == "get" then 
                return t.duration
            end 
        end
        local aliveDelay = nil 
        return function(action,...)
            if not action then
                if aliveDelay and GetGameTimer() < aliveDelay then 
                    return e()
                else 
                    aliveDelay = nil 
                    return selff(ref)
                end
            elseif action == "setalivedelay" then 
                local delay = ...
                aliveDelay = GetGameTimer() + delay
            else 
                ref(action,...)
            end
        end 
    end 

    local LoopParty = function(duration,init)
        if not Loops[duration] then Loops[duration] = {} end 
        local self = {}
        self.duration = duration
        self.fns = {}
        self.fnsbreak = {}
        local selff
        if init then 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                if init() then 
                    for i=1,n do 
                        fns[i](ref)
                    end 
                end 
            end 
        else 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                for i=1,n do 
                    fns[i](ref)
                end 
            end 
        end 
        setmetatable(self, {__index = Loops[duration],__call = function(t,f,...)
            if type(f) ~= "string" then 
                local fbreak = ...
                table.insert(t.fns, f)
                if fbreak then table.insert(self.fnsbreak, fbreak) end
                local obj = newLoopObject(self,selff,f)
                table.insert(Loops[duration], obj)
                self.obj = obj
                return self
            elseif self.obj then  
                return self.obj(f,...)
            end 
        end,__tostring = function(t)
            return "Loop("..t.duration.."), Total Thread: "..totalThread
        end})
        self.found = function(self,f)
            for i,v in ipairs(Loops[self.duration]) do
                if v == self.obj then
                    return i
                end 
            end 
            return false
        end
        self.delay = nil 
        local checktimeout = function(cb)
                
                if (self.delay and self.delay <= GetGameTimer()) or not self.delay then 
                    if Loops[duration] then 
                        local i = self.found(self)
                        if i then
                            local fns = self.fns
                            local fnsbreak = self.fnsbreak
                            local n = fns and #fns or 0
                            if n > 0 then 
                                table.remove(fns,n)
                                if fnsbreak and fnsbreak[n] then fnsbreak[n]() end
                                table.remove(fnsbreak,n)
                                if #fns == 0 then 
                                    table.remove(Loops[duration],i)
                                end
                                if cb then cb() end
                            elseif debugMode then  
                                error("It should be deleted")
                            end 
                            
                        elseif debugMode then  
                            error('Task deleteing not found',2)
                        end
                    elseif debugMode then  
                        error('Task deleteing not found',2)
                    end 
                end 
            end 
        self.delete = function(s,delay,cb)
            local delay = delay
            local cb = cb 
            if type(delay) ~= "number" then 
                cb = delay
                delay = nil 
            end 
            
            if delay and delay>0 then 
                self.delay = delay + GetGameTimer()   
                SetTimeout(delay,function()
                    checktimeout(cb)
                end)
            else
                self.delay = nil 
                checktimeout(cb)
            end 
        end
        self.transfer = function(s,newduration)
            if s.duration == newduration then return end
            local i = s.found(s) 
            if i then
                table.remove(Loops[s.duration],i)
                s.obj("setalivedelay",newduration)
                if not Loops[newduration] then Loops[newduration] = {} end 
                table.insert(Loops[newduration],s.obj)
                s.duration = newduration
            end
        end
        self.set = self.transfer 
        return self
    end 
    _M_.LoopParty = LoopParty
end 

local LoopParty = LoopParty
if not LoopParty then 
    local try = LoadResourceFile("nb-libs","shared/loop.lua") or LoadResourceFile("nb-loop","nb-loop.lua")
    LoopParty = LoopParty or (try and load(try.." return LoopParty(...)")) or _M_.LoopParty
end 


if GetCurrentResourceName() == "nb-keyevent" then 
    local RegisteredEvents = {}
    local local_fns = function(name)
        local t = RegisteredEvents[name]
         return function()
            for resource,idxs in pairs(t) do 
                if idxs then 
                    for i,v in pairs(idxs) do 
                        if v then 
                            TriggerEvent("NBRegCMDToResources:"..resource,name,i)
                        end 
                    end 
                end 
            end 
         end 
    end 
    AddEventHandler("NBRegCMDToResources:nb-keyevent",function(name,idx)
        local resource = GetInvokingResource()
        if not RegisteredEvents[name] then RegisteredEvents[name] = {} end 
        if not RegisteredEvents[name][resource] then RegisteredEvents[name][resource] = {} end 
        RegisteredEvents[name][resource][idx] = true 
        RegisterCommand(name,local_fns(name),false)
    end) 
    AddEventHandler("NBRegCMDToResourcesUndo:nb-keyevent",function(name,idx)
        local resource = GetInvokingResource()
        if not RegisteredEvents[name] then return end 
        if not RegisteredEvents[name][resource] then return end 
        RegisteredEvents[name][resource][idx] = false 
    end) 
    AddEventHandler("OnResourceStop",function(resource)
        if not RegisteredEvents then return end 
        for name,idxs in pairs(RegisteredEvents) do 
            if idxs then 
                if idxs[resource] then 
                    for i,v in pairs(idxs[resource]) do 
                        if v then 
                            TriggerEvent("NBRegCMDToResourcesUndo:"..resource,name,i)
                        end 
                    end 
                end 
            end 
        end 
    end)
    local reads = {}
    NBRegisterKeyMapping = function(name,desc,group,key ) --name,desc,group,key 
        local game = GetGameName()
        if game == "redm" or type(group) == "number" then 
            if type(key) == "string" then 
                local keys = {
                    -- Letters
                    ["A"] = 0x7065027D,
                    ["B"] = 0x4CC0E2FE,
                    ["C"] = 0x9959A6F0,
                    ["D"] = 0xB4E465B4,
                    ["E"] = 0xCEFD9220,
                    ["F"] = 0xB2F377E8,
                    ["G"] = 0x760A9C6F,
                    ["H"] = 0x24978A28,
                    ["I"] = 0xC1989F95,
                    ["J"] = 0xF3830D8E,
                    -- Missing K, don't know if anything is actually bound to it
                    ["L"] = 0x80F28E95,
                    ["M"] = 0xE31C6A41,
                    ["N"] = 0x4BC9DABB, -- Push to talk key
                    ["O"] = 0xF1301666,
                    ["P"] = 0xD82E0BD2,
                    ["Q"] = 0xDE794E3E,
                    ["R"] = 0xE30CD707,
                    ["S"] = 0xD27782E3,
                    -- Missing T
                    ["U"] = 0xD8F73058,
                    ["V"] = 0x7F8D09B8,
                    ["W"] = 0x8FD015D8,
                    ["X"] = 0x8CC9CD42,
                    -- Missing Y
                    ["Z"] = 0x26E9DC00,

                    -- Symbol Keys
                    ["RIGHTBRACKET"] = 0xA5BDCD3C,
                    ["LEFTBRACKET"] = 0x430593AA,
                    -- Mouse buttons
                    ["MOUSE1"] = 0x07CE1E61,
                    ["MOUSE2"] = 0xF84FA74F,
                    ["MOUSE3"] = 0xCEE12B50,
                    ["MWUP"] = 0x3076E97C,
                    -- Modifier Keys
                    ["CTRL"] = 0xDB096B85,
                    ["TAB"] = 0xB238FE0B,
                    ["SHIFT"] = 0x8FFC75D6,
                    ["SPACEBAR"] = 0xD9D0E1C0,
                    ["ENTER"] = 0xC7B5340A,
                    ["BACKSPACE"] = 0x156F7119,
                    ["LALT"] = 0x8AAA0AD4,
                    ["DEL"] = 0x4AF4D473,
                    ["PGUP"] = 0x446258B6,
                    ["PGDN"] = 0x3C3DD371,
                    -- Function Keys
                    ["F1"] = 0xA8E3F467,
                    ["F4"] = 0x1F6D95E5,
                    ["F6"] = 0x3C0A40F2,
                    -- Number Keys
                    ["1"] = 0xE6F612E4,
                    ["2"] = 0x1CE6D9EB,
                    ["3"] = 0x4F49CC4C,
                    ["4"] = 0x8F9F9E58,
                    ["5"] = 0xAB62E997,
                    ["6"] = 0xA1FDE2A6,
                    ["7"] = 0xB03A913B,
                    ["8"] = 0x42385422,
                    -- Arrow Keys
                    ["DOWN"] = 0x05CA7C52,
                    ["UP"] = 0x6319DB71,
                    ["LEFT"] = 0xA65EBAB4,
                    ["RIGHT"] = 0xDEB34313,
                    -- Numpad Keys
                    
                    ["QuickSelectSetForSwap"] = 0xD45EC04F,
                    ["QuickShortcutAbilitiesMenu"] = 0x9CC7A1A4,
                    ["QuickSelectSecondaryNavNext"] = 0xF1421CF5,
                    ["QuickSelectSecondaryNavPrev"] = 0xD9F9F017,
                    ["QuickSelectToggleShortcutItem"] = 0xFA0B29CD,
                    ["QuickSelectPutAwayRod"] = 0x253FEC09,
                    ["EmotesFavorite"] = 0xA835261B,
                    ["EmotesManage"] = 0x7E75F4DC,
                    ["EmotesSlotNavNext"] = 0xCBB12F87,
                    ["SelectNextWeapon"] = 0xD0842EDF,
                    ["SelectPrevWeapon"] = 0xF78D7337,
                    ["SkipCutscene"] = 0xCDC4E4E9,
                    ["CharacterWheel"] = 0x972F8D1E,
                    ["MultiplayerInfo"] = 0xE8342FF2,

                    
                    
                    
                    
                    
                    ["Phone"] = 0x4CF871D0,
                    
                    ["SpecialAbilitySecondary"] = 0x6328239B,
                    ["SecondarySpecialAbilitySecondary"] = 0x811F4A1A,
                    ["SpecialAbilityAction"] = 0x1ECA87D4,
                    ["MoveLr"] = 0x4D8FB4C1,
                    ["MoveUd"] = 0xFDA83190,
                    
                    
                    ["TwirlPistol"] = 0x938D4071,
                    
                    ["OpenWheelMenu"] = 0xAC4BD4F1,
                    
                    ["OpenSatchelHorseMenu"] = 0x5966D52A,
                    ["OpenCraftingMenu"] = 0x734C6E39,
                    
                    ["Pickup"] = 0xE6360A8E,
                    ["Ignite"] = 0xC75C27B0,
                    
                    
                    ["SniperZoomInSecondary"] = 0x6BE9C207,
                    ["SniperZoomOutSecondary"] = 0x8A7B8833,
                    
                    
                    
                    
                    ["Detonate"] = 0x73846677,
                    ["HudSpecial"] = 0x580C4473,
                    ["Arrest"] = 0xA4F1006B,
                    ["AccurateAim"] = 0x406ADFAE,
                    ["SwitchShoulder"] = 0x827E9EE8,
                    ["IronSight"] = 0x841240A9,
                    
                    ["SwitchFiringMode"] = 0xEED15F18,
                    ["Context"] = 0xB73BCA77,
                    ["ContextSecondary"] = 0xF19BE385,
                    ["WeaponSpecial"] = 0x733901F3,
                    ["WeaponSpecialTwo"] = 0x50BA1A77,
                    ["Dive"] = 0x06052D11,
                    ["DropWeapon"] = 0x7DBCD016,
                    ["DropAmmo"] = 0x4E42696E,
                    ["ThrowGrenade"] = 0x0AF99998,
                    ["FocusCam"] = 0xE72B43F4,
                    ["Inspect"] = 0xA61DC630,
                    ["InspectZoom"] = 0x53296B75,
                    ["InspectLr"] = 0x1788C283,
                    ["InspectUd"] = 0xF9781997,
                    ["InspectOpenSatchel"] = 0x9B1CA8DA,
                    ["DynamicScenario"] = 0x2EAB0795,
                    
                    ["OpenEmoteWheel"] = 0xE2B557A3,
                    ["OpenEmoteWheelHorse"] = 0x8B3FA65E,
                    ["EmoteGroupLink"] = 0x1C826362,
                    ["EmoteGroupLinkHorse"] = 0x4FD1C57B,
                    ["RevealHud"] = 0xCF8A4ECA,
                    ["SelectRadarMode"] = 0x0F39B3D4,
                    ["SimpleRadar"] = 0x5FEF1B6D,
                    ["ExpandRadar"] = 0xCF0B11DE,
                    ["RegularRadar"] = 0x51AA7A35,
                    ["DisableRadar"] = 0x70CBD78D,
                    ["Surrender"] = 0xDB8D69B8,
                    
                    ["WhistleHorseback"] = 0xE7EB9185,
                    ["StopLeadingAnimal"] = 0x7914A3DD,
                    ["CinematicCam"] = 0x620A6C5E,
                    ["CinematicCamHold"] = 0xD7E7B375,
                    ["CinematicCamChangeShot"] = 0xA6C67243,
                    ["CinematicCamUd"] = 0x84574AE8,
                    ["CinematicCamUpOnly"] = 0xEFCFE6B7,
                    ["CinematicCamDownOnly"] = 0x23AE34A2,
                    ["CinematicCamLr"] = 0x6BC904FC,
                    ["ContextA"] = 0x5181713D,
                    ["ContextB"] = 0x3B24C470,
                    ["ContextX"] = 0xE3BF959B,
                    ["ContextY"] = 0xD51B784F,
                    ["ContextLt"] = 0xC13A6564,
                    ["ContextRt"] = 0x07B8BEAF,
                    ["ContextAction"] = 0xB28318C0,
                    ["VehMoveLr"] = 0xF1E2852C,
                    ["VehMoveUd"] = 0x8A81C00C,
                    ["VehMoveUpOnly"] = 0xDEBD7EF6,
                    ["VehMoveDownOnly"] = 0x16D73E1D,
                    ["VehMoveLeftOnly"] = 0x9DF54706,
                    ["VehMoveRightOnly"] = 0x97A8FD98,
                    ["VehSpecial"] = 0x493919DB,
                    ["VehGunLr"] = 0xB6F3E4FE,
                    ["VehGunUd"] = 0x482560EE,
                    ["VehAim"] = 0xD7CAFCEF,
                    ["VehAttack"] = 0xF4330038,
                    ["VehAttack2"] = 0xF1C341BA,
                    ["VehAccelerate"] = 0x5B9FD4E2,
                    ["VehBrake"] = 0x6E1F639B,
                    ["VehDuck"] = 0x5B3690F2,
                    
                    ["VehExit"] = 0xFEFAB9B4,
                    ["VehHandbrake"] = 0x65D24C98,
                    ["VehLookBehind"] = 0xCAE9B017,
                    ["VehNextRadio"] = 0x22E0F7E7,
                    ["VehPrevRadio"] = 0x9785CE13,
                    ["VehNextRadioTrack"] = 0xF7FA2DDC,
                    ["VehPrevRadioTrack"] = 0x0A94C4FF,
                    ["VehRadioWheel"] = 0x4915AC0A,
                    ["VehHorn"] = 0x63A0D258,
                    ["VehFlyThrottleUp"] = 0x7232BAB3,
                    ["VehFlyThrottleDown"] = 0x084DFF95,
                    ["VehFlyYawLeft"] = 0x31589AD1,
                    ["VehFlyYawRight"] = 0xBD143FC6,
                    ["VehPassengerAim"] = 0xEE2804D0,
                    ["VehPassengerAttack"] = 0x27AD4433,
                    ["VehSpecialAbilityFranklin"] = 0x5EC33578,
                    ["VehStuntUd"] = 0x4AA1560E,
                    ["VehSelectNextWeapon"] = 0x889A626F,
                    ["VehSelectPrevWeapon"] = 0x0C97BAC7,
                    ["VehRoof"] = 0x3E7CF9A4,
                    ["VehJump"] = 0xAA56B926,
                    ["VehGrapplingHook"] = 0xB985AA5E,
                    
                    ["VehTraversal"] = 0x739D6261,
                    ["VehDropProjectile"] = 0xC61611E6,
                    ["VehMouseControlOverride"] = 0x39CCABD5,
                    ["VehFlyRollLr"] = 0x3C8AB570,
                    ["VehFlyRollLeftOnly"] = 0x56F84EA0,
                    ["VehFlyRollRightOnly"] = 0x876B3361,
                    ["VehFlyPitchUd"] = 0xE67E1E57,
                    ["VehFlyPitchUpOnly"] = 0x6280BA1A,
                    ["VehFlyPitchDownOnly"] = 0x0F4E369F,
                    ["VehFlyUndercarriage"] = 0xFE0FE518,
                    ["VehFlyAttack"] = 0x1D71D7AA,
                    ["VehFlySelectNextWeapon"] = 0x24E94299,
                    ["VehFlySelectPrevWeapon"] = 0xC0D874E5,
                    ["VehFlySelectTargetLeft"] = 0x307FC4C1,
                    ["VehFlySelectTargetRight"] = 0x52F25C96,
                    ["VehFlyVerticalFlightMode"] = 0xE3238029,
                    ["VehFlyDuck"] = 0x378A10F7,
                    ["VehFlyAttackCamera"] = 0x2FBA3F0B,
                    ["VehFlyMouseControlOverride"] = 0x6C9810A5,
                    ["VehSubMouseControlOverride"] = 0x2CAF327E,
                    ["VehSubTurnLr"] = 0x627C4619,
                    ["VehSubTurnLeftOnly"] = 0x44E7E093,
                    ["VehSubTurnRightOnly"] = 0xE78A5A3C,
                    ["VehSubPitchUd"] = 0x469CE271,
                    ["VehSubPitchUpOnly"] = 0xF9EF072A,
                    ["VehSubPitchDownOnly"] = 0xBA2D22AA,
                    ["VehSubThrottleUp"] = 0xD28C446F,
                    ["VehSubThrottleDown"] = 0xF5B2CEFB,
                    ["VehSubAscend"] = 0xD7991F74,
                    ["VehSubDescend"] = 0x7D51DE24,
                    ["VehSubTurnHardLeft"] = 0x64214D49,
                    ["VehSubTurnHardRight"] = 0xA44C0F83,
                    ["VehPushbikePedal"] = 0xFD8D64A7,
                    ["VehPushbikeSprint"] = 0xF03EE151,
                    ["VehPushbikeFrontBrake"] = 0x585E942D,
                    ["VehPushbikeRearBrake"] = 0xF8CBAFB5,
                    ["VehDraftMoveUd"] = 0x23595CEA,
                    ["VehDraftTurnLr"] = 0xA7DFAE8A,
                    ["VehDraftMoveUpOnly"] = 0x29A5E51E,
                    ["VehDraftMoveDownOnly"] = 0x25493EB3,
                    ["VehDraftTurnLeftOnly"] = 0x198AFC64,
                    ["VehDraftTurnRightOnly"] = 0x5E371EA7,
                    ["VehDraftAccelerate"] = 0xE99D2B05,
                    ["VehDraftBrake"] = 0xD648E48D,
                    ["VehDraftAim"] = 0xBDD5830D,
                    ["VehDraftAttack"] = 0xF40AB198,
                    ["VehDraftAttack2"] = 0x886F12DD,
                    ["VehDraftSwitchDrivers"] = 0x70B87844,
                    ["VehBoatTurnLr"] = 0xD8DFCAB3,
                    ["VehBoatTurnLeftOnly"] = 0x5BED7C91,
                    ["VehBoatTurnRightOnly"] = 0xF9780DFB,
                    ["VehBoatAccelerate"] = 0xB341E812,
                    ["VehBoatBrake"] = 0x428D5F39,
                    ["VehBoatAim"] = 0x92F5F01E,
                    ["VehBoatAttack"] = 0x6866FA3A,
                    ["VehBoatAttack2"] = 0x876096E9,
                    ["VehCarTurnLr"] = 0x3BD38D43,
                    ["VehCarTurnLeftOnly"] = 0x07D1654C,
                    ["VehCarTurnRightOnly"] = 0x6E3C3649,
                    ["VehCarAccelerate"] = 0xB9F544B0,
                    ["VehCarBrake"] = 0xD1887B3F,
                    ["VehCarAim"] = 0x6777B840,
                    ["VehCarAttack"] = 0x5572F386,
                    ["VehCarAttack2"] = 0x5B763AD7,
                    ["VehHandcartAccelerate"] = 0xFF3626FC,
                    ["VehHandcartBrake"] = 0x2D79D80A,
                    ["HorseMoveLr"] = 0x126796EB,
                    ["HorseMoveUd"] = 0x3BBDEFEF,
                    ["HorseMoveUpOnly"] = 0x699487BB,
                    ["HorseMoveDownOnly"] = 0x56F82045,
                    ["HorseMoveLeftOnly"] = 0x86D773F6,
                    ["HorseMoveRightOnly"] = 0x7E6B8612,
                    ["HorseSpecial"] = 0x70089459,
                    ["HorseGunLr"] = 0x3D99EEC6,
                    ["HorseGunUd"] = 0xBFF476F9,
                    ["HorseAttack"] = 0x60C81CDE,
                    ["HorseAttack2"] = 0xC904196D,
                    ["HorseSprint"] = 0x5AA007D7,
                    ["HorseStop"] = 0xE16B9AAD,
                    ["HorseExit"] = 0xCBDB82A8,
                    ["HorseLookBehind"] = 0x81280569,
                    ["HorseJump"] = 0xE4D2CE1D,
                    ["HorseAim"] = 0x61470051,
                    ["HorseCollect"] = 0x7D5B3717,
                    ["HitchAnimal"] = 0xA95E1468,
                    ["HorseCommandFlee"] = 0x4216AF06,
                    ["HorseCommandStay"] = 0xAE5DFDED,
                    ["HorseCommandFollow"] = 0x763E4D27,
                    ["HorseMelee"] = 0x1A3EABBB,
                    ["MeleeHorseAttackPrimary"] = 0x78ED2132,
                    ["MeleeHorseAttackSecondary"] = 0x162AFEB8,
                    ["HorseCoverTransition"] = 0x2996DD15,
                    
                    ["MeleeModifier"] = 0x1E7D7275,
                    ["MeleeBlock"] = 0xB5EEEFB7,
                    ["MeleeGrapple"] = 0x2277FAE9,
                    ["MeleeGrappleAttack"] = 0xADEAF48C,
                    ["MeleeGrappleChoke"] = 0x018C47CF,
                    ["MeleeGrappleReversal"] = 0x91C9A817,
                    ["MeleeGrappleBreakout"] = 0xD0C1FEFF,
                    ["MeleeGrappleStandSwitch"] = 0xBE1F4699,
                    ["MeleeGrappleMountSwitch"] = 0x67ED272E,
                    ["ParachuteDeploy"] = 0xEBF53058,
                    ["ParachuteDetach"] = 0xFFBFF139,
                    ["ParachuteTurnLr"] = 0x8EC920BF,
                    ["ParachuteTurnLeftOnly"] = 0xC4CF3322,
                    ["ParachuteTurnRightOnly"] = 0x2BDBA378,
                    ["ParachutePitchUd"] = 0xF0526228,
                    ["ParachutePitchUpOnly"] = 0x08BFEA69,
                    ["ParachutePitchDownOnly"] = 0x7C3A4352,
                    ["ParachuteBrakeLeft"] = 0x272BD8BA,
                    ["ParachuteBrakeRight"] = 0x948B3EA7,
                    ["ParachuteSmoke"] = 0x2574FAB0,
                    ["ParachutePrecisionLanding"] = 0xC675B8BD,
                    
                    ["SelectWeaponUnarmed"] = 0x1F6EEB0F,
                    ["SelectWeaponMelee"] = 0x109E6852,
                    ["SelectWeaponHandgun"] = 0x184960E3,
                    ["SelectWeaponShotgun"] = 0x76D3EA05,
                    ["SelectWeaponSmg"] = 0xCEF1BB48,
                    ["SelectWeaponAutoRifle"] = 0x05EEA9D0,
                    ["SelectWeaponSniper"] = 0x96C61FDF,
                    ["SelectWeaponHeavy"] = 0x3D1675C3,
                    ["SelectWeaponSpecial"] = 0xC41ECEF8,
                    ["SelectCharacterMichael"] = 0xEA9256B8,
                    ["SelectCharacterFranklin"] = 0x8E8B08CB,
                    ["SelectCharacterTrevor"] = 0xB00CC093,
                    ["SelectCharacterMultiplayer"] = 0xDFB2B3B8,
                    ["SaveReplayClip"] = 0x5B3AF9E3,
                    ["SpecialAbilityPc"] = 0x52E60A8B,
                    
                    ["CellphoneUp"] = 0xD2EE3B1E,
                    ["CellphoneDown"] = 0x82196002,
                    ["CellphoneLeft"] = 0x3ABBE990,
                    ["CellphoneRight"] = 0xD25EFDCD,
                    ["CellphoneSelect"] = 0xDC264018,
                    ["CellphoneCancel"] = 0xDD833287,
                    ["CellphoneOption"] = 0xD2C28BB4,
                    ["CellphoneExtraOption"] = 0xBE354011,
                    ["CellphoneScrollForward"] = 0xCB4E1798,
                    ["CellphoneScrollBackward"] = 0x47CD0F3B,
                    ["CellphoneCameraFocusLock"] = 0x5AC1805E,
                    ["CellphoneCameraGrid"] = 0xE18CC57A,
                    ["CellphoneCameraSelfie"] = 0x6A440BFE,
                    ["CellphoneCameraDof"] = 0x593DB489,
                    ["CellphoneCameraExpression"] = 0xD7E274E7,
                    
                    ["FrontendRdown"] = 0x5734A944,
                    ["FrontendRup"] = 0xD7DE6B1E,
                    ["FrontendRleft"] = 0x39336A4F,
                    ["FrontendRright"] = 0x5B48F938,
                    ["FrontendAxisX"] = 0xFB56DD5B,
                    ["FrontendAxisY"] = 0x091178D0,
                    ["FrontendScrollAxisX"] = 0x3224BC55,
                    ["FrontendScrollAxisY"] = 0x21651AD6,
                    ["FrontendRightAxisX"] = 0x3D23549A,
                    ["FrontendRightAxisY"] = 0xEB4130DF,
                    
                    ["FrontendPauseAlternate"] = 0x4A903C11,
                    
                    ["FrontendX"] = 0x6DB8C62F,
                    ["FrontendY"] = 0x7C0162C0,
                    ["FrontendLb"] = 0xE885EF16,
                    ["FrontendRb"] = 0x17BEC168,
                    ["FrontendLt"] = 0x51104035,
                    ["FrontendRt"] = 0x6FED71BC,
                    ["FrontendLs"] = 0x43CDA5B0,
                    ["FrontendRs"] = 0x7DA48D2A,
                    ["FrontendLeaderboard"] = 0x9EDC8D65,
                    ["FrontendSocialClub"] = 0x064D1698,
                    ["FrontendSocialClubSecondary"] = 0xBDB8D6F3,
                    
                    ["FrontendEndscreenAccept"] = 0x3E32FCEE,
                    ["FrontendEndscreenExpand"] = 0xC79BDE9F,
                    ["FrontendSelect"] = 0x171910DC,
                    ["FrontendPhotoMode"] = 0x44CD301B,
                    ["FrontendNavUp"] = 0x8CFFE0A1,
                    ["FrontendNavDown"] = 0x78114AB3,
                    ["FrontendNavLeft"] = 0x877F1027,
                    ["FrontendNavRight"] = 0x08BD758C,
                    ["FrontendMapNavUp"] = 0x125A70E5,
                    ["FrontendMapNavDown"] = 0xF8480EED,
                    ["FrontendMapNavLeft"] = 0xE0D75B00,
                    ["FrontendMapNavRight"] = 0x28725E5D,
                    ["FrontendMapZoom"] = 0x6B359A27,
                    ["GameMenuAccept"] = 0x43DBF61F,
                    ["GameMenuCancel"] = 0x308588E6,
                    ["GameMenuOption"] = 0xFBD7B3E6,
                    ["GameMenuExtraOption"] = 0xD596CFB0,
                    ["GameMenuUp"] = 0x911CB09E,
                    ["GameMenuDown"] = 0x4403F97F,
                    ["GameMenuLeft"] = 0xAD7FCC5B,
                    ["GameMenuRight"] = 0x65F9EC5B,
                    ["GameMenuTabLeft"] = 0xCBD5B26E,
                    ["GameMenuTabRight"] = 0x110AD1D2,
                    ["GameMenuTabLeftSecondary"] = 0x26E9DC00,
                    ["GameMenuTabRightSecondary"] = 0x8CC9CD42,
                    ["GameMenuScrollForward"] = 0x81457A1A,
                    ["GameMenuScrollBackward"] = 0x9DA42644,
                    ["GameMenuStickUp"] = 0x9CA97399,
                    ["GameMenuStickDown"] = 0x63898D36,
                    ["GameMenuStickLeft"] = 0x06C089D4,
                    ["GameMenuStickRight"] = 0x5BDBE841,
                    ["GameMenuRightStickUp"] = 0xF0232A03,
                    ["GameMenuRightStickDown"] = 0xADB78673,
                    ["GameMenuRightStickLeft"] = 0x71E38966,
                    ["GameMenuRightStickRight"] = 0xE1CECE4B,
                    ["GameMenuLs"] = 0xA8F6DE66,
                    ["GameMenuRs"] = 0x89EA3FA5,
                    ["GameMenuRightAxisX"] = 0x4685AA33,
                    ["GameMenuRightAxisY"] = 0x60C65EB4,
                    ["GameMenuLeftAxisX"] = 0xF431D57A,
                    ["GameMenuLeftAxisY"] = 0x226EB1EF,
                    ["Quit"] = 0x8E90C7BB,
                    ["DocumentPageNext"] = 0xC97792B7,
                    ["DocumentPagePrev"] = 0x20190AB4,
                    ["DocumentScroll"] = 0xAC70F311,
                    ["DocumentScrollUpOnly"] = 0x3D0C19EC,
                    ["DocumentScrollDownOnly"] = 0xD72F3E29,
                    ["Attack2"] = 0x0283C582,
                    ["PrevWeapon"] = 0xCC1075A7,
                    ["NextWeapon"] = 0xFD0F0C2C,
                    
                    ["SniperZoomInAlternate"] = 0x3A9897C1,
                    ["SniperZoomOutAlternate"] = 0xBC820489,
                    ["ReplayStartStopRecording"] = 0xDCA6978E,
                    ["ReplayStartStopRecordingSecondary"] = 0x8991A70B,
                    ["ReplayMarkerDelete"] = 0xC7D2C51B,
                    ["ReplayClipDelete"] = 0xF6734E42,
                    ["ReplayPause"] = 0x083137B2,
                    ["ReplayRewind"] = 0xC1339A31,
                    ["ReplayFfwd"] = 0x609A27E8,
                    ["ReplayNewmarker"] = 0xF7C6DA28,
                    ["ReplayRecord"] = 0xAD9A9C7C,
                    ["ReplayScreenshot"] = 0x567FAF34,
                    ["ReplayHidehud"] = 0x7E479C7B,
                    ["ReplayStartpoint"] = 0x5DAFACCF,
                    ["ReplayEndpoint"] = 0x4EF75BBD,
                    ["ReplayAdvance"] = 0x323AA450,
                    ["ReplayBack"] = 0x088C7CD4,
                    ["ReplayTools"] = 0x561A3387,
                    ["ReplayRestart"] = 0x81B8BC9D,
                    ["ReplayShowhotkey"] = 0xEBA2A41E,
                    ["ReplayCyclemarkerleft"] = 0x5C220959,
                    ["ReplayCyclemarkerright"] = 0xC69AE799,
                    ["ReplayFovincrease"] = 0x5925A10D,
                    ["ReplayFovdecrease"] = 0x2B88D701,
                    ["ReplayCameraup"] = 0x749EFF0C,
                    ["ReplayCameradown"] = 0xA1FE9E2A,
                    ["ReplaySave"] = 0xEBC60685,
                    ["ReplayToggletime"] = 0xE3FB91B3,
                    ["ReplayToggletips"] = 0xC8A1DE20,
                    ["ReplayPreview"] = 0x58AC1355,
                    ["ReplayToggleTimeline"] = 0xF8629909,
                    ["ReplayTimelinePickupClip"] = 0xD2454F90,
                    ["ReplayTimelineDuplicateClip"] = 0x4146A033,
                    ["ReplayTimelinePlaceClip"] = 0x60726F50,
                    ["ReplayCtrl"] = 0xD88B47E7,
                    ["ReplayTimelineSave"] = 0x65D70E9D,
                    ["ReplayPreviewAudio"] = 0x79022218,
                    ["ReplayActionReplayStart"] = 0xD9961107,
                    ["ReplayActionReplayCancel"] = 0x93776CAE,
                    ["ReplayRecordingStart"] = 0xFD28D0F4,
                    ["ReplayRecordingStop"] = 0xDB16E702,
                    ["ReplaySaveSnapshot"] = 0xEFEC8FDE,
                    ["VehDriveLook"] = 0xA2117C9A,
                    ["VehDriveLook2"] = 0x55AC04E5,
                    ["VehFlyAttack2"] = 0x4D83147C,
                    ["RadioWheelUd"] = 0x14C7291D,
                    ["RadioWheelLr"] = 0xF9FA6BC8,
                    ["VehSlowmoUd"] = 0xF1F9CD26,
                    ["VehSlowmoUpOnly"] = 0x2B981F4F,
                    ["VehSlowmoDownOnly"] = 0x642DE054,
                    ["MapPoi"] = 0x9BEE9213,
                    ["InteractLockon"] = 0xF8982F00,
                    ["InteractLockonNeg"] = 0x26A18F47,
                    ["InteractLockonPos"] = 0xF63A17F9,
                    ["InteractLockonRob"] = 0x9FA5AD07,
                    ["InteractLockonY"] = 0x09A92B8B,
                    ["InteractLockonA"] = 0xD10A3A36,
                    ["InteractNeg"] = 0x424BD2D2,
                    ["InteractPos"] = 0xF6BB7378,
                    
                    ["InteractOption2"] = 0x84543902,
                    ["InteractAnimal"] = 0xA1ABB953,
                    ["InteractLockonAnimal"] = 0x5415BE48,
                    ["InteractLeadAnimal"] = 0x17D3BFF5,
                    ["InteractLockonDetachHorse"] = 0xF5C4701B,
                    
                    ["InteractLockonCallAnimal"] = 0x71F89BBC,
                    ["InteractLockonTrackAnimal"] = 0xE2473BF0,
                    ["InteractLockonTargetInfo"] = 0x31219490,
                    ["InteractLockonStudyBinoculars"] = 0xB3F388BC,
                    ["InteractWildAnimal"] = 0x89F3D2E0,
                    ["InteractHorseFeed"] = 0x0D55A0F0,
                    ["InteractHorseBrush"] = 0x63A38F2C,
                    ["EmoteAction"] = 0x13C42BB2,
                    ["EmoteTaunt"] = 0x470DC190,
                    ["EmoteGreet"] = 0x72BAD5AA,
                    ["EmoteComm"] = 0x661857B3,
                    ["EmoteDance"] = 0xF311100C,
                    ["EmoteTwirlGunHold"] = 0x04FB8191,
                    ["EmoteTwirlGunVarA"] = 0x6990BDDF,
                    ["EmoteTwirlGunVarB"] = 0x52D29063,
                    ["EmoteTwirlGunVarC"] = 0xBC2AE312,
                    ["EmoteTwirlGunVarD"] = 0xAE69478F,
                    ["QuickEquipItem"] = 0x6070D032,
                    ["MinigameBuildingCameraNext"] = 0x16B0EEF8,
                    ["MinigameBuildingCameraPrev"] = 0x5F97B231,
                    ["MinigameBuildingHammer"] = 0xFA91AECD,
                    ["CursorAcceptDoubleClick"] = 0x1C559F2E,
                    ["CursorAcceptHold"] = 0xE474F150,
                    ["CursorAccept"] = 0x9D2AEA88,
                    ["CursorCancel"] = 0x27568539,
                    ["CursorCancelDoubleClick"] = 0x9CB4ECCE,
                    ["CursorCancelHold"] = 0xD7F70F36,
                    ["CursorX"] = 0xD6C4ECDC,
                    ["CursorY"] = 0xE4130778,
                    ["CursorScrollUp"] = 0x62800C92,
                    ["CursorScrollDown"] = 0x8BDE7443,
                    ["CursorScrollClick"] = 0x6AA8A71B,
                    ["CursorScrollDoubleClick"] = 0xE1B6ED6D,
                    ["CursorScrollHold"] = 0x5484DBDD,
                    ["CursorForwardClick"] = 0x11DBBAB9,
                    ["CursorForwardDoubleClick"] = 0x9805D715,
                    ["CursorForwardHold"] = 0x7630C9A1,
                    ["CursorBackwardClick"] = 0x9AF38793,
                    ["CursorBackwardDoubleClick"] = 0xA14BA1FC,
                    ["CursorBackwardHold"] = 0x01AA9FA1,
                    ["EnterCheatCode"] = 0x7BF65AC8,
                    ["InteractionMenu"] = 0xCC510E59,
                    ["MpTextChatAll"] = 0x9720FCEE,
                    ["MpTextChatTeam"] = 0x9098AD9D,
                    ["MpTextChatFriends"] = 0x7098AC73,
                    ["MpTextChatCrew"] = 0x8142FA92,
                    
                    ["CreatorLs"] = 0x339F3730,
                    ["CreatorRs"] = 0xD8CF0C95,
                    
                    ["CreatorMenuToggle"] = 0x85D24405,
                    ["CreatorAccept"] = 0x2CD5343E,
                    ["CreatorMenuUp"] = 0xBCD1444B,
                    ["CreatorMenuDown"] = 0x97410755,
                    ["CreatorMenuLeft"] = 0xEC6A30AA,
                    ["CreatorMenuRight"] = 0x19D8334C,
                    ["CreatorMenuAccept"] = 0xFB9C3231,
                    ["CreatorMenuCancel"] = 0xBB3FC460,
                    ["CreatorMenuFunction"] = 0x5A03B3F3,
                    ["CreatorMenuExtraFunction"] = 0xE6B8F103,
                    ["CreatorMenuSelect"] = 0x0984E40A,
                    ["CreatorPlace"] = 0xD74CACAD,
                    ["CreatorDelete"] = 0x3F4DC0EF,
                    ["CreatorDrop"] = 0x414034D5,
                    ["CreatorFunction"] = 0xB05FDA25,
                    ["CreatorRotateRight"] = 0x9D75674E,
                    ["CreatorRotateLeft"] = 0xD41E9C2A,
                    ["CreatorGrab"] = 0x338A0D45,
                    ["CreatorSwitchCam"] = 0x16CCFEC6,
                    ["CreatorZoomIn"] = 0x335D8D76,
                    ["CreatorZoomOut"] = 0x24A42F93,
                    ["CreatorRaise"] = 0x0D0FB9B1,
                    ["CreatorLower"] = 0x1BDE2EB3,
                    ["CreatorSearch"] = 0xF55864CD,
                    ["CreatorMoveUd"] = 0x82428676,
                    ["CreatorMoveLr"] = 0x59753EDC,
                    ["CreatorLookUd"] = 0x55EA24F3,
                    ["CreatorLookLr"] = 0xAEB2A9C7,
                    ["CutFree"] = 0xD2CC4644,
                    ["Drop"] = 0xD2928083,
                    ["PickupCarriable"] = 0xEB2AC491,
                    ["PickupCarriable2"] = 0xBE8593AF,
                    ["PlaceCarriableOntoParent"] = 0x7D326951,
                    ["PickupCarriableFromParent"] = 0xA1202C7B,
                    ["MercyKill"] = 0x956C2A0E,
                    ["Revive"] = 0x43F2959C,
                    ["Hogtie"] = 0xD9C50532,
                    ["CarriableSuicide"] = 0x6E9734E8,
                    ["CarriableBreakFree"] = 0x295175BF,
                    ["InteractHitCarriable"] = 0x0522B243,
                    ["Loot"] = 0x41AC83D1,
                    ["Loot2"] = 0x399C6619,
                    ["Loot3"] = 0x27D1C284,
                    ["LootVehicle"] = 0x14DB6C5E,
                    ["LootAmmo"] = 0xC23D7B9E,
                    ["BreakVehicleLock"] = 0x97C71B28,
                    ["LootAliveComponent"] = 0xFF8109D8,
                    
                    ["SaddleTransfer"] = 0x73A8FD83,
                    ["ShopBuy"] = 0xDFF812F9,
                    ["ShopSell"] = 0x6D1319BE,
                    ["ShopSpecial"] = 0xEA150E72,
                    ["ShopBounty"] = 0xD3ECF82F,
                    ["ShopInspect"] = 0x5E723D8C,
                    ["ShopChangeCurrency"] = 0x90FA19AB,
                    
                    ["PromptPageNext"] = 0x8CF90A9D,
                    ["FrontendTouchZoomFactor"] = 0xE7F89C38,
                    ["FrontendTouchZoomX"] = 0x16661AD0,
                    ["FrontendTouchZoomY"] = 0x253DB87F,
                    ["FrontendTouchDragX"] = 0xEC93548E,
                    ["FrontendTouchDragY"] = 0x9AC130EB,
                    ["FrontendTouchTapX"] = 0xC10E180A,
                    ["FrontendTouchTapY"] = 0xCF4B3484,
                    ["FrontendTouchDoubleTapX"] = 0x1661FAB0,
                    ["FrontendTouchDoubleTapY"] = 0x96E87BBF,
                    ["FrontendTouchHoldX"] = 0x0FF17F1D,
                    ["FrontendTouchHoldY"] = 0x398ED257,
                    ["FrontendTouchSwipeUpX"] = 0x0B71D439,
                    ["FrontendTouchSwipeUpY"] = 0x19CA70EA,
                    ["FrontendTouchSwipeDownX"] = 0xE3B30955,
                    ["FrontendTouchSwipeDownY"] = 0xBDFF3DEA,
                    ["FrontendTouchSwipeLeftX"] = 0x2545B0DE,
                    ["FrontendTouchSwipeLeftY"] = 0xD43D0ECE,
                    ["FrontendTouchSwipeRightX"] = 0xEAB68397,
                    ["FrontendTouchSwipeRightY"] = 0x675B7CE3,
                    ["MultiplayerInfoPlayers"] = 0x9C68CE34,
                    ["MultiplayerDeadSwitchRespawn"] = 0xB4F298BA,
                    ["MultiplayerDeadInformLaw"] = 0x6816A38E,
                    ["MultiplayerDeadRespawn"] = 0x18987353,
                    ["MultiplayerDeadDuel"] = 0xF875FC78,
                    ["MultiplayerDeadParley"] = 0x4D11FE01,
                    ["MultiplayerDeadFeud"] = 0xB4A11066,
                    ["MultiplayerDeadLeaderFeud"] = 0xCC18F960,
                    ["MultiplayerDeadPressCharges"] = 0xE50DCA13,
                    ["MultiplayerRaceRespawn"] = 0x014CA044,
                    ["MultiplayerPredatorAbility"] = 0xC5CF41B2,
                    ["MultiplayerSpectatePlayerNext"] = 0xBA065692,
                    ["MultiplayerSpectatePlayerPrev"] = 0x5092BF47,
                    ["MultiplayerSpectateHideHud"] = 0x7DBA5D49,
                    ["MultiplayerSpectatePlayerOptions"] = 0x4E074EE6,
                    ["MultiplayerLeaderboardScrollUd"] = 0xA917D24B,
                    ["MinigameQuit"] = 0xE9094BA0,
                    ["MinigameIncreaseBet"] = 0xC7CB8D5F,
                    ["MinigameDecreaseBet"] = 0xD3EBF425,
                    ["MinigameChangeBetAxisY"] = 0xBDC733EE,
                    ["MinigamePlaceBet"] = 0x410B0B2E,
                    ["MinigameClearBet"] = 0x4A21C66B,
                    ["MinigameHelp"] = 0x9384E0A8,
                    ["MinigameHelpPrev"] = 0xC5F53156,
                    ["MinigameHelpNext"] = 0x83608AC0,
                    ["MinigameReplay"] = 0x985243B7,
                    ["MinigameNewGame"] = 0x5D1788FF,
                    ["MinigamePokerSkip"] = 0x646A7792,
                    ["MinigamePokerCall"] = 0xDAB9EE72,
                    ["MinigamePokerFold"] = 0x49B4AD1E,
                    ["MinigamePokerCheck"] = 0x206B2087,
                    ["MinigamePokerCheckFold"] = 0x72A9D1F7,
                    ["MinigamePokerBet"] = 0xA9883369,
                    ["MinigamePokerHoleCards"] = 0xC2B1193A,
                    ["MinigamePokerBoardCards"] = 0x03753498,
                    ["MinigamePokerSkipTutorial"] = 0xB568BCD0,
                    ["MinigamePokerShowPossibleHands"] = 0x7765B9D4,
                    ["MinigamePokerYourCards"] = 0xF923B337,
                    ["MinigamePokerCommunityCards"] = 0xE402B898,
                    ["MinigamePokerCheatLr"] = 0x2330F517,
                    ["MinigameFishingResetCast"] = 0xB40A9BDB,
                    ["MinigameFishingReleaseFish"] = 0xF14FD435,
                    ["MinigameFishingKeepFish"] = 0x52C5C34A,
                    ["MinigameFishingHook"] = 0xA1CD103A,
                    ["MinigameFishingLeftAxisX"] = 0x69B10623,
                    ["MinigameFishingLeftAxisY"] = 0x09BF4645,
                    ["MinigameFishingRightAxisX"] = 0x4FD4E558,
                    ["MinigameFishingRightAxisY"] = 0x95F2F193,
                    ["MinigameFishingLeanLeft"] = 0x0D4C3ABA,
                    ["MinigameFishingLeanRight"] = 0x05074A9B,
                    ["MinigameFishingQuickEquip"] = 0x25F525CD,
                    ["MinigameFishingReelSpeedUp"] = 0x2FA915F5,
                    ["MinigameFishingReelSpeedDown"] = 0xD7AF56A0,
                    ["MinigameFishingReelSpeedAxis"] = 0x49C73CB2,
                    ["MinigameFishingManualReelIn"] = 0xA303F462,
                    ["MinigameFishingManualReelOutModifier"] = 0x4556642C,
                    ["MinigameCrackpotBoatShowControls"] = 0x524C3787,
                    ["MinigameDominoesViewDominoes"] = 0x88F8B6B1,
                    ["MinigameDominoesViewMoves"] = 0x7733CF2C,
                    ["MinigameDominoesPlayTile"] = 0x95F5BB7C,
                    ["MinigameDominoesSkipDeal"] = 0xC5E622D7,
                    ["MinigameDominoesMoveLeftOnly"] = 0xFDDD89D4,
                    ["MinigameDominoesMoveRightOnly"] = 0x7D5187C9,
                    ["MinigameDominoesMoveUpOnly"] = 0xC6AB8CB3,
                    ["MinigameDominoesMoveDownOnly"] = 0xFD9FC86D,
                    ["MinigameBlackjackHandView"] = 0x03F1E7CB,
                    ["MinigameBlackjackTableView"] = 0xADE09435,
                    ["MinigameBlackjackBetAxisY"] = 0x3D2EA092,
                    ["MinigameBlackjackBet"] = 0x661D8A31,
                    ["MinigameBlackjackDecline"] = 0xCD7DDF9B,
                    ["MinigameBlackjackStand"] = 0x31260507,
                    ["MinigameBlackjackHit"] = 0xA8142713,
                    ["MinigameBlackjackDouble"] = 0x74486CA4,
                    ["MinigameBlackjackSplit"] = 0x432B111F,
                    ["MinigameFffA"] = 0x0E717DC6,
                    ["MinigameFffB"] = 0x1BC81873,
                    ["MinigameFffX"] = 0x65F0ACDF,
                    ["MinigameFffY"] = 0x73AD4858,
                    ["MinigameFffZoom"] = 0x61E4CACC,
                    ["MinigameFffSkipTurn"] = 0x3073681B,
                    ["MinigameFffCycleSequenceLeft"] = 0x29A3550E,
                    ["MinigameFffCycleSequenceRight"] = 0x7B5B896D,
                    ["MinigameFffFlourishContinue"] = 0x6FC9DE68,
                    ["MinigameFffFlourishEnd"] = 0xF7750B25,
                    ["MinigameFffPractice"] = 0xCA379F82,
                    ["MinigameMilkingLeftAction"] = 0xFF4B2ADA,
                    ["MinigameMilkingRightAction"] = 0x30BE7CF2,
                    ["MinigameLeftTrigger"] = 0x7EC33553,
                    ["MinigameRightTrigger"] = 0xBE78B715,
                    ["MinigameActionLeft"] = 0x0A1EFC09,
                    ["MinigameActionRight"] = 0x16D70379,
                    ["MinigameActionUp"] = 0xF5A13A0D,
                    ["MinigameActionDown"] = 0xF601BCFC,
                    ["StickyFeedAccept"] = 0xF4DD4C67,
                    ["StickyFeedCancel"] = 0x0CFB963F,
                    ["StickyFeedX"] = 0xBD1D94A1,
                    ["StickyFeedY"] = 0xC85BAB1D,
                    ["CameraPutAway"] = 0x5FC770EA,
                    ["CameraBack"] = 0xA4BD74A5,
                    ["CameraTakePhoto"] = 0x44FA14C2,
                    ["CameraContextGallery"] = 0xE8337356,
                    ["CameraHandheldUse"] = 0x776F65E9,
                    ["CameraDof"] = 0x3003F9DC,
                    ["CameraSelfie"] = 0xAC5922EA,
                    ["CameraZoom"] = 0x47EC4C22,
                    ["CameraPoseNext"] = 0xF810FB35,
                    ["CameraPosePrev"] = 0x8D5BE9D1,
                    ["CameraExpressionNext"] = 0xCFA703D3,
                    ["CameraExpressionPrev"] = 0x07B6435D,
                    ["TithingIncreaseAmount"] = 0x24F37AB5,
                    ["TithingDecreaseAmount"] = 0xCEFF5C13,
                    ["BreakDoorLock"] = 0x77110B0A,
                    ["InterrogateQuestion"] = 0xA1AA2D8D,
                    ["InterrogateBeat"] = 0x6E1E0D62,
                    ["InterrogateKill"] = 0x81B2E311,
                    ["InterrogateRelease"] = 0x3C22EF0E,
                    ["CampBedInspect"] = 0xC67E13BB,
                    
                    ["MinigameBartenderRaiseGlass"] = 0xA13460F5,
                    ["MinigameBartenderRaiseBottle"] = 0xF0A25112,
                    ["MinigameBartenderPour"] = 0xCABC2460,
                    ["MinigameBartenderServe"] = 0xDC03B043,
                    
                    ["PhotoModePc"] = 0x35957F6C,
                    ["PhotoModeChangeCamera"] = 0x9F06B29C,
                    ["PhotoModeMoveLr"] = 0x4F136512,
                    ["PhotoModeMoveLeftOnly"] = 0x311353EB,
                    ["PhotoModeMoveRightOnly"] = 0x5357A7F5,
                    ["PhotoModeMoveUd"] = 0xEC001315,
                    ["PhotoModeMoveUpOnly"] = 0x315D57E6,
                    ["PhotoModeMoveDownOnly"] = 0x4EBCC409,
                    ["PhotoModeReset"] = 0xA209BD57,
                    ["PhotoModeLenseNext"] = 0xB138D899,
                    ["PhotoModeLensePrev"] = 0x06A057F8,
                    ["PhotoModeRotateLeft"] = 0x2EEA1D2A,
                    ["PhotoModeRotateRight"] = 0x96E70854,
                    ["PhotoModeToggleHud"] = 0x7F9055F5,
                    ["PhotoModeViewPhotos"] = 0xDCE96D67,
                    ["PhotoModeTakePhoto"] = 0xA190AAC7,
                    ["PhotoModeBack"] = 0x2F13EC9A,
                    ["PhotoModeSwitchMode"] = 0x8F32E2EB,
                    ["PhotoModeFilterIntensity"] = 0xFE6DD360,
                    ["PhotoModeFilterIntensityUp"] = 0x2286D46B,
                    ["PhotoModeFilterIntensityDown"] = 0xB341F407,
                    ["PhotoModeFocalLength"] = 0x886ABA4E,
                    ["PhotoModeFocalLengthUpOnly"] = 0xFAFBD66A,
                    ["PhotoModeFocalLengthDownOnly"] = 0x01EBFABD,
                    ["PhotoModeFilterNext"] = 0x699F8D08,
                    ["PhotoModeFilterPrev"] = 0x4F640885,
                    ["PhotoModeZoomIn"] = 0x5B843BC9,
                    ["PhotoModeZoomOut"] = 0x2354D2E6,
                    ["PhotoModeDof"] = 0x26B9AE6A,
                    ["PhotoModeDofUpOnly"] = 0x87B07940,
                    ["PhotoModeDofDownOnly"] = 0x047099F1,
                    ["PhotoModeExposureUp"] = 0xC64E2284,
                    ["PhotoModeExposureDown"] = 0xAD07A5A5,
                    ["PhotoModeExposureLock"] = 0x9DE08D71,
                    ["PhotoModeContrast"] = 0x483F707F,
                    ["PhotoModeContrastUpOnly"] = 0x5D2DD717,
                    ["PhotoModeContrastDownOnly"] = 0x30811620,
                    ["CraftingEat"] = 0xB99A9CAD,
                    ["CampSetupTent"] = 0x0B1BE2E8,
                    ["MinigameActionX"] = 0x1D927DF2,
                    ["DeprecatedAbove"] = 0xC1D24F92,
                    ["ScriptLeftAxisX"] = 0x1F8EEF84,
                    ["ScriptLeftAxisY"] = 0x5418D8AB,
                    ["ScriptRightAxisX"] = 0xA6B769E9,
                    ["ScriptRightAxisY"] = 0x27A5EBC0,
                    ["ScriptRup"] = 0x771D6E13,
                    ["ScriptRdown"] = 0x37933367,
                    ["ScriptRleft"] = 0xA4DB0458,
                    ["ScriptRright"] = 0x22A3B800,
                    ["ScriptLb"] = 0xE624C062,
                    ["ScriptRb"] = 0x91E9231C,
                    ["ScriptLt"] = 0x2B314A1E,
                    ["ScriptRt"] = 0x26E9CD17,
                    ["ScriptLs"] = 0xAADDC975,
                    ["ScriptRs"] = 0xD04E9FE2,
                    ["ScriptPadUp"] = 0x0DC15ADD,
                    ["ScriptPadDown"] = 0xB1DA5574,
                    ["ScriptPadLeft"] = 0x1AF81D9E,
                    ["ScriptPadRight"] = 0x82A9B758,
                    ["ScriptSelect"] = 0xC8722109,
                    ["ScriptedFlyUd"] = 0xAEB4B1DE,
                    ["ScriptedFlyLr"] = 0xF1111E4A,
                    ["ScriptedFlyZup"] = 0x639B9FC9,
                    ["ScriptedFlyZdown"] = 0x9C5E030C,
                    ["Count"] = 0x8EDFFB30
                }
                local hash = keys[string.upper(key)]
                if hash and not reads[hash] then reads[hash] = hash 
                    key = hash
                    
                    group = 0
                end 
                
            end 
            RegisterKeyMapping = function(name,desc,group,key)
                if type(group) == "number" and type(key) == "number" then 
                local KeyCheckLoop = LoopParty(0)
                KeyCheckLoop(function()
                    if string.sub(name,1,1) == "+" then 
                        if IsControlJustPressed(group,key) then 
                            
                            local_fns(name)()
                        end
                        if IsControlJustReleased(group,key) then 
                            local_fns("-"..string.sub(name,2))()
                        end
                    else 
                        if IsControlJustPressed(group,key) then 
                            local_fns(name)()
                            print(name,group,key)
                        end
                    end
                    
                end)
                end
            end 
        end 
        return RegisterKeyMapping(name,desc,group,key )
        
    end 
    exports("NBRegisterKeyMapping",NBRegisterKeyMapping)
else 
local RegisterEvents = {}
local idx = 1
AddEventHandler("NBRegCMDToResources:"..GetCurrentResourceName(),function(cbname,idx)
    if RegisterEvents[cbname] and RegisterEvents[cbname][idx] then RegisterEvents[cbname][idx]() end 
end) 
NBRegisterCommand = function(name,fn)
    local handle = {name,idx}
    if not RegisterEvents[name] then RegisterEvents[name] = {}   end 
    if not RegisterEvents[name][idx] then RegisterEvents[name][idx] = fn 
        TriggerEvent("NBRegCMDToResources:nb-keyevent",name,idx)
        idx = idx + 1
    end 
    return handle
end 
NBUnRegisterCommand = function(handle)
    RegisterEvents[handle[1]][handle[2]] = nil
    TriggerEvent("NBRegCMDToResourcesUndo:nb-keyevent",handle[1],handle[2])
end 
NBRegisterKeyMapping = function(...)
    return exports["nb-keyevent"]:NBRegisterKeyMapping(...)
end 


local e = {} setmetatable(e,{__call = function(self) return end})
local Flags = {
    [1] = "OnJustPressed",
    [2] = "OnJustReleased",
    [3] = "OnPressing"
}
local KeyGroupObjects = {}

local newkeyobject = function(groupid)
    local onfns = {
        [Flags[1]] = {},
        [Flags[2]] = {},
        [Flags[3]] = {},
    }
    return function (action,func)
        if action == "addonjustpressfunc" then
            table.insert(onfns[Flags[1]],func)
        elseif action == "addonholdfunc" then
            table.insert(onfns[Flags[3]],func)
        elseif action == "addonjustreleasedfunc" then
            table.insert(onfns[Flags[2]],func)
        elseif action == "removeonjustpressfunc" then
            for i=1,#onfns[Flags[1]] do
                
                if onfns[Flags[1]][i] == func then
                    table.remove(onfns[Flags[1]],i)
                    break
                end
            end
        elseif action == "removeonholdfunc" then
            for i=1,#onfns[Flags[3]] do
                if onfns[Flags[3]][i] == func then
                    table.remove(onfns[Flags[3]],i)
                    break
                end
            end
        elseif action == "removeonjustreleasedfunc" then
            for i=1,#onfns[Flags[2]] do
                if onfns[Flags[2]][i] == func then
                    table.remove(onfns[Flags[2]],i)
                    break
                end
            end
        
        elseif not action or action == "getonfns" then 
            local key = func
            return key and onfns[key] or onfns
        end
    end 
end 

local BeginKeyBindMethod = function(keygroup,key,description)
    local groupid = keygroup.."_"..key
    local obj = newkeyobject(groupid)
    
    local checkdelay = 250
    local checkduration = 50
    local dynamiclevel = 1
    local isholding = false 
    local ispressed = false
    local lastpressedtime = 0 
    local holdingloop = nil
    
    local self = {}
    self.addonjustpressed = function(func)
        obj("addonjustpressfunc",func)
    end
    self.addonhold = function(func)
        obj("addonholdfunc",func)
    end
    self.addonjustreleased = function(func)
        obj("addonjustreleasedfunc",func)
    end
    self.removeonjustpressed = function(func)
        obj("removeonjustpressfunc",func)
    end
    self.removeonhold = function(func)
        obj("removeonholdfunc",func)
    end
    self.removeonjustreleased = function(func)
        obj("removeonjustreleasedfunc",func)
    end
    self.getonfns = function()
        return obj("getonfns")
    end
    
    
    self.bindadd = function(regtype,func,duration,delay,dynamic)
        local action = nil
        if string.find(regtype:lower(),"justpress") then 
            action = Flags[1]
        elseif string.find(regtype:lower(),"release") then
            action = Flags[2]
        elseif string.len(regtype) > 0 then
            action = Flags[3]
            
            isholding = true 
            checkduration = duration or checkduration
            checkdelay = delay or checkdelay
            local dynamic = dynamic and type(dynamic) == "boolean" and 5 or dynamic
            if not holdingloop then holdingloop = LoopParty(checkduration) 
                holdingloop(function(duration)
                    
                    if holdingloop and isholding then
                        local diff = GetGameTimer() - lastpressedtime 
                        if ispressed  then 
                            if diff > checkdelay then 
                                local onpressingtasks = obj("getonfns")[Flags[3]]
                                local n = #onpressingtasks
                                if n == 0 then duration("kill") end 
                                
                                if dynamic then
                                    for i=1,n do
                                        onpressingtasks[i](dynamiclevel)
                                        
                                    end
                                    if dynamiclevel < dynamic then
                                        if diff > checkdelay * dynamiclevel then
                                            dynamiclevel = dynamiclevel + 1
                                        end
                                    end
                                    duration("set",checkduration/dynamiclevel)
                                else 
                                    for i=1,n do
                                        onpressingtasks[i]()
                                        
                                    end
                                end
                            end 
                        else 
                            dynamiclevel = 1
                            duration("set",checkdelay)
                        end 
                    else 
                        
                        isholding = false 
                        checkduration = 50
                        checkdelay = 250
                        dynamiclevel = 1
                        if holdingloop then 
                            holdingloop:delete()
                            holdingloop = nil
                        end 

                    end
                end)
            end
        end 
        if action == Flags[1] then
            self.addonjustpressed(func)
        elseif action == Flags[2] then
            self.addonjustreleased(func)
        elseif action == Flags[3] then
            self.addonhold(func)
        end
        table.insert(self.handles,{action,func})
        return {action,func}
    end
    self.bindremove = function(regtype,func)
        local action = nil
        if string.find(regtype:lower(),"justpress") then 
            action = Flags[1]
        elseif string.find(regtype:lower(),"release") then
            action = Flags[2]
        elseif string.len(regtype) > 0 then
            action = Flags[3]
            if #obj("getonfns")[Flags[3]] == 0 then 
                if isholding then isholding = false end
            end 
        end 
        if action == Flags[1] then
            self.removeonjustpressed(func)
        elseif action == Flags[2] then
            self.removeonjustreleased(func)
        elseif action == Flags[3] then
            self.removeonhold(func)
        end
        
    end
    self.handles = {}
    self.bindremoveall = function()
        for i,v in pairs(self.handles) do 
            self.bindremove(table.unpack(v))
        end 
    end 
    self.bindremovespec = function(data)
        local action = data[1]
        local func = data[2]
        self.bindremove(action,func)
    end 
    self.bindend = function()
        local fns = obj("getonfns")

        local reg = function(name,action)
            return NBRegisterCommand(name, function()
                local tempaction = action
                if fns and fns[tempaction] then 
                  for i=1,#fns[tempaction] do 
                       fns[tempaction][i]()
                  end 
                end 
                if tempaction == Flags[1] and isholding then 
                    ispressed = true 
                    lastpressedtime = GetGameTimer()
                elseif tempaction == Flags[2] then 
                    ispressed = false
                    lastpressedtime = 0 
                end 
            end, false, function()
                for i,v in pairs(fns) do 
                    self.bindremove(i,v)
                end 
            end)
        end 
        local result1,result2
        if (fns[Flags[2]] or e)[1] or (fns[Flags[3]] or e)[1] then
            local name = "+" .. groupid
            result1 = reg(name,Flags[1])
            NBRegisterKeyMapping(name, description or '', keygroup, key)
            result2 = reg(name:gsub("+","-"),Flags[2])
        else 
            local name = groupid
            result1 = reg(name,Flags[1])
            NBRegisterKeyMapping(name, description or '', keygroup, key)
        end
        --for cmd handle 
        return result1,result2
    end 
    KeyGroupObjects[groupid] = self
    return self
end


local unpack = table.unpack 

KeyEvent = function(keygroup, key, cb)
    local game = GetGameName() 
    
    local desc = tostring(keygroup):lower()..":"..tostring(key):lower()
    local groupid = keygroup.."_"..key
    
    local key = KeyGroupObjects[groupid] or BeginKeyBindMethod(keygroup,key,desc)
    local inputs = {}
    local actions = {}
    local inserter = function(type,...) 
        if not inputs[type] then inputs[type] = {} end
        table.insert(inputs[type],{...})
    end
    if cb then cb(inserter) end
    local found = false 
    for i,v in pairs(inputs) do 
        if string.find(i:lower(),"justpress") then 
            
        elseif string.find(i:lower(),"release") then
            
        elseif string.len(i) > 0 then
            found = true
        end 
    end 
    if found then 
        inserter("onreleased",function() end)
    end 
    for k,v in pairs(inputs) do
        for i=1,#v do
            key.bindadd(k,unpack(v[i]))
            table.insert(actions,{k,v[i][1]})
        end
    end
    
    return {keyhandle = key,commandhandle = {key.bindend()},actionhandle = actions}
end
RemoveKeyEvent = function(datahandle)
    local keyhandle = datahandle.keyhandle
    local commandhandle = datahandle.commandhandle
    local actionhandle = datahandle.actionhandle
    for i=1,#commandhandle do 
        NBUnRegisterCommand(commandhandle[i])
    end 
    for i=1,#actionhandle do 
        keyhandle.bindremovespec(actionhandle[i])
    end 
    
end 
end 
