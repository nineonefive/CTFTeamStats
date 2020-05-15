function CardRow(match) {
    return (
        <div class="row py-2">
            <div class="col-sm-3"></div>
            <div class="col-sm">
                {Match(match)}
            </div>
            <div class="col-sm-3"></div>
        </div>
    );
}

function Match(match) {
    return (
        <div class={"card " + ((match.conference == "red") ? "bg-danger" : (match.conference == "blue") ? "bg-info" : "")} style={{color: "white"}}>
            <div class="card-body" data-toggle="collapse" data-target={"#card-content-" + match.uuid}>
                <h4 class="card-title">
                    <span class="d-none d-lg-inline badge badge-pill badge-light align-middle">{match.team1.sym}</span>
                    {" " + match.team1.name + " vs. " + match.team2.name + " "}
                    <span class="d-none d-lg-inline badge badge-pill badge-light align-middle">{match.team2.sym}</span>
                </h4>
                <div class="row d-flex justify-content-between px-3">
                    {Scores(match.team1, match.team2, match.maps)}
                    {MVPPills([match.team1.mvp, match.team2.mvp])}
                </div>
            </div>

            {CardContent(match.uuid, match.team1, match.team2, match.maps)}
        </div>
    );
}

Array.prototype.last = function() { return this[this.length - 1]; }

/**
 * Shows map scores
 * @param {Team} team1 
 * @param {Team} team2 
 * @param {Array<Map>} maps 
 */
function Scores(team1, team2, maps) {
    const scores = maps.map(map => 
        <span>
            <span class="badge badge-pill badge-light">{map.team1Caps.length + "-" + map.team2Caps.length}</span>
            {((map.id == maps.last().id) ? null : " / ")}
        </span>
    );

    // console.log(maps.map(map => [map.team1Score, map.team2Score]))
    // console.log(scores)

    return (
        <span class="scores">
            {scores}
        </span>
    );
}

/**
 * Shows the MVPs
 * @param {Array<string>} names Names to display
 */
function MVPPills(names) {
    // console.log("Generating mvps: " + names )
    const mvps = names.map(name => MVP(name));
    // console.log(mvps);
    return (
        <span class="mvps">
            <b class="d-none d-lg-inline">MVP:&nbsp;</b> 
            {mvps}
        </span>
    );
}

function MVP(name) {
    return (
        <span>
            <span class="badge badge-pill bg-dark">
                <img src={"http://cravatar.eu/avatar/" + name + "/15.png"} />&nbsp;
                {name}
            </span>&nbsp;
        </span>
    );
}

/**
 * Collapsable card content for match details
 * @param {string} id unique identifier for the card collapsing
 * @param {Team} team1 Team object 1
 * @param {Team} team2 Team object 2
 * @param {Array<Map>} maps List of maps for the match
 */
function CardContent(id, team1, team2, maps) {
    // console.log("Generating card content for card " + id);
    // console.log(maps.length + " maps found");
    return (
        <div class="collapse bg-white" id={"card-content-" + id} style={{color: "black"}}>
            <ul class="list-group list-group-flush">
                {DisplayHeader(team1, team2)}
                {DisplayMaps(maps)}
            </ul>
        </div>
    );
}

function DisplayHeader(team1, team2) {
    return (
        <li class="list-group-item">
            <div class="row">
                <div class="col">
                    <b>Map</b>
                </div>
                <div class="col">
                    <b>{team1.sym} Caps</b>
                </div>
                <div class="col">
                    <b>{team2.sym} Caps</b>
                </div>
            </div>
        </li>
    );
}

function DisplayMaps(maps) {
    return maps.map(map => MapDisplay(map));
}

/**
 * Shows single map performance in a row
 * @param {Map} map 
 */
function MapDisplay(map) {
    // console.log("Displaying map " + map.name);
    return (
        <li class="list-group-item">
            <div class="row">
                <div class="col">
                    <a class="game-link" target="blank" href={"https://www.brawl.com/games/ctf/lookup/" + map.id}>{map.name}</a>
                </div>
                <div class="col">
                    <div class="d-flex flex-column">
                        {map.team1Caps.map(cap => Player(cap.name, cap.time, true))}
                    </div>
                </div>
                <div class="col">
                    <div class="d-flex flex-column">
                        {map.team2Caps.map(cap => Player(cap.name, cap.time, true))}
                    </div>
                </div>
            </div>
        </li>
    );
}

/**
 * Shows player head next to name with optional time
 * @param {string} player Name of the player to display
 * @param {string} time (Optional) timestamp to include for caps
 */
function Player(player, time=null, collapse=false) {
    return (
        <span class="player">
            {(time == null) ? null : <span style={{fontFamily: 'monospace'}}>({time})</span>} <img src={"http://cravatar.eu/avatar/" + player + "/15.png"} /> <p class={(collapse) ? "d-none d-lg-inline" : ""}>{player}</p>
        </span>
    );
}