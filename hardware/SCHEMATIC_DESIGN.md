# Schematic Design Guide

This document describes the circuit design for the OPNhydroponics controller PCB.

## Block Diagram

```
                       ┌─────────────────────────────────────────────────────┐
                       │                    CONNECTORS                       │
                       │  ┌─────┐ ┌─────┐ ┌─────┐  ┌──────────┐ ┌─────────┐  │
                       │  │ BNC │ │ BNC │ │ BNC │  │ Float SW │ │  LiDAR  │  │
                       │  │ pH  │ │ EC  │ │ RTD │  │  2×JST2P │ │  JST4P  │  │
                       │  └──┬──┘ └──┬──┘ └──┬──┘  └────┬─────┘ └────┬────┘  │
                       └─────┼───────┼───────┼──────────┼────────────┼───────┘
                             │       │       │          │            │
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    PCB                                          │
│  ┌─────────────┐   ┌───────────────────────────────────────────────────────┐    │
│  │   POWER     │   │                       SENSORS                         │    │
│  │             │   │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐       │    │
│  │ 24V ──►5V   │   │  │ EZO-pH │  │ EZO-EC │  │EZO-RTD │  │ BME280 │       │    │
│  │     ──►3.3V │   │  │  I2C   │  │  I2C   │  │  I2C   │  │  I2C   │       │    │
│  │             │   │  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘       │    │
│  └──────┬──────┘   │      └───────────┴───────────┴───────────┘            │    │
│         │          │                        │ I2C Bus                      │    │
│         │          │  ┌──────────────────┐  ┌───────────────────────────┐  │    │
│         │          │  │                  │  │    Float SW (×2)          │  │    │
│         │          │  │                  │  │    LOW:  GPIO0            │  │    │
│         │          │  │                  │  │    HIGH: GPIO1            │  │    │
│         │          │  └──────────────────┘  └───────────────────────────┘  │    │
│         │          └───────────────────────────────────────────────────────┘    │
│         │                                   │                                   │
│         │          ┌────────────────────────┴─────────────────────────────┐     │
│         │          │               ESP32-C6-WROOM-1                       │     │
│         │          │  ┌──────────────────────────────────────────────┐    │     │
│         └─────────►│  │  GPIO4/5: I2C        GPIO2:  ATO_VALVE       │    │     │
│                    │  │  GPIO7:   HC_TRIG    GPIO3:  HC_ECHO         │    │     │
│                    │  │  GPIO0:   FLOAT_LOW  GPIO1:  FLOAT_HIGH      │    │     │
│                    │  │  GPIO6:   EZO_PDIS   GPIO10: PUMP_MAIN       │    │     │
│                    │  │  GPIO11:  STEP_PH_DN GPIO15: STEP_NUT_A      │    │     │
│                    │  │  GPIO19:  STEP_NUT_B GPIO21/22: TMC_UART     │    │     │
│                    │  └──────────────────────────────────────────────┘    │     │
│                    └──────────────────────────────────────────────────────┘     │
│                                            │                                    │
│         ┌──────────────────────────────────┼──────────────────────────────┐     │
│         │           PUMP/VALVE DRIVERS (all 24V)                          │     │
│         │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐     │     │
│         │  │ 24V    │  │ 24V    │  │ 24V    │  │ 24V    │  │ 24V    │     │     │
│         │  │ Main   │  │ pH Dn  │  │ Nut A  │  │ Nut B  │  │ ATO    │     │     │
│         │  │ Pump   │  │ Dose   │  │ Dose   │  │ Dose   │  │ Valve  │     │     │
│         │  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘     │     │
│         └─────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Power Supply Section

The **main pump**, **stepper motors**, the **solenoid** and **buck converter** turns the PCB into a high-noise environment. Stepper drivers are notorious for creating Electromagnetic Interference (EMI) and ground bounce that can "ghost" your I2C bus or cause your pH readings to jump.

### 1.1. Protection Gauntlet

The 24V enters the board and passes through a "protection gauntlet" before it reaches the motor drivers or the sensitive sensor logic:

1. **DC Input Jack:** (Terminal Block).
2. **Main Fuse (F1):** 7A Fast-Acting. Not using PTC, because of Response Time and Voltage Drop. This provides a 32% headroom over the 5.3A peak, while still being close to 6.5A rating of the PSU.
3. **TVS Diode (D1):** 28V (SMCJ30A). If a massive overvoltage event occurs, the TVS diode will shunt the excess current to ground, potentially blowing the fuse but saving the rest of the PCB.
4. **Reverse Polarity Protection (T1):** If you plug the power in backward, this stops the current instantly, saving the TMC2209s.
5. **Main Bulk Capacitor (C3):** 1000µF 50V Electrolytic. The "local battery" that provides the surge current for simultaneaous motor steps.

**How the Reverse Polarity Protection works:**

Normal polarity (+24V at Source):
- 33kΩ pulls gate toward +24V
- Zener clamps gate at +12V (conducts in reverse/Zener mode when Vgate > 12V)
- Vgs = 12 − 24 = −12V → **FET fully ON** ✓
- Current through Zener: (24−12) / 33k = 0.36mA → 4.3mW dissipation, trivial

Reverse polarity (supply plugged backwards → Source at −24V):
- 33kΩ pulls gate toward 0V
- Zener anode is now at +24V → clamps gate at 24−12 = +12V
- Vgs = 12 − 0 = +12V → **FET stays OFF** ✓
- +12V is within the ±20V Vgs(max) rating — safe ✓


### 1.2 Wire Gauges

Given the 5.3A peak current identified in the sources, standard electrical practices suggest the following for 24V DC systems:
- **Main Power Input (from Supply to PCB):** 18 AWG is recommended for currents up to 10A to minimize voltage drop over short runs.
- **Individual Actuators (Pumps and Solenoids):** 20 AWG or 22 AWG is sufficient for the individual 1.2A to 1.5A loads of the pumps and valves.


### 1.3 Buck Converter

**24V to 5V (Logic/USB)**
The design is based on Figure 10.1 of the [TPS62933 Datasheet](https://www.ti.com/lit/ds/symlink/tps62933.pdf?ts=1773728788941) and their [WEBENCH Power Designer](https://webench.ti.com/power-designer/switching-regulator).

```
                                  TPS62933DRLR      
                            ┌───────────────────────┐
24V_SAFE ─┬─────────────────┤ VIN (2)       BST (1) ├────┐   
          │                 │                       │    │   
        [Cin]               │                       │  [Cbst]
          │           3.3V──┤ EN (3)         SW (6) ├────┘──────[L1]───────┬──► 5V
         GND                │                       │                      │
                   [Rrt] ───┤ RT (4)        GND (5) ├── GND             [3× Cout]
                     │      │                       │                      │
                    GND     │                FB (7) ├──┬─[R_top]──► 5V    GND
                            │                       │  │
                   [Css] ───┤ SS (8)                │  └─[R_bot]── GND
                     │      └───────────────────────┘
                    GND     

Vout = 0.8V × (1 + R_top/R_bot)  →  5V = 0.8 × (1 + 52.3k/10k) ≈ 4.98V ✓
Fsw  = 17293 × RT(kΩ)^(−0.942)   →  RT = 21kΩ → Fsw = 17293 × 21^(−0.942) ≈ 982 kHz ✓
```

Component Selection:
- IC:   TPS62933DRLR (SOT583, synchronous buck, 3.8–30V in, 3A, 200kHz–2.2MHz)
- L1:   10µH, 3A, DCR < 50mΩ (e.g. BournsSDR1307-100ML)
- Cin:  10µF / **50V** ceramic (X5R or X7R)
- Cout: 3×10µF / 10V ceramic (X5R or X7R)
- Cbst: 100nF / 10V ceramic (BST to SW)
- Css:  33nF (soft-start ≈ 5ms; minimum 6.8nF, do not float)
- Rrt:  21kΩ to GND → Fsw = 17293 * 21k^(-0.942) = ~1MHz
- R_top: 52.3kΩ 1%
- R_bot: 10kΩ 1% (E96 series)
- No external compensation required (internal loop compensation)
- No external diode required (synchronous rectification)


### 1.4 LDO (3.3V)

**Design Rationale — why a linear LDO for 5V→3.3V:**
The ESP32-C6's RF (Wi-Fi 6, BLE 5) and 12-bit SAR ADC are sensitive to supply noise.
A switching regulator on the 3.3V rail would inject switching ripple at its operating frequency (hundreds of kHz) directly into the ADC reference and RF supply — degrading ADC accuracy and potentially increasing Wi-Fi packet error rate. An LDO has no switching element; its output noise floor is limited only by its PSRR and output capacitance, typically <50µVrms. The 1.7V dropout (5V→3.3V) means only P = 1.7 × 0.35 = 0.6W worst case — manageable on a small SOT-223 package without a heatsink.

```
5V ──┬──[10µF]──┬──► VIN ┌─────────┐ VOUT ──┬──[10µF]──┬──► 3.3V
     │          │        │ AMS1117 │        │          │
    ─┴─        ─┴─       │  -3.3   │       ─┴─        ─┴─
    GND        GND       └────┬────┘       GND        GND
                              │
                             ─┴─
                             GND
```

---


## 2. ESP32-C6 Section

### 2.1 DevKit Pin Headers

The ESP32-C6-DevKitC-1-N8 mounts to the carrier PCB via 2×20 pin headers. USB-C, boot/reset buttons, antenna, and power regulation are on the DevKit.

```
                    ┌─────────────────────────────────────┐
                    │        ESP32-C6-DevKitC-1-N8        │
                    │     (includes USB-C, antenna,       │
                    │      boot/reset buttons, RGB LED)   │
                    │                                     │
           3.3V ────┤ 3V3                            GND  ├──── GND
            5V ─────┤ 5V (from USB or external)           │
                    │                                     │
    FLOAT_LOW ──────┤ GPIO0  (input)                      │
   FLOAT_HIGH ──────┤ GPIO1  (input)                      │
    ATO_VALVE ──────┤ GPIO2  (output)                     │
       US_ECHO ─────┤ GPIO3  (input)                      │
       I2C_SDA ─────┤ GPIO4  (bidirectional)              │
       I2C_SCL ─────┤ GPIO5  (output)                     │
      EZO_PDIS ─────┤ GPIO6  (output)                     │
                    │                                     │
      US_TRIG ──────┤ GPIO7  (output)                     │
                    │                                     │
     (reserved) ────┤ GPIO8  (RGB LED on DevKit)          │
    (available) ────┤ GPIO9  (strapping pin — 45kΩ pullup) │
     PUMP_MAIN ─────┤ GPIO10 (output)                     │
    STEP_PH_DN ─────┤ GPIO11 (output)                     │
                    │                                     │
    STEP_NUT_A ─────┤ GPIO15 (output, strapping pin)      │
     (reserved) ────┤ GPIO16 (CP2102N UART0 TX)           │
     (reserved) ────┤ GPIO17 (CP2102N UART0 RX from CP)   │
   (available) ─────┤ GPIO18 (available)                  │
    STEP_NUT_B ─────┤ GPIO19 (output)                     │
   (available) ─────┤ GPIO20 (available)                  │
                    │                                     │
 TMC2209_UART_RX ───┤ GPIO21 (input)                      │
 TMC2209_UART_TX ───┤ GPIO22 (output)                     │
    (available) ────┤ GPIO23 (available)                  │
                    │                                     │
                    └─────────────────────────────────────┘

Signal Type Key:
  (input)         = Input only
  (output)        = Output only
  (bidirectional) = Bidirectional (I2C)
```

### 2.2 Dual-Function Pin Considerations

#### GPIO8 — On-board RGB LED (reserved)
The DevKitC drives an on-board WS2812B RGB LED from GPIO8 through a series resistor.
Do not connect an external load to GPIO8 on the carrier PCB.
The LED is available for firmware status indication (boot state, error codes, etc.).

#### GPIO9 — Internal ~45kΩ pull-up (strapping pin, currently available)
GPIO9 is sampled at boot to select the boot mode:
- **HIGH** at boot (pull-up default) → normal application boot
- **LOW** at boot → enter ROM serial download mode

The internal pull-up holds GPIO9 HIGH in the absence of external drive, so normal boot
always succeeds when the pin is left unconnected. If GPIO9 is used in a future revision,
ensure any external load cannot pull it LOW during the boot window (~100ms after power-on
/ reset de-assertion).

#### GPIO12 / GPIO13 — USB D− / D+ (Serial logging, code upload, JTAG)
GPIO12 and GPIO13 are the USB D− and D+ lines on the ESP32-C6. The DevKitC connects
these directly to the USB-C connector for three simultaneous use cases:
- **Serial logging** via USB CDC (replaces UART0 for debug output)
- **Firmware upload** via esptool over USB CDC (no external programmer needed)
- **JTAG debugging** via USB (OpenOCD — no separate JTAG adapter needed)

Do not route GPIO12/GPIO13 to the carrier PCB. They are occupied by the DevKit USB
interface and must remain exclusive to the USB-C connector.

#### GPIO15 — TMC2209 STEP pull-down (strapping pin, STEP_NUT_A)
GPIO15 is a strapping pin. OPNhydro uses GPIO15 for STEP_NUT_A (TMC2209 STEP input for
the Nutrient A stepper driver). The TMC2209 STEP input has a 10kΩ pull-down on the PCB.
At boot, the ESP32-C6 samples GPIO15:
- The 10kΩ pull-down holds GPIO15 LOW → **ESP32 ROM boot messages are suppressed** on
  the UART0 TX pin. This is cosmetic only and has no effect on application operation.
- The pull-down also holds STEP_NUT_A LOW at power-on — no step pulses are generated
  before firmware runs. This is the correct fail-safe behaviour.

#### GPIO16 — CP2102N UART0 TX (reserved, do not connect externally)
GPIO16 is the ESP32-C6 UART0 TX output. On the DevKitC-1, this connects to the CP2102N
USB-UART bridge RX input. UART0 may transmit ROM boot messages and other serial data.
Do not route GPIO16 to the carrier PCB for any other purpose. Any external load would
corrupt serial output and could interfere with boot-time messages.

> Note: GPIO15's pull-down suppresses ROM messages on UART0 TX (GPIO16). Even so,
> GPIO16 remains occupied by the CP2102N connection and must not be used.


#### GPIO17 — CP2102N UART TX (reserved, do not connect)
GPIO17 is actively driven by the CP2102N USB-to-UART bridge TX output on the DevKitC.
Do not route GPIO17 to the carrier PCB. Any external connection would fight the CP2102N
output and could damage the bridge IC or the ESP32-C6 input buffer.

#### GPIO21 / GPIO22 — TMC2209 UART bus (RX / TX)
GPIO21 and GPIO22 are assigned to the TMC2209 single-wire UART bus (ESP32-C6 UART1):
- GPIO22: UART1 TX → drives the shared PDN_UART bus
- GPIO21: UART1 RX ← receives responses from the addressed TMC2209

See §7.2 for the UART wiring diagram, address table, and configuration registers.

#### GPIO23 — Available
No assignment. Leave unconnected on the carrier PCB.

#### ~RST — Reset input
- **Leave floating** — internally held HIGH by the chip; normal operation
- **Optional external reset button**: normally-open push-button from ~RST to GND on the
  carrier PCB; add 100nF bypass capacitor from ~RST to GND to suppress glitches
- **Do not drive HIGH externally** — the pin is already pulled HIGH internally
- A LOW pulse ≥1µs resets the device; the DevKitC on-board RST button does the same

---

### 2.3 Carrier PCB Headers

```
Use 2×20 female headers (2.54mm pitch) on carrier PCB.
DevKit plugs in from above.

Header spacing: 22.86mm (900 mils) between rows
```

---

## 3. I2C Sensor Interface


### 3.3 EZO Circuit Connections

```
Atlas Scientific EZO circuits use standard I2C.
Default addresses:
- EZO-pH:  0x63  (MEZZ3, isolated via U3 ADM3260)
- EZO-EC:  0x64  (MEZZ2, isolated via U4 ADM3260)
- EZO-RTD: 0x66  (MEZZ1, no isolation required)
- BME280:  0x76

EZO-pH and EZO-EC (isolated via ADM3260):

                                         GPIO6 (EZO_PDIS)
                                              │
┌──────────────────────────────────────┐   ┌──┴───────────────────────┐
│  EZO-pH (MEZZ3) or EZO-EC (MEZZ2)    │   │  ADM3260 (U3 or U4)      │
│                                      │   │                          │
│   VCC ◄──── 3.3V_ISO ────────────────┼───┤ isoPower out   VCC1◄─3.3V│
│   GND ◄──── GND_ISO  ────────────────┼───┤ GND_ISO        PDIS◄─────┘
│   SDA ◄───► I2C SDA  ────────────────┼───┤ SDA2 ◄──► SDA1           │
│   SCL ◄──── I2C SCL  ────────────────┼───┤ SCL2 ◄─── SCL1           │
│   PRB ◄──── BNC panel-mount          │   └──────────────────────────┘
│                                      │
└──────────────────────────────────────┘

GPIO6 (EZO_PDIS) — active-HIGH power disable, shared by U3 (pH) and U4 (EC):
  GPIO6 LOW  → isoPower enabled  → EZO-pH and EZO-EC powered normally
  GPIO6 HIGH → isoPower disabled → EZO-pH and EZO-EC de-energised

Use cases:
  - Fault recovery: pulse HIGH 100ms then LOW; wait ≥1.2s before sending I2C commands
  - Power saving: de-energise both circuits when readings are not needed (~30mA saved)

EZO-RTD (MEZZ1) has no ADM3260 and is not controlled by EZO_PDIS.

EZO-RTD (MEZZ1, no isolation):
┌──────────────────────────────────────┐
│  EZO-RTD (MEZZ1)                     │
│                                      │
│   VCC ◄──── 3.3V                     │
│   GND ◄──── GND                      │
│   SDA ◄───► I2C SDA                  │
│   SCL ◄──── I2C SCL                  │
│   PRB ◄──── BNC panel-mount          │
│                                      │
└──────────────────────────────────────┘

The ADM3260 provides both I2C signal isolation (2.5kV) and isolated DC power
via integrated isoPower — up to 150mW output. No external DC-DC converter needed.

3.3V ──► ADM3260 (U3 or U4) VCC1 ──► isoPower ──► 3.3V_ISO ──► EZO VCC/SDA/SCL
GPIO6 ──► ADM3260 PDIS (U3 and U4 tied together) — HIGH disables isoPower
```





### 3.4 Switching EZO Circuits to I2C Mode (Manual, No UART Required)

EZO circuits ship in **UART mode** (green LED). They must be switched to **I2C mode** (blue LED)
before connecting to OPNhydro. This is done by briefly shorting two pins at power-on — no USB
adapter, no serial terminal, no programming required.

**LED color key:**
```
Green = UART mode
Blue  = I2C mode
```

**Pins to short (by circuit type):**

| EZO Circuit | Short these two pins | Default I2C address after switch |
|-------------|----------------------|----------------------------------|
| EZO-pH      | TX → PGND            | 0x63 (99)                        |
| EZO-EC      | TX → PGND            | 0x64 (100)                       |
| EZO-DO      | TX → PGND            | 0x61 (97)                        |

**Step-by-step procedure (from Atlas Scientific EZO pH datasheet, p.37):**

```
1. Disconnect GND (power off the EZO circuit)

2. Disconnect TX and RX from any microcontroller

3. Connect TX to PGND using a jumper wire
   (short these two pins directly on the EZO carrier board)

4. Confirm RX is disconnected — leaving RX connected will prevent switching

5. Connect GND (power on)

6. Wait for LED to change from Green → Blue
   (takes ~2 seconds; indicates I2C mode is now active)

7. Disconnect GND (power off)

8. Remove the TX-to-PGND jumper wire

9. Reconnect SDA, SCL, VCC, GND for normal I2C operation
```

> **Important:** RX must be floating (disconnected) during the switch.
> If RX is connected or pulled to any voltage, the mode switch will not occur.

> **Address reset:** The manual switch always resets the I2C address to the
> circuit's factory default (see table above). If you need a non-default address,
> set it via I2C command (`I2C,<addr>`) after switching.

**Wiring diagram for the switch:**

```
          EZO Circuit (during switching only)

    VCC ─────── [leave disconnected until step 5]
    GND ─────── [connect at step 5, disconnect at step 7]
    TX  ─┐
         │ jumper wire (short for steps 3–8)
    PGND─┘
    RX  ─────── [must be disconnected / floating]
    SDA ─────── [leave disconnected until step 9]
    SCL ─────── [leave disconnected until step 9]
```

**Reversing back to UART:** Same procedure — short TX to PGND again; LED changes Blue → Green.

---

### 3.5 I2C Connector

**OPNhydro uses Phoenix Contact 4-pin (3.5mm pitch) ✅**

```
Phoenix Contact 4-pin connector specification:
──────────────────────────────────────────────

Manufacturer: Phoenix Contact
PCB Header: 1803280 (4-position, through-hole, straight)
Plug Housing: 1803581 (4-position pluggable)
Pitch: 3.5mm (COMBICON series)
Wire Range: 28-16 AWG (0.08-1.5mm²)
Rated Voltage: 160V
Rated Current: 8A per contact
Contact Material: Copper alloy, tin-plated
Termination: Screw connection (plug side)
Mounting: Through-hole, solder pins
Cost: ~$1.50-2.50 per set (header + plug)

Pinout (standard I2C):
┌─────────────────────┐
│ Pin 1: GND (Black)  │ ◄── System GND
│ Pin 2: 3.3V (Red)   │ ◄── 3.3V power rail
│ Pin 3: SDA (Blue)   │ ◄── I2C Data (GPIO1 via pullup)
│ Pin 4: SCL (Yellow) │ ◄── I2C Clock (GPIO2 via pullup)
└─────────────────────┘

Advantages:
- Industrial-grade reliability and durability
- Screw terminals - no crimping required, field-serviceable
- Large pitch (3.5mm) - easy hand assembly
- High current rating (8A) - suitable for power distribution
- Positive locking mechanism - vibration resistant
- Through-hole mounting - very strong PCB attachment
- Color-coded options available for easier assembly
- Wide wire gauge acceptance (28-16 AWG)

PCB Layout:
- Place connector(s) on board edge for easy access
- Multiple connectors can be chained on same I2C bus
- Keep connector away from high-current traces (pump drivers)
- Typical placement: near ESP32-C6 header for short I2C traces
- Through-hole mount requires 1.0mm drill holes
- Recommended pad size: 1.7mm diameter (0.35mm annular ring)

Recommended usage:
- EZO pH circuit (I2C address 0x63)
- EZO EC circuit (I2C address 0x64)
- EZO DO circuit (I2C address 0x61)
- BME280 air temp/humidity sensor (I2C address 0x76/0x77)
- BH1750 light sensor (I2C address 0x23/0x5C)
- Optional OLED display (SSD1306, I2C address 0x3C/0x3D)
- Future I2C expansion modules

Ordering Information:
- DigiKey: Search "1803280" (header), "1803581" (plug)
- Mouser: Phoenix Contact COMBICON series
- Alternative: Use Phoenix Contact MC 1.5/4-ST-3.5 (generic equivalent)

**Note:** NOT compatible with Qwiic/STEMMA QT (which uses 1.0mm JST-SH).
          Requires field wiring with screw terminals on plug side.
          Excellent for industrial/commercial applications.
```

**Connector comparison:**
- Float switches: JST-XH 2-pin (2.5mm pitch)
- Ultrasonic (HC-SR04+ / RCWL-1601): JST-XH 4-pin (2.5mm pitch) - smaller pitch!
- I2C sensors: Phoenix Contact 4-pin (3.5mm pitch) ✅

---

### 3.6 EZO Circuit Calibration

All calibration is performed over I2C by sending ASCII command strings to each circuit's address.
After sending a command, wait **300 ms** before reading the response.

Query current calibration status at any time with `Cal,?` → returns `?Cal,<n>` where `n` = number
of calibration points stored (0 = uncalibrated).

---

#### EZO-pH — 3-Point Calibration (address 0x63)

**Calibration solutions needed:** pH 4.00, 7.00, 10.00 buffers
**Order is mandatory:** mid → low → high. Starting over with `Cal,mid` clears all stored points.

```
Step 1 — Mid-point (pH 7.00)
  Place probe in pH 7.00 buffer.
  Wait for readings to stabilize (~1–2 min).
  Send:  Cal,mid,7
  Wait:  300 ms
  Read:  response (should be "*OK")

Step 2 — Low-point (pH 4.00)
  Rinse probe with DI water, dry gently.
  Place probe in pH 4.00 buffer.
  Wait for readings to stabilize (~1–2 min).
  Send:  Cal,low,4
  Wait:  300 ms
  Read:  response

Step 3 — High-point (pH 10.00)
  Rinse probe with DI water, dry gently.
  Place probe in pH 10.00 buffer.
  Wait for readings to stabilize (~1–2 min).
  Send:  Cal,high,10
  Wait:  300 ms
  Read:  response

Verify: Send Cal,?  →  expect ?Cal,3
```

| Command | Description |
|---------|-------------|
| `Cal,mid,7` | Midpoint calibration at pH 7 (must do first) |
| `Cal,low,4` | Low-point calibration at pH 4 |
| `Cal,high,10` | High-point calibration at pH 10 |
| `Cal,?` | Query — returns `?Cal,0/1/2/3` |
| `Cal,clear` | Erase all calibration data |

> **Recalibrate:** Every 6–12 months, or when probe response drifts >0.1 pH.
> **Storage:** Keep Gen 3 probe tip submerged in storage solution when not in use.

---

#### EZO-EC — 2-Point Calibration (address 0x64, K=1.0 probe)

**Calibration solutions needed:** 12,880 µS/cm and 80,000 µS/cm standards
(Atlas Scientific COND-12880 and COND-80000, or equivalent NIST-traceable solutions)

```
Step 1 — Dry calibration
  Remove probe from any liquid. Ensure probe is completely dry.
  Send:  Cal,dry
  Wait:  300 ms
  Read:  response (*OK)

Step 2 — Low-point (12,880 µS/cm)
  Place probe in 12,880 µS/cm standard.
  Wait for readings to stabilize (~1 min).
  Send:  Cal,low,12880
  Wait:  300 ms
  Read:  response

Step 3 — High-point (80,000 µS/cm)
  Rinse probe with DI water, dry gently.
  Place probe in 80,000 µS/cm standard.
  Wait for readings to stabilize (~1 min).
  Send:  Cal,high,80000
  Wait:  300 ms
  Read:  response

Verify: Send Cal,?  →  expect ?Cal,2
```

| Command | Description |
|---------|-------------|
| `Cal,dry` | Dry calibration (always first) |
| `Cal,low,12880` | Low-point at 12,880 µS/cm (K=1.0) |
| `Cal,high,80000` | High-point at 80,000 µS/cm (K=1.0) |
| `Cal,one,<value>` | Single-point calibration (alternative to 2-point) |
| `Cal,?` | Query — returns `?Cal,0/1/2` |
| `Cal,clear` | Erase all calibration data |

> **Recalibrate:** Annually or when probe is replaced.
> **K value:** Confirm probe is K=1.0 (`K,?` should return `?K,1.00`). If not, set with `K,1.0`.

---

#### EZO-DO — 1-Point Atmospheric Calibration (address 0x61)

**No calibration solution required** for standard atmospheric calibration.
Optional zero-point uses sodium sulfite solution (Na₂SO₃) to create 0 mg/L DO water.

```
Step 1 — Atmospheric (single-point, sufficient for hydroponics)
  Remove probe from water.
  Expose probe to open air for 30–60 seconds (readings must stabilize).
  Send:  Cal
  Wait:  300 ms
  Read:  response (*OK)

Verify: Send Cal,?  →  expect ?Cal,1

Optional Step 2 — Zero-point (improves accuracy, rarely needed)
  Prepare sodium sulfite solution (Na₂SO₃ in DI water).
  Submerge probe until DO reading reaches 0.00 mg/L.
  Send:  Cal,0
  Wait:  300 ms
  Read:  response

Verify: Send Cal,?  →  expect ?Cal,2
```

| Command | Description |
|---------|-------------|
| `Cal` | Atmospheric single-point calibration |
| `Cal,0` | Zero-point calibration (0 mg/L, optional) |
| `Cal,?` | Query — returns `?Cal,0/1/2` |
| `Cal,clear` | Erase all calibration data |

> **Recalibrate:** Every 8–12 months, or after membrane replacement.
> **Temperature compensation:** Send `T,<temp>` before calibrating if water temp ≠ 25°C.

---

#### General I2C Calibration Notes

```
I2C transaction for any calibration command:

1. Write command string to EZO address (e.g., 0x63)
   e.g.,  i2c_write(0x63, "Cal,mid,7")

2. Wait 300 ms minimum before reading response

3. Read 1+ bytes from EZO address
   Response byte 1 = status code:
     1 = success (*OK)
     2 = syntax error
     254 = still processing (wait longer)
     255 = no data

4. If status = 254, wait another 100 ms and retry read
```

**Calibration frequency summary:**

| Circuit | Method | Solutions | Frequency |
|---------|--------|-----------|-----------|
| EZO-pH  | 3-point | pH 4, 7, 10 buffers | Every 6–12 months |
| EZO-EC  | 2-point + dry | 12,880 + 80,000 µS/cm | Annually |
| EZO-DO  | 1-point atmospheric | None (air) | Every 8–12 months |

---

## 4. Temperature Sensor (1-Wire) — ⛔ NOT POPULATED

> **Design decision:** The 1-Wire DS18B20 has been removed from the build.
> Water temperature is measured by the EZO-RTD circuit (MEZZ1, I2C address 0x66).
> Ambient temperature is measured by the BME280 (I2C).
> GPIO2 is now used for ATO_VALVE (output). R30 (4.7kΩ 1-Wire pullup) is DNP.
>
> The technical documentation below is retained for reference only.

### 4.1 Basic Circuit

```
1-Wire Bus Connection:

    3.3V ───┬────────────────────────────► VDD to DS18B20 (Pin 3, Red)
            │
           [R1] 4.7kΩ pullup resistor
            │
            └──┬─────────────────────────► DQ to DS18B20 (Pin 2, White)
               │
    GPIO2 ─────┘

    GND ────────────────────────────────► GND to DS18B20 (Pin 1, Black)


IMPORTANT: R1 connects between 3.3V and DQ (NOT to GND!)
           The pullup resistor pulls the 1-wire data line HIGH


Complete DS18B20 Wiring:

         3.3V rail
            │
            ├──────────────────────► Pin 3: VDD (Red wire)
            │
           [R1]
           4.7kΩ
            │
            ├─────┬────────────────► Pin 2: DQ (White wire)  [SEN-11050]
            │     │
    GPIO2 ────────┘
            │
    GND rail│
            └──────────────────────► Pin 1: GND (Black wire)
```

### 4.2 Component Selection

| Component | Value/Type | Purpose | Package |
|-----------|------------|---------|---------|
| **R1** | 4.7kΩ ±5% | 1-wire data line pullup | 0805 SMD |
| **C1** (optional) | 100nF | VDD decoupling near sensor | 0805 SMD |
| **D1** (optional) | 5.6V TVS | ESD protection for long cables | SOD-123 |
| **R2** (optional) | 100Ω | Series protection with TVS | 0805 SMD |

### 4.3 PCB Connector

**3-pin JST-XH connector (2.5mm pitch) for waterproof probe:**
```
┌─────────────────────┐
│ Pin 1: GND (Black)  │ ◄── To system GND
│ Pin 2: DQ (White)   │ ◄── To GPIO2 via 4.7kΩ pullup to 3.3V  [SEN-11050 uses White]
│ Pin 3: VDD (Red)    │ ◄── To 3.3V rail
└─────────────────────┘

Connector: JST-XH 3-pin S3B-XH-A (Right-angle, through-hole PCB mount)
Housing: JST XHP-3 (3-pin for cable assembly)
Contacts: JST SXH-001T-P0.6 (crimp terminals, 30-26 AWG)

Probe: SparkFun SEN-11050 bare wire ends → crimp SXH-001T-P0.6 contacts onto wires
```

### 4.4 How the 1-Wire Protocol Works

**Open-Drain Bidirectional Communication:**
- Both ESP32 and DS18B20 can only pull the line **LOW** (to GND)
- Neither device drives the line HIGH - the pullup resistor does this
- This allows bidirectional communication on a single wire
- Multiple devices can share the bus without conflict

**Why 4.7kΩ Pullup?**
```
Bus Capacitance: C_bus ≈ 200-400pF (typical 1-3m cable + sensor)
Pullup Resistor: R_pullup = 4.7kΩ
Time Constant: τ = R × C = 4.7kΩ × 400pF = 1.88µs
Rise Time (10-90%): t_rise = 2.2 × τ = 4.1µs

1-Wire Standard Speed Requirement: t_rise < 15µs ✓
Fast: 4.7kΩ works for cables up to 100m
```

**For longer cables or noisy environments:**
- Use 3.3kΩ pullup (faster rise time)
- Add 100Ω series resistor + TVS diode for ESD protection

### 4.5 Multiple Sensors on Same Bus

The 1-wire protocol supports **multiple DS18B20 sensors** on GPIO2:

```
         3.3V
          │
         R1
        4.7kΩ (single pullup for entire bus)
          │
GPIO2 ────┼──────┬──────────┬──────────┬──────────► (More sensors...)
                 │          │          │
               ┌─┴─┐      ┌─┴─┐      ┌─┴─┐
         GND   │DS1│      │DS2│      │DS3│
               └───┘      └───┘      └───┘
            Water Temp  Nutrient   Air Temp
                        Stock

Each sensor has unique 64-bit ROM ID for addressing:
- Sensor 1: 28-FF-64-1D-33-17-03-8C
- Sensor 2: 28-AA-12-5E-44-19-01-F3
- Sensor 3: 28-BB-34-6F-55-20-02-A1
```

**Important Notes:**
- Use **normal powered mode** (VDD connected to 3.3V) for multiple sensors
- Parasite power mode (VDD to GND) only works reliably with single sensor
- Firmware must address each sensor by its unique ROM ID

### 4.6 Typical OPNhydro Configuration

**Primary Use Case:**
- **Waterproof DS18B20 probe** in nutrient solution (required)
- Measures water temperature for EZO pH/EC/DO temperature compensation
- 3-wire cable: Red (VDD), Yellow (DQ), Black (GND)

**Optional Additional Sensors:**
- Ambient air temperature near grow area
- Nutrient stock solution temperature
- Root zone temperature (DWC systems)

### 4.7 Waterproof Probe Specifications

**Selected part: SparkFun SEN-11050** (Waterproof DS18B20, ~$10)

```
SparkFun SEN-11050 specifications:
- Part number: SEN-11050
- Sensor IC: Maxim DS18B20
- Cable: ~1.8m (6 ft), PVC jacketed, bare wire ends (no connector)
- Wire colors: Red (VDD), White (DQ/SIG), Black (GND)
- Probe tip: Stainless steel, 6mm diameter
- Temperature range: -55°C to +125°C
- Accuracy: ±0.5°C (-10°C to +85°C)
- Operating voltage: 3.0V to 5.5V (use 3.3V rail)
- Interface: 1-Wire
- Waterproof: Yes (sealed epoxy probe tip)
```

**PCB connector wiring for SEN-11050:**
```
JST-XH 3-pin on PCB        SEN-11050 wire
─────────────────────────────────────────
Pin 1: GND (to GND rail) ◄── Black wire
Pin 2: DQ  (to GPIO2)    ◄── White wire  ← NOTE: White, not Yellow
Pin 3: VDD (to 3.3V)     ◄── Red wire
```

> **Note:** The bare wire ends of the SEN-11050 require termination.
> Crimp JST-XH contacts (SXH-001T-P0.6) onto each wire to plug directly
> into the PCB's JST-XH 3-pin header, or use a screw terminal adapter.

### 4.8 Temperature Conversion Timing

**Resolution vs Speed Trade-off:**
| Resolution | Conversion Time | Temperature Step | Use Case |
|------------|-----------------|------------------|----------|
| 9-bit | 93.75ms | 0.5°C | Fast updates |
| 10-bit | 187.5ms | 0.25°C | Standard |
| 11-bit | 375ms | 0.125°C | Good accuracy |
| **12-bit** | **750ms** | **0.0625°C** | **Default (best accuracy)** ✅ |

**Firmware Timing Example:**
```c
// Request temperature conversion
ds18b20_trigger_conversion(GPIO2);

// Wait for conversion (12-bit resolution = 750ms)
vTaskDelay(pdMS_TO_TICKS(750));

// Read temperature
float water_temp = ds18b20_read_temp(GPIO2);

// Send to EZO circuits for automatic compensation
char cmd[16];
snprintf(cmd, sizeof(cmd), "T,%.1f", water_temp);
ezo_send_command(I2C_EZO_PH, cmd);  // pH compensation
ezo_send_command(I2C_EZO_EC, cmd);  // EC compensation
ezo_send_command(I2C_EZO_DO, cmd);  // DO compensation
```

### 4.9 Optional ESD Protection (Long Cables)

For cables **>3 meters** or **harsh EMI environments**:

```
         3.3V
          │
         R1
        4.7kΩ
          │
GPIO2 ────┼──────[R2 100Ω]────┬────► To DS18B20 DQ
          │                   │
         D1                 ──┴──
      (5.6V TVS)           ─ ─ ─  D2: 5.6V TVS diode
         │                 ──┬──
        ─┴─                  │
        GND                 ─┴─
                            GND

Component Selection:
- D1: TVS diode 5.6V bidirectional (e.g., SMAJ5.0CA)
- D2: TVS diode 5.6V bidirectional (at sensor end if possible)
- R2: 100Ω current-limiting resistor
```

### 4.10 Power Modes

**Normal (Powered) Mode** ✅ **Recommended for OPNhydro**
```
VDD (Pin 3) ──► 3.3V
DQ (Pin 2)  ──► GPIO2 + 4.7kΩ pullup
GND (Pin 1) ──► GND

Advantages:
- Reliable operation with multiple sensors
- Faster conversion times
- Recommended for permanent installations
```

**Parasite Power Mode** (Alternative)
```
VDD (Pin 3) ──► GND (tied to ground)
DQ (Pin 2)  ──► GPIO2 + 4.7kΩ pullup
GND (Pin 1) ──► GND

Power "stolen" from DQ line via internal capacitor

Use only when:
- Cable has only 2 wires available
- Single sensor only
- Temporary/portable applications

Note: OPNhydro uses normal powered mode for reliability
```

### 4.11 Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| No sensor detected | Incorrect wiring | Verify VDD, GND, DQ connections with multimeter |
| Intermittent readings | Weak pullup for cable length | Reduce R1 to 3.3kΩ or 2.2kΩ |
| CRC errors | Bus capacitance too high | Shorten cable or reduce pullup resistance |
| Multiple sensors conflict | Parasite power with >1 sensor | Use normal powered mode (VDD to 3.3V) |
| Slow thermal response | Large thermal mass | Use thin-wall stainless probe |
| Erratic readings | EMI/RFI interference | Add 100Ω series + TVS protection |
| Reading stuck at 85°C | Power-on reset default | Check power supply, add decoupling cap |

### 4.12 Why GPIO2 Was Selected

From ESP32-C6 pinout:
- **GPIO2**: Bidirectional, suitable for 1-wire protocol
- No boot strapping requirements (safe to use)
- Not shared with USB (D+/D-), UART, or SPI
- Located near I2C pins (GPIO4/5) for logical grouping on PCB
- Can be configured as input/output via software

### 4.13 Integration with EZO Sensors

**Temperature compensation is critical** for accurate pH/EC/DO measurements:

```
Temperature Effect on Sensors:
- pH: ±0.003 pH per °C (Nernst equation)
- EC: ±2% per °C (ion mobility changes)
- DO: ±2.3% per °C (oxygen solubility decreases with temp)

Firmware Integration:
void update_ezo_temperature_compensation(void) {
    // Read water temperature
    float water_temp = ds18b20_read_temp(GPIO2);

    // Format command
    char temp_cmd[16];
    snprintf(temp_cmd, sizeof(temp_cmd), "T,%.1f", water_temp);

    // Send to all EZO circuits
    ezo_send_command(I2C_EZO_PH, temp_cmd);  // Address 0x63
    ezo_send_command(I2C_EZO_EC, temp_cmd);  // Address 0x64
    ezo_send_command(I2C_EZO_DO, temp_cmd);  // Address 0x61

    // EZO circuits now automatically compensate all readings
}

Update Frequency:
- Every measurement cycle (recommended)
- Or only when temp changes >0.5°C (power saving)
```


---

## 6. Float Switch Interface

```
FLOAT_LOW  (GPIO0) — hole at LOW water mark:
  Float arm UP   (water ≥ LOW mark):  NC CLOSED → switch pulls to GND → GPIO0 LOW  (water OK)
  Float arm DOWN (water < LOW mark):  NC OPEN   → pull-up → GPIO0 HIGH (alarm — stop pump)
  PCB wiring: switch wire → GND terminal

FLOAT_HIGH  (GPIO1) — hole at HIGH water mark:
  Float arm UP   (water ≥ HIGH mark): NC CLOSED → switch pulls to 3.3V → GPIO1 HIGH (stop ATO)
  Float arm DOWN (water < HIGH mark): NC OPEN   → pull-down → GPIO1 LOW  (ATO OK)
  PCB wiring: switch wire → 3.3V terminal
```


### 6.3 Circuit

The two float switches use opposite pull directions so that both GPIO signals are
**active-HIGH when their cutoff condition is triggered** — consistent logic for both
software and the hardware NPN cutoff transistors (see section 6.4).

```
Float Switch - FLOW (low level alarm, GPIO0):
Pull-UP to 3.3V, switch-to-GND, NC (hinge down)

        3.3V
         │
        R1
       10k (pullup)
         │
GPIO0 ───┼──────────────► LH25 FLOW (NC, hinge down) ──► GND
         │
        C1
       100nF (debounce)
         │
        ─┴─
        GND

Float arm UP   (water at/above LOW mark): NC CLOSED → GPIO0 = LOW  (0) — water OK
Float arm DOWN (water below LOW mark):    NC OPEN   → GPIO0 = HIGH (1) — ALARM, stop pump

Float Switch - HIGH (high level cutoff, GPIO1):
Pull-DOWN to GND, switch-to-3.3V, NC (hinge down)
⚠ Reversed from FLOAT_LOW so GPIO1 is also active-HIGH on cutoff.

        3.3V
         │
        LH25 HIGH (NC, hinge down)
         │
GPIO1 ───┼──────────────────────────────────────────────────
         │
        R1
       10k (pulldown)
         │
        C1
       100nF (debounce)
         │
        ─┴─
        GND

Float arm UP   (water at/above HIGH mark): NC CLOSES to 3.3V → GPIO1 = HIGH (1) — STOP ATO
Float arm DOWN (water below HIGH mark):    NC OPEN → pull-down → GPIO1 = LOW  (0) — ATO OK
```

---

### 6.4 Hardware Cutoff via NPN Transistors

Each float switch drives a small NPN transistor that directly clamps the respective
MOSFET gate to GND when the cutoff condition fires. This is independent of firmware —
the pump and ATO valve shut down in hardware even if the MCU is hung or misbehaving.

```
FLOAT_LOW hardware cutoff (water-low → main pump off):

GPIO0 (HIGH = water low) ────── R_base ──── Base  ┐
                                4.7kΩ              │ MMBT3904 NPN
                                         Emitter ──┴── GND
                                         Collector ──────────────────────────► Q1 Gate
                                                              (also driven by GPIO10 through 100Ω)

FLOAT_HIGH hardware cutoff (water-high → ATO valve closes):

GPIO1 (HIGH = water high) ───── R_base ──── Base  ┐
                                4.7kΩ              │ MMBT3904 NPN
                                         Emitter ──┴── GND
                                         Collector ──────────────────────────► Q8 Gate
                                                              (also driven by GPIO2 through 100Ω)
```

**Operation:**
| Condition | GPIO state | NPN | MOSFET gate | Load |
|-----------|-----------|-----|-------------|------|
| Water OK / ATO OK | LOW (0) | OFF | Controlled by GPIO10/GPIO2 | Normal operation |
| Water LOW / Water HIGH | HIGH (1) | ON (saturated) | Pulled to ≈GND | OFF (hardware) |

**Component selection:**
- MMBT3904 (SOT-23): β ≥ 100, I_C(max) = 200mA, V_CE(sat) ≈ 0.2V
- Base resistor: 4.7kΩ → I_B = (3.3V − 0.7V) / 4.7kΩ = 0.55mA
- Worst-case I_C when GPIO10/GPIO7 HIGH and NPN ON: (3.3V − 0.2V) / 100Ω = 31mA
- Saturation overdrive: 0.55mA / 0.31mA = 1.8× → fully saturated ✓
- Gate clamped to ≤ 0.2V, well below VGS(th) = 1.5V of both Q1 and Q8

**Schematic note:** Two additional MMBT3904 transistors (Q9, Q10) and two 4.7kΩ
resistors are required on the PCB. The 4.7kΩ value is already present in the BOM (R30).

---

### 6.5 Normally Open vs Normally Closed — Full Explanation

A float switch contains a **reed switch** — a sealed glass capsule with two metal contacts
that close when a magnet is brought near. The float arm holds a permanent magnet that moves
closer to or farther from the reed switch as the water level changes.

**Normally Closed (NC)** — contacts CLOSED in the resting state:

```
                ╔════════════╗
                ║  Reed      ║
                ║  Switch    ║  ← magnet near = contacts CLOSED
    ┌───┤≈────╗ ║            ║
    │  float  ╚═╗  ───────── ║
    │   arm     ║  contacts  ║
    └───────────╚════════════╝

  Float UP (in water):  Magnet near reed → contacts CLOSED  → circuit CONDUCTING
  Float DOWN (in air):  Magnet away      → contacts OPEN    → circuit BROKEN
```

**Normally Open (NO)** — contacts OPEN in the resting state:

```
  Same hardware as NC — just flip the float arm orientation on the LH25.
  Float UP (in water):  Magnet near reed → contacts OPEN     → circuit BROKEN
  Float DOWN (in air):  Magnet away      → contacts CLOSED   → circuit CONDUCTING
```

For the **Flowline LH25**, NO/NC is selected by the float hinge orientation:

```
  Hinge DOWN (arm hangs down by gravity in air):
    → In air: arm DOWN, magnet away  = NC resting state = CLOSED
    → In water: arm UP, magnet near  = NC actuated    = OPEN? ← confusing!
```

Wait — the LH25 spec states it the other way. Here is the correct behaviour:

```
  LH25, Hinge DOWN = NC wiring:
    Float arm UP  (water present at switch level) → reed CLOSES → contacts CONDUCTING
    Float arm DOWN (water below switch level)     → reed OPENS  → contacts BROKEN

  LH25, Hinge UP = NO wiring:
    Float arm UP  (water present at switch level) → reed OPENS  → contacts BROKEN
    Float arm DOWN (water below switch level)     → reed CLOSES → contacts CONDUCTING
```

**OPNhydro uses NC (hinge DOWN) for both switches.**
When water rises to the switch, the float arm lifts → reed closes → circuit makes.
When water drops below the switch, the float arm falls → reed opens → circuit breaks.



---



**Decision: FLOAT_LOW and FLOAT_HIGH provide hardware-enforced cutoffs, not software-only.**

To ensure fail-safe operation independent of MCU firmware, each float switch drives a small NPN transistor that directly pulls the respective MOSFET gate to GND when its cutoff condition is met. The MCU can still read the float state via GPIO for monitoring and alerting, but the hardware path acts regardless of software state.

**FLOAT_LOW (GPIO0) → Main Pump (Q1) hardware cutoff:**
- GPIO0 HIGH = water below LOW mark (switch open, pull-up active) = pump must stop
- GPIO0 drives NPN transistor base; NPN collector tied to Q1 gate
- When GPIO0 HIGH: NPN saturates → Q1 gate pulled to ≈GND → pump off (hardware)
- When GPIO0 LOW: NPN off → Q1 gate controlled by GPIO10 normally

**FLOAT_HIGH (GPIO1) → ATO Valve (Q8) hardware cutoff:**
- FLOAT_HIGH is wired with pull-DOWN + switch-to-3.3V (reversed from FLOAT_LOW)
  so that GPIO1 HIGH = water at/above HIGH mark = consistent active-HIGH logic
- GPIO2 drives NPN transistor base; NPN collector tied to Q8 gate
- When GPIO1 HIGH: NPN saturates → Q8 gate pulled to ≈GND → ATO valve closes (hardware)
- When GPIO1 LOW: NPN off → Q8 gate controlled by GPIO7 normally

**Additional components required (per channel):**
- 1× MMBT3904 NPN transistor, SOT-23 (~$0.05)
- 1× 4.7kΩ base resistor, 0805 (already in BOM)




---

### 6.6 Mounting the Float Switches

**Tools required:**
- Step drill bit or hole saw: 18mm (23/32") for 1/2" NPT tap drill
- 1/2" NPT tap + tap handle
- Adjustable wrench or pipe wrench
- PTFE thread tape

**Step 1 — Determine water levels:**
```
       ┌──────────────────────────┐
       │                          │   ← tank top / lid
       │       FLOAT_HIGH         │ ← HIGH mark: ATO stops here
       │          ●               │   (e.g., 25mm below brim)
       │                          │
       │  [operating range]       │
       │                          │
       │       FLOAT_LOW          │ ← LOW mark: pump stops here
       │          ●               │   (e.g., 50mm above bottom)
       │                          │
       └──────────────────────────┘
```

- **FLOAT_LOW (low mark):** Set high enough that the pump is never run dry.
  Typically 50–75mm above the reservoir bottom.
- **FLOAT_HIGH (high mark):** Set low enough to prevent overflow.
  Typically 25–50mm below the top of the reservoir.
- The vertical distance between them defines the ATO working range.

**Step 2 — Drill the side-wall holes:**
1. Mark the two hole positions on the reservoir side wall.
2. Use an 18mm (23/32") step bit or hole saw to drill each hole.
3. Tap each hole to 1/2" NPT using the NPT tap.
   - Apply cutting oil if drilling into HDPE or polypropylene.
   - Use a slow, steady hand — plastic cracks if rushed.
4. Deburr the inside edge with a countersink or knife.

**Step 3 — Install the switches:**
1. Wrap 3–4 turns of PTFE tape on the LH25 NPT threads (clockwise wrap).
2. Thread into the hole by hand until snug.
3. Orient the float hinge **pointing DOWN** (NC mode) — the hinge end is marked on the body.
4. Use a wrench to tighten 1–2 additional turns past hand-tight. Do not overtighten.
5. The float arm should point **toward the inside of the reservoir** and swing freely.

```
   Outside of reservoir wall:     Inside of reservoir:

     ┌────────────────┐             ┌─────────────────┐
     │   NPT threads  │             │                 │
     │ LLLLL LH25 body│═════════════│  ←arm swings    │
     │  (hinge DOWN)  │             │   freely here   │
     └────────────────┘             └─────────────────┘
           ↑
      Wire exits here
      (2', 22 AWG,
       2-conductor)
```

**Step 4 — Route and connect the wires:**

Both switches come with 2' (61cm) bare wire leads. Terminate each wire with a
JST-XH 2-pin crimp or strip and clamp into a 2-pin screw terminal on the PCB.

| Switch | Wire to PCB pin 1 | Wire to PCB pin 2 | Notes |
|--------|-------------------|-------------------|-------|
| FLOAT_LOW (GPIO0) | GND | GND | Both wires to GND — polarity doesn't matter for dry reed |
| FLOAT_HIGH (GPIO1) | 3.3V | 3.3V | Both wires to 3.3V |

Wait — a reed switch is a 2-terminal device with no polarity. The PCB has a pull-up or
pull-down resistor and the switch creates the signal. The actual connection is:

```
FLOAT_LOW (GPIO0):
  PCB header Pin 1: → GPIO0 signal node (already has pull-up to 3.3V on PCB)
  PCB header Pin 2: → GND
  Wire one switch lead to each pin. No polarity.

FLOAT_HIGH (GPIO1):
  PCB header Pin 1: → GPIO1 signal node (already has pull-down to GND on PCB)
  PCB header Pin 2: → 3.3V
  Wire one switch lead to each pin. No polarity.
```

**Step 5 — Test before filling:**
1. With the reservoir empty, both float arms should hang DOWN.
   - GPIO0 should read HIGH (water low alarm, expected)
   - GPIO1 should read LOW (ATO OK, expected)
2. Lift FLOAT_LOW arm by hand — GPIO0 should go LOW (arm up = water OK).
3. Lift FLOAT_HIGH arm by hand — GPIO1 should go HIGH (arm up = water at HIGH mark → ATO stops).

---

## 7. Pump Driver Circuits

> ⚠️ **PENDING SELECTION:** Main circulation pump — **24V DC required** (system rail is 24V).
> The AUBIG DC40-1250 (12V) is no longer suitable.
>
> **Requirements for replacement:**
> - Voltage: **24V DC**
> - Flow: ≥500 L/H at operating head
> - Head: ≥4m
> - Brushless preferred (reliability)
> - PWM-capable preferred for variable flow via Q1 MOSFET gate
> - Barbed fittings preferred

All pumps and the ATO valve use the same 24V rail and identical driver circuits.

### Main Pump

**Installation Notes:**
1. Pump must be fully submerged in water before power-on (prevents dry-run damage)
2. Mount pump vertically or horizontally, avoid inverted position
3. Use 1/2" ID vinyl or silicone tubing on barbed fittings; secure with hose clamps
4. Add inline strainer/filter to prevent debris clogging impeller
5. Test PWM control at low duty cycles to find minimum stable speed
6. Allow 10-15 second startup delay in software for motor initialization




### 7.1 24V Main Pump Driver

```
                                    24V
                                     │
                        ┌────────────┼────┬──── 24V rail
                        │            │    │
                        │           C2  ─┴─
                        │          100nF GND (local bypass)
                        │            │
                       D1          PUMP+
                    (SS34)          │
                        │          PUMP
                        │         (1.2A)
               ┌────────┴───────┐   │
               │     DRAIN      │   │
        ┌──────┤  Q1            ├───┴── PUMP-
        │      │  IRLR2905      │
        │      │  (DPAK)        │
        │      └───────┬────────┘
        │           SOURCE
        │              │
       R2             ─┴─
      100Ω            GND
        │
        ├────────────────────────────────── Gate (Q1)
        │                                       │
GPIO10 ─┘                                      R1
                                              10kΩ (pull-down)
                                               │
                                              ─┴─
                                              GND

Hardware cutoff — FLOAT_LOW (water-low) overrides GPIO10:

GPIO0 ──── R_base (4.7kΩ) ──── Base ┐
                                     │ Q9: MMBT3904 NPN
                          Emitter ───┴─── GND
                          Collector ─────────────────────────► Gate (Q1)

When GPIO0 HIGH (water low): Q9 saturates → Gate clamped to ≤0.2V → Q1 OFF (hardware)
When GPIO0 LOW  (water OK):  Q9 off      → Gate driven by GPIO10 normally

C2: 100nF / 50V ceramic (X7R, 0805)
- Local bypass capacitor for switching transients
- Place within 5mm of Q1 DRAIN pin
- Reduces high-frequency noise on 24V rail

Q1: IRLR2905 (Logic-level N-MOSFET, DPAK/TO-252)
- VDS = 55V, ID = 42A
- RDS(on) = 40mΩ @ VGS=4.5V, 27mΩ @ VGS=10V
- VGS(th) = 1.5V (works with 3.3V logic)
- Power dissipation: 1.2A² × 0.04Ω = 58mW
- Current margin: 35× (42A / 1.2A)
- SMD package for automated assembly
- PWM capable: ESP32 GPIO10 can output PWM for variable pump speed control

D1: SS34 (3A Schottky flyback diode, SMC)
- Handles main pump inductive kickback
```


**AUBIG DC40-1250 PWM Speed Control Implementation:**

The main pump supports PWM speed control via the 24V power input. The ESP32-S3 can generate PWM on GPIO10 to modulate the MOSFET gate, providing variable pump speed:

```
PWM Duty Cycle vs Flow Rate (typical):
- 100% duty cycle: 500-510 L/H (full flow)
- 75% duty cycle: ~375-380 L/H (75% flow)
- 50% duty cycle: ~250-255 L/H (50% flow)
- 25% duty cycle: ~125-130 L/H (25% flow, may stall)
- Minimum: ~30-40% duty recommended to prevent stall

ESP32-S3 PWM Configuration (suggested):
- Frequency: 25 kHz (above audible range, smooth motor control)
- Resolution: 10-bit (0-1023 values for fine control)
- Channel: LEDC PWM channel 0
- Pin: GPIO10 (same as pump control)

Benefits of PWM Control:
- Adjust circulation rate for different growth stages
- Reduce power consumption during low-demand periods
- Lower noise levels at reduced speeds
- Fine-tune nutrient flow for optimal plant uptake
- Extend pump lifespan with reduced wear
```


```
Recommended Power Supplies:
- For main pump only: 12V 3A regulated DC
- For full system (pump + dosing + ATO): 12V 5-10A regulated DC
- Quality: Mean Well, TDK-Lambda, or equivalent (low ripple essential)
```



**Pump Power Connector:**

According to the NEMA 17 convention — JST PH 2.0mm 4-pin on motor body; cable free end terminates in JST XH 2.5mm 4-pin (commonly mislabelled "XH2.54"); XH series is 2.5mm pitch, not 2.54mm DuPont). PCB footprint: B4B-XH-A; verify on receipt [ankoproducts.com](https://ankoproducts.com/products/a200sx)


```
Phoenix Contact MSTB 2.5/2-ST-5.08 (2-position screw terminal)
- Pitch: 5.08mm (0.2")
- Wire size: 24-12 AWG (for 1.5A @ 12V)
- PCB mount: Through-hole or SMD
- Mating plug: MSTB 2.5/2-STF-5.08 (optional, can use direct wire)
- Alternative: Phoenix Contact 1803280 (same as I2C) for consistency

Pin Assignment:
Pin 1: 12V_PUMP (switched via Q1)
Pin 2: GND

Pump Side Connection Options:
1. Wire leads (most common) - strip and insert into screw terminal
2. 5.5×2.1mm barrel jack - add PCB-mount jack in parallel
3. Anderson Powerpole 15A - industrial alternative
```

**PCB Layout Notes:**
- Place screw terminal at board edge for easy access
- 24V trace width: 50 mil (1.27mm) minimum for main pump
- Keep Q1 and screw terminal close to minimize trace resistance
- Add test points for 24V_SWITCHED and GND for diagnostics
- **C2 (100nF bypass)**: Place within 5mm of Q1 DRAIN pin for best performance

### 7.2 24V Dosing Pump Drivers — TMC2209 Stepper (×3)


Using a **single UART bus** with the MS1 and MS2 pins for addressing is the most "EZO-like" way to handle your **TMC2209** drivers—it keeps your pin count low and your control digital.

By hard-wiring the MS1 and MS2 pins to different logic levels (GND or VCC), you assign each driver a unique **Node Address** (0 to 3). This allows you to send commands like VACTUAL (speed) or IRUN (current) to specific pumps using only one TX/RX pair from your microcontroller.

**The "One-Wire" UART Schematic**
TMC2209s use a single-wire UART. Since your MCU likely has separate TX and RX pins, you must merge them:
- Connect **MCU TX** to a 1k  resistor, then to the PDN_UART pins of all three drivers.
- Connect **MCU RX** directly to the PDN_UART pins of all three drivers.
- Add a **10k pull-up resistor** from the UART line to your 3.3V logic rail to ensure the bus stays high during idle.




Three TMC2209 stepper drivers (QFN-28) each drive one ANKO A200SX bipolar stepper peristaltic pump. All drivers operate in **UART mode** via GPIO21/22 (ESP32-C6 UART1).
StealthChop2 is active by default at the low step rates used for dosing.

TMC2209 thermal at 1.7A: copper pour + thermal vias on PCB (standard practice) keeps Tj ~73°C at 30°C ambient; very low dosing duty cycle (seconds/day) keeps this transient.


**TMC2209 UART Configuration:**
- PDN_UART: 100Ω series resistor to shared UART bus. GPIO22 TX → bus via 1kΩ; GPIO21 RX → bus direct
- MS1/MS2: set UART address per driver (see address table below)
- EN: tied to GND — drivers permanently enabled; standstill current eliminated via `IHOLD=0`
- DIR: hardwired to 3.3V — peristaltic pumps never need reversal
- SPREAD: GND → StealthChop2 mode (silent)
- RSENSE: 120mΩ (per TMC2209 datasheet Ch. 8 recommendation for 1.7A motor) — see RSENSE section below
- VREF: resistor divider from 3.3V → 2.161V → hard 90% current cap (1.53A); IRUN register sets operating point
- STDBY (pin 20): HIGH = standby (internal regulator off, all UART registers reset to defaults);
  LOW = normal operation. **Tied to GND** — OPNhydro runs continuously; IHOLD=0 handles
  standstill power saving without the register-reset complication of STDBY.
  ⚠ If STDBY is ever asserted, all UART registers (IRUN, IHOLD, IHOLDDELAY, TPWMTHRS…)
  must be re-written by firmware after wake-up. EN must be HIGH and VREF driven to 0V
  before asserting STDBY.
- DIAG: active-HIGH output; asserts when StallGuard4 detects a stall or a driver error; see below
- INDEX: pulse output; see below

**UART address wiring (MS1/MS2 per driver):**

| Driver | MS1 | MS2 | Address |
|--------|-----|-----|---------|
| U5 pH Down | GND | GND | 0 |
| U6 Nut A | 3.3V | GND | 1 |
| U7 Nut B | GND | 3.3V | 2 |

**UART bus wiring:**

```
ESP32 GPIO22 (TX) ──── 1kΩ ──┐
                              ├── shared bus node
ESP32 GPIO21 (RX) ────────────┘        │
                                  100Ω ├──── U5 PDN_UART
                                  100Ω ├──── U6 PDN_UART
                                  100Ω └──── U7 PDN_UART
```

> **⚠ Critical Wiring Detail — The UART Resistor (per TMC2209 datasheet §4.3)**
> Connect ESP32 TX to the TMC2209 PDN_UART bus through a **1kΩ series resistor**.
> Connect ESP32 RX **directly** to the same PDN_UART bus node — no resistor on RX.
> The 1kΩ goes on the **TX line**, not the RX line.
> Source: [TMC2209 Datasheet Rev 1.09, §4.3 UART Signals](https://www.analog.com/media/en/technical-documentation/data-sheets/tmc2209_datasheet_rev1.09.pdf)

**1kΩ on GPIO22 TX:**
PDN_UART is an open-drain bidirectional pin. When the ESP32 TX drives HIGH to send a command, and the TMC2209's open-drain output momentarily pulls the bus LOW to begin its response (a brief overlap before software tri-states TX), a low-impedance conflict occurs between TX driving HIGH and the open-drain pulling LOW. The 1kΩ on TX limits the fault current during this window to (3.3V / 1kΩ) = 3.3 mA — safe for both the ESP32 output driver and the TMC2209 PDN_UART. RX is connected directly because it is a high-impedance input that only monitors the bus voltage; no protection is needed.

Configure ESP32-C6 UART1 in **half-duplex / single-wire mode** so TX is tri-stated (high-impedance) during the receive window. The TMC2209 then pulls the bus LOW open-drain to transmit its response, with no conflict from TX.

**100Ω on each PDN_UART pin:**
All three drivers share the same bus node. When one driver responds, its open-drain output pulls that driver's PDN_UART pin LOW. Without isolation, this LOW would also be seen at the PDN_UART pin of the other two non-responding drivers, which could
corrupt their internal UART state (treating the bus activity as addressed to them). 
The 100Ω series resistor on each PDN_UART pin creates a small voltage drop that decouples each driver's input from the bus during contention, and limits the current path between drivers if two open-drain outputs are momentarily both active.

**Circuit (same topology for U5/U6/U7 — MS1/MS2 differ per address table):**

```
                24V (VM)
                  │
           ┌───┬──┴──────┐
           │   │         │
        100µF 100nF      │  ← 100µF bulk + 100nF local bypass per driver
          ─┴─ ─┴─     VM │
              ┌──────────┴───────────┐
 3.3V ───────►│ VIO                  │
 GND ────────►│ GND                  │
              │                      │
 STEP_xxx ───►│ STEP          OA1 ───┼──► coil A+   ← U5: GPIO11, U6: GPIO15, U7: GPIO19
 3.3V ───────►│ DIR           OA2 ───┼──► coil A-
  GND ───────►│ EN            OB1 ───┼──► coil B+
              │               OB2 ───┼──► coil B-
UART bus─100Ω►│ PDN_UART             │   ← bus: GPIO22─1kΩ─┤; GPIO21 direct; 100Ω isolates each driver
  MS1* ──────►│ MS1           BRA ───┼──── 220mΩ ──── GND   ← RSENSE: 1%, 1/4W 0805
  MS2* ──────►│ MS2           BRB ───┼──── 220mΩ ──── GND   ← 1/8W insufficient at full scale
  GND ───────►│ SPREAD               │
  GND ───────►│ STDBY                │   ← tied LOW; STDBY resets all UART regs if pulsed
              │                      │
see below  ──►│ VREF                 │   ← ~0.58V, full-scale ~1.32A
              │      TMC2209         │
              └──────────────────────┘
  * MS1/MS2 per address table: U5=GND/GND, U6=3.3V/GND, U7=GND/3.3V
```

**GPIO Assignments:**
```
GPIO11 ──► STEP_PH_DN  (U5 pH Down driver STEP)
GPIO15 ──► STEP_NUT_A  (U6 Nutrient A driver STEP)
GPIO19 ──► STEP_NUT_B  (U7 Nutrient B driver STEP)
GPIO21 ──► TMC2209_UART_RX  (UART1 RX — shared bus listen, direct connection)
GPIO22 ──► TMC2209_UART_TX  (UART1 TX — shared bus drive, 1kΩ series to bus)
GPIO20 ──  (available — STEPPER_EN not needed; EN tied to GND)
```

**DIR hardwired to 3.3V** on all three drivers. Peristaltic pumps are self-sealing — the rollers pinch the tube closed when stopped, so backflow cannot occur and direction reversal is never needed. If a pump runs backwards on first install, swap the coil A wires (OA1 ↔ OA2) on the connector.

**SENSE resistors (R<sub>sa</sub> and R<sub>sb</sub>):**
BRA and BRB are the low-side current sense points of the H-bridge for coil A and coil B respectively. A shunt resistor connects each pin to GND. The TMC2209 measures the voltage drop across this resistor to determine actual coil current, then adjusts its PWM chopper duty cycle to regulate current to the IRUN/IHOLD target.

> All currents in this section are RMS currents. 

Following the TMC2209 datasheet Ch. 8 recommendation for the A200SX 1.7A motor.
> **R<sub>s</sub> = 120mΩ**

Based on the formula from chapter 9 of the datasheet:
> **I<sub>max</sub> = V<sub>fs</sub> / (R<sub>s</sub>+20mΩ) * 1 / √2**, where V<sub>fs</sub> is the full-scale voltage as determined by the `vsense control bit`. Default is 325mV.

So with a R<sub>s</sub> = 120mΩ and V<sub>fs</sub> = 325mV
> **I<sub>max</sub>** = 325mV / (120mΩ+20mΩ) * 1 / √2 = **1.77A**,

Set a hard limit using the V<sub>REF</sub> input of the TMC2209. This linearly scales the maximum current. To cap the operating range in hardware at 90%, apply a 
> **V<sub>REF</sub>** = (0.9 * 1.7A) / 1.77A * 2.5V = **2.161V**

Too create this voltage, use the 3.3V rail with a R<sub>H</sub> and R<sub>L</sub> voltage divider. Taking into account a R<sub>VREF</sub>=240MΩ, the required resistors follow as:
> **R<sub>H</sub> = 3.92kΩ**
> **R<sub>L</sub> = 7.68kΩ** (both E96 Series, 1%)

At 90% of I<sub>max</sub>, the sense resistor R<sub>s</sub> will dissipate:
>  **P<sub>d</sub> = I<sub>rms</sub><sup>2</sup> × R<sub>s</sub>** = (0.9 * 1.7A)<sup>2</sup> * 0.12Ω = 0.28W ⇒ choose **1/2W**

With the current capped at 90% of 1.7A, we lower the current futher with the current scale specified by the `IHOLD_IRUN` register:
> I<sub>rms</sub> = V<sub>REF</sub>/2.5V * (CS + 1)/32 * V<sub>fs</sub> / (R<sub>s</sub>+20mΩ) * 1 / sqrt(2), where V<sub>fs</sub> is the full-scale voltage as determined by the `vsense control bit`. Default is 325mV.

Try an initial **70% or 80%** operating range by setting the **CS to 24 or 27**. Increase to 85–90% only if stalling occurs on aged tubing.

CS value | Current limit| Target range
---------|---------|-------------
24       | 1.19A   | 70%
25       | 1.24A   | 73%
26       | 1.29A   | 76%
27       | 1.34A   | 79%
28       | 1.43A   | 81%
29       | 1.39A   | 84%
30       | 1.48A   | 87%
31       | 1.53A   | 90%

The sense voltage is also used by StealthChop2 (current-mode PWM feedback) and StallGuard4 (coil current deviation from expected pattern signals a stall).

**Key UART registers to configure at startup:**

| Register | Value | Purpose |
|----------|-------|---------|
| `IHOLD` | 0 | Zero standstill current (EN tied to GND — this is essential) |
| `IRUN` | 24 | Run current ≈ 70% (CS=24 → 1.19A; increase to 27 for ~79% if stalling occurs — see CS table above) |
| `IHOLDDELAY` | 6 | Steps between IRUN→IHOLD transition after last STEP pulse |
| `TPWMTHRS` | 0 | StealthChop2 active at all speeds |
| `SENDDELAY` | ≥2 | **Required for multi-driver bus.** Reply delay before TMC2209 begins its UART response. Default (0) can cause a non-addressed chip to detect a transmission error when a different chip responds. Set to 2 or higher on all drivers. See note below. |

> **⚠ Multi-driver SENDDELAY note**
> When multiple TMC2209 chips share the same serial line with different addresses, the
> `SENDDELAY` register must be increased from its default value, otherwise a non-addressed
> chip may detect a transmission error when it sees the response from the addressed chip.
> Set `SENDDELAY` ≥ 2 on every driver at firmware init.
> Source: [janelia-arduino/TMC2209 library README](https://github.com/janelia-arduino/TMC2209)

**DIAG pin:**
Active-HIGH open-drain output. Asserts (goes HIGH) when StallGuard4 detects a motor
stall or when a driver error occurs (overtemperature, short circuit). In UART mode,
stall detection is preferred via the `DRV_STATUS` register (read `SG_RESULT` field)
rather than the DIAG pin — this avoids spending a GPIO and is more informative
(gives a numeric stall load value, not just a binary flag).

PCB connection options:
- **v1 (recommended):** leave DIAG floating — no GPIO required; poll `DRV_STATUS` via
  UART instead. Place a DNP 10kΩ pullup footprint to 3.3V for future use.
- **v2 (optional):** connect each DIAG to a free GPIO (GPIO18, GPIO20, GPIO23) via
  10kΩ pullup; allows interrupt-driven stall detection without polling.

**INDEX pin:**
Pulse output — by default emits one pulse per electrical period (every 4 full steps at
1× microstepping). Can be reconfigured via UART `IOIN` register to signal other events
(e.g. first microstep position, stepper index).

For dosing pumps, step count is controlled directly by the ESP32 (counted steps = known
volume), so INDEX adds no value in normal operation. **Leave INDEX floating** (high-Z
output, no harm). Place a DNP 1kΩ series + test point footprint for debugging if needed.

**Standalone fallback (no firmware UART):** replace each 100Ω PDN_UART series resistor
with 100kΩ to 3.3V; set MS1/MS2 both to 3.3V (1/16 microstep, addr unused); connect
EN to GPIO20. Current then set by VREF divider only. StealthChop2 remains active.

**VM Bulk Capacitance:**
Place at least one **100µF electrolytic capacitor** (≥35V, low-ESR) close to each
driver's VM pin. The TMC2209 chopper switches coil current rapidly — each switching
event draws a brief spike from the VM supply. Without local bulk capacitance these
spikes appear as voltage transients on the VM rail, which can corrupt UART communication
(if the supply dips below the VIO logic threshold briefly) and degrade StallGuard4
accuracy (coil current measurement depends on a stable VM). A 100nF ceramic (already
in the circuit) handles high-frequency transients; the 100µF electrolytic handles the
lower-frequency, higher-energy spikes from step-rate switching. Place the 100µF within
5mm of the VM pin, with a short direct trace to GND.

**Firmware — TMCStepper Library:**

Use **[TMCStepper](https://github.com/teemuatlut/TMCStepper)** for all TMC2209 driver
configuration and status monitoring. It provides full UART register access: write
IRUN=18, IHOLD=0, IHOLDDELAY=6, TPWMTHRS=0 at startup; read DRV_STATUS.SG_RESULT and
temperature flags during operation. No alternative library provides this capability.

**Firmware — STEP Pulse Generation (RMT / LEDC / ISR Timer):**

STEP pulses must be generated by hardware peripherals, not software loops.

If the ESP32 is busy with a Wi-Fi request, SSL/TLS handshake, or MQTT reconnect, a
software-timed pulse loop can stall for tens of milliseconds. A single missed or late
pulse causes the stepper to lose a step — and since dosing accuracy is derived from
step count × tube displacement constant, one lost step per dose accumulates into
measurable calibration error over time.

The ESP32-C6 provides three suitable hardware options:

**Option 1 — RMT (Remote Control Transceiver) — recommended:**
The RMT peripheral generates arbitrary pulse sequences from a preloaded buffer with
nanosecond resolution, independent of the CPU. Configure it to output N pulses at the
target step frequency, then trigger it once per dose. When the burst completes it fires
a done interrupt; the CPU core is free throughout.

```
// Pseudocode — ESP-IDF RMT approach
rmt_config_t cfg = { .gpio_num = STEP_PH_DN, .clk_src = RMT_CLK_SRC_DEFAULT };
rmt_channel_handle_t ch;
rmt_new_tx_channel(&cfg, &ch);
// preload N symbols: 50% duty, period = 1/step_freq
rmt_transmit(ch, encoder, symbols, n_steps, NULL);
// CPU is free; RMT fires done callback when burst finishes
```

Supports up to 4 independent TX channels on ESP32-C6 → one per STEP pin (GPIO11,
GPIO15, GPIO19) with one spare.

**Option 2 — LEDC (LED PWM Controller):**
LEDC generates continuous PWM at hardware level. For dosing, drive LEDC at the target
step frequency and disable it after counting the required pulses via a GPIO interrupt
on the STEP line, or use a one-shot approach: enable LEDC, start a hardware timer for
N/freq seconds, disable LEDC in the timer callback. Less precise step count than RMT
(off-by-one at stop edge possible) but simpler to configure.

**Option 3 — ESP32_ISR_Stepper / ESP32TimerInterrupt:**
The [ESP32TimerInterrupt](https://github.com/khoih-prog/ESP32TimerInterrupt) library
configures hardware timer ISRs that run independently of the main loop and Wi-Fi
stack. Use with `ESP32_ISR_Timer` in non-blocking mode: the ISR toggles the STEP GPIO
at the target rate and decrements a step counter; when it reaches zero the ISR
disables itself. All three pump channels require separate hardware timer instances
(ESP32-C6 has 2 hardware timer groups × 2 timers each = 4 timers available).

**Recommendation for OPNhydro:**
Use **RMT** as the primary approach. It is the most deterministic, requires no ISR
management, and the burst-complete callback integrates cleanly with an ESPHome custom
component or FreeRTOS task. Use `ESP32TimerInterrupt` as a fallback if the RMT
peripheral is needed for other functions (e.g. WS2812B LED strip).

**Dosing Pump — ANKO A200SX:**

| Parameter | Specification |
|-----------|---------------|
| Motor body connector | JST PH 2.0mm 4-pin (female, on pump body) |
| Cable free-end connector | JST XH 2.5mm 4-pin (female) — PCB side |
| Source | [ankoproducts.com/products/a200sx](https://ankoproducts.com/products/a200sx) |

The A200SX motor cable carries coil wires only (4 pins). VCC/GND are not in this connector — the TMC2209 H-bridge drives the coils directly.

```
JST XH 2.5mm 4-pin Assignment (verify against A200SX datasheet on receipt):
┌─────┬────────────────┬─────────────────────────────────────┐
│ Pin │ Signal         │ PCB connection                      │
├─────┼────────────────┼─────────────────────────────────────┤
│  1  │ Coil A+  (OA1) │ TMC2209 OA1                         │
│  2  │ Coil A−  (OA2) │ TMC2209 OA2                         │
│  3  │ Coil B+  (OB1) │ TMC2209 OB1                         │
│  4  │ Coil B−  (OB2) │ TMC2209 OB2                         │
└─────┴────────────────┴─────────────────────────────────────┘
⚠ Verify pin order from A200SX datasheet before PCB layout. Coil swap (A↔B or polarity)
  only affects rotation direction; the TMC2209 handles both.
```

**Dosing Pump Connector (×3, PCB side):**

```
JST B4B-XH-A (4-position XH male header, 2.5mm pitch, right-angle TH, PCB mount) ×3
- Mates with: JST XH 2.5mm 4-pin female housing on pump cable free end
- Pitch: 2.5mm
- 4 pins: coil A+, coil A−, coil B+, coil B−  (no VCC/GND)
- Silkscreen label: "pH DN", "NUT A", "NUT B"
- Right-angle orientation: cable exits horizontally toward board edge
- Alternative: B4B-XH-AM (vertical TH) if cables must exit upward
- Verify exact part on receipt — ARCHITECTURE.md notes connector mislabelled "XH 2.54mm"
  in 3D printer community; XH series is 2.5mm pitch
```

### 7.3 ATO Solenoid Valve Driver

```
Same circuit topology as dosing pumps, using AO3400A MOSFET.
Connected to 24V rail.
Uses normally-closed (NC) solenoid valve for fail-safe operation.

                                    24V
                                     │
                        ┌────────────┤
                        │            │
                       D1         VALVE+
                   (1N5819)         │
                        │         VALVE
                        │        (NC, 500mA)
               ┌────────┴───────┐   │
               │     DRAIN      │   │
        ┌──────┤  Q8            ├───┴── VALVE-
        │      │  AO3400A       │
        │      │  (SOT-23)      │
        │      └───────┬────────┘
        │           SOURCE
        │              │
       R2             ─┴─
      100Ω            GND
        │
        ├────────────────────────────────── Gate (Q8)
        │                                       │
GPIO2 ──┘                                      R1
                                              10kΩ (pull-down)
                                               │
                                              ─┴─
                                              GND

Hardware cutoff — FLOAT_HIGH (water-high) overrides GPIO7:

GPIO1 ──── R_base (4.7kΩ) ──── Base ┐
                                     │ Q10: MMBT3904 NPN
                          Emitter ───┴─── GND
                          Collector ─────────────────────────► Gate (Q8)

When GPIO1 HIGH (water high): Q10 saturates → Gate clamped to ≤0.2V → Q8 OFF → valve closes (hardware)
When GPIO1 LOW  (water OK):   Q10 off      → Gate driven by GPIO2 normally
```

Q8: AO3400A (Logic-level N-MOSFET, SOT-23)
- VDS = 30V, ID = 5.8A
- RDS(on) = 33mΩ @ VGS=4.5V
- Handles 500mA solenoid load with margin
- Power dissipation: ~8mW (very low)
- Alternative: BSS214N (50V, 5A, 100mΩ)

D1: 1N5819 (1A Schottky flyback diode, SOD-123)
- Sufficient for solenoid valve inductive spike suppression


**ATO Valve Connector:**

```
Phoenix Contact MC 1.5/2-ST-3.5 (2-position pluggable screw terminal)
- Pitch: 3.5mm — same family as dosing pump connectors
- PCB header: MC 1.5/2-G-3.5
- Wire size: 24-18 AWG (for 250mA @ 24V)
- Label silkscreen: "ATO VALVE" or "WATER IN"

Pin Assignment:
Pin 1: 24V_VALVE (switched via Q8)
Pin 2: GND

Valve Side Connection:
- Most solenoid valves have 2-wire leads (polarity doesn't matter for DC)
- Some have wire connectors (DIN 43650A common)
- Strip and insert into screw terminal, or add mating connector
```

**Safety Notes:**
- ✅ NC valve ensures no water flow if controller loses power
- ✅ Float switch (GPIO1 - FLOAT_HIGH) provides hardware backup cutoff
- ✅ Float switch (GPIO0 - FLOAT_LOW) provides low-level alarm
- ✅ Software timeout prevents flooding if level sensor fails
- ✅ Recommend inline manual shutoff valve for maintenance
- ✅ Consider water leak sensor near reservoir for additional protection

**Both switches are mounted NC (hinge pointing DOWN).** Wiring to the PCB differs
between the two so that both GPIO signals are active-HIGH on their cutoff condition



**Valve Installation:**
1. Install valve inline on water supply line (before reservoir)
2. Arrow on valve body indicates flow direction
3. Mount valve with coil vertical (prevents water ingress)
4. Use thread sealant (Teflon tape or pipe dope) on NPT threads
5. Test valve operation before connecting to reservoir

### 7.4 MOSFET Selection Summary

**Design Strategy:** All-SMD design with appropriately-sized MOSFETs for each load type.

| Load | Current | MOSFET | Package | RDS(on) @ 4.5V | Margin | Rationale |
|------|---------|--------|---------|----------------|--------|-----------|
| **Main Pump (AUBIG DC40-1250)** | 1.2A | **IRLR2905** | DPAK | 40mΩ | 35× | PWM capable, SMD |
| **ATO Solenoid** | 500mA | **AO3400A** | SOT-23 | 33mΩ | 11× | Low cost, efficient |

Dosing pumps (A200SX) are driven by TMC2209 internal H-bridges — no discrete MOSFET required.

**Power Dissipation Analysis:**
- IRLR2905 (Main pump): 1.2A² × 0.04Ω = **58mW** (DPAK handles easily)
- AO3400A (ATO): 500mA² × 0.033Ω = **8mW** (very low for SOT-23)

**Benefits:**
- ✅ **100% SMD design** - entire board can use pick-and-place assembly
- ✅ **Compact footprint** - DPAK + 5× SOT-23 (vs 6× TO-220 through-hole)
- ✅ **Production-friendly** - no manual through-hole soldering required
- ✅ **Lower assembly cost** - automated SMD assembly throughout
- ✅ **Appropriate sizing** for each load (not overkill)
- ✅ **All logic-level compatible** (work with 3.3V GPIO)
- ✅ **Consistent design** - all MOSFETs are SMD packages
- ✅ **AO3400A optimization** - Lower RDS(on) (33mΩ vs 100mΩ), lower cost ($0.10 vs $0.20)

**Part Numbers:**
- Q1 (Main Pump): **IRLR2905** or IRLR2905ZPBF (Infineon, DPAK/TO-252)
- Q2 (ATO Solenoid): **AO3400A** (Alpha & Omega, SOT-23) - Primary choice
- Alternative for Q2: BSS214N / BSS214NH6327XTSA1 (Infineon, 5A, SOT-23)


⚠️ **CRITICAL for AUBIG DC40-1250**: Brushless motor requires stable, low-ripple DC power supply.

| Specification | Minimum | Recommended | Ideal (Commercial) |
|---------------|---------|-------------|-------------------|
| **Voltage** | 12V DC ±5% | 12V DC ±2% | 12V DC ±1% |
| **Current** | 3A (36W) | 5A (60W) | 10A (120W) |
| **Ripple** | <200mV p-p | <100mV p-p | <50mV p-p |
| **Regulation** | Line ±5% | Line/Load ±2% | Line/Load ±1% |
| **Inrush Handling** | 2× rated | 2× rated | 3× rated |
| **Use Case** | Budget (no PWM) | Standard (PWM OK) | Professional |



## 8. Status LED

The ESP32-C6-DevKitC-1 includes a built-in RGB LED (WS2812B) on GPIO8.
No external status LED is needed on the OPNhydro PCB.

Use GPIO8 in firmware for status indication (do not route GPIO8 to any PCB pad).

---


----

# ADM3260 Specifics

- **Stitching Capacitance:** To reduce Electromagnetic Interference (EMI) caused by the internal DC-DC converter, place a small amount of "stitching capacitance" across the isolation barrier. This is often achieved by overlapping internal PCB layers (if using a 4-layer board) or using a dedicated Y-rated capacitor. [1, 5, 12]

- **Bypass Capacitors:** Place a 0.1µF ceramic capacitor as close as possible to the VCC and VISO pins. For the ADM3260, a 10µF tantalum or ceramic capacitor is also required on both the input and output power pins to handle the switching currents of the internal transformer. [5, 8, 12]

- **Pull-up Resistors:** I2C requires pull-up resistors on both sides of the isolation barrier.
  - Primary Side (SDA/SCL): 4.7k to 10k tied to the microcontroller's 3.3V/5V.
  - Secondary Side (SDA_ISO/SCL_ISO): 1k to 4.7k tied to VISO. Using lower values (like 2.2k) on the isolated side helps maintain signal integrity in mineral-heavy environments where cable capacitance might be higher. [1, 5]

- **Trace Lengths:** Keep the I2C traces between the ADM3260 and the EZO socket as short as possible to prevent picking up noise from your 24V solenoid or pump. [1, 8]

Sources and Documentation:
- **Analog Devices ADM3260 Datasheet:** The definitive source for "Layout Guidelines" and "EMI Considerations" (See pages 16-18). [5, 8]
- **Atlas Scientific USB Isolator Schematic:** Their public hardware documentation shows the ADM3260 implementation for I2C isolation. [1, 10]
- **AN-0971 Application Note:** "Recommendations for Control of Radiated Emissions with isoPower Devices." [12]



