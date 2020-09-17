using JSON

"Gets the metadata of `metadata.json` "
function getMetadata()
    metadata = open("metadata.json", "r") do io
        lines = readlines(io)
        json = JSON.parse(join(lines, " "))
        (json)
    end

    return metadata
end

"Returns the time that the names were last updated"
function getNameUpdateTime()
    metadata = getMetadata()
    metadata["names_updated"]
end