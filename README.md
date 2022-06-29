# nb-keyevent
Register Key Events helper

## fxmanifest.lua
```
client_scripts {
    '@nb-keyevent/nb-keyevent.lua',
     ...
}


dependencies {
    'nb-keyevent',
    ...
}
```


## Example 
```
CreateThread(function()
    KeyEvent("keyboard","i",function(on)
        on("justpressed",function() --the type keyword has 'justpress' would be on justpressed
            print("just pressed i 123")
        end) -- keywordtype,cb
        on("justreleased",function() --the type keyword has 'justreleased' would be on justreleased
            print("just released i 123")
        end) -- keywordtype,cb
        on("pressing",function() -- other types of keywords would be on holding
            print("onpressing i 123")
        end,250,500) -- type,cb,duration,delay,isdynamic(isdynamic would take duration become faster and faster when you keep pressing)
    end)

    KeyEvent("MOUSE_BUTTON","MOUSE_LEFT",function(on)
        on("justpressed",function()   --the type keyword has 'justpress' would be on justpressed
            print("just pressed MOUSE_BUTTON")
        end) -- keywordtype,cb
        on("justreleased",function() --the type keyword has 'justreleased' would be on justreleased
            print("just released MOUSE_BUTTON")
        end) -- keywordtype,cb
        on("pressing",function()  -- other types of keywords would be on holding
            print("onpressing MOUSE_BUTTON")
        end,250,500) -- type,cb,duration,delay,isdynamic(isdynamic would take duration become faster and faster when you keep pressing)
    end)
    
    
end)
```
