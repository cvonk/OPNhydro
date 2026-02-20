# Schematic Design Guide

This document describes the circuit design for the OPNhydroponics controller PCB.

## Block Diagram

```
                                    ┌────────────────────────────────────────┐
                                    │              CONNECTORS                │
                                    │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
                                    │  │ BNC │ │ BNC │ │ BNC │ │Float│       │
                                    │  │ pH  │ │ EC  │ │ DO  │ │ SW  │       │
                                    │  └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘       │
                                    └─────┼──────┼──────┼──────┼─────────────┘
                                          │      │      │      │
┌──────────────────────────────────────────────────────────────────────────────┐
│                                  PCB                                         │
│  ┌─────────────┐    ┌─────────────────────────────────────────────────────┐  │
│  │   POWER     │    │                    SENSORS                          │  │
│  │             │    │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐     │  │
│  │ 12V ──►5V   │    │  │ EZO-pH │  │ EZO-EC │  │ EZO-DO │  │ BME280 │     │  │
│  │     ──►3.3V │    │  │  I2C   │  │  I2C   │  │  I2C   │  │  I2C   │     │  │
│  │             │    │  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘     │  │
│  └──────┬──────┘    │      │           │           │           │          │  │
│         │           │      └───────────┴───────────┴───────────┘          │  │
│         │           │                      │ I2C Bus                      │  │
│         │           └──────────────────────┼──────────────────────────────┘  │
│         │                                  │                                 │
│         │           ┌──────────────────────┼──────────────────────────────┐  │
│         │           │              ESP32-C6-WROOM-1                       │  │
│         │           │  ┌────────────────────────────────────────────┐     │  │
│         └──────────►│  │  GPIO1/2: I2C    GPIO3: 1-Wire             │     │  │
│                     │  │  GPIO4/5: Ultrasonic  GPIO6-10: Pumps      │     │  │
│                     │  │  GPIO11/12: Float SW  GPIO13: LED          │     │  │
│                     │  │  GPIO18/19: USB       GPIO15/16: UART      │     │  │
│                     │  └────────────────────────────────────────────┘     │  │
│                     └──────────────────────┬──────────────────────────────┘  │
│                                            │                                 │
│         ┌──────────────────────────────────┼──────────────────────────────┐  │
│         │                   PUMP/VALVE DRIVERS (all 12V)                  │  │
│         │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐     │  │
│         │  │ 12V    │  │ 12V    │  │ 12V    │  │ 12V    │  │ 12V    │     │  │
│         │  │ Main   │  │ pH Up  │  │ pH Dn  │  │ Nut A  │  │ Nut B  │     │  │
│         │  │ Pump   │  │ Dose   │  │ Dose   │  │ Dose   │  │ Dose   │     │  │
│         │  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘     │  │
│         │                                                  ┌────────┐     │  │
│         │                                                  │ 12V    │     │  │
│         │                                                  │ ATO    │     │  │
│         │                                                  │ Valve  │     │  │
│         │                                                  └────────┘     │  │
│         └─────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Power Supply Section

### 1.1 Input Protection

```
12V DC IN ──┬──[PTC 5A]──┬──[TVS 15V]──┬──► 12V_PROTECTED
            │            │             │
           ─┴─          ─┴─           ─┴─
           GND          GND           GND

Component Selection:
- PTC: RXEF500 (5A hold, 10A trip)
- TVS: SMBJ15A (15V standoff, 24V clamp)
```

### 1.2 Reverse Polarity Protection

```
12V_PROTECTED ────┬───────────────────────► 12V_RAIL
                  │
              ┌───┴───┐
              │       │ S (Source tied to input)
       ┌──────┤ Q1    │──────────────────────────────────► 12V_SAFE
       │      │ (P-FET)│
       │      └───┬───┘ D
       │          │G
       R1      ┌──┴──┐
       10k     │ R2  │ 100k
       │       │     │
       ├───────┴─────┘
       │
      ─┴─
      GND

Q1: SI2301 (P-channel MOSFET, SOT-23)
- Vds = -20V, Id = -2.8A, Rds(on) = 80mΩ
```

### 1.3 Buck Converter

**12V to 5V (Logic/USB)**
```
                        Cbst
            ┌──────────┤├───────────────────────────────┐
            │         100nF                             │
            │                                      BST─┘
12V_SAFE ───┼──[Cin]──┬──────────────────────────┐
            │  10µF   │                      VIN─┤2      1├─BST
            │        ─┴─                         │           │
            │        GND          EN ────────────┤3  TPS  6 ├─SW──┬──[L1 4.7µH]──┬──► 5V
            │                    3.3V             │  62933    │     │               │
            │                    Rrt ─────────────┤4  DRL  5 ├─GND │            [Cout]
            │                    47k              │           │    ─┴─           2×22µF
            │                    │               ─┴─         GND   │               │
            │                   ─┴─              GND               │              ─┴─
            │                   GND                                │              GND
            │                                                      │
            │              ┌──[R_top 200k]────────────────────────┤ 5V
            │              │                                       │
            │           FB─┤7                                     ─┴─
            │              └──[R_bot 38.3k]──► GND               GND
            │
            │        Css ──────────────────── SS─┤8
            │       10nF                          │
            │                                    ─┴─
            │                                    GND
           ─┴─
           GND

Vout = 0.8V × (1 + R_top/R_bot)  →  5V = 0.8 × (1 + 200k/38.3k) ≈ 4.98V ✓
Fsw  = 57,400 / RT(kΩ) + 10.3    →  RT = 47kΩ → Fsw ≈ 1 MHz

Component Selection:
- IC:   TPS62933DRLR (SOT583, synchronous buck, 3.8–30V in, 3A, 200kHz–2.2MHz)
- L1:   4.7µH, 3A, DCR < 50mΩ (e.g. Würth 744043004)
- Cin:  10µF / 25V ceramic (X5R or X7R)
- Cout: 2×22µF / 10V ceramic (X5R or X7R)
- Cbst: 100nF / 10V ceramic (BST to SW)
- Css:  10nF (soft-start ≈ 1.5ms; minimum 6.8nF, do not float)
- Rrt:  47kΩ to GND → Fsw = 1MHz
- R_top: 200kΩ 1%
- R_bot:  38.3kΩ 1% (E96 series)
- No external compensation required (internal loop compensation)
- No external diode required (synchronous rectification)

Note: 12V rail powers pumps and ATO valve directly.
```

### 1.4 LDO (3.3V)

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

The ESP32-C6-DevKitC-1-N8 mounts to the carrier PCB via 2×20 pin headers.
USB-C, boot/reset buttons, antenna, and power regulation are on the DevKit.

```
                    ┌─────────────────────────────────────┐
                    │        ESP32-C6-DevKitC-1-N8        │
                    │     (includes USB-C, antenna,       │
                    │      boot/reset buttons, RGB LED)   │
                    │                                     │
           3.3V ────┤ 3V3                            GND  ├──── GND
            5V ─────┤ 5V (from USB or external)           │
                    │                                     │
    FLOAT_LOW ──────┤ GPIO1                               │
       US_ECHO ─────┤ GPIO2                               │
   FLOAT_HIGH ──────┤ GPIO3                               │
       I2C_SDA ─────┤ GPIO4                               │
       I2C_SCL ─────┤ GPIO5                               │
      ONE_WIRE ─────┤ GPIO6                               │
       US_TRIG ─────┤ GPIO7                               │
                    │                                     │
     (reserved) ────┤ GPIO8 (RGB LED on DevKit)           │
     ATO_VALVE ─────┤ GPIO9  (strapping pin - see note)   │
     PUMP_MAIN ─────┤ GPIO10                              │
     PUMP_PH_UP ────┤ GPIO11                              │
                    │                                     │
     PUMP_PH_DN ────┤ GPIO15                              │
    PUMP_NUT_A ─────┤ GPIO19                              │
    PUMP_NUT_B ─────┤ GPIO20                              │
                    │                                     │
                    └─────────────────────────────────────┘

Note: DevKit has onboard RGB LED on GPIO8 - we use external WS2812B on GPIO13
      for visibility through enclosure. GPIO8 is reserved (do not use).

WARNING: GPIO9 is a strapping pin (boot mode). For output use (ATO_VALVE), ensure
         the MOSFET driver circuit has a 10k pullup to 3.3V on the GPIO side so the
         pin floats high during boot. Do not pull low externally during power-on.
```

### 2.2 Carrier PCB Headers

```
Use 2×20 female headers (2.54mm pitch) on carrier PCB.
DevKit plugs in from above.

Header spacing: 22.86mm (900 mils) between rows
```

---

## 3. I2C Sensor Interface

### 3.1 I2C Bus

```
                3.3V
                 │
            ┌────┴────┐
            │    │    │
           R1   R2   C1
           4.7k 4.7k 100nF
            │    │    │
GPIO1 ──────┼────┴────┴──────────► SDA Bus (to all I2C devices)
            │
GPIO2 ──────┴────────────────────► SCL Bus (to all I2C devices)
```

### 3.2 EZO Circuit Connections

```
Atlas Scientific EZO circuits use standard I2C.
Default addresses:
- EZO-pH:  0x63
- EZO-EC:  0x64
- EZO-DO:  0x61 (may need address change to avoid conflict)
- BME280:  0x76
- BH1750:  0x23

Each EZO circuit:
┌──────────────────────────────────────┐
│  EZO-pH (or EC, DO)                  │
│                                      │
│   VCC ◄──── 3.3V (isolated)          │
│   GND ◄──── GND (isolated)           │
│   SDA ◄───► I2C SDA                  │
│   SCL ◄──── I2C SCL                  │
│   PRB ◄──── BNC panel-mount (probe uses SMA-to-BNC adapter) │
│                                      │
└──────────────────────────────────────┘

For probe isolation, power each EZO from isolated DC-DC:
3.3V ──► [B0303S-1WR2] ──► 3.3V_ISO ──► EZO VCC
```

### 3.3 Qwiic/STEMMA QT Compatible Connectors

```
JST-SH 4-pin (1mm pitch) or JST-PH 4-pin (2mm pitch)

Pin 1: GND (Black)
Pin 2: 3.3V (Red)
Pin 3: SDA (Blue)
Pin 4: SCL (Yellow)
```

---

## 4. Temperature Sensor (1-Wire)

```
         3.3V
          │
         R1
        4.7k
          │
GPIO3 ────┼───────────────────► To DS18B20 Data
          │
         ─┴─
         GND

DS18B20 (TO-92 or waterproof probe):
┌──────────┐
│ DS18B20  │
│          │
│ GND ─────┼──► GND
│ DQ ──────┼──► GPIO3 (with 4.7k pullup)
│ VDD ─────┼──► 3.3V
└──────────┘

Multiple sensors can share the same bus (each has unique 64-bit ROM ID)
```

---

## 5. Ultrasonic Sensor (HC-SR04)

```
HC-SR04 runs at 5V but GPIO is 3.3V tolerant

        5V ──────────────────────────► VCC
                                        │
                                   ┌────┴────┐
        GND ─────────────────────► │ HC-SR04 │
                                   │         │
        GPIO4 ───────────────────► │ TRIG    │
                                   │         │
                  ┌───[1k]───┬───► │ ECHO    │
                  │          │     └─────────┘
        GPIO5 ◄───┘       [2.2k]
                            │
                           ─┴─
                           GND

Note: Voltage divider on ECHO (5V → 3.3V)
      Or use level shifter if preferred
```

---

## 6. Float Switch Interface

```
        3.3V
         │
        R1
       10k (pullup)
         │
GPIO11 ──┼──────────────► Float Switch ──► GND
         │
        C1
       100nF (debounce)
         │
        ─┴─
        GND

Repeat for GPIO12 (second float switch)
```

---

## 7. Pump Driver Circuits

All pumps and the ATO valve use the same 12V rail and identical driver circuits.

### 7.1 12V Main Pump Driver

```
                                    12V
                                     │
                        ┌────────────┤
                        │            │
                       D1          PUMP+
                    (SS34)          │
                        │          PUMP
                        │           │
               ┌────────┴───────┐   │
               │     DRAIN      │   │
        ┌──────┤  Q1            ├───┴── PUMP-
        │      │  IRLZ44N       │
        │      │                │
        │      └───────┬────────┘
        │           SOURCE
        │              │
       R2             ─┴─
      100Ω            GND
        │
        │
GPIO6 ──┼────────┬─────────────────► Gate Drive
                 │
                R1
               10k
                 │
                ─┴─
                GND

Q1: IRLZ44N (Logic-level N-MOSFET)
- Vds = 55V, Id = 47A
- Vgs(th) = 1-2V (works with 3.3V logic)

D1: SS34 (3A Schottky flyback diode)
```

### 7.2 12V Dosing Pump Drivers (×4)

```
Same circuit as main pump, all on 12V rail.
Use separate MOSFET for each dosing pump.

GPIO7  ──► Pump pH Up (optional)
GPIO21 ──► Pump pH Down
GPIO9  ──► Pump Nutrient A
GPIO10 ──► Pump Nutrient B
```

### 7.3 ATO Solenoid Valve Driver

```
Same circuit as dosing pumps, connected to 12V rail.
Uses normally-closed (NC) solenoid valve for fail-safe operation.

GPIO20 ──► ATO Solenoid Valve (12V NC)

                                    12V
                                     │
                        ┌────────────┤
                        │            │
                       D1         VALVE+
                    (SS34)          │
                        │         VALVE
                        │        (NC)
               ┌────────┴───────┐   │
               │     DRAIN      │   │
        ┌──────┤  Q6            ├───┴── VALVE-
        │      │  IRLZ44N       │
        │      │                │
        │      └───────┬────────┘
        │           SOURCE
        │              │
       R2             ─┴─
      100Ω            GND
        │
        │
GPIO20 ─┼────────┬─────────────────► Gate Drive
                 │
                R1
               10k
                 │
                ─┴─
                GND

Solenoid Valve Selection:
- Type: Normally Closed (NC) - fails safe (closed when power off)
- Voltage: 12V DC
- Current: 300-500mA typical
- Connection: 1/2" NPT or hose barb
- Material: Food-safe (brass or plastic body, EPDM seals)

Safety Notes:
- NC valve ensures no water flow if controller loses power
- Float switch (GPIO12) provides hardware backup cutoff
- Software timeout prevents flooding if level sensor fails
```

---

## 8. Status LED (WS2812B)

```
        5V ──────┬────────────────────► VDD
                 │
               C1
              100nF
                 │
               ─┴┬─
              GND│
                 │
                 │    ┌─────────────┐
        GPIO13 ──┴──► │ DIN         │
                      │   WS2812B   │
                      │             │
        GND ────────► │ VSS         │
                      └─────────────┘

Note: WS2812B runs at 5V but data line works with 3.3V logic
      Add 100Ω series resistor on data line for signal integrity
```

---

## 9. Optional OLED Display

```
SSD1306 128x64 I2C OLED

4-pin header (2.54mm):
┌─────────────────────────┐
│ Pin 1: GND ──► GND      │
│ Pin 2: VCC ──► 3.3V     │
│ Pin 3: SCL ──► I2C_SCL  │
│ Pin 4: SDA ──► I2C_SDA  │
└─────────────────────────┘

I2C Address: 0x3C (default)
```

---

## 10. PCB Layout Guidelines

### 10.1 Layer Stack (2-layer)
- Top: Signal + Power
- Bottom: Ground plane (solid)

### 10.2 Critical Routing
1. Keep power traces wide (1mm min for logic, 2mm+ for pump circuits)
2. Star ground from single point near power input
3. Keep analog (I2C sensors) away from switching circuits
4. Keep 40mm clearance around ESP32-C6 antenna (no copper on top layer)

### 10.3 Connector Placement
- Power input on one edge
- Pump outputs grouped together
- BNC connectors on opposite edge from power
- USB-C accessible for programming

### 10.4 Thermal Considerations
- Add thermal vias under MOSFET source pads
- Use large copper pours for heatsinking
- Consider heatsinks on MOSFETs if continuous pump operation

---

## 11. Test Points

Add test points for debugging:
- TP1: 3.3V
- TP2: 5V
- TP3: 12V
- TP4: GND
- TP5: I2C SDA
- TP6: I2C SCL
- TP7: 1-Wire
