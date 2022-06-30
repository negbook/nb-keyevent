--Credit: negbook
if GetCurrentResourceName() == "nb-keyevent" then 
    local RegisteredEvents = {}
    local local_fns = function(name)
        local t = RegisteredEvents[name]
         return function()
            for resource,_ in pairs(t) do 
                TriggerEvent("NBRegCMDToResources:"..resource,name)
            end 
         end 
    end 
    AddEventHandler("NBRegCMDToResources:nb-keyevent",function(name)
        local resource = GetInvokingResource()
        if not RegisteredEvents[name] then RegisteredEvents[name] = {} end 
        RegisteredEvents[name][resource] = true 
        RegisterCommand(name,local_fns(name),false)
    end) 
    NBRegisterKeyMapping = function(...)
        return RegisterKeyMapping(...)
    end 
    exports("NBRegisterKeyMapping",NBRegisterKeyMapping)
else 
local RegisterEvents = {}
AddEventHandler("NBRegCMDToResources:"..GetCurrentResourceName(),function(cbname)
    if RegisterEvents[cbname] then RegisterEvents[cbname]() end 
end) 
NBRegisterCommand = function(name,fn)
    RegisterEvents[name] = fn 
    TriggerEvent("NBRegCMDToResources:nb-keyevent",name)
end 
NBRegisterKeyMapping = function(...)
    return exports["nb-keyevent"]:NBRegisterKeyMapping(...)
end 

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

local PepareLoopLocal = _M_.PepareLoop

local e = {} setmetatable(e,{__call = function(self) return end})
local Flags = {
    [1] = "OnPress",
    [2] = "OnRelease",
    [3] = "OnHold"
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
        elseif string.find(regtype:lower(),"justreleased") then
            action = Flags[2]
        elseif string.len(regtype) > 0 then
            action = Flags[3]
            
            isholding = true 
            checkduration = duration or checkduration
            checkdelay = delay or checkdelay
            isdynamic = dynamic or isdynamic
            if not holdingloop then holdingloop = PepareLoopLocal(checkduration) end
            
            holdingloop(function(duration)
                if holdingloop and isholding then
                    local diff = GetGameTimer() - lastpressedtime 
                    if ispressed and diff > checkdelay then 
                        for i=1,#obj("getonfns")[Flags[3]] do
                            obj("getonfns")[Flags[3]][i]()
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
        if action == Flags[1] then
            self.addonjustpressed(func)
        elseif action == Flags[2] then
            self.addonjustreleased(func)
        elseif action == Flags[3] then
            self.addonhold(func)
        end
    end
    self.bindremove = function(regtype,func)
        local action = nil
        if string.find(regtype:lower(),"justpress") then 
            action = Flags[1]
        elseif string.find(regtype:lower(),"justreleased") then
            action = Flags[2]
        elseif string.len(regtype) > 0 then
            action = Flags[3]
            if isholding then isholding = false end
        end 
        if action == Flags[1] then
            self.removeonjustpressed(func)
        elseif action == Flags[2] then
            self.removeonjustreleased(func)
        elseif action == Flags[3] then
            self.removeonhold(func)
        end
    end
    self.bindend = function()
        local fns = obj("getonfns")
        local reg = function(name,action)
            NBRegisterCommand(name, function()
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
            end, false)
        end 
        if (fns[Flags[2]] or e)[1] or (fns[Flags[3]] or e)[1] then
            local name = "+" .. groupid
            reg(name,Flags[1])
            NBRegisterKeyMapping(name, description or '', keygroup, key)
            reg(name:gsub("+","-"),Flags[2])
        else 
            local name = groupid
            reg(name,Flags[1])
            NBRegisterKeyMapping(name, description or '', keygroup, key)
        end
        
    end 
    KeyGroupObjects[groupid] = self
    return self
end


local unpack = table.unpack 

KeyEvent = function(keygroup, key, cb)
    local desc = keygroup:lower()..":"..key:lower()
    local groupid = keygroup.."_"..key
    local key = KeyGroupObjects[groupid] or BeginKeyBindMethod(keygroup,key,desc)
    local inputs = {}
    local inserter = function(type,...) 
        if not inputs[type] then inputs[type] = {} end
        table.insert(inputs[type],{...})
    end
    if cb then cb(inserter) end
    for k,v in pairs(inputs) do
        for i=1,#v do
            key.bindadd(k,unpack(v[i]))
        end
    end
    key.bindend()
end

end 
