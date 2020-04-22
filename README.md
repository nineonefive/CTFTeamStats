# CTF Team Stats

So this project really isn't to showcase code as much as it is to just house the competitive stats of the various teams competing in the tournament. The list of teams and their rosters is under `teams/`. The saved stats are under `stats/<team name>`.

## Usage

If for some reason you want to run the code here, you need Julia installed, as well as the packages:
- HTTP
- Gumbo
- DataFrames
- CSV
- ProgressBars

Each of these can be installed by pressing `]` at the Julia interpreter, then typing `add <Pkg>`, for instance `add DataFrames`. 

To retrieve stats of a particular player (for example, 915), you can run

```
    julia> include("comp-stats.jl")
    julia> last_updated, data = getCompetitiveStats("915")
```

`last_updated` is the most recent game id that was processed and accumulated in the stats. `data` is the actual DataFrame object, grouped by class. Note that you can get the most recent games (example, 10) with

```
    julia> last_updated, data = getCompetitiveStats("915", 10)
```

To retrieve all the teams, follow the format of existing rosters under `teams/`. Each entry must be the current in-game name of the player. To start the retrieval process, which can be ~30 minutes for a 25-person team, run

```
    julia> getTeamStats('team-name')
```

This automatically places each member's stats under `stats/team-name/player.csv`. To retrieve all the teams under `teams/`, use

```
    julia> loadAllTeams()
```

This takes a bit longer because it also checks that each name in each roster is valid and recognized, and will terminate if there is one that is unknown.

## Post-processing

If you want to do some stats afterwards, you can just use the CSV files (for instance, with Python's pandas package). I originally wrote this in Julia just because it gained a 10x speedup over an equivalent set of code in Python.

```
    import pandas as pd
    df = pd.read_csv("stats/team-name/player.csv")
    ...
    # do stuff
```