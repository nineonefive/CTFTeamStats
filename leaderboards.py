import numpy as np
import pandas as pd
from glob import glob
from pathlib import Path
import requests
from pyquery import PyQuery as pq
from multiprocessing import Pool

ctfClasses = """Archer
Assassin
Chemist
Dwarf
Elf
Engineer
Fashionista
Heavy
Mage
Medic
Pyro
Ninja
Scout
Soldier
Necro""".split("\n")

column_order = ['name', 'playtime', 'kills', 'deaths', 'kdr', 'flags_captured', 'flags_recovered',
       'flags_stolen', 'time_with_flag', 'damage_dealt', 'damage_received',
       'hp_restored']

def getNames():
    """Returns the names of every player tracked on a team"""
    res = []
    teamfiles = glob("teams/*.txt")
    for tf in teamfiles:
        with open(tf) as f:
            for line in f.readlines():
                res.append(line)
    
    return res

def extractCTFText(r):
    """Extracts the ctf section of the webpage
    """
    start = r.text.find("<!-- CTF Statistics -->")
    text = r.text[start:]
    d = pq(text)
    ctf_div = d("div.col-md-8")[0]

    return pq(ctf_div.html())

    
    # end = r.text.find("<!-- Party Statistics -->", start)
    # endhg = r.text.find("<!-- HG Statistics -->", start)
    # end = end if end < endhg else endhg
    # if end - start > 0:
    #     return pq(ctf_div.html())
    # else:
    #     return None

def extractClassText(d, ctfClass):
    """Returns the stats section of a particular class"""
    return d(f"div#ctfAdditionalDetailsDisplay{ctfClass.upper()}").html()

def parsePlaytime(time):
    """Converts the playtime to units of days"""
    d = 0
    for div in time.split(' '):
        if len(div) == 0:
            continue
        if div[-1] == 'y':
            d += int(div[:-1]) * 365
        elif div[-1] == 'd':
            d += int(div[:-1])
        elif div[-1] == 'h':
            d += int(div[:-1]) / 24.0
        elif div[-1] == 'm':
            d += int(div[:-1]) / (24.0 * 60)
        elif div[-1] == 's':
            d += int(div[:-1]) / (24.0 * 3600)
        else:
            d += 0
    
    return d
    
def parseClassText(text):
    """Parses a section of a class
    
    Returns:
    - stats: a pandas Series of the class stats
    """
    labels = [li.text[:-2] for li in pq(text)("li")]
    stats = [span.text for span in pq(text)(".stat-kills")]
    stats[0] = parsePlaytime(stats[0])
    stats = [float(x) for x in stats]
    
    if not "HP Restored" in labels:
        labels.append("HP Restored")
        stats.append(0.0)
    
    if not "Headshots" in labels:
        labels.append("Headshots")
        stats.append(0.0)
    
    labels = [l.lower().replace(' ', '_') for l in labels]
    
    return pd.Series({labels[i]: stats[i] for i in range(min(len(labels), len(stats)))})

def getAvailableClasses(ctf):
    res = []
    for c in ctfClasses:
        if len(ctf(f"#ctfAdditionalDetailsDisplay{c.upper()}")) > 0:
            res.append(c)

    return res

def getPlayerStats(player):
    """Retrieves the CTF stats of a particular player
    
    Returns:
    - stats: Dictionary of stats for each class as well as an aggregate (accessible with `stats["Total"]`). Returns `None` if 
    there is no player found for that name
    
    Usage:
    Get the stats of a player
        ```
            stats, response = getPlayerStats("915")
        ```
    Then view stats breakdown:
        ```
            stats["Elf"] # stats for Elf class
            stats["Elf"]["flags_captured"] # flags captured while Elf
            stats["Total"]["kdr"] # overall KDR (please don't look, it's horrible)
        ```
    """
    r = requests.get(f"http://brawl.com/players/{player}")
    if r.status_code == 200:
        ctf = pq(r.text)
        
        clist = getAvailableClasses(ctf)
        
        # print(f"Detected classes: {clist}")

        stats = {c: parseClassText(extractClassText(ctf, c)) for c in clist}
        df = pd.DataFrame([stats[c] for c in clist])
        return stats
    else:
        print(r.status_code)
        return None

def generateCasualLeaderboards():
    print("Creating casual leaderboards..")
    names = getNames()
    leaderboard = {c: pd.DataFrame() for c in ctfClasses}

    for name in names:
        name = name[:-1]
        data = getPlayerStats(name)
        if data is None:
            print(f"Could not retrieve casual stats for player {name}")
            continue
        for c in ctfClasses:
            if c in data:
                s = data[c]
                s["name"] = name

                leaderboard[c] = leaderboard[c].append(s, ignore_index=True)
    
    for c in ctfClasses:
        leaderboard[c] = leaderboard[c].reindex(columns=column_order)
        leaderboard[c] = leaderboard[c].replace([np.inf], np.nan).fillna(0).round(3)
        # print(f"Casual {c} leaderboard")
        # print(leaderboard[c].head())
        leaderboard[c].to_csv(f"leaderboards/casual/{c}.csv", index=False)

def generateCompetitiveLeaderboards():
    """Generates the competitive leaderboards
    
    This groups the downloaded files by class, so the main `comp-stats.jl` needs to have been run previously before this method can work
    """
    files = glob("stats/*/*.csv")

    for c in ctfClasses:
        print(f"Creating competitive {c} leaderboard..")
        df = pd.DataFrame()
        for file in files:
            name = file.split("\\")[-1][:-4]
            data = pd.read_csv(file)
            data["name"] = name
            s = data[data.kit_type == c.upper()]

            if len(s) == 0:
                # print(f"Skipping {name}")
                continue
            
            s = s.iloc[0]
            
            entry = s[column_order]
            df = df.append(entry)
        
        df = df.reindex(columns=column_order)

        df.playtime /= 3600*24
        df = df.replace([np.inf], np.nan).fillna(0).round(3)
        # print(df.head())
        df.to_csv(f"leaderboards/competitive/{c}.csv", index=False)

if __name__ == "__main__":
    generateCasualLeaderboards()
    generateCompetitiveLeaderboards()