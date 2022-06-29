# nb-keyevent

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
        on("justpress",function()
            print("just pressed i 123")
        end)
        on("justreleased",function()
            print("just released i 123")
        end)
        on("pressing",function()
            print("onpressing i 123")
        end,250,500)
    end)

    KeyEvent("MOUSE_BUTTON","MOUSE_LEFT",function(on)
        on("justpress",function()
            print("just pressed MOUSE_BUTTON")
        end)
        on("justreleased",function()
            print("just released MOUSE_BUTTON")
        end)
        on("pressing",function()
            print("onpressing MOUSE_BUTTON")
        end,250,500)
    end)
    
    
end)
```
