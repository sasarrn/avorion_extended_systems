if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";?"

require ("galaxy")
require ("randomext")
ShipGenerator = require ("shipgenerator")

function getUpdateInterval()
    return 120
end

function hasTraders(station)
    -- check if there are traders flying to this station
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}

    for _, ship in pairs(ships) do
        local ok, index = ship:invokeFunction("tradeship.lua", "getStationIndex")
        if ok == 0 and index and station.index == index then
            return true
        end
    end

    return false
end

function update(timeStep)

    -- find all stations that buy or sell goods
    local scripts = {"consumer.lua", "factory.lua", "tradingpost.lua"}
    local sector = Sector()

    local tradingStations = {}

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do

        if not hasTraders(station) then

            for _, script in pairs(scripts) do

                local results = {station:invokeFunction(script, "getSoldGoods")}
                local callResult = results[1]

                local tradingStation = nil

                if callResult == 0 then -- call was successful, the station sells goods
                    tradingStation = {station = station, script = script, bought = {}, sold = {}}
                    tradingStation.sold = {}

                    for i = 2, tablelength(results) do
                        table.insert(tradingStation.sold, results[i])
                    end
                end

                local results = {station:invokeFunction(script, "getBoughtGoods")}
                local callResult = results[1]
                if callResult == 0 then -- call was successful, the station buys goods

                    if tradingStation == nil then
                        tradingStation = {station = station, script = script, bought = {}, sold = {}}
                    end

                    for i = 2, tablelength(results) do
                        table.insert(tradingStation.bought, results[i])
                    end

                end

                if tradingStation then
                    table.insert(tradingStations, tradingStation)
                end
            end
        end
    end

    -- find stations that need goods or would sell goods
    local tradingPossibilities = {}

    for _, v in pairs(tradingStations) do
        local station = v.station
        local bought = v.bought
        local sold = v.sold
        local script = v.script

        -- these are all possibilities for goods to be bought from stations
        for _, name in pairs(sold) do
            local err, amount, maxAmount = station:invokeFunction(script, "getStock", name)
            if err == 0 and amount / maxAmount > 0.6 then
                table.insert(tradingPossibilities, {tradeType = 1, station = station, script = script, name = name})
            end
        end

        -- these are all possibilities for goods to be sold to stations
        for _, name in pairs(bought) do
            local err, amount, maxAmount = station:invokeFunction(script, "getStock", name)
            if err == 0 and amount / maxAmount < 0.4 then
                table.insert(tradingPossibilities, {tradeType = 0, station = station, script = script, name = name, amount = maxAmount - amount})
            end
        end

    end

    -- if there is no way for trade, exit
    if #tradingPossibilities == 0 then return end

    -- choose one at random
    local trade = tradingPossibilities[getInt(1, #tradingPossibilities)]

    -- create a trader ship that will fly to this station to trade
    -- find a position rather outside the sector
    -- this is the position where the trader spawns
    local pos = random():getDirection() * 1500
    local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)

    -- create the trader
    local faction = Galaxy():getNearestFaction(sector:getCoordinates())
    local ship = ShipGenerator.createFreighterShip(faction, matrix)

    -- if the trader buys, he has no cargo, if he sells, add cargo
    if trade.tradeType == 0 then
        -- selling goods to station
        local g = goods[trade.name]
        local good = g:good()

        local amount = math.max(20, math.random() * 500)

        ship:addCargo(good, amount)
        ship:addScript("merchants/tradeship.lua", trade.station.index, trade.script)

--        print ("creating a trader for " .. trade.station.title .. " to sell " .. amount .. " " .. trade.name)
--        print ("index: ".. ship.index)
    elseif trade.tradeType == 1 then
        -- buying goods from station
        local amount = math.max(50, math.random() * 500)

        ship:addScript("merchants/tradeship.lua", trade.station.index, trade.script, trade.name, amount)

--        print ("creating a trader for " .. trade.station.title .. " to buy " .. amount .. " " .. trade.name)
--        print ("index: ".. ship.index)
    end

end

end
