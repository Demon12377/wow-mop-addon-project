select(2, ...) 'aux.util.info'

local aux = require 'aux'

CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')

do
    local map = { [1] = 2, [2] = 8, [3] = 24 }
    function M.duration_hours(duration_code)
        return map[duration_code]
    end
end

function M.container_item(bag, slot)
	local link = C_Container.GetContainerItemLink(bag, slot)
    if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = item(item_id, suffix_id, unique_id, enchant_id)
        if item_info then -- TODO apparently this can be undefined
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot) -- TODO quality not working?
            local durability, max_durability = C_Container.GetContainerItemDurability(bag, slot)
            local tooltip = tooltip('bag', bag, slot)
            local max_charges = max_item_charges(item_id)
            local charges = max_charges and item_charges(tooltip)
            local auctionable = auctionable(tooltip) and durability == max_durability and charges == max_charges and not lootable
            if max_charges and not charges then -- TODO find better fix
                return
            end
            return {
                item_id = item_id,
                suffix_id = suffix_id,
                unique_id = unique_id,
                enchant_id = enchant_id,

                link = link,
                item_key = item_id .. ':' .. suffix_id,

                name = item_info.name,
                texture = containerInfo.iconFileID,
                level = item_info.level,
                quality = item_info.quality,
                max_stack = item_info.max_stack,

                count = containerInfo.stackCount,
                locked = containerInfo.isLocked,
                readable = containerInfo.isReadable,
                auctionable = auctionable,

                tooltip = tooltip,
            }
        end
    end
end

function M.auction_sell_item()
    local sell_item_location = C_AuctionHouse.GetSellItemLocation()
    if sell_item_location then
        local item_info = C_Item.GetItemInfo(sell_item_location)
        local container_info = C_Container.GetContainerItemInfo(sell_item_location:GetBagAndSlot())
        return {
            name = item_info.itemName,
            texture = item_info.itemIcon,
            quality = item_info.itemQuality,
            count = container_info.stackCount,
            usable = item_info.isUsable,
            vendor_price = item_info.itemSellPrice,
        }
    end
    return {}
end

function M.auction(index, query_type)
    query_type = query_type or 'list'

    local auction_info = C_AuctionHouse.GetItemInfoByIndex(query_type, index)

    if auction_info and (aux.account_data.ignore_owner or auction_info.owner) then
        local link = auction_info.itemLink
        if not link then
            return
        end

        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local blizzard_bid = auction_info.highBid > 0 and auction_info.highBid or auction_info.startPrice
        local bid_price = auction_info.highBid > 0 and (auction_info.highBid + auction_info.minIncrement) or auction_info.startPrice

        return {
            item_id = item_id,
            suffix_id = suffix_id,
            unique_id = unique_id,
            enchant_id = enchant_id,

            link = link,
            item_key = item_id .. ':' .. suffix_id,
            search_signature = aux.join({item_id, suffix_id, enchant_id, auction_info.startPrice, auction_info.buyoutPrice, bid_price, auction_info.stackCount, auction_info.timeLeft, query_type == 'owner' and auction_info.highBidder or (auction_info.highBidder and 1 or 0), auction_info.saleStatus, aux.account_data.ignore_owner and (is_player(auction_info.owner) and 0 or 1) or (auction_info.owner or '?')}, ':'),
            sniping_signature = aux.join({item_id, suffix_id, enchant_id, auction_info.startPrice, auction_info.buyoutPrice, auction_info.stackCount, aux.account_data.ignore_owner and (is_player(auction_info.owner) and 0 or 1) or (auction_info.owner or '?')}, ':'),

            name = auction_info.name,
            texture = auction_info.texture,
            quality = auction_info.quality,
            requirement = auction_info.level,

            count = auction_info.stackCount,
            start_price = auction_info.startPrice,
            high_bid = auction_info.highBid,
            min_increment = auction_info.minIncrement,
            blizzard_bid = blizzard_bid,
            bid_price = bid_price,
            buyout_price = auction_info.buyoutPrice,
            unit_blizzard_bid = blizzard_bid / auction_info.stackCount,
            unit_bid_price = bid_price / auction_info.stackCount,
            unit_buyout_price = auction_info.buyoutPrice / auction_info.stackCount,
            high_bidder = auction_info.highBidder,
            owner = auction_info.owner,
            sale_status = auction_info.saleStatus,
            duration = auction_info.timeLeft,
            usable = auction_info.usable,
        }
    end
end

function M.bid_update(auction_record)
    auction_record.high_bid = auction_record.bid_price
    auction_record.blizzard_bid = auction_record.bid_price
    auction_record.min_increment = max(1, floor(auction_record.bid_price / 100) * 5)
    auction_record.bid_price = auction_record.bid_price + auction_record.min_increment
    auction_record.unit_blizzard_bid = auction_record.blizzard_bid / auction_record.count
    auction_record.unit_bid_price = auction_record.bid_price / auction_record.count
    auction_record.high_bidder = 1
    auction_record.search_signature = aux.join({auction_record.item_id, auction_record.suffix_id, auction_record.enchant_id, auction_record.start_price, auction_record.buyout_price, auction_record.bid_price, auction_record.count, auction_record.sale_status == 1 and 0 or auction_record.duration, 1, 0, aux.account_data.ignore_owner and (is_player(auction_record.owner) and 0 or 1) or (auction_record.owner or '?')}, ':')
end

function M.set_tooltip(itemstring, owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)
end

function M.tooltip_match(entry, tooltip)
    return aux.any(tooltip, function(text)
        return strupper(entry) == strupper(text)
    end)
end

function M.tooltip_find(pattern, tooltip)
    local count = 0
    for _, entry in pairs(tooltip) do
        if strfind(entry, pattern) then
            count = count + 1
        end
    end
    return count
end

function M.display_name(item_id, no_brackets, no_color)
	local item_info = item(item_id)
    if item_info then
        local name = item_info.name
        if not no_brackets then
            name = '[' .. name .. ']'
        end
        if not no_color then
            name = '|c' .. select(4, GetItemQualityColor(item_info.quality)) .. name .. FONT_COLOR_CODE_CLOSE
        end
        return name
    end
end

function M.auctionable(tooltip, quality)
    local status = tooltip[2]
    return (not quality or quality < 6)
            and status ~= ITEM_BIND_ON_PICKUP
            and status ~= ITEM_BIND_QUEST
            and status ~= ITEM_SOULBOUND
            and (not tooltip_match(ITEM_CONJURED, tooltip) or tooltip_find(ITEM_MIN_LEVEL, tooltip) > 1)
end

function M.tooltip(setter, arg1, arg2)
    AuxTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    AuxTooltip:ClearLines()
    if setter == 'auction' then
	    AuxTooltip:SetAuctionItem(arg1, arg2)
    elseif setter == 'bag' then
	    AuxTooltip:SetBagItem(arg1, arg2)
    elseif setter == 'inventory' then
	    AuxTooltip:SetInventoryItem(arg1, arg2)
    elseif setter == 'link' then
	    AuxTooltip:SetHyperlink(arg1)
    end
    local tooltip = {}
    for i = 1, AuxTooltip:NumLines() do
        for side in aux.iter('Left', 'Right') do
            local text = _G['AuxTooltipText' .. side .. i]:GetText()
            if text then
                tinsert(tooltip, text)
            end
        end
    end
    return tooltip
end

do
    local patterns = {}
    for i = 1, 10 do
        patterns[aux.pluralize(format(ITEM_SPELL_CHARGES, i))] = i
    end

	function item_charges(tooltip)
        for _, entry in pairs(tooltip) do
            if patterns[entry] then
                return patterns[entry]
            end
	    end
	end
end

do
	local data = {
		-- wizard oil
		[20744] = 5,
		[20746] = 5,
		[20750] = 5,
		[20749] = 5,

		-- mana oil
		[20745] = 5,
		[20747] = 5,
		[20748] = 5,

		-- discombobulator
		[4388] = 5,

		-- recombobulator
		[4381] = 10,
		[18637] = 10,

        -- deflector
        [4376] = 5,
        [4386] = 5,

		-- ... TODO
	}
	function M.max_item_charges(item_id)
	    return data[item_id]
	end
end

function M.item_key(link)
    local item_id, suffix_id = parse_link(link)
    return item_id .. ':' .. suffix_id
end

function M.parse_link(link)
    local _, _, item_id, enchant_id, suffix_id, unique_id, name = strfind(link, '|Hitem:(%d*):(%d*):::::(%d*):(%d*)[:0-9]*|h%[(.-)%]|h')
    return tonumber(item_id) or 0, tonumber(suffix_id) or 0, tonumber(unique_id) or 0, tonumber(enchant_id) or 0, name
end

function M.item(item_id, suffix_id)
    local itemstring = 'item:' .. (item_id or 0) .. '::::::' .. (suffix_id or 0)
    local name, link, quality, level, requirement, class, subclass, max_stack, slot, texture, sell_price = GetItemInfo(itemstring)
    return name and {
        name = name,
        link = link,
        quality = quality,
        level = level,
        requirement = requirement,
        class = class,
        subclass = subclass,
        slot = slot,
        max_stack = max_stack,
        texture = texture,
        sell_price = sell_price
    } or item_info(item_id)
end

function M.category_index(category)
    for i, v in ipairs(AuctionCategories) do
        -- ignoring trailing s because sometimes type and category differ in number
        if gsub(strupper(v.name), 'S$', '') == gsub(strupper(category), 'S$', '') then
            return i, v.name
        end
    end
end

function M.subcategory_index(category_index, subcategory)
    if category_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories or empty) do
            if strupper(v.name) == strupper(subcategory) then
                return i, v.name
            end
        end
    end
end

function M.subsubcategory_index(category_index, subcategory_index, subsubcategory)
    if category_index > 0 and subcategory_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories[subcategory_index].subCategories or empty) do
            if strupper(v.name) == strupper(subsubcategory) then
                return i, v.name
            end
        end
    end
end

function M.item_quality_index(item_quality)
    for i = 0, 4 do
        local quality = _G['ITEM_QUALITY' .. i .. '_DESC']
        if strupper(item_quality) == strupper(quality) then
            return i, quality
        end
    end
end

function M.inventory()
	local bag, slot = 0, 0
	return function()
		if slot >= C_Container.GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until C_Container.GetContainerNumSlots(bag) > 0 or bag > 4
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= 4 then return {bag, slot} end
	end
end
