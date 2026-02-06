# OPNhydroponics - Hardware Architecture

## System Overview

ESP32-C6 based NFT hydroponics controller with full sensor suite and dosing pump control, designed for Home Assistant integration via ESPHome.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           24V DC INPUT                                   │
│                               │                                          │
│                    ┌──────────┼──────────┐                               │
│                    │          │          │                               │
│                    ▼          ▼          ▼                               │
│              ┌─────────┐ ┌─────────┐ ┌─────────┐                         │
│              │ 24V Bus │ │ 12V DC  │ │ 5V DC   │                         │
│              │ (Pump)  │ │ (Dosing)│ │ (Logic) │                         │
│              └────┬────┘ └────┬────┘ └────┬────┘                         │
│                   │           │           │                              │
│                   ▼           ▼           ▼                              │
│            ┌──────────┐ ┌──────────┐ ┌──────────┐                        │
│            │Main Pump │ │ Dosing   │ │ 3.3V LDO │                        │
│            │ MOSFET   │ │ MOSFETs  │ │          │                        │
│            └──────────┘ └──────────┘ └────┬─────┘                        │
│                                           │                              │
│                                    ┌──────┴──────┐                       │
│                                    │  ESP32-C6   │                       │
│                                    │             │                       │
│                                    └──────┬──────┘                       │
│                                           │                              │
│         ┌─────────────┬─────────────┬─────┴─────┬─────────────┐          │
│         │             │             │           │             │          │
│    ┌────┴────┐  ┌─────┴─────┐ ┌─────┴─────┐ ┌───┴───┐  ┌──────┴──────┐   │
│    │  I2C    │  │  1-Wire   │ │  GPIO     │ │ UART  │  │    SPI      │   │
│    │  Bus    │  │  Bus      │ │           │ │       │  │  (future)   │   │
│    └────┬────┘  └─────┬─────┘ └─────┬─────┘ └───────┘  └─────────────┘   │
│         │             │             │                                    │
│    ┌────┴───────┐     │        ┌────┴─────┐                              │
│    │ pH EZO     │     │        │Ultrasonic│                              │
│    │ EC EZO     │     │        │ HC-SR04  │                              │
│    │ DO EZO     │     │        └──────────┘                              │
│    │ BH1750     │     │                                                  │
│    │ BME280     │     │                                                  │
│    │ OLED       │     │                                                  │
│    └────────────┘     │                                                  │
│                       │                                                  │
│               ┌───────┴───────┐                                          │
│               │   DS18B20     │                                          │
│               │ (Water Temp)  │                                          │
│               └───────────────┘                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

### 1. Probe Isolation Strategy

To prevent ground loops and probe interference (especially between pH and EC), we use:

**Option A: Time-Division Multiplexing (Budget)**
- Single non-isolated ADC (ADS1115)
- MOSFET switches to power probes sequentially
- Only one probe powered at a time
- Cost: ~$15 for all probe interfaces

**Option B: EZO-Style I2C Circuits (Recommended)**
- Each probe has dedicated I2C interface circuit
- Galvanically isolated power per probe
- All probes can read simultaneously
- Cost: ~$60-150 depending on source (Atlas vs clones)

**Selected: Option B** - Better accuracy, easier software, worth the cost for medium scale.

### 2. Dosing Pump Selection

Peristaltic pumps recommended for:
- Self-priming capability
- Precise volume control via timing
- Chemical resistance
- No contamination between fluids

Specification:
- Voltage: 12V DC
- Flow rate: 1-3 mL/s adjustable via PWM
- Tubing: Silicone, 3mm ID

### 3. ESP32-C6 Module Selection

Options:
- **ESP32-C6-WROOM-1** - Standard module, good availability
- **ESP32-C6-MINI-1** - Smaller footprint

Selected: **ESP32-C6-WROOM-1-N8** (8MB flash) for easier hand soldering and good flash size.

## Pin Assignment

| GPIO | Function | Notes |
|------|----------|-------|
| 0 | BOOT | Button to GND |
| 1 | I2C SDA | Sensors, display |
| 2 | I2C SCL | Sensors, display |
| 3 | 1-Wire | DS18B20 temp probes |
| 4 | Ultrasonic TRIG | Water level |
| 5 | Ultrasonic ECHO | Water level |
| 6 | Main Pump PWM | 24V pump control |
| 7 | Dosing 1 (pH Up) | 12V peristaltic |
| 8 | Dosing 2 (pH Down) | 12V peristaltic |
| 9 | Dosing 3 (Nutrient A) | 12V peristaltic |
| 10 | Dosing 4 (Nutrient B) | 12V peristaltic |
| 11 | Float Switch 1 | Low level alarm |
| 12 | Float Switch 2 | High level (optional) |
| 13 | Status LED | WS2812B RGB |
| 15 | TX (UART) | Debug/programming |
| 16 | RX (UART) | Debug/programming |
| 18 | USB D- | Native USB |
| 19 | USB D+ | Native USB |
| 20 | Probe Power Enable | Isolator control |
| 21 | Spare GPIO | Future expansion |
| 22 | Spare GPIO | Future expansion |
| 23 | Spare GPIO | Future expansion |

## Power Architecture

```
24V DC Input (2A min)
    │
    ├──► 24V Rail ──► Main Pump MOSFET (IRLZ44N or similar)
    │
    ├──► XL4015 Buck ──► 12V @ 3A ──► Dosing Pump MOSFETs
    │                                  (4x IRLZ44N)
    │
    └──► MP1584 Buck ──► 5V @ 2A ──► USB/Sensors
                              │
                              └──► AMS1117-3.3 ──► 3.3V @ 800mA ──► ESP32-C6
                                                                    │
                                                   Isolated DC-DC ──┘
                                                   (per probe)
```

### Power Budget

| Component | Voltage | Current (typ) | Current (max) |
|-----------|---------|---------------|---------------|
| ESP32-C6 | 3.3V | 80mA | 350mA |
| pH EZO circuit | 3.3V | 15mA | 50mA |
| EC EZO circuit | 3.3V | 15mA | 50mA |
| DO EZO circuit | 3.3V | 15mA | 50mA |
| BME280 | 3.3V | 1mA | 3mA |
| BH1750 | 3.3V | 0.2mA | 1mA |
| DS18B20 (×2) | 3.3V | 2mA | 4mA |
| OLED Display | 3.3V | 20mA | 30mA |
| HC-SR04 | 5V | 2mA | 15mA |
| WS2812B LED | 5V | 20mA | 60mA |
| **3.3V Total** | | ~150mA | ~550mA |
| **5V Total** | | ~25mA | ~80mA |
| Dosing Pump (each) | 12V | 0 (idle) | 300mA |
| **12V Total** | | 0 | 1.2A |
| Main Pump | 24V | 500mA | 1.5A |
| **24V Total** | | 500mA | 1.5A |

## Sensor Specifications

### pH Sensor
- Type: Glass electrode with BNC connector
- Range: 0-14 pH
- Accuracy: ±0.1 pH
- Interface: I2C via EZO circuit (address 0x63)
- Calibration: 2 or 3 point (pH 4, 7, 10)

### EC/TDS Sensor
- Type: 2-electrode conductivity probe, K=1.0
- Range: 0-20,000 µS/cm
- Accuracy: ±2%
- Interface: I2C via EZO circuit (address 0x64)
- Calibration: Dry, single or dual point

### Dissolved Oxygen Sensor
- Type: Galvanic DO probe
- Range: 0-20 mg/L
- Accuracy: ±0.2 mg/L
- Interface: I2C via EZO circuit (address 0x61)
- Note: Membrane replacement every 6-12 months

### Water Temperature
- Type: DS18B20 waterproof probe
- Range: -55 to +125°C
- Accuracy: ±0.5°C
- Interface: 1-Wire (parasite or powered)

### Water Level
- Primary: HC-SR04 ultrasonic (non-contact)
- Backup: Float switches (alarm/safety)
- Range: 2-400cm
- Accuracy: ±3mm

### Air Temperature/Humidity
- Type: BME280
- Temp range: -40 to +85°C
- Humidity range: 0-100% RH
- Accuracy: ±1°C, ±3% RH
- Interface: I2C (address 0x76 or 0x77)

### Light/PAR
- Type: BH1750 (lux meter)
- Range: 1-65535 lux
- Interface: I2C (address 0x23 or 0x5C)
- Note: For true PAR, multiply lux by ~0.015 for typical grow lights

## PCB Design Requirements

### Board Specifications
- Size: 100mm × 80mm (fits common enclosures)
- Layers: 2 (4-layer preferred for EMI)
- Copper: 2oz outer layers (for power traces)
- Finish: HASL or ENIG

### Connector Selection
| Function | Connector Type |
|----------|----------------|
| 24V Power | 5.5×2.1mm barrel or screw terminal |
| Main Pump | 2-pin screw terminal (5.08mm) |
| Dosing Pumps | 4×2-pin JST-XH or screw terminal |
| pH/EC/DO Probes | BNC female (panel mount) or SMA |
| I2C Sensors | 4-pin JST-PH (Qwiic compatible) |
| 1-Wire | 3-pin JST-PH |
| Float Switches | 2-pin JST-XH |
| Ultrasonic | 4-pin JST-XH |
| OLED Display | 4-pin header or JST-PH |
| Programming | USB-C |

### Protection Features
- Reverse polarity protection (P-MOSFET)
- Overvoltage protection (TVS diodes)
- ESD protection on all external connections
- Fused inputs (resettable PTC)
- Optocoupler isolation on pump outputs (optional)

### EMC Considerations
- Keep analog traces away from switching supplies
- Ground plane under ESP32-C6 antenna keep-out
- Decoupling capacitors close to ICs
- Ferrite beads on power inputs

## Enclosure

Recommended: IP65 rated ABS enclosure, ~150×100×70mm
- Cable glands for all wiring
- Panel-mount BNC connectors for probes
- Optional: Clear lid for status LED visibility
