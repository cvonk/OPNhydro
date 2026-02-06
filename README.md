# ESP32-C6 Hydroponics Controller

A fully autonomous, data-rich hydroponics automation system with precision control and remote monitoring.

## Project overview

Build a custom ESP32-C6-based controller for hydroponics/aquaponics that monitors water quality and environment, automatically doses nutrients and adjusts pH, logs everything to Home Assistant, and provides rich dashboards.

* Domain: Hydroponics/Aquaponics
* Scope: Go big (custom PCB)
* Goals: Autonomous + Data + Precision + Remote
* Available parts: Environmental sensors (BME280, etc.), pumps/solenoids
* Infrastructure: Home Assistant and Google Home already running, both supporting Matter/Thread


## Idea

Category	        | Selection
------------------|-----------
System	          | Nutrient Film Technique (NFT), 20-60 plants
Integration       | Home Assistant/Wifi via ESPHome first, then add Matter/Thread.
Analytics         | InfluxDB and Grafana
Controller        | ESP32-C6 based custom PCB with daughter boards


## Bill of Materials

### Sensors (Water Quality)

Purpose               | Interface     | Component     | Description
----------------------|---------------|---------------|-------------
pH sensor	            | analog to I2C | ENV-40-pH     | Atlas Scientific lab grade pH probe
EC sensor             | analog to i2C | ENV-40-EC-K10 | Atlas Scientific conductivity probe K 1.0
Water temp            | 1-wire        | DS18B20       | waterproof water temperature sensor, 3.3V - 5V 
Reservoir water level | GPIO          | JSN-SR04T     | waterproof ultrasonic distance sensor, 3.3V - 5V, 20 - 600 cm range

### Sensors (Environment)

Purpose                | Interface     | Component     | Description
-----------------------|---------------|---------------|-------------
Temp/humidity/pressure | I2C           | BME280        | optional Air temp, humidity, pressure
Light intensity        | I2C           | BH1750        | optional Light intensity (lux)

### Actuators

Purpose               | Interface      | Component        | Description
----------------------|----------------|------------------|-------------
pH down               | GPIO PWM/Relay |                  | Peristaltic pump, 12V
Nutrient A up         | GPIO PWM/Relay |                  | Peristaltic pump, 12V
Nutrient B up         | GPIO PWM/Relay |                  | Peristaltic pump, 12V
Water inlet valve     |                | Hunter 3/​4 in.   | Anti-siphon irrigation valve
Circulation pump      | GPIO Relay     | AUBIG DC40E-1250 | Submersible pump, 12V, 500 l/hr, 5 m head
Optional air pump     | GPIO Relay     |                  | Air pump 

### Core Electronics

Purpose                 | Component               | Description
------------------------|-------------------------|-------------
Main controller         | ESP32-C6-DevKitC-1-N8   | SoC supporting Matter over Thread or WiFi
pH sensor interface     | EZO-pH                  | Atlas Scientific pH SNA to I2C daughter board
EC sensor interface     | EZO-EC                  | Atlas Scientific EC SNA to I2C daughter board
Logic level shifters  	|                         | 3.3V ↔ 5V for sensors
Power supply            |                         | 12 V, 3 A, 5.5 mm male barrel plug
MOSFETs                 | IRLZ44N                 | PWM actuator control
Power input             |                         | panel mount 5.5mm female barrel socket for 12 V power

### Other

Category	        | Selection
------------------|-----------
Channels          | 4× e.g. AmHydro finishing channel 52 inch (amhydro.com)
Valves            | manual valve for each channel, and drain valve for each group
Seedlings         | e.g. Lettuce seeds, hydroponic performer, pelleted seeds such as Rex (or Nancy, Salanova red oakleaf) (johnnyseeds.com)
Nutrients         | e.g. AmHydro Lettuce Nutrients  (amhydro.com)
Growth medium     | e.g. Oasis Horticubes 162CT (LC-1) 5225 (amhydro.com)
pH down liquid    | e.g. hydroponics pH-down liquid, 1-Gallon (amazon.com)
Filter            | add filter in return path. e.g. foam gutter filter insert
Slope             | about 2 degrees (make adjustable)
Tubing            | various rigid and flexible tubing and adapters


## Software Features

### User Interface 

* Home Assistant
* Matter/Thread, for Google Home and Apple Homekit support

### Control Algorithms

1. pH Control - PID controller maintaining target pH (5.5-6.5 typical)
   * Hysteresis to prevent oscillation
   * Configurable dosing intervals and max doses
   * Safety limits (never dose if pH is within acceptable range)

2. EC Control - Proportional nutrient dosing
   * Target EC based on growth stage
   * Ratio-based A/B dosing
   * Top-off detection (EC drop = water added, don't dose)

3. Scheduling
   * Circulation pump intervals
   * Air pump duty cycle

### Data & Analytics

* Home Assistant - Real-time entity display, automations, notifications
* InfluxDB - Long-term time-series storage
* Grafana - Rich visualization dashboards:
   * pH/EC trends over time
   * Nutrient consumption tracking
   * Environmental correlations
   * Growth stage timeline

### Autonomous Features

* Auto-calibration reminders (pH probe drift)
* Reservoir refill alerts
* Anomaly detection (sudden pH/EC swings, water leaks)
* Nutrient depletion estimates
* "Vacation mode" - conservative dosing


## Custom PCB Design

### Features

* ESP32-C6-DevKitC-1-N8 module footprint (has USB C for programming)
* EZO-pH module footprint for Atlas Scientific pH SNA to I2C daughter board
* EZO-EC module footprint for Atlas Scientific EC SNA to I2C daughter board
* JSN-SR04T module footprint for Ultrasonic sensor
* Isolated analog input section (to reduce noise)
* SNA connectors for pH/EC probes
* Screw terminals for pump connections
* Fixed terminal block for other inputs, e.g. Phoenix-Contact 1862437
* Status LEDs for each channel
* Optional: RS-485 for expansion

### Stackup

* 2-layer board sufficient
* Ground plane under analog section
* Star grounding for analog/digital separation
