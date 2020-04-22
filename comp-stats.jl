using HTTP
using Gumbo
using DataFrames
using CSV
using ProgressBars
using Logging

function getPlayerPage(player)
    r = HTTP.get("https://www.brawl.com/MPS/MPSStatsCTF.php?player=$(player)")
    doc = parsehtml(String(r.body))
    table = doc.root[2][2]
    header = table[1][1]
    rows = table[2].children
    
    (header, rows)
end

function isNameValid(player)
    r = HTTP.get("https://www.brawl.com/MPS/MPSStatsCTF.php?player=$(player)")
    doc = parsehtml(String(r.body))
    label = text(doc.root[2][1][1])

    return label == "Played Games"
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

function getCompetitiveStats(player, n=-1, autosave=false)
        header, rows = getPlayerPage(player)
        games = processGameRow.(rows)
    
    # only competitive games
    filter!(x -> occursin("ctfmatch", x[2]), games)
    
    # take n most recent games
    if n > 0
        games = games[end-(n-1):end]
    end
    
    important_stats = ["kit_type", "playtime", "kills", "deaths", "flags_captured", 
                       "flags_recovered", "flags_stolen", "time_with_flag", "damage_dealt", 
                       "damage_received", "hp_restored"]
    
    headers = ["kit_type"; [s * "_sum" for s in important_stats[2:end]]]
    
    df = DataFrame()
    last_updated = 0
    Threads.@threads for game in games
        try
            data = getGameStats(game[1])
            data = data[(data.name .== lowercase(player)) .& (data.playtime .> 0.0), :]
            select!(data, Not(:name))
            append!(df, data)

            if game == games[end]
                last_updated = game[1]
            end
        catch
            continue
        end
    end
    
    # Sum and group by class
    data = aggregate(groupby(df, :kit_type), sum)
    
    # Rename to remove '_sum' from headers
    select!(data, All(Symbol.(headers)))
    for (i, new_name) in enumerate(important_stats[2:end])
        old = Symbol(headers[i+1])
        new = Symbol(new_name)
        
        rename!(data, old => new)
    end
    
    data.kdr = data.kills ./ data.deaths
    
    if autosave
        label = if (n == -1) "all_time" else string(n) end
        CSV.write("./ctf-stats/$player-$label.csv", data)
    end
    
    return last_updated, data
    
end

function getTeamStats(team)
    names = open("./teams/$team.txt", "r") do f
        lines = readlines(f)
        (lines)
    end

    updates = DataFrame()
    for name in ProgressBar(names)
        time = @elapsed last_updated, df = getCompetitiveStats(name)
        push!(updates, (name=name, game=last_updated))

        @info "Retrieved stats for $name in $time s"

        mkpath("stats/$team")

        CSV.write("stats/$team/$name.csv", df)
    end

    return updates
end

function verifyTeams()
    teams = cd(readdir, "teams")
    teams = [team[begin:end - 4] for team in teams]

    invalid_names = []

    for team in teams
        @info "Verifying $team"
        names = open("./teams/$team.txt", "r") do f
            lines = readlines(f)
            (lines)
        end

        Threads.@threads for name in names
            res = isNameValid(name)
            if !res
                @info "Invalid name $name"
                push!(invalid_names, "$team/$name")
            end
        end
    end

    return isempty(invalid_names)

end

function loadAllTeams()
    updates = DataFrame()

    if !verifyTeams()
        return
    end

    # logging
    open("log.txt", "w") do io
        logger = SimpleLogger(io)
        with_logger(logger) do
            teams = cd(readdir, "teams")
            teams = [team[begin:end - 4] for team in teams]

            @info "$(size(teams)[1]) teams found.."
            println("$(size(teams)[1]) teams found..")

            for team in teams
                @info "Processing $team.."
                println("Processing $team..")
                u = getTeamStats(team)
                append!(updates, u)
            end
        end
        
        CSV.write("last-updated.csv", updates)
    end
end
