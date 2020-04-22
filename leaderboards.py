import numpy as np
import pandas as pd
from glob import glob
from pathlib import Path

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

if __name__ == "__main__":
    files = glob("stats/*/*.csv")

    for c in ctfClasses:
        print(f"Creating {c} leaderboard..")
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
        print(df.head())
        df.to_csv(f"leaderboards/{c}.csv", index=False)