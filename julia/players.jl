using HTTP
using JSON

function getUnixTime()
    round(Int, time())
end

"Returns the UUID corresponding to the person who had name at the timestamp"
function getPlayerUUID(name, timestamp=getUnixTime())
    r = HTTP.get("https://api.mojang.com/users/profiles/minecraft/$(name)?at=$(timestamp)")
    text = String(r.body)
    
    if text == ""
        return nothing
    end
    
    json = JSON.parse(text)
end

"Returns the name history of the account with the UUID"
function getUUIDNames(uuid)
    r = HTTP.get("https://api.mojang.com/user/profiles/$(uuid)/names")
    text = String(r.body)
    
    if text == ""
        return nothing
    end
    
    json = JSON.parse(text)
end

"""Tries to map an old name to a new name, returns nothing if it fails

Parameters:
- name: Name of the player to check at the timestamp
- timestamp: timestamp at which the name was valid (default now)

Returns:
- name: Current name, if found, otherwise `nothing`
- uuid: UUID of player, if found, otherwise `nothing`
"""
function verifyPlayer(name, timestamp=getUnixTime())
    uuid_json = getPlayerUUID(name, timestamp)
    
    if isnothing(uuid_json)
        return nothing
    end
    
    if name != uuid_json["name"]
        names_json = getUUIDNames(uuid_json["id"])
        new_name = names_json[end]["name"]
        
        if length(names_json) == 1
            return nothing
        end
        
        if names_json[begin]["name"] == name
            return new_name, uuid_json["id"]
        end
        
        name_hist = reverse(names_json[2:end])
        for (i, entry) in enumerate(name_hist)
            cname = entry["name"]
            changedToAt = entry["changedToAt"] // 1000
            if cname == name
                new_entry = name_hist[begin]
                if new_entry["changedToAt"] > changedToAt
                    return new_name, uuid_json["id"]
                end
            end
        end
        
        return nothing
                
    end
    
    return name, uuid_json["id"]
end