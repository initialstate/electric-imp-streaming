// Agent Code

#require "InitialState.class.nut:1.0.0"

// Establish a local variable to hold environmental data
local lastReading = {};
lastReading.pressure <- 1013.25;
lastReading.temp <- 22;
lastReading.day <- true;
lastReading.lux <- 300;
lastReading.humid <- 0;

// Initialize the Initial State streamer with Access Key (required),
// Bucket Key (optional), and Bucket Name (optional)
is <- InitialState("qC6dQ25yOCP1j2AnIuH9JijTaLnNF5fD","imptail",":smiling_imp: Electric Imp + Env Tail");

// Add a function to post data from the device to your stream

function manageReading(reading) {
    // Note: reading is the data passed from the device, ie.
    // a Squirrel table with the key 'temp'

    // Print to the device logs that data is being posted
    server.log("manageReading called");
    
    // Create strings that round readings to 2 decimal places
    local tempString = format("%.2f", reading.temp);
    local humidString = format("%.2f", reading.humid);
    local pressString = format("%.2f", reading.pressure);
    local luxString = format("%.2f", reading.lux);

    // Send a particular message based on certain readings
    local day = reading.day;
    
    if (day == true) {
        dayString <- ":city_sunset:";
    } else {
        dayString <- ":night_with_stars:";
    }

    local diff = reading.pressure - lastReading.pressure;
    
    if (diff > 0) {
        diffString <- ":arrow_up: Rising";
    } else {
        diffString <- ":arrow_down: Falling";
    }
    
    // Send an array of events to Initial State
    is.sendEvents([
        {"key": ":thermometer: temperature (C)", "value": tempString},
        {"key": ":sweat_drops: humidity (%)", "value": humidString},
        {"key": ":balloon: pressure (hPa)", "value": pressString},
        {"key": ":arrow_up_down: pressure is", "value": diffString},
        {"key": ":alarm_clock: day or night?", "value": dayString},
        {"key": ":bulb: light level (lux)", "value": luxString},
    ], function(err, data) {
        if (err != null) server.error("Error: " + err);
    });
    
    lastReading = reading;
}


// Register the function to handle data messages from the device
device.on("reading", manageReading);
