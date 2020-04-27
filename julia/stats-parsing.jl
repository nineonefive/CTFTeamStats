using HTTP
using Gumbo
using DataFrames

"""Returns the table found on the player page, if found"""
function getPlayerPage(player)
    r = HTTP.get("https://www.brawl.com/MPS/MPSStatsCTF.php?player=$(player)")
    doc = parsehtml(String(r.body))
    table = doc.root[2][2]
    header = table[1][1]
    rows = table[2].children
    
    (header, rows)
end

getThText(th) = text(th.children[1])
htmlRowToVec(row) = getThText.(row.children)
convertRow(row) = [row[1:2]; [parse(Float64, x) for x in row[3:end]]]

function processGameRow(row)
    elem = row.children
    game_id = text(elem[1][1].children[1])
    server = text(elem[4].children[1])
    
    (game_id, server)
end

function processStatRow(row)
    (name = lowercase(row[1]), kit_type = row[2], playtime = row[3], kills = row[4], deaths = row[5],
    damage_dealt = row[6], damage_received = row[7], flags_captured = row[21], flags_recovered = row[18], flags_stolen = row[19], drops = row[20],
    time_with_flag = row[22], hp_restored = row[8])
end

"""Retrieves the per-class stats of the game"""
function getGameStats(game)
    r = HTTP.get("https://www.brawl.com/MPS/MPSStatsCTF.php?game=$(game)");
    doc = parsehtml(String(r.body))
    table = doc.root[2].children[end] # last table in the document, per class stats
    header = htmlRowToVec(table[1][1])
    rows = table[2].children
    
    rows = htmlRowToVec.(rows)
    rows = convertRow.(rows)
    
    df = DataFrame()
    for row in rows
        push!(df, processStatRow(row))
    end
    
    return df
end