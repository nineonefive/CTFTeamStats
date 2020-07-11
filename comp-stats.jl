using DataFrames
using CSV
using ProgressBars
using Logging
using JSON

module Players
    include("julia/players.jl")
end

module Parsing
    include("julia/stats-parsing.jl")
end

module Metadata
    include("julia/metadata.jl")
end

function getCompetitiveStats(player, n=-1, autosave=false)
    header, rows = Parsing.getPlayerPage(player)
    games = Parsing.processGameRow.(rows)
    
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
            data = Parsing.getGameStats(game[1])
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

function getTeamStats(team, invalid)
    names = loadTeamRoster(team)

    updates = DataFrame()
    for name in ProgressBar(names)
        if name in invalid
            continue
        end

        try
            time = @elapsed last_updated, df = getCompetitiveStats(name)
            push!(updates, (name=name, game=last_updated))

            @info "Retrieved stats for $name in $time s"

            mkpath("stats/$team")

            CSV.write("stats/$team/$name.csv", df)
        catch e
            @warn "Failed to retrieve stats for $name"
            @warn "$e"
            continue
        end
    end

    return updates
end

function verifyTeamRoster!(team, last_updated=Metadata.getNameUpdateTime())
    invalid_names = []

    @info "Verifying $team"
    names = loadTeamRoster(team)

    Threads.@threads for i in axes(names, 1)
        name = names[i]
        res = Players.verifyPlayer(name, last_updated)
        if isnothing(res)
            @info "Unresolved name $name"
            push!(invalid_names, name)
        else
            if name != res[begin]
                @info "Updated $name to $(res[begin])"
                names[i] = res[begin]

                # mv("stats/$team/$name.csv", "stats/$team/$(res[begin]).csv")
            end
        end
    end

    open("./teams/$team.txt", "w") do f
        for name in names
            write(f, "$name\n")
        end
    end

    return isempty(invalid_names), invalid_names

end

function loadTeamRoster(team)
    names = open("./teams/$team.txt", "r") do f
        lines = readlines(f)
        (lines)
    end

    return filter(x -> x != "", names)
end

function getAllTeams()
    teams = cd(readdir, "teams")
    teams = [team[begin:end - 4] for team in teams]
end


function loadAllTeams()
    updates = DataFrame()

    # logging
    open("log.txt", "w") do io
        logger = SimpleLogger(io)
        with_logger(logger) do
            teams = getAllTeams()
            @info "$(size(teams)[1]) teams found.."
            println("$(size(teams)[1]) teams found..")

            for team in teams
                @info "Verifying $team"
                println("Verifying $team")
                res, invalid = verifyTeamRoster!(team)
                @info "Processing $team.."
                println("Processing $team")
                u = getTeamStats(team, invalid)
                append!(updates, u)
            end
        end
        
        CSV.write("last-updated.csv", updates)
    end
end
