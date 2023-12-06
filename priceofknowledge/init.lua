-- bytebite01 2023/12/05
-- Script to recycle instances of Jaled Dar's Price of Knowledge.
-- Assumes use of CWTN and a full group.  
-- Bone Mask of Ancient Iksar a requirement right now to avoid invis requirements to zone in.
-- Change minutesToRun to change cycle length, don't go less than 15 for Fellowship Cooldown.
-- Change buffingMinutes to allow more or less time at the start of a cycle.
-- Edit to test git integration 0.0.2
-- Edit to test git integration 0.0.3
-- Edit to test git integration 0.0.4



local mq = require('mq')

-- Scriber Write format purloined.
local Write = require('PriceOfKnowledge.Write')

Write.prefix = 'PriceOfKnowledge'
Write.loglevel = 'info'

----------------------CONFIG ELEMENTS--------------------
local minutesToRun = 50         -- Suggested 50 to avoid recasts on the bone mask.
local buffingMinutes = 1  --  How ever long you want you group to wait before switching from Tank to Hunter
---------------------------------------------------------

local DoLoop = true
local luaName = 'PriceOfKnowledge'
local MyClass = mq.TLO.Me.Class.Name()
local MyClassSN = mq.TLO.Me.Class.ShortName()
local IksarMask = 'Bone Mask of the Ancient Iksar'
local InstanceName = 'oldkaesoraa'

local startTime = os.time()     -- Initial start time, updates per run to track shutdown time.
local buffStartTime = 0
local lastUpdateTime = 0        -- Periodic Status Updates

local loopState = {
    [0] = "start",
    [1] = "getQuest",
    [2] = "confirmIllusion",
    [3] = "travelToZone",
    [4] = "confirmArrival",
    [5] = "startBuffs",
    [6] = "startHunter",
    [7] = "continueHunting",
    [8] = "fellowshipOut",
    [9] = "kickTask",
    [10] = "wait"
}

local currentState = 0     -- Change me to value you want, suggested 0 to start when standing next to Jaled Dar in Field of Bone.

-- Purloined from Easy.lua
local function Campfire()
    if mq.TLO.Me.Fellowship.Campfire() == false and not mq.TLO.Me.Hovering() and mq.TLO.SpawnCount('radius 50 fellowship')() > 2 then
        mq.cmd('/windowstate FellowshipWnd open')
        mq.delay(1000)
        mq.cmd('/nomodkey /notify FellowshipWnd FP_Subwindows tabselect 2')
        mq.delay(1000)
        mq.cmd('/nomodkey /notify FellowshipWnd FP_RefreshList leftmouseup')
        mq.delay(1000)
        mq.cmd('/nomodkey /notify FellowshipWnd FP_CampsiteKitList listselect 1')
        mq.delay(1000)
        mq.cmd('/nomodkey /notify FellowshipWnd FP_CreateCampsite leftmouseup')
        mq.delay(1000)
        mq.cmd('/windowstate FellowshipWnd close')
        mq.delay(1000)
        if mq.TLO.Me.Fellowship.Campfire() then
            Write.Info('\a-yWe got a fire going.')
        end
        mq.delay(1000)
    end
end

local function DoStuff()
    Write.Debug('\a-yDoStuff() Called: %s', loopState[currentState])

    if loopState[currentState] == "start" then
        mq.cmd('/dgga /boxr pause')
        mq.delay('1s')
        mq.cmd('/cleanup')
        mq.delay('1s')
        mq.cmd('/cleanup')
        mq.delay('1s')
        
        -- double check kickp task
        Write.Info('\a-yChecking for existing task and cancelling.')
        mq.cmd("/dgga /taskquit")
        mq.delay('4s')
        

        -- check group comp and running on tank
        Write.Info('\a-yI am a %s and I will be tanking.  Good luck.', MyClass)
        
        -- everyone present?
        Write.Info('\a-yThere are %d members in my group.', mq.TLO.Group()+1)
        if mq.TLO.SpawnCount('group radius 100')() < 6 then
            Write.Info('\a-yThere are less than 6 people in your group within 100 meters.')
        else
            Write.Info('\a-yEveryone is here, let us get ready.')
        end

        -- update state
        Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
        currentState = currentState + 1
    end

    if loopState[currentState] == "getQuest" then
        local weGood = true
        -- make sure in zone field of bone
        weGood = weGood and mq.TLO.Zone.ID() == 452 
            
        -- make sure close to jaled dar
        weGood = weGood and mq.TLO.SpawnCount('jaled radius 50')() > 0

        if not weGood then
            Write.Error('\a-yThis only works for price of knowledge in Field of Bone.  Go there first.')
            DoLoop = false
            mq.cmdf('/lua stop %s', luaName)
        end

        Campfire()

        -- hail jaled and say I am still available
        mq.cmd('/mqtarget Jaled')
        mq.delay('2s')
        mq.cmd('/say I am still available')
        mq.delay('2s')
        
        Write.Info('\a-yWe do not have the quest.  Getting it from Jaled Dar.')
        
       
        -- if task select window open
        if mq.TLO.Window('TaskSelectWnd').Open() then
            -- get index of the quest we want
            local questIndex = mq.TLO.Window('TaskSelectWnd').Child('TSEL_TaskList').List('The Price of Knowledge')()
            if questIndex ~= nil then
                mq.cmdf('/notify TaskSelectWnd TSEL_TaskList listselect %d', questIndex)
                mq.delay('2s')
                mq.cmd('/notify TaskSelectWnd TSEL_AcceptButton leftmouseup')
                Write.Info('\a-yGot the Task!')
                mq.delay('3s')
            end
        end

            
        -- final double checks
        if mq.TLO.Task('The Price of Knowledge')() ~= nil then
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        end

    end

    if loopState[currentState] == "confirmIllusion" then
        Write.Info('\a-yPut your masks on.')
        mq.cmdf('/dgga /useitem %s', IksarMask)
        mq.delay('4s')
        Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
        currentState = currentState + 1
    end


    if loopState[currentState] == "travelToZone" then

        mq.cmd('/dgga /cleanup')
        mq.delay('1s')
        mq.cmd('/dgga /cleanup')
        mq.delay('1s')
        
        mq.cmd('/dgga /autoinv')
        mq.delay(500)
        mq.cmd('/dgga /autoinv')
        

        -- make sure everyone is iksar illusioned and on their way 
        while mq.TLO.Zone.ID() == 452 and mq.TLO.SpawnCount('group')() > 1 do
            Write.Info('\a-yGet to the door.')
            mq.cmdf('/dgza /if ( !$\\{Me.Buff[Ancient Iksar].ID} ) /useitem %s', IksarMask)
            -- if I am iksared, run to zone in
            mq.cmdf('/dgza /if ( $\\{Me.Buff[Ancient Iksar].ID} ) /travelto %s', InstanceName)

            while mq.TLO.Navigation.Active() do
                mq.delay(100)
            end
            mq.delay('1s')
            mq.cmd('/dgze /yes')

            Write.Info('\a-yWaiting on %d group members to zone in before I do.', mq.TLO.SpawnCount('group')()-1)
        end

        Write.Info('\a-yAlright I\'m zoning in.')
        
        mq.cmd('/yes')
        
        while mq.TLO.Zone.ID() == 452 do
            mq.delay('10s', function ()
				return mq.TLO.Zone.ID() ~= 452
			end)
        end

        -- update state
        Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
        currentState = currentState + 1
        
    end

    --[4] = "confirmArrival",
    if loopState[currentState] == "confirmArrival" then
        mq.cmdf('/dgza /if ( !$\\{Me.Buff[Ancient Iksar].ID} ) /useitem %s', IksarMask)
        mq.delay('4s')
       
        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 453 ) then
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Info('\a-yWaiting on people to zone.')
        end
    end
    
    --[5] = "startBuffs",
    if loopState[currentState] == "startBuffs" then
        
        -- start up automation with tank to have all buffs go
        mq.cmd('/dgza /boxr camp')
        mq.delay(100)
        mq.cmdf('/%s mode tank', MyClassSN)
        mq.delay(100)
        mq.cmd('/dgza /boxr unpause')
        mq.delay(100)
        
        if buffStartTime == 0 then
            buffStartTime = os.time()
        end

        -- Wait X minutes to let buffs land
        while(buffStartTime + (buffingMinutes * 60) > os.time()) do
            mq.delay('2s')
            mq.doevents()
        end
        
        
        -- update state if I am in kaesora library and my whole group is here, and ostime is after buffingMinutes delay
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 453 ) then
            buffStartTime = 0
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Debug('\a-yWaiting on people.')
        end
    end
    --[6] = "startHunter",
    if loopState[currentState] == "startHunter" then
        -- start huntertank on tank with chase on others
        -- Should use boxr for chase on bards and wizards?
        mq.cmd('/dgze /boxr chase')
        mq.delay('1s')
        mq.cmdf('/%s mode huntertank', MyClassSN)
        mq.delay('1s')
        mq.cmd('/dgga /boxr unpause')
        mq.delay('1s')


        --TODO: Configure tank and settings here?
        -- Suggested ZHigh 1k+ Zlow 1k+  radius 2k, 360 arc and group watch all while testing
        

        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 453 ) then
            startTime = os.time()
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Debug('\a-yWaiting on people.')
        end
    end

    --[7] = "continueHunting",
    if loopState[currentState] == "continueHunting" then
        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 453 and os.time() > (startTime + (minutesToRun * 60))  ) then
            mq.delay(50)
            mq.cmdf('/%s resetcamp', MyClassSN)
            mq.delay(50)
            mq.cmdf('/%s mode tank', MyClassSN)
            mq.delay(50)

            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Debug('\a-yContinuing to Roam and Murder.')
        end
    end

    --[8] = "fellowshipOut",
    if loopState[currentState] == "fellowshipOut" then
        if mq.TLO.Zone.ID() == 453 and mq.TLO.Me.XTarget() < 1 and not mq.TLO.Me.Combat() and mq.TLO.Me.CombatState() ~= 'COOLDOWN' and mq.TLO.SpawnCount('group')() > 1 then
            -- safe to pause while we are illusioned and out of combat and out of hunter tank mode
            mq.cmd('/dgza /boxr pause')
            mq.delay(10)
            mq.cmd('/dgza /makemevis')
            mq.delay(10)
            mq.cmd('/dgze /useitem fellowship')
            mq.delay(10)
        end

        if mq.TLO.SpawnCount('group')() == 1 and mq.TLO.Zone.ID() == 453 then
            Write.Info('\a-yEveryone is out, I\'m coming out too.')
            mq.cmd('/makemevis')
            mq.delay(10)
            mq.cmd('/useitem fellowship')
            mq.delay(10)
        end

        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 452 ) then
            Write.Info('\a-yEveryone is here in Field of bone.  Time to recycle instance.')
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Info('\a-yWaiting on people.')
        end
    end

    --[9] = "kickTask",
    if loopState[currentState] == "kickTask" then
        -- make sure everyone is iksar illusioned
        mq.cmd('/dgga /useitem %s', IksarMask)
        mq.delay('4s')
        mq.cmd('/dgga /taskquit')
        -- make sure in field of bone
        mq.cmd('/dgga /nav spawn Jaled')
        while mq.TLO.Navigation.Active() do
            mq.delay(100)
        end

        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 452 and mq.TLO.SpawnCount('Jaled radius 50')() > 0) then
            Write.Info('\a-yBack a jaled, going on')
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[currentState+1])
            currentState = currentState + 1
        else 
            Write.Info('\a-yWaiting on people.')
        end
    end

    --[10] = "wait"
    if loopState[currentState] == "wait" then
        -- make sure everyone is iksar illusioned
        -- should be next to jaled dar camp, if not return to jaled dar illusioned
        -- update state to 0
        -- update state
        if ( mq.TLO.SpawnCount('group')() > 5 and mq.TLO.Zone.ID() == 452 and mq.TLO.SpawnCount('Jaled radius 50')() > 0) then
            Write.Info('\a-yNo need to wait yet.. no config set up yet.')
            Write.Info('\a-yNEXT STEP: %s=>%s', loopState[currentState], loopState[0])
            currentState = 0
        else 
            Write.Info('\a-yWaiting on people.')
        end
    end


end

while DoLoop do
	--pause_script()
    mq.doevents()
    if lastUpdateTime + 60 < os.time() then
        lastUpdateTime = os.time()
        Write.Info('\a-yCurrent State: %s', loopState[currentState])
        Write.Info('\a-yThis run duration: %d', os.time() - startTime)
        Write.Info('\a-yThis run remaining: %d', (startTime + (minutesToRun * 60) - os.time()))
    end

    -- A little bit of a restart ability if script dies in zone.  Basically just starts off buffing and resetting timer in there.
    if mq.TLO.Zone.ID() == 453 and currentState < 4 then
        -- Todo abstract this
        currentState = 4
    end
    
    DoStuff()

    mq.delay('5s')
end
