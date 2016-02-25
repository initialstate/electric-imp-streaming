// Device Code
// Adapted from Electric Imp's Nora example: https://electricimp.com/docs/hardware/resources/reference-designs/nora/

// Temperature/Humidity 
#require "Si702x.class.nut:1.0.0"
// Light/Proximity 
#require "Si114x.class.nut:1.0.0"
// Air Pressure 
#require "LPS25H.class.nut:2.0.0"
// Magnetometer 
#require "LIS3MDL.class.nut:1.0.1"
// Temperature 
#require "TMP1x2.class.nut:1.0.1"
// Accelerometer 
#require "LIS3DH.class.nut:1.0.1"

// Custom built class to handle the sensors on Nora.  
// This class does not have all the functionality for each sensor implemented. 
// Current functionality includes:
    // All sensors can take readings
    // Temperature sensor interrupt 
    // Accelerometer sensor free fall interrupt
// You should modify this class to suit your specific needs.
class HardwareManager {
    
    // 8-bit left-justified I2C address for sensors on Nora
    // Temp
    static TMP1x2_ADDR = 0x92; 
    // Temp/Humid
    static Si702x_ADDR = 0x80;
    // Amb Light
    static Si1145_ADDR = 0xC0; 
    // Accelerometer
    static LIS3DH_ADDR = 0x32;
    // Air Pressure
    static LPS25H_ADDR = 0xB8; 
    // Magnetometer
    static LIS3MDL_ADDR = 0x3C;
    
    // Wake Pins for sensors on Nora
    static TEMP_PIN = hardware.pinE; 
    static AMBLIGHT_PIN = hardware.pinD; 
    static ACCEL_PIN = hardware.pinB;
    static AIR_PRESS_PIN = hardware.pinA; 
    static MAG_PIN = hardware.pinC;
    static ALERT_PIN = hardware.pin1;
    
    // Wake Pin Polarity if Event is Triggered
    static TEMP_EVENT = 0;
    static AMBLIGHT_EVENT = 0;
    static ACCEL_EVENT = 1;
    static AIR_PRESS_EVENT = 1;
    static MAG_EVENT = 0;
    static ALERT_EVENT = 1;
    
    // Variables to store initialized sensors 
    _temp = null;
    _tempHumid = null;
    _ambLight = null;
    _accel = null;
    _airPress = null;
    _mag = null;
    
    _i2c = null;
    
    constructor() {
        _configureI2C();
        _initializeSensors();
        _configureWakePins();
    }
    
    /////////// Private Functions ////////////
    
    function _configureI2C() {
        _i2c = hardware.i2c89;
        _i2c.configure(CLOCK_SPEED_400_KHZ);
    }
    
    function _initializeSensors() {
        _temp = TMP1x2(_i2c, TMP1x2_ADDR);
        _tempHumid = Si702x(_i2c, Si702x_ADDR);
        _ambLight = Si114x(_i2c, Si1145_ADDR);
        _accel = LIS3DH(_i2c, LIS3DH_ADDR);
        _airPress = LPS25H(_i2c, LPS25H_ADDR);
        _mag = LIS3MDL(_i2c, LIS3MDL_ADDR);
    }
    
    function _configureWakePins() {
        AIR_PRESS_PIN.configure(DIGITAL_IN);
        ACCEL_PIN.configure(DIGITAL_IN);  
        MAG_PIN.configure(DIGITAL_IN);    
        AMBLIGHT_PIN.configure(DIGITAL_IN);    
        TEMP_PIN.configure(DIGITAL_IN);    
        ALERT_PIN.configure(DIGITAL_IN_WAKEUP);
        
        // disable unused interrupts
        ambLightDisableInterrupt();
        pressureDisableInterrupt();
        
        // mag needs to be configured 
        // for wake pins on nora to work properly
        _mag.configureInterrupt(true);
    }  
    
    
    ///////// Sleep & Wake Functions //////////
    
    function setLowPowerMode() {
        // ambLight low power mode
        _ambLight.enableALS(false);
        _ambLight.enableProximity(false);
        _ambLight.setDataRate(0);
        
        // mag
        _mag.enable(false);
    }
    
    function configureSensors() {
        configureAccel();
        configurePressure();
        configureMagnetometer();
        configureTemp();
    }
    
    //////// Temp sensor Functions //////// 
    
    function configureTemp() {
        _temp.setActiveLow();
        _temp.setShutdown(0);
    }
    
    function tempRead(callback) {
        _temp.read(function(result) {
            if("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, {"temperature" : result.temp});
            }
        })
    }
    
    // opts format - {"mode" : "interrupt", "low" : 20, "high" : 30}
    function tempConfigureInterrupt(opts) {
        if ("mode" in opts) {
            if (opts.mode == "comparator") {
                _temp.setModeComparator();
            }
            if (opts.mode == "interrupt") {
                _temp.setModeInterrupt();
            }
        }
        if ("high" in opts) {
            _temp.setHighThreshold(opts.high);
            // server.log("Temp high threshold set: " + _temp.getHighThreshold());
        }
        if ("low" in opts) {
            _temp.setLowThreshold(opts.low);
            // server.log("Temp low threshold set: " + _temp.getLowThreshold());
        }
    }   
    
    ///////// Temp/Humid Sensor Functions /////////
    
    function tempHumidRead(callback) {
        _tempHumid.read(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, result);
            }
        });
    }
    
    //////// Light/Proximity Sensor Functions ///////
    
    function lightRead(callback) {
        _ambLight.enableALS(true);
        _ambLight.forceReadALS(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                // result table contains: visible, ir and uv
                callback(null, result);
            }
        });
    }
    
    function proximityRead(callback) {
        _ambLight.enableProximity(true);
        _ambLight.forceReadProximity(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, result)
            }
        });
    }
    
    function ambLightDisableInterrupt() {
        _ambLight.configureDataReadyInterrupt(false);
    }
    
    //////// Accelerometer Sensor Functions ///////
    
    function configureAccel() {
        _accel.init();
        _accel.enable(true);
        _accel.setDataRate(50); 
        _accel.setLowPower(true); 
    }
       
    function accelRead(callback) {
        _accel.getAccel(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, {"accelerometer": result});
            }
        });
    }
    
    function configureAccelFreeFallInterrupt(state, threshhold = 0.5, duration = 15) {
        _accel.configureInterruptLatching(true);
        _accel.configureFreeFallInterrupt(state, threshhold, duration);
    }

    function getAccelInterruptTable() {
        return _accel.getInterruptTable();
    }
    
    ///////// Pressure Sensor //////////
    
    function configurePressure() {
        _airPress.softReset();
        _airPress.enable(true);
    }
    
    function pressureRead(callback) {
        _airPress.read(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, result);
            }
        });    
    } 
    
    function pressureDisableInterrupt() {
        _airPress.configureInterrupt(false);
    }
    
    ///////// Magnetometer Sensor //////////
    
    function configureMagnetometer() {
        _mag.enable(true);
    }
    
    function magetometerRead(callback) {
        _mag.readAxes(function(result) {
            if ("err" in result) {
                callback(result.err, null);
            } else {
                callback(null, {"magnetometer" : result});
            }
        });    
    } 
    
}

// Custom built class to handle locaally stored data, 
// wakeup, connection, and sending data.
// Constructor takes 2 parameters:
    // 1st: reading interval - number of seconds between scheduled readings
    // 2nd: reporting interval - number of seconds between scheduled 
    //      connections to send data to the agent. 
// You should modify this class to suit your specific needs.

class localDataManager {
    readingInt = null;
    reportingInt = null;
    
    constructor(_reading, _reporting) {
        readingInt = _reading;
        reportingInt = _reporting;
        
        // Take reading(s) every minute
        readingInt = 60;
        // Send reading(s) every 5 minutes
        reportingInt = 300;
        _configureNV();
    }
    
    function setReadingInt(newReadingInt) {
        readingInt = newReadingInt;
    }
    
    function setReportingInt(newReportingInt) {
        reportingInt = newReportingInt;
    }
    
    function getReadingInt() {
        return readingInt;
    }
    
    function getReportingInt() {
        return reportingInt;
    }
    
    function setNextWake() {
        nv.nextWake <- (time() + readingInt);
    }
    
    function setNextConnect() {
        nv.nextConnect <- (time() + reportingInt);
    }
    
    function readingTimerExpired() {
        if (time() > nv.nextWake) { return true; }
        return false
    }
    
    function reportingTimerExpired() {
        if (time() > nv.nextConnect) { return true; }
        return false        
    }
    
    function storeData(sensorName, data) {
        // add time stamp to data
        data.epoch <- time();
        // make sure sensor has a slot in nv
        if (!(sensorName in nv.data)) {
            nv.data[sensorName] <- [];
        }
        
        // add data to sensor's data array
        nv.data[sensorName].push(data);
    }
    
    function sendData() {
        agent.send("data", nv.data)
    }
    
    function clearNVReadings() {
        nv.data <- {};
    }
    
    function _configureNV() {
        local root = getroottable();
        if ( !("nv" in root) ) { root.nv <- {}; }
        
        if ( !("nextWake" in nv) ) { setNextWake(); }
        if ( !("nextConnect" in nv) ) { setNextConnect(); }
        
        if ( !("data" in nv) ) { nv.data <- {}; }
    }
}

///////// Application Code ///////////

// CONSTANTS
const DEFAULT_READING_INTERVAL = 60;
const DEFAULT_REPORTING_INTERVAL = 300;
const READINGS_TIMEOUT = 2;
const BLINKUP_TIMEOUT = 10;
const TEMP_THRESH_LOW = 26;
const TEMP_THRESH_HIGH = 29;

// INITIALIZE CLASSES
nora <- HardwareManager();
ldm <- localDataManager(DEFAULT_READING_INTERVAL, DEFAULT_REPORTING_INTERVAL);

// APPLICATION FUNCTIONS

// Temperature and Accelerometer Interrupts
function setUpInterrupts() {
    nora.tempConfigureInterrupt({"mode" : "interrupt", "low" : TEMP_THRESH_LOW, "high" : TEMP_THRESH_HIGH});
    nora.configureAccelFreeFallInterrupt(true);
}

// Set up sensors
function setUpSensors() {
    nora.configureSensors();
    setUpInterrupts();
}

// Take readings from each sensor and store in NV
function takeReadings() {
    nora.tempRead(function(err, reading) {
        if (err) { server.log(err); }
        // Store the data in the format the Initial State library takes
        ldm.storeData("tempSensor", {"key": "tempSensor.temperature", "value": reading.temperature});
    });
    
    nora.tempHumidRead(function(err, reading) {
        if (err) { server.log(err); }
        ldm.storeData("tempHumidSensor", {"key": "tempHumidSensor.humidity", "value": reading.humidity});
        ldm.storeData("tempHumidSensor", {"key": "tempHumidSensor.temperature", "value": reading.temperature});  
    });
    
    nora.lightRead(function(err, reading) {
        if (err) { server.log(err); }
        ldm.storeData("ambLightSensor", {"key": "ambLightSensor.uv", "value": reading.uv});
        ldm.storeData("ambLightSensor", {"key": "ambLightSensor.visible", "value": reading.visible});
        ldm.storeData("ambLightSensor", {"key": "ambLightSensor.ir", "value": reading.ir});   
    });
    
    nora.proximityRead(function(err, reading) {
        if (err) { server.log(err); }
        ldm.storeData("ambLightSensor", {"key": "ambLightSensor.proximity", "value": reading.proximity});  
    });
    
    // nora.accelRead(function(err, reading) {
    //     if (err) { server.log(err); }
    //     ldm.storeData("accelerometerSensor", {"key": "accelerometerSensor.accelerometer.x", "value": reading.accelerometer.x});
    //     ldm.storeData("accelerometerSensor", {"key": "accelerometerSensor.accelerometer.y", "value": reading.accelerometer.y}); 
    //     ldm.storeData("accelerometerSensor", {"key": "accelerometerSensor.accelerometer.z", "value": reading.accelerometer.z});    
    // });
    
    nora.pressureRead(function(err, reading) {
        if (err) { server.log(err); }
        ldm.storeData("pressureSensor", {"key": "pressureSensor.pressure", "value": reading.pressure});   
    });
    
    nora.magetometerRead(function(err, reading) {
        if (err) { server.log(err); }
        ldm.storeData("magnetometerSensor", {"key": "magnetometerSensor.magnetometer.x", "value": reading.magnetometer.x});
        ldm.storeData("magnetometerSensor", {"key": "magnetometerSensor.magnetometer.y", "value": reading.magnetometer.y});  
        ldm.storeData("magnetometerSensor", {"key": "magnetometerSensor.magnetometer.z", "value": reading.magnetometer.z});    
    });
}

// Update next Wake and Connect times
function setTimers() {
    ldm.setNextWake();
    ldm.setNextConnect();
}

// Put Imp into Low power state 
// then sleep until next scheduled Wake time
function sleep() {
    local timer = nv.nextWake - time();
    
    nora.setLowPowerMode();
    // put imp to sleep
    server.log("going to sleep for " + timer + " sec");
    if (server.isconnected()) {
        imp.onidle(function() { server.sleepfor(timer); });
    } else {
        imp.deepsleepfor(timer);
    }
}

// Check if time to take readings and/or connect
// takes a parameter boolean value 
    // if true then sleep after checks
function checkTimers(ready) {
    // check reading timer
    if(ldm.readingTimerExpired()) {
        takeReadings();
        ldm.setNextWake();

        // wait for readings, then check reporting timer
        imp.wakeup(READINGS_TIMEOUT, function() {
            // check reporting
            if(ldm.reportingTimerExpired()) {
                ldm.sendData();
                ldm.setNextConnect();
            } else {
                if (ready) { sleep(); }
            }
        });
    } else {
        if (ready) { sleep(); }
    }
}

// Store reading and reporting interval on agent
function sendSettings(dummy) {
    local settings = {"readingInt" : ldm.readingInt, "reportingInt" : ldm.reportingInt};
    agent.send("deviceSettings", settings);
}

// Update reading and/or reporting intervals and update timers
function updateSettings(settings) {
    server.log("settings updated");
    if ("readingInt" in settings) { ldm.setReadingInt(settings.readingInt); }
    if ("reportingInt" in settings) { ldm.setReportingInt(settings.reportingInt); }
    setTimers();
}

// AGENT LISTENERS
agent.on("agentSettings", updateSettings);
agent.on("getDeviceSettings", sendSettings);
agent.on("ack", function(res) {
    ldm.clearNVReadings();
    sleep();
});

// WAKEUP LOGIC
switch(hardware.wakereason()) {
    case WAKEREASON_TIMER:
        server.log("WOKE UP B/C TIMER EXPIRED");
        setUpSensors();
        checkTimers(true);
        break;
    case WAKEREASON_POWER_ON:
        server.log("COLD BOOT");
        setUpSensors();
        agent.send("getAgentSettings", null);
        takeReadings();
        // Wait reasonable time for a blink up before going to sleep
        imp.wakeup(BLINKUP_TIMEOUT, sleep);
        break;
    default:
        server.log("WOKE UP B/C RESTARTED DEVICE, LOADED NEW CODE, ETC");
        setUpSensors();
        agent.send("getAgentSettings", null);
        takeReadings();
        // Wait for readings then sleep
        imp.wakeup(READINGS_TIMEOUT, sleep);
}
