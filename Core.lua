--Global Variables
local GRAR = LibStub("AceAddon-3.0"):NewAddon("GuildRevenueAgentRevamp", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("GuildRevenueAgentRevamp")

GRAWatchForMailInboxUpdate = 0

-- option panel
GRA_AddConfigPanel()

-- Initialize variables
--Global Variables
GRA_TaxRate = nil

--Local Variables
local GRA_TaxDue = nil
local GRA_TaxDueDate = nil
local GRA_CopperChange = nil
local GRA_SilverChange = nil
local GRA_GoldChange = nil
local GRA_CopperChangeTotal = nil
local GRA_SilverChangeTotal = nil
local GRA_GoldChangeTotal = nil



function GRAR:OnIntialize()
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
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("MAIL_INBOX_UPDATE")

    -- Guild bank access
    self:RegisterEvent("GUILDBANKFRAME_OPENED", DepositTaxDue())

    -- other required events
    self:RegisterEvent("ADDON_LOADED")

    --Initialize deposit prompt frame
    if GRARPromptFrame == nil then
        GRARPromptFrame = CreateFrame("Frame", "GRATaxPrompt", UIParent, "BackdropTemplate")
        GRARPromptFrame:SetHeight(100)
        GRARPromptFrame:SetWidth(300)
        GRARPromptFrame:SetPoint("CENTER", UIParent, "CENTER")
        GRARPromptFrame:SetBackdrop({
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
        GRARPromptFrame:Hide()
        GRARPromptPayText = GRARPromptFrame:CreateFontString("GRARToPayText", "OVERLAY", "GameFontNormal")
        GRARPromptPayText:SetPoint("TOP", GRARPromptFrame, "TOP", 0, -25)
        GRARPromptPayText:SetText("No payment amount")


        local paybutton = CreateFrame("Button", "GRAPHICS_QUALITY_RECOMENDEDTaxPromptPay", GRARPromptFrame,
            "UIPanelButtonTemplate")
        paybutton:SetPoint("BOTTOMLEFT", GRARPromptFrame, "BOTTOMLEFT", 25, 25)
        paybutton:SetText("Pay")
        paybutton:SetScript("OnClick", function()
            GRA_DepositMoney()
            GRARPromptFrame:Hide()
        end)


        local closebutton = CreateFrame("Button", "GRARTaxPromptClose", GRARPromptFrame, "UIPanelButtonTemplate")
        closebutton:SetPoint("BOTTOMRIGHT", GRARPromptFrame, "BOTTOMRIGHT", -25, 25)
        closebutton:SetText("Close")
        closebutton:SetScript("OnClick", function()
            GRARPromptFrame:Hide()
        end)
    end

    -- slash command
    SLASH_GRA1 = "/gra"
    SlashCmdList["GRA"] = function(msg, editBox)
        if msg == "reset" then
            print("|cFF8040FFGRA|r: Tax due reset!")
            GRA_TaxDue = 0
        elseif msg == "quiet" then
            GRA_QuietMode = 1
            GRAQuietControl:SetChecked(true)
            print("|cFF8040FFGRA|r: Quiet mode enabled.")
        elseif msg == "verbose" then
            GRA_QuietMode = 0
            GRAQuietControl:SetChecked(false)
            print("|cFF8040FFGRA|r: Verbose mode enabled.")
        elseif msg == "prompt" then
            GRA_TaxPrompt = 1
            GRATaxPromptControl:SetChecked(true)
            print("|cFF8040FFGRA|r: Prompting before deposit.")
        elseif msg == "auto" then
            GRA_TaxPrompt = 0
            GRATaxPromptControl:SetChecked(false)
            print("|cFF8040FFGRA|r: Deposit automatically.")
        elseif msg == "help" then
            print("|cFF8040FFGRA|r: Version: " .. GetAddOnMetadata("GRAR", "Version"))
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
            print("|cFF8040FFGRA|r: Version: " .. GetAddOnMetadata("GRAR", "Version"))
            print(format("|cFF8040FFGRA|r: Current Tax Rate: %d%%", GRATaxPercentage))
            print("|cFF8040FFGRA|r: Current Tax Due: " .. GetCoinText(GRATaxDue))
            print("|cFF8040FFGRA|r: Total Tax Paid: " .. GetCoinText(GRATaxToDate))
        end
    end

    -- create delay frame
    if GRADelayFrame == nil then
        GRADelayFrame = CreateFrame("Frame")
        GRADelayFrame:Hide()
        GRADelayFrame:SetScript("OnUpdate", function(self, elapsed)
            self.delay = self.delay - elapsed
            if self.delay <= 0 then
                self:Hide()
                self.func()
            end
        end)
    end
end

-- Deposit tax due to guild bank
function DepositTaxDue()
    if GRA_TaxDue > 0 then
        if GRA_TaxPrompt == 1 then
            StaticPopupDialogs["GRA_DEPOSIT_TAX"] = {
                text = format("|cFF8040FFGRA|r: Tax due: %s. Deposit to guild bank?", GetCoinText(GRA_TaxDue)),
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    DepositGuildBankMoney(GRA_TaxDue)
                    GRA_TaxToDate = GRA_TaxToDate + GRA_TaxDue
                    GRA_TaxDue = 0
                end,
                OnCancel = function()
                    -- do nothing
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("GRA_DEPOSIT_TAX")
        else
            DepositGuildBankMoney(GRA_TaxDue)
            GRA_TaxToDate = GRA_TaxToDate + GRA_TaxDue
            GRA_TaxDue = 0
        end
    end
end

-- Set guild tax rated
function SetGuildTaxRate()
    local guildInfo = GetGuildInfoText()
    local guildTaxRate = 10
    if guildInfo ~= nil then
        local taxRate = string.match(guildInfo, "tax = (%d+)%%")
        if taxRate ~= nil then
            guildTaxRate = tonumber(taxRate)
        end
    end
    GRA_TaxRate = guildTaxRate
end