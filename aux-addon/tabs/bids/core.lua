select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Bids'

function aux.event.AUX_LOADED()
    aux.event_listener('AUCTION_HOUSE_BIDS_UPDATED', function()
        locked = {}
        refresh = true
    end)
    aux.coro_thread(function()
        while true do
            local timestamp = GetTime()
            while GetTime() - timestamp < 1 do
                aux.coro_wait()
            end
            refresh = true
        end
    end)
end

function tab.OPEN()
    frame:Show()
end

function tab.CLOSE()
    listing:SetSelectedRecord()
    frame:Hide()
end

function M.scan_auctions()
    C_AuctionHouse.QueryBids()
end

function aux.event.AUCTION_HOUSE_BIDS_UPDATED()
    local auctions = {}
    for i = 1, C_AuctionHouse.GetNumBids() do
        local auction = info.auction(i, 'bidder')
        if auction then
            tinsert(auctions, auction)
        end
    end
    listing:SetDatabase(auctions)
    listing:Sort()
end

function place_bid(buyout)
    local record = listing:GetSelection().record
    for i in scan.bidder_auctions() do
        if GetTime() - (locked[i] or 0) > .5 and scan_util.test('bidder', record, i) then
            local money = GetMoney()
            local amount = buyout and record.buyout_price or record.bid_price
            PlaceAuctionBid('bidder', i, amount)
            if money >= amount then -- TODO maybe try to reset it after errors instead
                locked[i] = GetTime()
            end
            return
        end
    end
end

function on_update()
    if refresh then
        refresh = false
        scan_auctions()
    end

    local selection = listing:GetSelection()
    if selection then
        if not C_AuctionHouse.CanQuery() then
            bid_button:Disable()
            buyout_button:Disable()
            return
        end
        if not selection.record.high_bidder then
            bid_button:Enable()
        else
            bid_button:Disable()
        end
        if selection.record.buyout_price > 0 then
            buyout_button:Enable()
        else
            buyout_button:Disable()
        end
    end
end
