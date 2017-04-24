--      ######################################
--      ##     'ByS XP-System' by w4rum     ##
--      ##               v1.1               ##
--      ######################################


local UPPER_LEFT = 0
local BOTTOM_LEFT = 1
local BOTTOM_RIGHT = 2
local UPPER_RIGHT = 3

function shallowcopy(orig)  -- shallow table copying (source: http://lua-users.org/wiki/CopyTable)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

if (SERVER) then
    
    -- server-side settings
    local iKt               = CreateConVar("ttt_bys_InnoKillT_reward", 30)  -- Reward for an inno killing a traitor
    local tKi               = CreateConVar("ttt_bys_TKillInno_reward", 10)  -- Reward for a traitor killing an inno
    local iRB               = CreateConVar("ttt_bys_InnoRoundBonus", 15)    -- Reward for an inno not killing another inno
    local tRB               = CreateConVar("ttt_bys_TRoundBonus", 5)        -- Reward for a traitor not killing another traitor
    
    -- shared settings (to be transmitted to the client)
    local xpFormat          = CreateConVar("ttt_bys_xpCalc", 0)             -- 0 = quadratic; 1 = linear; 2 = exponential growth
    local xpOffset          = CreateConVar("ttt_bys_xpOffset", 175)         -- Y-Axis Offset
    local xpFactor          = CreateConVar("ttt_bys_xpFactor", 125)         -- x-factor
    local xpBase            = CreateConVar("ttt_bys_xpBase", 1.5)           -- base for exponential calculation
    local priceRed          = CreateConVar("ttt_bys_priceReduction", .01)   -- factor of price reduction per level (don't worry, it's exponential, not multiplicative)
    
    -- client-side settings (to be transmitted to the client)
    local altHud            = CreateConVar("ttt_bys_hud_alt", 0)            -- use the alternative (arguably worse) HUD
    local hudPos            = CreateConVar("ttt_bys_hud_pos", BOTTOM_RIGHT) -- positions of the exp bar and stuff (old HUD)
    
    util.AddNetworkString("bys_xp_upd8")
    util.AddNetworkString("bys_xp_settings")
    util.AddNetworkString("bys_xp_xptable")
    util.AddNetworkString("bys_xp_levels")
    
    
    local meta = FindMetaTable("Player")
    
    function xpCalc(curLvl) -- starts with 100 XP, increases by 50% with each level 
        if xpFormat:GetInt() == 0 then
            return math.floor(xpFactor:GetFloat() * curLvl^2 + xpOffset:GetFloat())
        elseif xpFormat:GetInt() == 1 then
            return math.floor(xpFactor:GetFloat() * curLvl + xpOffset:GetFloat())
        else
            return math.floor(xpFactor:GetFloat() * xpBase:GetFloat()^curLvl + xpOffset:GetFloat())
        end
    end
    
	-- Adding XP (or subtracting if amt is negative)
	function meta:AddXp(amt)
		self:SetPData("bys_xp", self:GetPData("bys_xp", 0) + amt)
		self:CheckLvl()
	end
    
	-- Setting LVL and XP
	function meta:SetLvlXp(lvl, xp)
		if (lvl < 1) then
                self:SetPData("bys_xp", 0)
                self:SetPData("bys_lvl", 0)
			else
				self:SetPData("bys_xp", xp)
                self:SetPData("bys_lvl", lvl)
		end
        self:CheckLvl()
        self.xpE = true -- apply a tag to the player, showing that he was edited
	end

	-- Checking whether the player has acquired/lost enough XP to reach the next/previous LVL
	function meta:CheckLvl()
		local currentXP = tonumber(self:GetPData("bys_xp", 0))
		local currentLVL = tonumber(self:GetPData("bys_lvl", 1))
		local currentXPNeeded =  xpCalc(currentLVL)
		
        while (currentXPNeeded <= currentXP) or (currentXP < 0) do
            if (currentXPNeeded <= currentXP) then
                currentLVL = currentLVL + 1
                currentXP = currentXP - currentXPNeeded
            elseif (currentXP < 0) then
                if not (currentLVL == 1) then
                    currentLVL = currentLVL - 1
                    currentXP = currentXP + xpCalc(currentLVL)
                else
                    currentXP = 0
                end
            end
		end
        
        if (currentLVL == 0) then -- workaround-ish bugfix, too lazy at the moment
            currentLVL = 1
            currentXP = 0
        end
        
        self:SetPData("bys_lvl", currentLVL)
		self:SetPData("bys_xp", currentXP)
	end

	-- sync with the client
	function meta:UpdateXPSystem()
        if not self.rbl then self.rbl = 0 end
        if not self.kbl then self.kbl = 0 end
        net.Start("bys_xp_upd8")
            net.WriteInt(self:GetPData("bys_lvl"),32)
            net.WriteInt(self:GetPData("bys_xp"),32)
            net.WriteInt(self.rbl,32)
            net.WriteInt(self.kbl,32)
            net.WriteBit(self.xpE)
        net.Send(self)
	end
    
    -- transmit settings to the client
    function meta:TransmitSettings()
        net.Start("bys_xp_settings")
            net.WriteInt(xpFormat:GetInt(),32)
            net.WriteFloat(xpOffset:GetFloat())
            net.WriteFloat(xpFactor:GetFloat())
            net.WriteFloat(xpBase:GetFloat())
            net.WriteFloat(priceRed:GetFloat())
            net.WriteInt(hudPos:GetInt(),32)
            net.WriteInt(altHud:GetInt(),32)
        net.Send(self)
    end
    
    -- transmit players levels to the client
    function meta:TransmitLevels()
        net.Start("bys_xp_levels")
            for k, v in ipairs(player.GetAll()) do
                net.WriteInt(v:GetPData("bys_lvl", 1), 32)
            end
        net.Send(self)
    end
    
    -- Return true if a traitor could have easily avoided the damage/death -- imported from karma.lua
    local function WasAvoidable(attacker, victim, dmginfo)
       local infl = dmginfo:GetInflictor()
       if attacker:IsTraitor() and victim:IsTraitor() and IsValid(infl) and infl.Avoidable then
          return true
       end

       return false
    end
    
    -- substitute for the original KARMA.Killed
    local oKarmaKilled
    function handleKills(attacker, victim, dmginfo)
        if not (attacker == victim) and attacker:IsPlayer() and victim:IsPlayer() then -- we do not care about suicides
            if (attacker:GetTraitor() == victim:GetTraitor()) then
                if not WasAvoidable(attacker, victim, dmginfo) then
                    attacker.rb = 0 -- If you RDM, you won't get the round bonus
                end
            elseif attacker:GetTraitor() then
                attacker:AddXp(tKi:GetInt())
                attacker.kbl = attacker.kbl + tKi:GetInt()
            else
                attacker:AddXp(iKt:GetInt())
                attacker.kbl = attacker.kbl + iKt:GetInt()
            end
        end
        oKarmaKilled(attacker, victim, dmginfo)
    end
    
    -- hook handleKills into KARMA.Killed
    function hookKarmaKilled()
        if KARMA then
            if not oKarmaKilled then -- be sure it's not already done
                oKarmaKilled = KARMA.Killed -- store the original function
                KARMA.Killed = handleKills  -- redirect calls to the original function to ours
            end
        else
            timer.Simple(1,hookKarmaKilled)
        end
    end
    timer.Simple(1,hookKarmaKilled) -- delay the hooking as long as it takes for KARMA to load (this file will be executed before karma.lua so we have to wait a little)
    
    local origPSPrice
    function psPrice(ply, item)
        local newItem = shallowcopy(item)      -- Just pass the original function an item with a lower price, so everything else changed by a server admin in the original functions still works fine and stacks with the xp-based bonus
        
        newItem.Price = newItem.Price * math.floor((1 - priceRed:GetFloat())^(ply:GetPData("bys_lvl", 1) - 1)* 100) / 100 -- reduction starts at level 2
        
        return origPSPrice(ply, newItem)
    end
    
    function hookPSPrice()
        if PS then
            if not origPSPrice then
                origPSPrice = PS.Config.CalculateBuyPrice
                PS.Config.CalculateBuyPrice = psPrice
            end
        else
            timer.Simple(2,psTest)
        end
    end
    timer.Simple(2, hookPSPrice)
    
    -- sync on connect (initial spawn triggers on "sending client info")
    hook.Add("PlayerInitialSpawn", "bys_xp_spawnsync", function(ply)
        ply:TransmitSettings()
        
        if (ply:GetPData("bys_lvl", -1) == -1) then
            ply:SetLvlXp(1,0) -- new players get level 1, xp 0
        end
        ply.rb = 1 -- by default, you get the round bonus
        ply.xpE = false -- clear the edit tag
        ply:UpdateXPSystem()
    end)
    
    hook.Add("PlayerSpawn", "bys_xp_levelsync", function(ply)
        ply:TransmitLevels()
    end)
    hook.Add("PlayerSpawnAsSpectator", "bys_xp_levelsync_spec", function(ply)
        ply:TransmitLevels()
    end)
    
    function changexp(caller, cmd, args)
        if caller:IsAdmin() then
            if args[1] and tonumber(args[2]) and tonumber(args[3]) then
                local name = args[1]:lower()                -- convert name and (later) players nickname to lower-case for comparison
                local chosenPly
                for k, ply in pairs(player.GetHumans()) do
                    local curName = ply:Nick():lower()
                    if curName:find(name, 1, true) then     -- check if a nickname contains name
                        if curName == name then             -- skip the searching if name fits exactly
                            ply:SetLvlXp(tonumber(args[2]), tonumber(args[3]))
                            print("XP CHANGE: "..caller:Nick().. " set "..ply:Nick().." to level "..args[2].." and "..args[3].." XP.")
                            caller:ChatPrint("XP CHANGE: "..ply:Nick().." was set to level "..args[2].." and "..args[3].." XP.")
                            return 
                        else
                            if not chosenPly then
                                chosenPly = ply
                            else
                                caller:ChatPrint("Given part of nickname is ambiguous!")
                                return                      -- if multiple nicknames fit the name, abort
                            end
                        end
                    end
                end
                if chosenPly then
                    chosenPly:SetLvlXp(tonumber(args[2]), tonumber(args[3]))
                    print("XP CHANGE: "..caller:Nick().. " set "..chosenPly:Nick().." to level "..args[2].." and "..args[3].." XP.")
                    caller:ChatPrint("XP CHANGE: "..chosenPly:Nick().." was set to level "..args[2].." and "..args[3].." XP.")
                else
                    caller:ChatPrint("Player not found!")
                end
            else
                caller:ChatPrint("Invalid Syntax! Use 'changexp name level xp'")
            end
        else
            caller:ChatPrint("You are missing the necessary rights to run this command!")
        end
    end
    
    function getXpTable(caller, cmd, args)
        if caller:IsAdmin() then          
            net.Start("bys_xp_xptable")
                local humans = player.GetHumans()
                net.WriteInt(table.Count(humans), 32)
                for k, ply in pairs(humans) do
                    net.WriteString(ply:Nick())
                    net.WriteInt(ply:GetPData("bys_lvl"), 32)
                    net.WriteInt(ply:GetPData("bys_xp"), 32)
                end
            net.Send(caller)
        end
    end
    
    -- sync on roundEnd (so no information about kills is given inRound)
    -- also handle the roundEnd xp bonus
    hook.Add("TTTEndRound", "bys_xp_endround", function()
        for k, ply in pairs(player.GetHumans()) do
            if ply.rb == 1 and (not ply:IsSpec() or ply:IsDeadTerror()) then -- spectators do not get the round bonus
                local bonus
                if ply:GetTraitor() then
                    bonus = tRB:GetInt()
                    ply:AddXp(bonus)
                    ply.rbl = bonus -- write the round bonus into the round bonus log
                else
                    bonus = iRB:GetInt()
                    ply:AddXp(bonus) -- it's harder for innos to not RDM, so they get a bigger round bonus
                    ply.rbl = bonus
                end
            else
                ply.rbl = 0
            end
            ply:UpdateXPSystem()
            ply.rb = 1 -- reset the round bonus
            ply.kbl = 0 -- reset the round bonus log
            ply.kbl = 0 -- reset the kill bonus log
            ply.xpE = false -- reset the edit tag
            
            ply:TransmitLevels()
        end
        
        
    end)
    
    hook.Add("PlayerSay", "bys_exp_chatcmd", function(ply, text)
        if text[1] == "!" then
            local split = string.Explode(" ", string.sub(text, 2))
            local cmd = split[1]:lower()
            if cmd == "changexp" then
                changexp(ply, "changexp", {split[2], split[3], split[4]})     -- forward the command to the console
                return ""                                                       -- suppress the actual message
            elseif cmd == "showxptable" then
                ply:ConCommand("showxptable")
                return ""
            end
        end   
    end)
    
    concommand.Add("changexp", changexp)
    concommand.Add("getXpTable", getXpTable)
end

if (CLIENT) then
    local LEFT = 0
    local CENTER = 1
    local RIGHT = 2
    
    local lvl               = 1
    local xp                = 50
    local neededXp          = 150
    local kbl               = 0
    local rbl               = 0
    local showLogs          = false
    local xpEdited          = 0
    local curPriceFactor    = 1
    
    local xpFormat          = 0
    local xpOffset          = 175.0
    local xpFactor          = 125.0
    local xpBase            = 1.5
    local priceRed          = .01
    
    local altHud            = 0
    local hudPos            = BOTTOM_RIGHT
    
    local wi                = ScrW()
    local he                = ScrH()
    
    local xpTable           = {}
    local xpTableMenu       = false
    local xpTableUpdateDone = false
    
    local origPSPrice
    function psPrice(ply, item)
        local newItem = shallowcopy(item)
        newItem.Price = newItem.Price * curPriceFactor -- moved calculation into the sync, since it's not necessary to run 
        
        return origPSPrice(ply, newItem)
    end
    
    function hookPSPrice()
        if PS then
            if not origPSPrice then
                origPSPrice = PS.Config.CalculateBuyPrice
                PS.Config.CalculateBuyPrice = psPrice
            end
        else
            timer.Simple(1,psTest)
        end
    end
    timer.Simple(1, hookPSPrice)
    
    function xpCalc(curLvl) -- starts with 100 XP, increases by 50% with each level 
        if xpFormat == 0 then
            return math.floor(xpFactor * curLvl^2 + xpOffset)
        elseif xpFormat == 1 then
            return math.floor(xpFactor * curLvl + xpOffset)
        else
            return math.floor(xpFactor * xpBase^curLvl + xpOffset)
        end
    end
    
    -- receiving the sync
    net.Receive("bys_xp_upd8", function()
        lvl = net.ReadInt(32)
        xp = net.ReadInt(32)
        rbl = net.ReadInt(32)
        kbl = net.ReadInt(32)
        xpEdited = net.ReadBit() == 1
        neededXp = xpCalc(lvl)
        
        curPriceFactor = math.floor((1 - priceRed)^(lvl - 1) * 100) / 100
    end)
    
    -- receiving the settings
    net.Receive("bys_xp_settings", function()
        xpFormat    = net.ReadInt(32)
        xpOffset    = net.ReadFloat()
        xpFactor    = net.ReadFloat()
        xpBase      = net.ReadFloat()
        priceRed    = net.ReadFloat()
        hudPos      = net.ReadInt(32)
        altHud      = net.ReadInt(32)
        
        chooseHUD()
    end)

    -- receiving the XP Table
    net.Receive("bys_xp_xptable", function()
        local amount = net.ReadInt(32)
        for i = 1, amount, 1 do
            xpTable[i] = {}                             -- make id 2D!  o.O
            
            xpTable[i][1] = net.ReadString()            -- index 1 is the player's nickname
            xpTable[i][2] = net.ReadInt(32)             -- index 2 is the player's level
            xpTable[i][3] = net.ReadInt(32)             -- index 3 is the player's XP
        end
        
        xpTableUpdateDone = true
    end)
    
    net.Receive("bys_xp_levels", function()
        for k, v in ipairs(player.GetAll()) do
            v:SetPData("bys_lvl", net.ReadInt(32))
        end
    end)
    
    function drwTxt(x, y, clr, textBlub, fontBlub, alig)
        local struc = {}
        struc.pos = {}
        struc.pos[1] = x -- x pos
        struc.pos[2] = y -- y pos
        struc.color = clr -- Red
        struc.text = textBlub -- Text
        struc.font = fontBlub -- Font
        if alig == 0 then
            struc.xalign = TEXT_ALIGN_LEFT
        elseif alig == 2 then
            struc.xalign = TEXT_ALIGN_RIGHT
        else
            struc.xalign = TEXT_ALIGN_CENTER -- Horizontal Alignment
        end
        struc.yalign = TEXT_ALIGN_CENTER -- Vertical Alignment
        draw.Text(struc)
    end
    
    function drwBox(bds, x, y, width, height, clr)
        draw.RoundedBoxEx(bds, x, y, width, height, clr, false, false, false, false)
    end
    
	-- drawing the display
	function disCreate()
        -- reference position and which corners are to be rounded
        local x,y
        local down = -1     -- used to make the log go up or down depending on the position of the bar
        local ulc = false
        local blc = false
        local brc = false
        local urc = false
        
        if (hudPos == 0) then
            x = 300
            y = 0
            brc = true
            blc = true
            down = 1
        elseif (hudPos == 1) then
            x = 300
            y = he-50
            urc = true
            ulc = true
        elseif (hudPos == 2) then
            x = wi-700
            y = he-50          
            urc = true
            ulc = true
        else
            x = wi-730
            y = 0
            brc = true
            blc = true
            down = 1
        end
        
        -- background
        drwBox(16, x, y, 300, 50, Color(50,50,50,200))
        
        -- level text
        drwTxt(x + 70, y + 10, Color(255, 255, 255, 255), "Level: " .. lvl, "CenterPrintText", 1)
        
        -- price reduction text math.floor((priceRed)^(lvl - 1) * 100)
        drwTxt(x + 210, y + 10, Color(255, 255, 255, 255), "Prices: -" .. 100 - math.floor((1 - priceRed)^(lvl - 1) * 100) .."%", "CenterPrintText", 1)
        
        -- exp bar
        surface.SetDrawColor(0,0,0)
        surface.DrawOutlinedRect(x + 1, y + 21, 298, 28)
        surface.SetDrawColor(25,25,25)
        surface.DrawOutlinedRect(x, y + 20, 300, 30)                                                        -- borders
        surface.DrawOutlinedRect(x, y, 300, 21)
        surface.SetDrawColor(100,0,255)
        local barWidth = math.Clamp(math.ceil(xp/neededXp*296),0,296)
        surface.DrawRect(x + 2, y + 22, barWidth, 26)                                                       -- bar
        
        local maxAlpha  = 50
        local minAlpha  = 0
        local maxAlphaY = 22
        local minAlphaY = 48
        local factrr    = (maxAlpha-minAlpha)/(maxAlphaY-minAlphaY)
        local offstt    = minAlpha - (minAlphaY * factrr)
        
        for i=maxAlphaY,minAlphaY,1 do
            surface.SetDrawColor(255, 255, 255, math.floor(i*factrr+offstt))    -- hyper complex algorithms going on (careful, not suited for mathematicians w/o humor)
            surface.DrawLine(x + 2,y+i,x+2+barWidth-1,y+i)                      -- shade
        end
        
        
        -- exp text
        drwTxt(x+150, y+35, Color(255, 255, 255, 255), xp.." / "..neededXp, "CenterPrintText")
        
        if showLogs then
            -- log background
            draw.RoundedBoxEx(16, x+50, y + math.Clamp(down*120-60,-80,60), 200, 60, Color(50,50,50,200), true, true, true, true) -- puts the box 60px down when on the top but 120px up when on the bottom (because height is always pointing down and negative height doesn't work with rounded corners)
            
            
            -- log text
            local labelY = y+ math.Clamp(down*150-75,-65,75)
            if not xpEdited then
                local clrR = Color(math.Clamp(rbl*(-510)+255,0,255),math.Clamp(rbl*255,0,255),0,255) -- red is only shown when rbl is 0 (hence rendering the '*(-510)' ineffective) and green is only shown when rbl is above 0
                local clrK = Color(math.Clamp(kbl*(-510)+255,0,255),math.Clamp(kbl*255,0,255),0,255)
                local clrSum = Color(math.Clamp((kbl+rbl)*(-510)+255,0,255),math.Clamp((kbl+rbl)*255,0,255),0,255)
                --- log labels
                
                drwTxt(x+65, labelY, clrR, "No-RDM Bonus", "BudgetLabel",0)
                drwTxt(x+65, labelY+10, clrK, "Kill Bonus", "BudgetLabel",0)
                surface.SetDrawColor(clrSum)
                surface.DrawLine(x+65,labelY+20,x+235,labelY+20)
                drwTxt(x+64, labelY+30, clrSum, "Sum", "BudgetLabel",0)
                --- log values
                drwTxt(x+235, labelY, clrR, "+ "..rbl, "BudgetLabel",2)
                drwTxt(x+235, labelY+10, clrK, "+ "..kbl, "BudgetLabel",2)
                drwTxt(x+235, labelY+30, clrSum, rbl+kbl, "BudgetLabel",2)
                
                -- bar addon
                if (rbl + kbl > 0) then
                    surface.SetDrawColor(255,255,255,50)
                    local previousBarLength = math.Clamp(math.ceil((xp-(kbl+rbl))/neededXp*298),0,298)
                    surface.DrawRect(x+2 + previousBarLength,y+22,barWidth - previousBarLength,26)
                end
            else
                drwTxt(x+150, labelY+10, Color(255,200,0,255), "Your XP were changed", "BudgetLabel")
                drwTxt(x+150, labelY+20, Color(255,200,0,255), "by an operator", "BudgetLabel")
            end
        end
    end
    
    --[[ 
    STAPPEHD HEYA:
    - Logs missing
    - maybe current xp
    ]]
    
    function disCreateAlt()
        local x = math.floor(wi/4)
        local y = he-100
        
        -- background
        drwBox(16, x, y, math.floor(wi/2), 75, Color(50,50,50,200))
        surface.SetDrawColor(0,0,0)
        surface.DrawOutlinedRect(x, y, math.floor(wi/2), 75)
        
        -- xp-bar
        local barWidth = math.Clamp(math.ceil(xp/neededXp*(math.floor(wi/2)-20)),0,(math.floor(wi/2)-20))
        surface.SetDrawColor(0,255,255, 150)
        surface.DrawRect(x+10, y+35, barWidth, 30)
        surface.SetDrawColor(0,0,0)
        surface.DrawOutlinedRect(x+10, y+35, math.floor(wi/2)-20, 30)
        
        -- level-text
        drwTxt(x + 50, y + 18, Color(255, 255, 255, 255), "Level: " .. lvl, "Trebuchet24", 0)
        
        -- missing-xp-text
        drwTxt(x + math.floor(wi/2) - 200, y + 18, Color(255, 255, 255, 255), "Fehlende XP: " .. neededXp - xp, "Trebuchet24", 0)
        
        -- xp-percentage-text
        --drwTxt(x + math.floor(wi/4), y + 50, Color(0,0,0), "00", "CloseCaption_Bold", 1)
        draw.SimpleTextOutlined(math.Clamp(math.floor(xp/neededXp*100),0,100).."%", "CloseCaption_Bold", x + math.floor(wi/4), y + 50, Color(255,255,255), 1, 1, 1, Color(0,0,0))
    end
    
    function showXpTableMenu()
        if not xpTableMenu then
            local panel = vgui.Create("DFrame")
            panel:SetPos(wi/2-250,he/2-250)
            panel:SetSize(415,500)
            panel:SetTitle("BysExp: XP Table")
            panel:SetVisible(true)
            panel:SetDraggable(true)
            panel:ShowCloseButton(true)
            panel:MakePopup()
            
            local nameLbl = vgui.Create("DLabel", panel)
            nameLbl:SetPos(10,30)
            nameLbl:SetSize(224,15)
            nameLbl:SetText("Name")
            
            local levelLbl = vgui.Create("DLabel", panel)
            levelLbl:SetPos(250,30)
            levelLbl:SetSize(50,15)
            levelLbl:SetText("Level")
            
            local xpLbl = vgui.Create("DLabel", panel)
            xpLbl:SetPos(295,30)
            xpLbl:SetSize(50,15)
            xpLbl:SetText("XP")
            
            local name = vgui.Create("DLabel", panel)
            name:SetPos(10,47)
            name:SetSize(224,15) -- longest possible username (32 very-wide chars) fits in 224,15
            name:SetText("Select a user")
            
            local levelTE = vgui.Create("DTextEntry", panel)
            levelTE:SetPos(248,45)
            levelTE:SetWide(45)
            levelTE:SetEnterAllowed(true)
            levelTE:SetNumeric(true)
            
            local xpTE = vgui.Create("DTextEntry", panel)
            xpTE:SetPos(293,45)
            xpTE:SetWide(60)
            xpTE:SetEnterAllowed(true)
            xpTE:SetNumeric(true)
            
            local xpLV = vgui.Create("DListView", panel)
            xpLV:SetPos(12,70)
            xpLV:SetSize(390,400)
            xpLV:SetMultiSelect(false)
            xpLV:AddColumn("Name")
            xpLV:AddColumn("Level")
            xpLV:AddColumn("XP")
            xpLV:SetDrawBackground(false)
            if not origOnClick then                                     -- same procedure as (almost) every hook
                local origOnClick = xpLV.OnClickLine
                xpLV.OnClickLine = function(self, line, isSelected)
                    origOnClick(self, line, isSelected)
                    name:SetText(line:GetValue(1))
                    levelTE:SetValue(line:GetValue(2))
                    xpTE:SetValue(line:GetValue(3))
                end
            end
            
            local refreshB = vgui.Create("DButton", panel)
            refreshB:SetPos(12,470)
            refreshB:SetSize(390,20)
            refreshB:SetText("Refresh data")
            refreshB.DoClick = function()
                RunConsoleCommand("getXpTable")
                xpLVUpdate()
            end
            
            local submitB = vgui.Create("DButton", panel)
            submitB:SetPos(355,45)
            submitB:SetSize(50,20)
            submitB:SetText("Submit")
            submitB.DoClick = function() 
                local curName = name:GetText()
                local curLvl = levelTE:GetValue()
                local curXp = xpTE:GetValue()
                if curName ~= "Select a user" and curLvl ~= "" and curXp ~= "" then
                    RunConsoleCommand("changexp", curName, curLvl, curXp)
                    refreshB:DoClick()
                else
                    chat.AddText("Please select a user and fill in both fields prior to hitting the 'Submit'-Button.")
                end
            end
            
            function xpLVUpdate()
                if xpTableUpdateDone then
                    xpLV:Clear()
                    for _, i in pairs(xpTable) do
                        xpLV:AddLine(i[1], i[2], i[3])
                    end
                    xpTableUpdateDone = false
                else
                    timer.Simple(0.1, xpLVUpdate)
                end
            end
            
            RunConsoleCommand("getXpTable")                     -- inital data refresh
            xpLVUpdate()
            
        end
    end
    
    function chooseHUD()
        if (altHud == 0) then
            hook.Add("HUDPaint", "bys_exp_display_hook", disCreate)
        else
            hook.Add("HUDPaint", "bys_exp_display_hook", disCreateAlt)
        end
    end
    chooseHUD()
    
    hook.Add("TTTEndRound", "bys_exp_logs_show", function()
        showLogs = true
    end)
    hook.Add("TTTBeginRound", "bys_exp_logs_hide", function()
        showLogs = false
    end)
    
    concommand.Add("showxptable", showXpTableMenu)
end
