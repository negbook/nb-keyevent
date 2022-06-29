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
    KeyEvent("keyboard","i",function(insert)
        insert("onjustpress",function()
            print("just pressed i 123")
        end)
        insert("onjustreleased",function()
            print("just released i 123")
        end)
        insert("onpressing",function()
            print("onpressing i 123")
        end,250,500)
    end)

    KeyEvent("MOUSE_BUTTON","MOUSE_LEFT",function(insert)
        insert("onjustpress",function()
            print("just pressed MOUSE_BUTTON")
        end)
        insert("onjustreleased",function()
            print("just released MOUSE_BUTTON")
        end)
        insert("onpressing",function()
            print("onpressing MOUSE_BUTTON")
        end,250,500)
    end)
    
    
end)
```
