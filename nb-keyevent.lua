--Credit: negbook

local _M_ = {}
do 
local Tasksync = _M_
local Loops = {}
local e = {}
local totalthreads = 0
setmetatable(Loops,{__newindex=function(t,k,v) rawset(t,tostring(k),v) end,__index=function(t,k) return rawget(t,tostring(k)) end})
setmetatable(e,{__call=function()end})

local GetDurationAndIndex = function(obj,cb) for duration,names in pairs(Loops) do for i=1,#names do local v = names[i] if v == obj then local duration_tonumber = tonumber(duration) if cb then cb(duration_tonumber,i) end return duration_tonumber,i end end end end
local remove_manual = function(duration,index) local indexs = Loops[duration] table.remove(indexs,index) if #indexs == 0 then Loops[duration] = nil end end 
local remove = function(obj,cb) GetDurationAndIndex(obj,function(duration,index) remove_manual(duration,index) if cb then cb() end end) end 
local init = function(duration,obj,cb) if Loops[duration] == nil then Loops[duration] = {}; if cb then cb() end end table.insert(Loops[duration],obj) end 
local newloopobject = function(duration,onaction,ondelete)
    local onaction = onaction 
    local ondelete = ondelete 
    local duration = duration 
    local releaseobject = nil 
    local ref = nil 
    if onaction and ondelete then 
        return function (action,value)
            if not action or action == "onaction" then 
                return onaction(ref)
            elseif action == "ondelete" then 
                return ondelete()
            elseif action == "setduration" then 
                duration = value 
            elseif action == "getduration" then 
                return duration 
            elseif action == "getfn" then 
                return onaction 
            elseif action == "setref" then 
                ref = value
            elseif action == "setreleasetimerobject" then 
                releaseobject = value 
            elseif action == "getreleasetimerobject" then 
                return releaseobject
            elseif action == "set" then 
                duration = value 
            elseif action == "get" then 
                return duration 
            end 
        end 
    elseif onaction and not ondelete then 
        return function (action,value)
            if not action or action == "onaction" then 
                return onaction(ref)
            elseif action == "setduration" then 
                duration = value 
            elseif action == "getduration" then 
                return duration 
            elseif action == "getfn" then 
                return onaction 
            elseif action == "setref" then 
                ref = value
            elseif action == "setreleasetimerobject" then 
                releaseobject = value 
            elseif action == "getreleasetimerobject" then 
                return releaseobject
            elseif action == "set" then 
                duration = value 
            elseif action == "get" then 
                return duration 
            end 
        end 
    end 
end 


local updateloop = function(obj,new_duration,cb)
    remove(obj,function()
        init(new_duration,obj,function()
            Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup(new_duration,cb)
        end)
    end)
end 

local ref = function (default,obj)
    return function(action,v) 
        if action == 'get' then 
            return obj("getduration") 
        elseif action == 'set' then 
            return Tasksync.transferobject(obj,v)  
        elseif action == 'kill' or action == 'break' then 
            Tasksync.deleteloop(obj)
        end 
    end 
end 

Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup = function(duration,init)
    local init = init   
    CreateThread(function()
        totalthreads = totalthreads + 1
        local loop = Loops[duration]
        
        if init then init() init = nil end
        repeat 
            local Objects = (loop or e)
            local n = #Objects
            for i=1,n do 
                (Objects[i] or e)()
            end 
            Wait(duration)
            
        until n == 0 
        --print("Deleted thread",duration)
        totalthreads = totalthreads - 1
        return 
    end)
end     

Tasksync.__createNewThreadForNewDurationLoopFunctionsGroupDebug = function(duration,init)
    local init = init   
    CreateThread(function()
        local loop = Loops[duration]
        if init then init() init = nil end
        repeat 
            local Objects = (loop or e)
            local n = #Objects
            for i=1,n do 
                (Objects[i] or e)()
            end 
        until n == 0 
        --print("Deleted thread",duration)
        return 
    end)
end     

Tasksync.addloop = function(duration,fn,fnondelete,isreplace)
    local obj = newloopobject(duration,fn,fnondelete)
    obj("setref",ref(duration,obj))
    local indexs = Loops[duration]
    if isreplace and Loops[duration] then 
        for i=1,#indexs do 
            if indexs[i]("getfn") == fn then 
                remove(indexs[i])
            end 
        end 
    end 
    init(duration,obj,function()
        if duration < 0 then Tasksync.__createNewThreadForNewDurationLoopFunctionsGroupDebug(duration) else 
            Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup(duration)
        end 
    end)
    return obj
end 
Tasksync.insertloop = Tasksync.addloop

Tasksync.deleteloop = function(obj,cb)
    remove(obj,function()
        obj("ondelete")
        if cb then cb() end 
    end)
end 
Tasksync.removeloop = Tasksync.deleteloop

Tasksync.transferobject = function(obj,duration)
    local old_duration = obj("getduration")
    if duration ~= old_duration then 
        updateloop(obj,duration,function()
            obj("setduration",duration)
            Wait(old_duration)
        end)
    end 
end 
 
local newreleasetimer = function(obj,timer,cb)
    local releasetimer = timer   + GetGameTimer()
    local obj = obj 
    local tempcheck = Tasksync.PepareLoop(250)  
    tempcheck(function(duration)
        if GetGameTimer() > releasetimer then 
            tempcheck:delete()
            Tasksync.deleteloop(obj,cb)
        end 
    end)
    return function(action,value)
        if action == "get" then 
            return releasetimer
        elseif action == "set" then 
            releasetimer = timer + GetGameTimer()
        end 
    end 
end  


Tasksync.setreleasetimer = function(obj,releasetimer,cb)
    if not obj("getreleasetimerobject") then 
        obj("setreleasetimerobject",newreleasetimer(obj,releasetimer,function()
            obj("setreleasetimerobject",nil)
            if cb then cb() end 
        end))
    else 
        obj("getreleasetimerobject")("set",releasetimer)
    end 

end 

Tasksync.PepareLoop = function(duration,releasecb)
    local self = {}
    local obj = nil 
    self.add = function(self,_fn,_fnondelete)
        local ontaskdelete = nil
        if not _fnondelete then 
            if releasecb then 
                ontaskdelete = function()
                    releasecb(obj)
                end 
            end
        else 
            if releasecb then 
                ontaskdelete = function()
                    releasecb(obj)
                    _fnondelete(obj)
                end 
            else 
                ontaskdelete = function()
                    _fnondelete(obj)
                end 
            end
        end
        obj = Tasksync.addloop(duration,_fn,ontaskdelete)
        return obj
    end
    self.delete = function(self,duration,cb)
        local cb = type(duration) ~= "number" and duration or cb 
        local duration = type(duration) == "number" and duration or nil
    
        if obj then 
            if duration then 
                Tasksync.setreleasetimer(obj,duration,cb) 
            else 
                Tasksync.deleteloop(obj,cb) 
            end 
        end
    end
    self.release = self.delete
    self.remove = self.delete
    self.kill = self.delete
    self.set = function(self,newduration)
        if obj then Tasksync.transferobject(obj,newduration) end 
    end
    self.get = function(self)
        if obj then return obj("getduration") end 
    end

    return setmetatable(self,{__call = function(self,...)
        return self:add(...)
    end,__tostring = function()
        return "This duration:"..self.get().."Total loop threads:"..totalthreads
    end})
end
end 


PepareLoop = PepareLoop
if not PepareLoop then 
    local try = LoadResourceFile("nb-libs","shared/loop.lua") or LoadResourceFile("nb-loop","nb-loop.lua")
    PepareLoop = PepareLoop or (try and load(try.." return PepareLoop(...)")) or _M_.PepareLoop
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
    NBRegisterKeyMapping = function(name,desc,group,key ) --name,desc,group,key 
        local game = GetGameName()
        if game == "redm" or type(group) == "number" then 
            if type(key) == "string" then 
                local hashes = {}
                table.insert(hashes,`INPUT_NEXT_CAMERA`)
                table.insert(hashes,`INPUT_LOOK_LR`)
                table.insert(hashes,`INPUT_LOOK_UD`)
                table.insert(hashes,`INPUT_LOOK_UP_ONLY`)
                table.insert(hashes,`INPUT_LOOK_DOWN_ONLY`)
                table.insert(hashes,`INPUT_LOOK_LEFT_ONLY`)
                table.insert(hashes,`INPUT_LOOK_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_CINEMATIC_SLOWMO`)
                table.insert(hashes,`INPUT_SCRIPTED_FLY_UD`)
                table.insert(hashes,`INPUT_SCRIPTED_FLY_LR`)
                table.insert(hashes,`INPUT_SCRIPTED_FLY_ZUP`)
                table.insert(hashes,`INPUT_SCRIPTED_FLY_ZDOWN`)
                table.insert(hashes,`INPUT_WEAPON_WHEEL_UD`)
                table.insert(hashes,`INPUT_WEAPON_WHEEL_LR`)
                table.insert(hashes,`INPUT_WEAPON_WHEEL_NEXT`)
                table.insert(hashes,`INPUT_WEAPON_WHEEL_PREV`)
                table.insert(hashes,`INPUT_SELECT_NEXT_WEAPON`)
                table.insert(hashes,`INPUT_SELECT_PREV_WEAPON`)
                table.insert(hashes,`INPUT_SKIP_CUTSCENE`)
                table.insert(hashes,`INPUT_CHARACTER_WHEEL`)
                table.insert(hashes,`INPUT_MULTIPLAYER_INFO`)
                table.insert(hashes,`INPUT_SPRINT`)
                table.insert(hashes,`INPUT_JUMP`)
                table.insert(hashes,`INPUT_ENTER`)
                table.insert(hashes,`INPUT_ATTACK`)
                table.insert(hashes,`INPUT_AIM`)
                table.insert(hashes,`INPUT_LOOK_BEHIND`)
                table.insert(hashes,`INPUT_PHONE`)
                table.insert(hashes,`INPUT_SPECIAL_ABILITY`)
                table.insert(hashes,`INPUT_SPECIAL_ABILITY_SECONDARY`)
                table.insert(hashes,`INPUT_MOVE_LR`)
                table.insert(hashes,`INPUT_MOVE_UD`)
                table.insert(hashes,`INPUT_MOVE_UP_ONLY`)
                table.insert(hashes,`INPUT_MOVE_DOWN_ONLY`)
                table.insert(hashes,`INPUT_MOVE_LEFT_ONLY`)
                table.insert(hashes,`INPUT_MOVE_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_DUCK`)
                table.insert(hashes,`INPUT_SELECT_WEAPON`)
                table.insert(hashes,`INPUT_PICKUP`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_IN_ONLY`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_OUT_ONLY`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_IN_SECONDARY`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_OUT_SECONDARY`)
                table.insert(hashes,`INPUT_COVER`)
                table.insert(hashes,`INPUT_RELOAD`)
                table.insert(hashes,`INPUT_TALK`)
                table.insert(hashes,`INPUT_DETONATE`)
                table.insert(hashes,`INPUT_HUD_SPECIAL`)
                table.insert(hashes,`INPUT_ARREST`)
                table.insert(hashes,`INPUT_ACCURATE_AIM`)
                table.insert(hashes,`INPUT_CONTEXT`)
                table.insert(hashes,`INPUT_CONTEXT_SECONDARY`)
                table.insert(hashes,`INPUT_WEAPON_SPECIAL`)
                table.insert(hashes,`INPUT_WEAPON_SPECIAL_TWO`)
                table.insert(hashes,`INPUT_DIVE`)
                table.insert(hashes,`INPUT_DROP_WEAPON`)
                table.insert(hashes,`INPUT_DROP_AMMO`)
                table.insert(hashes,`INPUT_THROW_GRENADE`)
                table.insert(hashes,`INPUT_VEH_MOVE_LR`)
                table.insert(hashes,`INPUT_VEH_MOVE_UD`)
                table.insert(hashes,`INPUT_VEH_MOVE_UP_ONLY`)
                table.insert(hashes,`INPUT_VEH_MOVE_DOWN_ONLY`)
                table.insert(hashes,`INPUT_VEH_MOVE_LEFT_ONLY`)
                table.insert(hashes,`INPUT_VEH_MOVE_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_VEH_SPECIAL`)
                table.insert(hashes,`INPUT_VEH_GUN_LR`)
                table.insert(hashes,`INPUT_VEH_GUN_UD`)
                table.insert(hashes,`INPUT_VEH_AIM`)
                table.insert(hashes,`INPUT_VEH_ATTACK`)
                table.insert(hashes,`INPUT_VEH_ATTACK2`)
                table.insert(hashes,`INPUT_VEH_ACCELERATE`)
                table.insert(hashes,`INPUT_VEH_BRAKE`)
                table.insert(hashes,`INPUT_VEH_DUCK`)
                table.insert(hashes,`INPUT_VEH_HEADLIGHT`)
                table.insert(hashes,`INPUT_VEH_EXIT`)
                table.insert(hashes,`INPUT_VEH_HANDBRAKE`)
                table.insert(hashes,`INPUT_VEH_HOTWIRE_LEFT`)
                table.insert(hashes,`INPUT_VEH_HOTWIRE_RIGHT`)
                table.insert(hashes,`INPUT_VEH_LOOK_BEHIND`)
                table.insert(hashes,`INPUT_VEH_CIN_CAM`)
                table.insert(hashes,`INPUT_VEH_NEXT_RADIO`)
                table.insert(hashes,`INPUT_VEH_PREV_RADIO`)
                table.insert(hashes,`INPUT_VEH_NEXT_RADIO_TRACK`)
                table.insert(hashes,`INPUT_VEH_PREV_RADIO_TRACK`)
                table.insert(hashes,`INPUT_VEH_RADIO_WHEEL`)
                table.insert(hashes,`INPUT_VEH_HORN`)
                table.insert(hashes,`INPUT_VEH_FLY_THROTTLE_UP`)
                table.insert(hashes,`INPUT_VEH_FLY_THROTTLE_DOWN`)
                table.insert(hashes,`INPUT_VEH_FLY_YAW_LEFT`)
                table.insert(hashes,`INPUT_VEH_FLY_YAW_RIGHT`)
                table.insert(hashes,`INPUT_VEH_PASSENGER_AIM`)
                table.insert(hashes,`INPUT_VEH_PASSENGER_ATTACK`)
                table.insert(hashes,`INPUT_VEH_SPECIAL_ABILITY_FRANKLIN`)
                table.insert(hashes,`INPUT_VEH_STUNT_UD`)
                table.insert(hashes,`INPUT_VEH_CINEMATIC_UD`)
                table.insert(hashes,`INPUT_VEH_CINEMATIC_UP_ONLY`)
                table.insert(hashes,`INPUT_VEH_CINEMATIC_DOWN_ONLY`)
                table.insert(hashes,`INPUT_VEH_CINEMATIC_LR`)
                table.insert(hashes,`INPUT_VEH_SELECT_NEXT_WEAPON`)
                table.insert(hashes,`INPUT_VEH_SELECT_PREV_WEAPON`)
                table.insert(hashes,`INPUT_VEH_ROOF`)
                table.insert(hashes,`INPUT_VEH_JUMP`)
                table.insert(hashes,`INPUT_VEH_GRAPPLING_HOOK`)
                table.insert(hashes,`INPUT_VEH_SHUFFLE`)
                table.insert(hashes,`INPUT_VEH_DROP_PROJECTILE`)
                table.insert(hashes,`INPUT_VEH_MOUSE_CONTROL_OVERRIDE`)
                table.insert(hashes,`INPUT_VEH_FLY_ROLL_LR`)
                table.insert(hashes,`INPUT_VEH_FLY_ROLL_LEFT_ONLY`)
                table.insert(hashes,`INPUT_VEH_FLY_ROLL_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_VEH_FLY_PITCH_UD`)
                table.insert(hashes,`INPUT_VEH_FLY_PITCH_UP_ONLY`)
                table.insert(hashes,`INPUT_VEH_FLY_PITCH_DOWN_ONLY`)
                table.insert(hashes,`INPUT_VEH_FLY_UNDERCARRIAGE`)
                table.insert(hashes,`INPUT_VEH_FLY_ATTACK`)
                table.insert(hashes,`INPUT_VEH_FLY_SELECT_NEXT_WEAPON`)
                table.insert(hashes,`INPUT_VEH_FLY_SELECT_PREV_WEAPON`)
                table.insert(hashes,`INPUT_VEH_FLY_SELECT_TARGET_LEFT`)
                table.insert(hashes,`INPUT_VEH_FLY_SELECT_TARGET_RIGHT`)
                table.insert(hashes,`INPUT_VEH_FLY_VERTICAL_FLIGHT_MODE`)
                table.insert(hashes,`INPUT_VEH_FLY_DUCK`)
                table.insert(hashes,`INPUT_VEH_FLY_ATTACK_CAMERA`)
                table.insert(hashes,`INPUT_VEH_FLY_MOUSE_CONTROL_OVERRIDE`)
                table.insert(hashes,`INPUT_VEH_SUB_TURN_LR`)
                table.insert(hashes,`INPUT_VEH_SUB_TURN_LEFT_ONLY`)
                table.insert(hashes,`INPUT_VEH_SUB_TURN_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_VEH_SUB_PITCH_UD`)
                table.insert(hashes,`INPUT_VEH_SUB_PITCH_UP_ONLY`)
                table.insert(hashes,`INPUT_VEH_SUB_PITCH_DOWN_ONLY`)
                table.insert(hashes,`INPUT_VEH_SUB_THROTTLE_UP`)
                table.insert(hashes,`INPUT_VEH_SUB_THROTTLE_DOWN`)
                table.insert(hashes,`INPUT_VEH_SUB_ASCEND`)
                table.insert(hashes,`INPUT_VEH_SUB_DESCEND`)
                table.insert(hashes,`INPUT_VEH_SUB_TURN_HARD_LEFT`)
                table.insert(hashes,`INPUT_VEH_SUB_TURN_HARD_RIGHT`)
                table.insert(hashes,`INPUT_VEH_SUB_MOUSE_CONTROL_OVERRIDE`)
                table.insert(hashes,`INPUT_VEH_PUSHBIKE_PEDAL`)
                table.insert(hashes,`INPUT_VEH_PUSHBIKE_SPRINT`)
                table.insert(hashes,`INPUT_VEH_PUSHBIKE_FRONT_BRAKE`)
                table.insert(hashes,`INPUT_VEH_PUSHBIKE_REAR_BRAKE`)
                table.insert(hashes,`INPUT_MELEE_ATTACK_LIGHT`)
                table.insert(hashes,`INPUT_MELEE_ATTACK_HEAVY`)
                table.insert(hashes,`INPUT_MELEE_ATTACK_ALTERNATE`)
                table.insert(hashes,`INPUT_MELEE_BLOCK`)
                table.insert(hashes,`INPUT_PARACHUTE_DEPLOY`)
                table.insert(hashes,`INPUT_PARACHUTE_DETACH`)
                table.insert(hashes,`INPUT_PARACHUTE_TURN_LR`)
                table.insert(hashes,`INPUT_PARACHUTE_TURN_LEFT_ONLY`)
                table.insert(hashes,`INPUT_PARACHUTE_TURN_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_PARACHUTE_PITCH_UD`)
                table.insert(hashes,`INPUT_PARACHUTE_PITCH_UP_ONLY`)
                table.insert(hashes,`INPUT_PARACHUTE_PITCH_DOWN_ONLY`)
                table.insert(hashes,`INPUT_PARACHUTE_BRAKE_LEFT`)
                table.insert(hashes,`INPUT_PARACHUTE_BRAKE_RIGHT`)
                table.insert(hashes,`INPUT_PARACHUTE_SMOKE`)
                table.insert(hashes,`INPUT_PARACHUTE_PRECISION_LANDING`)
                table.insert(hashes,`INPUT_MAP`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_UNARMED`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_MELEE`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_HANDGUN`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_SHOTGUN`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_SMG`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_AUTO_RIFLE`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_SNIPER`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_HEAVY`)
                table.insert(hashes,`INPUT_SELECT_WEAPON_SPECIAL`)
                table.insert(hashes,`INPUT_SELECT_CHARACTER_MICHAEL`)
                table.insert(hashes,`INPUT_SELECT_CHARACTER_FRANKLIN`)
                table.insert(hashes,`INPUT_SELECT_CHARACTER_TREVOR`)
                table.insert(hashes,`INPUT_SELECT_CHARACTER_MULTIPLAYER`)
                table.insert(hashes,`INPUT_SAVE_REPLAY_CLIP`)
                table.insert(hashes,`INPUT_SPECIAL_ABILITY_PC`)
                table.insert(hashes,`INPUT_CELLPHONE_UP`)
                table.insert(hashes,`INPUT_CELLPHONE_DOWN`)
                table.insert(hashes,`INPUT_CELLPHONE_LEFT`)
                table.insert(hashes,`INPUT_CELLPHONE_RIGHT`)
                table.insert(hashes,`INPUT_CELLPHONE_SELECT`)
                table.insert(hashes,`INPUT_CELLPHONE_CANCEL`)
                table.insert(hashes,`INPUT_CELLPHONE_OPTION`)
                table.insert(hashes,`INPUT_CELLPHONE_EXTRA_OPTION`)
                table.insert(hashes,`INPUT_CELLPHONE_SCROLL_FORWARD`)
                table.insert(hashes,`INPUT_CELLPHONE_SCROLL_BACKWARD`)
                table.insert(hashes,`INPUT_CELLPHONE_CAMERA_FOCUS_LOCK`)
                table.insert(hashes,`INPUT_CELLPHONE_CAMERA_GRID`)
                table.insert(hashes,`INPUT_CELLPHONE_CAMERA_SELFIE`)
                table.insert(hashes,`INPUT_CELLPHONE_CAMERA_DOF`)
                table.insert(hashes,`INPUT_CELLPHONE_CAMERA_EXPRESSION`)
                table.insert(hashes,`INPUT_FRONTEND_DOWN`)
                table.insert(hashes,`INPUT_FRONTEND_UP`)
                table.insert(hashes,`INPUT_FRONTEND_LEFT`)
                table.insert(hashes,`INPUT_FRONTEND_RIGHT`)
                table.insert(hashes,`INPUT_FRONTEND_RDOWN`)
                table.insert(hashes,`INPUT_FRONTEND_RUP`)
                table.insert(hashes,`INPUT_FRONTEND_RLEFT`)
                table.insert(hashes,`INPUT_FRONTEND_RRIGHT`)
                table.insert(hashes,`INPUT_FRONTEND_AXIS_X`)
                table.insert(hashes,`INPUT_FRONTEND_AXIS_Y`)
                table.insert(hashes,`INPUT_FRONTEND_RIGHT_AXIS_X`)
                table.insert(hashes,`INPUT_FRONTEND_RIGHT_AXIS_Y`)
                table.insert(hashes,`INPUT_FRONTEND_PAUSE`)
                table.insert(hashes,`INPUT_FRONTEND_PAUSE_ALTERNATE`)
                table.insert(hashes,`INPUT_FRONTEND_ACCEPT`)
                table.insert(hashes,`INPUT_FRONTEND_CANCEL`)
                table.insert(hashes,`INPUT_FRONTEND_X`)
                table.insert(hashes,`INPUT_FRONTEND_Y`)
                table.insert(hashes,`INPUT_FRONTEND_LB`)
                table.insert(hashes,`INPUT_FRONTEND_RB`)
                table.insert(hashes,`INPUT_FRONTEND_LT`)
                table.insert(hashes,`INPUT_FRONTEND_RT`)
                table.insert(hashes,`INPUT_FRONTEND_LS`)
                table.insert(hashes,`INPUT_FRONTEND_RS`)
                table.insert(hashes,`INPUT_FRONTEND_LEADERBOARD`)
                table.insert(hashes,`INPUT_FRONTEND_SOCIAL_CLUB`)
                table.insert(hashes,`INPUT_FRONTEND_SOCIAL_CLUB_SECONDARY`)
                table.insert(hashes,`INPUT_FRONTEND_DELETE`)
                table.insert(hashes,`INPUT_FRONTEND_ENDSCREEN_ACCEPT`)
                table.insert(hashes,`INPUT_FRONTEND_ENDSCREEN_EXPAND`)
                table.insert(hashes,`INPUT_FRONTEND_SELECT`)
                table.insert(hashes,`INPUT_SCRIPT_LEFT_AXIS_X`)
                table.insert(hashes,`INPUT_SCRIPT_LEFT_AXIS_Y`)
                table.insert(hashes,`INPUT_SCRIPT_RIGHT_AXIS_X`)
                table.insert(hashes,`INPUT_SCRIPT_RIGHT_AXIS_Y`)
                table.insert(hashes,`INPUT_SCRIPT_RUP`)
                table.insert(hashes,`INPUT_SCRIPT_RDOWN`)
                table.insert(hashes,`INPUT_SCRIPT_RLEFT`)
                table.insert(hashes,`INPUT_SCRIPT_RRIGHT`)
                table.insert(hashes,`INPUT_SCRIPT_LB`)
                table.insert(hashes,`INPUT_SCRIPT_RB`)
                table.insert(hashes,`INPUT_SCRIPT_LT`)
                table.insert(hashes,`INPUT_SCRIPT_RT`)
                table.insert(hashes,`INPUT_SCRIPT_LS`)
                table.insert(hashes,`INPUT_SCRIPT_RS`)
                table.insert(hashes,`INPUT_SCRIPT_PAD_UP`)
                table.insert(hashes,`INPUT_SCRIPT_PAD_DOWN`)
                table.insert(hashes,`INPUT_SCRIPT_PAD_LEFT`)
                table.insert(hashes,`INPUT_SCRIPT_PAD_RIGHT`)
                table.insert(hashes,`INPUT_SCRIPT_SELECT`)
                table.insert(hashes,`INPUT_CURSOR_ACCEPT`)
                table.insert(hashes,`INPUT_CURSOR_CANCEL`)
                table.insert(hashes,`INPUT_CURSOR_X`)
                table.insert(hashes,`INPUT_CURSOR_Y`)
                table.insert(hashes,`INPUT_CURSOR_SCROLL_UP`)
                table.insert(hashes,`INPUT_CURSOR_SCROLL_DOWN`)
                table.insert(hashes,`INPUT_ENTER_CHEAT_CODE`)
                table.insert(hashes,`INPUT_INTERACTION_MENU`)
                table.insert(hashes,`INPUT_MP_TEXT_CHAT_ALL`)
                table.insert(hashes,`INPUT_MP_TEXT_CHAT_TEAM`)
                table.insert(hashes,`INPUT_MP_TEXT_CHAT_FRIENDS`)
                table.insert(hashes,`INPUT_MP_TEXT_CHAT_CREW`)
                table.insert(hashes,`INPUT_PUSH_TO_TALK`)
                table.insert(hashes,`INPUT_CREATOR_LS`)
                table.insert(hashes,`INPUT_CREATOR_RS`)
                table.insert(hashes,`INPUT_CREATOR_LT`)
                table.insert(hashes,`INPUT_CREATOR_RT`)
                table.insert(hashes,`INPUT_CREATOR_MENU_TOGGLE`)
                table.insert(hashes,`INPUT_CREATOR_ACCEPT`)
                table.insert(hashes,`INPUT_CREATOR_DELETE`)
                table.insert(hashes,`INPUT_ATTACK2`)
                table.insert(hashes,`INPUT_RAPPEL_JUMP`)
                table.insert(hashes,`INPUT_RAPPEL_LONG_JUMP`)
                table.insert(hashes,`INPUT_RAPPEL_SMASH_WINDOW`)
                table.insert(hashes,`INPUT_PREV_WEAPON`)
                table.insert(hashes,`INPUT_NEXT_WEAPON`)
                table.insert(hashes,`INPUT_MELEE_ATTACK1`)
                table.insert(hashes,`INPUT_MELEE_ATTACK2`)
                table.insert(hashes,`INPUT_WHISTLE`)
                table.insert(hashes,`INPUT_MOVE_LEFT`)
                table.insert(hashes,`INPUT_MOVE_RIGHT`)
                table.insert(hashes,`INPUT_MOVE_UP`)
                table.insert(hashes,`INPUT_MOVE_DOWN`)
                table.insert(hashes,`INPUT_LOOK_LEFT`)
                table.insert(hashes,`INPUT_LOOK_RIGHT`)
                table.insert(hashes,`INPUT_LOOK_UP`)
                table.insert(hashes,`INPUT_LOOK_DOWN`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_IN`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_OUT`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_IN_ALTERNATE`)
                table.insert(hashes,`INPUT_SNIPER_ZOOM_OUT_ALTERNATE`)
                table.insert(hashes,`INPUT_VEH_MOVE_LEFT`)
                table.insert(hashes,`INPUT_VEH_MOVE_RIGHT`)
                table.insert(hashes,`INPUT_VEH_MOVE_UP`)
                table.insert(hashes,`INPUT_VEH_MOVE_DOWN`)
                table.insert(hashes,`INPUT_VEH_GUN_LEFT`)
                table.insert(hashes,`INPUT_VEH_GUN_RIGHT`)
                table.insert(hashes,`INPUT_VEH_GUN_UP`)
                table.insert(hashes,`INPUT_VEH_GUN_DOWN`)
                table.insert(hashes,`INPUT_VEH_LOOK_LEFT`)
                table.insert(hashes,`INPUT_VEH_LOOK_RIGHT`)
                table.insert(hashes,`INPUT_REPLAY_START_STOP_RECORDING`)
                table.insert(hashes,`INPUT_REPLAY_START_STOP_RECORDING_SECONDARY`)
                table.insert(hashes,`INPUT_SCALED_LOOK_LR`)
                table.insert(hashes,`INPUT_SCALED_LOOK_UD`)
                table.insert(hashes,`INPUT_SCALED_LOOK_UP_ONLY`)
                table.insert(hashes,`INPUT_SCALED_LOOK_DOWN_ONLY`)
                table.insert(hashes,`INPUT_SCALED_LOOK_LEFT_ONLY`)
                table.insert(hashes,`INPUT_SCALED_LOOK_RIGHT_ONLY`)
                table.insert(hashes,`INPUT_REPLAY_MARKER_DELETE`)
                table.insert(hashes,`INPUT_REPLAY_CLIP_DELETE`)
                table.insert(hashes,`INPUT_REPLAY_PAUSE`)
                table.insert(hashes,`INPUT_REPLAY_REWIND`)
                table.insert(hashes,`INPUT_REPLAY_FFWD`)
                table.insert(hashes,`INPUT_REPLAY_NEWMARKER`)
                table.insert(hashes,`INPUT_REPLAY_RECORD`)
                table.insert(hashes,`INPUT_REPLAY_SCREENSHOT`)
                table.insert(hashes,`INPUT_REPLAY_HIDEHUD`)
                table.insert(hashes,`INPUT_REPLAY_STARTPOINT`)
                table.insert(hashes,`INPUT_REPLAY_ENDPOINT`)
                table.insert(hashes,`INPUT_REPLAY_ADVANCE`)
                table.insert(hashes,`INPUT_REPLAY_BACK`)
                table.insert(hashes,`INPUT_REPLAY_TOOLS`)
                table.insert(hashes,`INPUT_REPLAY_RESTART`)
                table.insert(hashes,`INPUT_REPLAY_SHOWHOTKEY`)
                table.insert(hashes,`INPUT_REPLAY_CYCLEMARKERLEFT`)
                table.insert(hashes,`INPUT_REPLAY_CYCLEMARKERRIGHT`)
                table.insert(hashes,`INPUT_REPLAY_FOVINCREASE`)
                table.insert(hashes,`INPUT_REPLAY_FOVDECREASE`)
                table.insert(hashes,`INPUT_REPLAY_CAMERAUP`)
                table.insert(hashes,`INPUT_REPLAY_CAMERADOWN`)
                table.insert(hashes,`INPUT_REPLAY_SAVE`)
                table.insert(hashes,`INPUT_REPLAY_TOGGLETIME`)
                table.insert(hashes,`INPUT_REPLAY_TOGGLETIPS`)
                table.insert(hashes,`INPUT_REPLAY_PREVIEW`)
                table.insert(hashes,`INPUT_REPLAY_TOGGLE_TIMELINE`)
                table.insert(hashes,`INPUT_REPLAY_TIMELINE_PICKUP_CLIP`)
                table.insert(hashes,`INPUT_REPLAY_TIMELINE_DUPLICATE_CLIP`)
                table.insert(hashes,`INPUT_REPLAY_TIMELINE_PLACE_CLIP`)
                table.insert(hashes,`INPUT_REPLAY_CTRL`)
                table.insert(hashes,`INPUT_REPLAY_TIMELINE_SAVE`)
                table.insert(hashes,`INPUT_REPLAY_PREVIEW_AUDIO`)
                table.insert(hashes,`INPUT_VEH_DRIVE_LOOK`)
                table.insert(hashes,`INPUT_VEH_DRIVE_LOOK2`)
                table.insert(hashes,`INPUT_VEH_FLY_ATTACK2`)
                table.insert(hashes,`INPUT_RADIO_WHEEL_UD`)
                table.insert(hashes,`INPUT_RADIO_WHEEL_LR`)
                table.insert(hashes,`INPUT_VEH_SLOWMO_UD`)
                table.insert(hashes,`INPUT_VEH_SLOWMO_UP_ONLY`)
                table.insert(hashes,`INPUT_VEH_SLOWMO_DOWN_ONLY`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_TOGGLE`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_LEFT`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_RIGHT`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_UP`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_DOWN`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_UD`)
                table.insert(hashes,`INPUT_VEH_HYDRAULICS_CONTROL_LR`)
                table.insert(hashes,`INPUT_SWITCH_VISOR`)
                table.insert(hashes,`INPUT_VEH_MELEE_HOLD`)
                table.insert(hashes,`INPUT_VEH_MELEE_LEFT`)
                table.insert(hashes,`INPUT_VEH_MELEE_RIGHT`)
                table.insert(hashes,`INPUT_MAP_POI`)
                table.insert(hashes,`INPUT_REPLAY_SNAPMATIC_PHOTO`)
                table.insert(hashes,`INPUT_VEH_CAR_JUMP`)
                table.insert(hashes,`INPUT_VEH_ROCKET_BOOST`)
                table.insert(hashes,`INPUT_VEH_FLY_BOOST`)
                table.insert(hashes,`INPUT_VEH_PARACHUTE`)
                table.insert(hashes,`INPUT_VEH_BIKE_WINGS`)
                table.insert(hashes,`INPUT_VEH_FLY_BOMB_BAY`)
                table.insert(hashes,`INPUT_VEH_FLY_COUNTER`)
                table.insert(hashes,`INPUT_VEH_TRANSFORM`)
                table.insert(hashes,`INPUT_QUAD_LOCO_REVERSE`)
                table.insert(hashes,`INPUT_RESPAWN_FASTER`)
                table.insert(hashes,`INPUT_HUDMARKER_SELECT`)
                local Keys = { ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18, ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182, ["LSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81, ["LCONTROL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RCONTROL"] = 70, ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178, ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173, ["NENTER"] = 201, ["NUMPAD4"] = 108, ["NUMPAD5"] = 60, ["NUMPAD6"] = 107, ["ADD"] = 96, ["SUBTRACT"] = 97, ["NUMPAD7"] = 117, ["NUMPAD8"] = 61, ["NUMPAD9"] = 118 }
                
                key = hashes[Keys[string.upper(key)]+1]
                group = 0
            end 
            RegisterKeyMapping = function(name,desc,group,key)
                if type(group) == "number" and type(key) == "number" then 
                if not KeyCheckLoop then KeyCheckLoop = PepareLoop(0) end 
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
    if RegisterEvents[cbname][idx] then RegisterEvents[cbname][idx]() end 
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
    local isdynamic = false
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
            isdynamic = dynamic or isdynamic
            if not holdingloop then holdingloop = PepareLoop(checkduration) 
                holdingloop(function(duration)
                    
                    if holdingloop and isholding then
                        local diff = GetGameTimer() - lastpressedtime 
                        if ispressed and diff > checkdelay then 
                            local onpressingtasks = obj("getonfns")[Flags[3]]
                            local n = #onpressingtasks
                            if n == 0 then duration("kill") end 
                            for i=1,n do
                                onpressingtasks[i]()
                            end
                            if isdynamic then
                                if dynamiclevel < 5 then
                                    if diff > checkdelay * dynamiclevel then
                                        dynamiclevel = dynamiclevel + 1
                                    end
                                end
                                duration("set",checkduration/dynamiclevel)
                            end
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
    print(groupid)
    local key = KeyGroupObjects[groupid] or BeginKeyBindMethod(keygroup,key,desc)
    local inputs = {}
    local actions = {}
    local inserter = function(type,...) 
        if not inputs[type] then inputs[type] = {} end
        table.insert(inputs[type],{...})
    end
    if cb then cb(inserter) end
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
