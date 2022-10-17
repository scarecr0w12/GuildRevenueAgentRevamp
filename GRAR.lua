function GRA_OnLoad(self)
	GRAWatchForMailInboxUpdate = 0
	-- Note: need to add guild joining/leaving 
	-- money making events
	self:RegisterEvent("CHAT_MSG_MONEY")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterEvent("MERCHANT_CLOSED")
	-- Tax notification events
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterEvent("GUILD_MOTD")
	self:RegisterEvent("CHAT_MSG_GUILD")
	self:RegisterEvent("CHAT_MSG_WHISPER")
	-- Mail -- tax auction money
	-- Guild bank access
	self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
	-- other required events
	self:RegisterEvent("ADDON_LOADED")
	-- option panel
	GRA_AddConfigPanel()
	-- create delay frame
	if GRADelayFrame == nil then
		GRADelayFrame = CreateFrame("Frame")
		GRADelayFrame:Hide()
		GRADelayFrame:SetScript("OnUpdate", function (self, elapsed)
			self.delay = self.delay - elapsed
			if self.delay <= 0 then
				self:Hide()
				self.func()
			end
		end)
	end
	-- create pormpt frame
	if GRAPromptFrame == nil then
		GRAPromptFrame = CreateFrame("Frame", "GRATaxPrompt", UIParent, "BackdropTemplate")
		GRAPromptFrame:SetHeight(100)
		GRAPromptFrame:SetWidth(300)
		GRAPromptFrame:SetPoint("CENTER", UIParent, "CENTER")
		GRAPromptFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = {
				left = 11,
				right = 12,
				top = 12,
				bottom = 11,
			}
		})
		GRAPromptFrame:Hide()
		GRAPromptPayText = GRAPromptFrame:CreateFontString("GRAToPayText", "OVERLAY", "GameFontNormal")
		GRAPromptPayText:SetPoint("TOP", GRAPromptFrame, "TOP", 0, -25)
		GRAPromptPayText:SetText("No payment amount")
		local paybutton = CreateFrame("Button", "GRATaxPromptPay", GRAPromptFrame, "UIPanelButtonTemplate")
		paybutton:SetPoint("BOTTOMLEFT", GRAPromptFrame, "BOTTOMLEFT", 25, 25)
		paybutton:SetText("Pay")
		paybutton:SetScript("OnClick", function()
			GRA_DepositMoney()
			GRAPromptFrame:Hide()
		end)
		local closebutton = CreateFrame("Button", "GRATaxPromptClose", GRAPromptFrame, "UIPanelButtonTemplate")
		closebutton:SetPoint("BOTTOMRIGHT", GRAPromptFrame, "BOTTOMRIGHT", -25, 25)
		closebutton:SetText("Close")
	    closebutton:SetScript("OnClick", function()
			GRAPromptFrame:Hide()
		end)
	end
	-- slash command
	SLASH_GRA1 = "/gra"
	SlashCmdList["GRA"] = function(msg, editBox)
		if msg == "reset" then
			print("|cFF8040FFGRA|r: Tax due reset!")
			GRATaxDue = 0
		elseif msg == "quiet" then
			GRAQuietMode = 1
			GRAQuietControl:SetChecked(true)
			print("|cFF8040FFGRA|r: Quiet mode enabled.")
		elseif msg == "verbose" then
			GRAQuietMode = 0
			GRAQuietControl:SetChecked(false)
			print("|cFF8040FFGRA|r: Verbose mode enabled.")
		elseif msg == "prompt" then
			GRATaxPrompt = 1
			GRATaxPromptControl:SetChecked(true)
			print("|cFF8040FFGRA|r: Prompting before deposit.")
		elseif msg == "autp" then
			GRATaxPrompt = 0
			GRATaxPromptControl:SetChecked(false)
			print("|cFF8040FFGRA|r: Deposit automatically.")
		elseif msg == "help" then
			print("|cFF8040FFGRA|r: Version: "..GetAddOnMetadata("GRAR","Version")) 
			print("To use, all guild members that will be taxed must have the add-on installed.")
			print("Set the tax rate by including in the Guild Info text a string in the format |cFF00FFFFtax = 10%|r (or whetever percentage you want)")
			print("Tax rates can be overriden for individual members by including a tax = xx% in the officer notes for the guild member (where xx is the tax percentage)")
			print("Tax rate defaults to 10% if not specified in the guild info/officer notes.")
			print("Income from loot, quest rewards & auction house will be taxed. Individual player transactions are not taxed. Any tax due will be deposited (assuming the member has funds) next time the member opens the guild bank.")
			print("Slash commands usable by members:")
			print("|cFF8040FF/gra help|r -- prints this message")
			print("|cFF8040FF/gra reset|r -- reset tax due")
			print("|cFF8040FF/gra quiet|r -- turn on quiet(ish) mode, user won't get notified when amounts are taxed")
			print("|cFF8040FF/gra verbose|r -- turn on verbose mode (default), user will be notified of amounts taxed")
			print("|cFF8040FF/gra prompt|r -- prompt user before depositing tax to the guild bank")
			print("|cFF8040FF/gra auto|r -- deposit tax to guild bank automatically")
			print("|cFF8040FF/gra|r -- display version, current tax due and total tax paid")
			print("Officer commands:")
			print("Officers can type the commands below in the guild chat or in a private tell to a guild member. The addon on each member's computer will reply automatically.")
			print("|cFF8040FF!graaudit|r -- audit the installation of GRA. If GRA is installed, each player will automatically whisper back with a message confirming the addon is installed, the current tax due and tax paid to date.")
			print("|cFF8040FF!graguild|r -- like !graaudit, but replies will be sent to guild chat instead of being whispered back privately.")
			print("|cFF8040FF!graupdate|r -- after updating the tax rate in the Guild Info/Officer Notes, force the addon to load the new tax rate.")
			print("The addon will ignore !gra*** messages unless the player who sent the message is rank 5 or higher in the guild hierarchy (typically an officer).")
		else
			print("|cFF8040FFGRA|r: Version: "..GetAddOnMetadata("GRAR","Version")) 
			print(format("|cFF8040FFGRA|r: Current Tax Rate: %d%%", GRATaxPercentage)) 
			print("|cFF8040FFGRA|r: Current Tax Due: "..GetCoinText(GRATaxDue)) 
			print("|cFF8040FFGRA|r: Total Tax Paid: "..GetCoinText(GRATaxToDate))
		end
	end
	local origTakeInboxMoney = TakeInboxMoney
	TakeInboxMoney = function(...)
		local index = ...
		local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(index)
		if invoiceType == "seller" then
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, 
				textCreated, canReply, isGM = GetInboxHeaderInfo(index)
			if money > 0 then
				local taxMoney = money*GRATaxPercentage/100
				if taxMoney > 0 then
					if GRAQuietMode == 0 then
						print(format("|cFF8040FFGRA|r: Taxed auction house revenue: %s", GetCoinText(taxMoney)))
					end
					GRATaxDue = GRATaxDue + taxMoney
				end
			end
		end
		origTakeInboxMoney(...)
	end
end

local function GRA_UpdateTaxAfterTransaction()
	local newMoney = GetMoney()
	if newMoney > GRACurrentMoney then
		local taxMoney = (newMoney - GRACurrentMoney)*GRATaxPercentage/100
		GRATaxDue = GRATaxDue + taxMoney
		if taxMoney>0 then
			if GRAQuietMode == 0 then
				print(format("|cFF8040FFGRA|r: Taxed sales: %s", GetCoinText(taxMoney)))
			end
		end
		-- prevent double taxation in case events fire twice
		GRACurrentMoney = newMoney
	end
end

local function GRA_UpdateTaxAfterQuestOrLoot(chatmsg)
	-- parse the message
	local gold = tonumber(chatmsg:match("(%d+)%s" .. GRAGoldStr)) or 0
	local silver = tonumber(chatmsg:match("(%d+)%s" .. GRASilverStr)) or 0
	local copper = tonumber(chatmsg:match("(%d+)%s" .. GRACopperStr)) or 0
	local newMoney = gold * COPPER_PER_GOLD + silver * COPPER_PER_SILVER + copper
	local taxMoney = newMoney*GRATaxPercentage/100
	if taxMoney > 0 then
		if GRAQuietMode == 0 then
			print(format("|cFF8040FFGRA|r: Taxed loot/quest: %s", GetCoinText(taxMoney)))
		end
		GRATaxDue = GRATaxDue + taxMoney
	end
end

local function GRA_UpdateTaxRate()
	local guildInfo = GetGuildInfoText()
	if guildInfo == nil then
		return
	end
	local newRateText = "nothing"
	local newRate
	-- first check officer's note for player
	local whoami = UnitName("player")
	local i
	for i=1, GetNumGuildMembers() do
		local playerName,_,_,_,_,_,_,officerNote = GetGuildRosterInfo(i)
		if playerName == whoami or playerName == whoami.."-"..GetRealmName() then
			if officerNote ~= nil then
				newRateText = officerNote:lower()
			end
			break
		end
	end
	newRate = newRateText:match("tax%s*[:=]?%s*(%d+)%%")
	if newRate == nil then
		-- not found in officer's note, search GuildInfoText
		newRateText = GetGuildInfoText()
		if newRateText ~= nil then
			newRate = newRateText:lower():match("tax%s*[:=]?%s*(%d+)%%")
		end
	end
	if guildInfoText:match("tax%s*[:=]?%s*%d+%%!") == nil then
		GRASpamGuildChannel = 1
	else
		GRASpamGuildChannel = 0
	end
	if newRate == nil then
		newRate = 10
	else
		newRate = tonumber(newRate)
		if newRate > 100 or newRate < 0 then 
			newRate = 10
		end
	end
	if newRate ~= GRATaxPercentage then
		GRATaxPercentage = newRate
		print(format("|cFF8040FFGRA|r: Tax Rate: %d%%", GRATaxPercentage))
	end
end

local function GRA_AuditCommand(command, sender)
	if command:find("!gra") ~= nil then
		-- only rank 5 or higher should be able to issue that command
		local i
		local found = 0
		for i=1, GetNumGuildMembers() do
			local playerName,_,playerRank = GetGuildRosterInfo(i)
			-- player name may be in format name-server
			if playerName == sender or playerName == sender.."-"..GetRealmName() then
				-- this can be optimized to check for specific permissions
				-- of the rank and cache the minimum level at load time
				-- instead of hardcoding rank 5
				found = 1
				if playerRank < 5 then
					if command == "!graaudit" then
						SendChatMessage("GRA Active, Rate: "..GRATaxPercentage.."%, Tax due: "..GetCoinText(GRATaxDue)..", Paid to date: "..GetCoinText(GRATaxToDate),
							"WHISPER", nil, sender)
					elseif command == "!graguild" then
						SendChatMessage("GRA Active, Rate: "..GRATaxPercentage.."%, Tax due: "..GetCoinText(GRATaxDue)..", Paid to date: "..GetCoinText(GRATaxToDate),
							"GUILD", nil, nil)
					elseif command == "!graupdate" then
						GRA_UpdateTaxRate()
					end
					break
				else
				end
			end
		end
	end
end

local function GRA_PayTax()
	local toPay
	-- can we even pay the whole amount of the tax?
	if GetMoney() > GRATaxDue then
		toPay = GRATaxDue
	else
		toPay = GetMoney()
	end
	-- anything to pay?
	if toPay > 0 then
		if GRATaxPrompt ~= 1 then
			-- auto deposit mode; wait 2 seconds to give the server time to sync and then deposit money
			GRA_Delay(2, GRA_DepositMoney)
		else
			-- prompt mode; display prompt
			GRAPromptPayText:SetText("Tax due: "..GetCoinText(toPay))
			GRAPromptFrame:Show()
		end
	end
end

function GRA_DepositMoney()
	-- recalculate the payable amount, just in case
	local toPay = 0;
	if GetMoney() > GRATaxDue then
		toPay = GRATaxDue
	else
		toPay = GetMoney()
	end
	if toPay > 0 then
		-- calculate how much money we need to have after depositing
		DepositGuildBankMoney(toPay)
		if GRASpamGuildChannel == 1 then
			SendChatMessage("Guild Tax deposited: "..GetCoinText(toPay), "GUILD")
		else
			print("|cFF8040FFGRA|r: Guild Tax deposited: "..GetCoinText(toPay))
		end
		GRATaxDue = GRATaxDue - toPay
		GRATaxToDate = GRATaxToDate + toPay
	end 
end

function GRA_OnEvent(self, event, ...)
	local arg1, arg2 = ...
	if event == "ADDON_LOADED" then
		if arg1 == "GRAR" then
			-- first time we load the addon, GRATaxDue/GRATaxPercentage will be nil
			if GRATaxDue == nil then
				GRATaxDue = 0
			end
			if GRATaxToDate == nil then
				GRATaxToDate = 0
			end
			if GRATaxPercentage == nil then
				GRATaxPercentage = 0
			end
			if GRAQuietMode == nil then
				GRAQuietMode = 0
			end
			if GRAQuietControl ~= nil then
				GRAQuietControl:SetChecked(GRAQuietMode == 1)
			end
			if GRATaxPrompt == nil then
				GRATaxPrompt = 0
			end
			if GRATaxPromptControl ~= nil then
				GRATaxPromptControl:SetChecked(GRATaxPrompt == 1)
			end
			GRACurrentMoney = GetMoney()
			-- Figure out what GOLD, SILVER, and COPPER are in the client language 
			GRAGoldStr = strmatch(format(GOLD_AMOUNT, 20), "%d+%s(.+)") -- This will return what's in the brackets, which on enUS would be "Gold"
			GRASilverStr = strmatch(format(SILVER_AMOUNT, 20), "%d+%s(.+)")
			GRACopperStr = strmatch(format(COPPER_AMOUNT, 20), "%d+%s(.+)")
			-- print welcome message
			print("|cFF8040FFGuild Revenue Agent|r version "..GetAddOnMetadata("GRAR","Version")..". Type |cFF8040FF/gra help|r for help.") 
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		GRA_UpdateTaxRate()	-- pull guild info on entering world
	elseif event == "GUILD_ROSTER_UPDATE" then
		GRA_UpdateTaxRate()
	elseif event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_WHISPER" then
		GRA_AuditCommand(arg1, arg2)
	elseif event == "MERCHANT_SHOW" then
		GRACurrentMoney = GetMoney()
	elseif event == "MERCHANT_CLOSED" then
		GRA_UpdateTaxAfterTransaction()
	elseif event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM" then
		GRA_UpdateTaxAfterQuestOrLoot(arg1)
	elseif event == "GUILDBANKFRAME_OPENED" then
		GRA_PayTax()
	end
end

function GRA_Delay(delay, action)
	GRADelayFrame.func = action
	GRADelayFrame.delay = delay
	GRADelayFrame:Show()
end

function GRA_AddConfigPanel()
	GRAPanel = CreateFrame("Frame", "GRAPanel", UIParent)
	GRAPanel.name = "Guild Revenue Agent"
	local title = GRAPanel:CreateFontString("GRAOptTile", "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", GRAPanel, "TOPLEFT", 15, -15)
	title:SetText("Guild Revenue Agent")
	local text1 = GRAPanel:CreateFontString("GRAOptText1", "OVERLAY", "GameFontNormal")
	text1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
	text1:SetText("Version "..GetAddOnMetadata("GRAR","Version"))

	GRATaxPromptControl = CreateFrame("CheckButton", "OptInteractive", GRAPanel, "InterfaceOptionsCheckButtonTemplate")
	GRATaxPromptControl:SetPoint("TOPLEFT", text1, "BOTTOMLEFT", 0, -15)
	_G[GRATaxPromptControl:GetName() .. "Text"]:SetText("Use interactive prompt for tax payment")
	GRATaxPromptControl:SetScript("OnClick", GRA_Opt_Prompt_Click)
	GRATaxPromptControl:SetChecked(GRATaxPrompt == 1)
	GRAQuietControl = CreateFrame("CheckButton", "OptQuiet", GRAPanel, "InterfaceOptionsCheckButtonTemplate")
	GRAQuietControl:SetPoint("TOPLEFT", GRATaxPromptControl, "BOTTOMLEFT", 0, -15)
	_G[GRAQuietControl:GetName() .. "Text"]:SetText("Quiet mode -- don't notify when amounts are taxed")
	GRAQuietControl:SetScript("OnClick", GRA_Opt_Quiet_Click)
	GRAQuietControl:SetChecked(GRAQuietMode == 1)
	InterfaceOptions_AddCategory(GRAPanel)
end

function GRA_Opt_Prompt_Click(self)
	if self:GetChecked() then
		GRATaxPrompt = 1
	else
		GRATaxPrompt = 0
	end
end

function GRA_Opt_Quiet_Click(self)
	if self:GetChecked() then
		GRAQuietMode = 1
	else
		GRAQuietMode = 0
	end
end
