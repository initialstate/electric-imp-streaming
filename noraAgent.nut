#require "Firebase.class.nut:1.0.0"
#require "InitialState.class.nut:1.0.0"

///////// Application Code ///////////

// VARIABLES
agentID <- split(http.agenturl(), "/").pop();

// Initialize the Initial State streamer with Access Key (required),
// Bucket Key (optional), and Bucket Name (optional)
is <- InitialState("Your_Access_Key","nora",":smiling_imp: Electric Imp Nora");

// APPLICATION FUNCTIONS

// save settings to local storage
function saveSettings(settings) {
    server.save({ "settings" : settings });
}

// check local storage for settings and sync with device
function getSettings(dummy) {
    local persist = server.load();

    // if no settings request from device
    if (!("settings" in persist)) { device.send("getDeviceSettings", null); }
    
    // if have settings send to device
    if ("settings" in persist) { device.send("agentSettings", persist.settings); }
}

// overwrite default reading/reporting interval
// settings is a table 
function updateSettings(settings) {
    local persist = server.load();
    if ("settings" in persist) {
        if ( !("readingInt" in settings) ) {
            settings.readingInt <- persist.settings.readingInt;
        }
        if ( !("reportingInt" in settings) ) {
            settings.reportingInt <- persist.settings.reportingInt;
        }
    }
    saveSettings(settings);
    device.send("agentSettings", settings);
}

// Send data to Initial State
function storeData(data) {
    server.log(data.len());
    foreach(sensor, readings in data) {
        server.log(readings);
        server.log(sensor + " " + http.jsonencode(readings));
        buildQue(sensor, readings, writeQueToIS)
    }
    device.send("ack", "OK");
}

// Sort readings by timestamp
function buildQue(sensor, readings, callback) {
    readings.sort(function (a, b) { return b.epoch <=> a.epoch });
    callback(sensor, readings);
}

// Loop that sends readings to Initial State
function writeQueToIS(sensor, que) {
    local events = [];
    while (que.len() > 0) {
        local reading = que.pop();
        events.append(reading);
    }
    // Send readings to Initial State
    is.sendEvents(events, function(err, data) {
        if (err != null) server.error("Error: " + err);
    })
}



// DEVICE LISTENERS
device.on("deviceSettings", saveSettings);
device.on("getAgentSettings", getSettings);
device.on("data", storeData);

// // Uncomment if you want to update reading and/or reporting intervals
//local newSettings = {"reportingInt" : 30, "readingInt": 15};
//updateSettings(newSettings);
