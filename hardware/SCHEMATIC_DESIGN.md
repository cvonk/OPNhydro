# Schematic Design Guide

This document describes the circuit design for the OPNhydroponics controller PCB.  It **answers how:** to implement the architecture.  As such it covers the schematics including the glue around the ICs, trace widths and placement rules.

The key challange with this board is the mix of a **sensitive** MCU and sensors (pH/EC), and their **noisy neighbors** such as a buck converter, isolated DC/DC converter (ADM3260), and high-noise steppers (TMC2209).

This document starts with the most critical parts of the Schematic and PCB Layout:
1. Stability Under Peak Loads
2. Integration of Precision Dosing and EMI Mitigation
3. Maintaining Signal Integrity via Isolation

It then continues to fill in the details:
4. Reservoir Level Circuits
5. Main Pump and OTA Solenoid Drivers
6. I2C and Optional Sensors
7. ESP32-C6 Hookup
8. EZO Circuits for the Probes
9. Hand-Soldering


---


## 1. Stability Under Peak Loads

The system must manage a **peak draw of approximately 4.7A** when the 1.2A main pump, the Solenoid Valve and two 1.53A nutrient pumps are active on top of the typical current draw from the Reflected 5V Rail and .

Stability is provided by:
- Bulk Capacitance that supply instantaneous current surges, preventing "voltage sags".
- PCB Specifications: a 4-layer PCB with 2oz copper outer layers.

The **main pump**, **stepper motors**, the **solenoid** and **buck converter** turns the PCB into a high-noise environment. Stepper drivers are notorious for creating Electromagnetic Interference (EMI) and ground bounce that can "ghost" the I2C bus or cause pH readings to jump.

**Topology:**

```
 [PSU]
   │
   ├──► 24V Rail ──┬──► MOSFET ───► Main Pump
   │               ├──► MOSFET ───► Solenoid Valve
   │               ├──► TMC2209 ──► Stepper pH Down
   │               ├──► TMC2209 ──► Stepper Nutrient A
   │               └──► TMC2209 ──► Stepper Nutrient B
[Buck 24V─►5V]
   │
   ├──► 5V Rail ───┬──► ESP32-C6 (makes its own 3.3V rail)
   │               └──► LiDAR
   │
 [LDO 5V─►3V3]
   │
   └──► 3V3 Rail ──┬──► ADM3260 ──► pH EZO (isolated 3.3V via isoPower)
                   ├──► ADM3260 ──► EC EZO (isolated 3.3V via isoPower)
                   ├──► RTD EZO circuit
                   ├──► BME280
                   └──► BH1750
```


### 1.1. Connector

- Phoenix Contact, Series MSTBA (P/N 1757242)
- 2 Position Header
- Pitch 0.2" (5.08mm)
- Pin 1 to 24V, pin 2 to GND
- Mating plug: Phoenix Contact P/N 1757019


### 1.2. Protection Gauntlet

The 24V enters the board and passes through a "protection gauntlet" before it reaches the motor drivers or the sensitive sensor logic:

1. **Main Fuse (F1):** 7A Fast-Acting. Not using PTC, because of Response Time and Voltage Drop. This provides a 32% headroom over the 5.3A peak, while still being close to 6.5A rating of the PSU.
2. **TVS Diode (D1):** 28V (SMCJ30A). If a massive overvoltage event occurs, the TVS diode will shunt the excess current to ground, potentially blowing the fuse but saving the rest of the PCB.
3. **Reverse Polarity Protection (T1):** If power is connected in reverse polarity, this stops current instantly, saving the TMC2209s.

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


Given the 5.3A peak current identified in the sources, standard electrical practices suggest the following for 24V DC systems:
- **Main Power Input (from Supply to PCB):** 18 AWG is recommended for currents up to 10A to minimize voltage drop over short runs.


### 1.3. Buck Converter

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


---


### 1.4 Lineair Regulator LDO (3.3V)

```
5V ───────┬──► VIN ┌─────────┐ VOUT ──┬──[10µF]────► 3.3V
          │        │ AMS1117 │        │          
       [10µF]      │  -3.3   │     [10µF]
          │        └────┬────┘        │
          │             │             │
         ─┴─           ─┴─           ─┴─
```

---


### 1.5. Bulk Caps are Your Friend

The use of a hierarchical capacitance strategy — employing a global reservoir and multiple local reservoirs — is fundamental to maintaining the chemical and thermal stability required for this high-precision 100L systems. This approach ensures that peak loads stay as local as possible.

Every wire and PCB trace has inductance. Inductance resists instantaneous changes in current:
$$
  U = L \  \frac{dI}{dt}
$$

When a stepper driver or motor demands a sudden surge of current, the inductance of the supply path creates a voltage drop — the rail sags. The further the current has to travel from the supply, the worse the sag. Bulk capacitance acts as a local energy reservoir — storing charge close to the load so it can be delivered instantly when current demand spikes.

For this board, the TMC2209 is of special concern, because it chops current to the stepper coils at 20–50kHz. Every switching cycle it draws a sharp current pulse from the VM pin. Without local capacitance, these pulses travel back through the trace inductance to the bulk cap at the power entry.

The recommended bulk capacitors:

Rail | Place               | Peak Current | Value / Voltage | Dielectric             | Purpose
----:|---------------------|--------------|----------------:|------------------------|--------
 24V | Main power entry    | ~4.7A        | 1000µF / 50V    | Aluminium electrolytic | Primary reservoir
 24V | Each TMC2209 VM pin | ~1.5A        |  220µF / 50V    | Aluminium electrolytic | Local reservoir
 24V | Main Pump MOSFET    | ~1.2A        |  220µF / 50V    | Aluminium electrolytic | Local reservoir
  5V | Buck output         | ~0.75A       |  220µF / 10V    | Aluminium polymer      | ESP32 WiFi Tx
3.3V | LDO output          | ~0.15A       |   22µF / 10V    | MLCC X7R               | Low current

The Engineering:
- Given the acceptable ripple and transient duration, the required capacitance follows as: $C = I × Δt / ΔU$.
- If these are unknown, use a rule of thumb: provide 100µF to 200µF electrolytic capacitors for every 1A of current. 
- To reduce aging, use electrolytic capacitors that are rated for 150% to 200% of the expected voltage.
- Aluminium polymer is low ESR, but hard to find at above 25V. Aluminium electrolytic capacitors are a pragmatic choice for 50V.
- Use low-ESR capacitors: e.g. Panasonic FR series for Aluminium electrolytic, and Panasonic FK or Kemet R60 for Aluminium polymer.
- Place local bulk capacitance directly at the Voltage Supply (VS) pins of the three TMC2209 drivers and MOSFETs.


---


### 1.6. PCB guidelines

To safely handle the peak **4.7A** load, the architecture mandates a **4-layer PCB** with **2oz copper** outer layers. This copper weight is essential for managing the heat and resistance of the 24V power traces under continuous 24/7 operation.


#### Layer Stack-Up

Layer | Name | Function               | Components
------|------|------------------------|--------------------------
L1    | Top  | Signal layer           | MCU, LiDAR, I2C, UART, EZO, BNC
L2    | GND  | Solid Main GND Plane   | One uninterrupted copper pour. This is the EMI shield.
L3    | PWR  | 3.3V / 5V / 24V Planes | Seperate copper pours for low resistance.
L4    | Bot  | Steppers / MOSFETs     | So GND plane shields them from signal layer


#### Enclusure et al

- Recommended: IP65 rated ABS enclosure, ~150×100×70mm
- Cable glands for all wiring
- Panel-mount BNC connectors for pH/EC/RTD probes (3×)
- Optional: Clear lid for status LED visibility

- **Size:** 100mm × 80mm (fits common enclosures)
- **Finish:** HASL or ENIG


#### Trace Widths

Trace width is calculated using the IPC-2221 empirical formula for external conductors.[^1]
[^1]: [IPC-2221 Trace Width Calculator, Altium PCB Design Guide](https://resources.altium.com/p/ipc-2221-calculator-pcb-trace-current-and-heating).

$$
    \begin{align}
    I  &= k × ΔT^{0.44} × A^{0.725} \\
    \rm{where\ \ } I &= \rm{current\ [A]} \nonumber \\
    k  &= 0.048 \rm{\ for\ outer\ layer,\ or\ } 0.024 \rm{\ for\ inner\ layer} \nonumber \\
    ΔT &= \rm{allowable\ temperature\ increase\ [°C]} \nonumber \\
    A  &= \rm{cross\ sectional\ area\ [mil²]} =  width_{mil} × thickness_{mil} \nonumber \\
   \rm{thickness_{mil}} &= 1.37\rm{mil\ for\ 1oz\ Cu,\ or\ } 2.74\rm{mil}\rm{\ for\ 2oz\ Cu} \nonumber 
\end{align}
$$

The table below use a conservative $ΔT = 10°\rm{C}$ (IPC-2221 permits 20°C for most PCB classes). 

Net                     | Target Current    | Internal Trace Width | External Trace Width | Rationale
------------------------|-------------------|----------------------|----------------------|----------
24V input (PSU→TVS→RPP) | 6.5A (Peak)       | 5.0mm (200mil)       |  2.0mm (80mil)       | Reduce sag
24V main pump           | 1.2A (Continous)  | 1.0mm  (40mil)       |  0.4mm (15mil)       | Manage heat
24V each dosing pump    | 1.53A (Peak)      | 1.0mm  (40mil)       |  0.4mm (15mil)       | Lower inductance
24V ATO valve           | 0.3 (Peak)        | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum
5V rail (post-buck)     | 0.75A (Peak)      | 0.5mm  (20mil)       |  0.2mm  (8mil)       | Stable power
3.3V rail (post-LDO)    | 0.15 (Peak)       | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum


Plane and Routing Guidelines
- **Star Power**: Run a dedicated pair of 24V wires from your main power input connector directly to the stepper section, and a separate pair to the logic regulator. Do not "daisy chain" the power from the motors to the sensors.
- **Via Stitching:** If you must switch the 24V rail between layers, use multiple vias (at least 3–4 vias per 2A connection). A single standard 10-mil via is only rated for about 0.5A–1A before it acts like a fuse.
- **Antenna Support:** The ground plane should not extend under the **ESP32-C6 antenna** keep-out area to ensure proper wireless performance.
- **Analog/Digital Isolation:** The layout must keep **analog traces physically isolated** from switching power supplies (like the TPS62933) and high-current motor traces.



---



## 2. Integration of Precision Dosing and EMI Mitigation

The high precission steppers generate significant **Electromagnetic Interference (EMI)** through high-speed PWM switching. To mitigate this:
- A *"Silent Read" Strategy* protects sensitive probes from the electromagnetic interference (EMI) generated by stepper PWM switching. The firmware shuts down the stepper drivers during sensor reads (via ENA) to create a "blackout" of switching noise for the sensitive pH and EC probes
- *Bypass Capacitors* surpress the middle and high frequency noise.
- *PCB Layout Strategy*, thermal relief and EMI shielding.


---


### 2.1. Stepper Driver Circuit (TMC2209)

> All currents in this section are RMS currents. 

```
                24V (VM)
           ┌───┬──┴──────┐
           │   │         │
        100µF 100nF      │  ← 220µF bulk + 2x 100nF local bypass per driver
          ─┴─ ─┴─     VM │
              ┌──────────┴───────────┐
 3.3V ───────►│ VIO                  │
 GND ────────►│ GND                  │
              │                      │
 STEP_xxx ───►│ STEP          OA1 ───┼──► coil A+
 3.3V ───────►│ DIR           OA2 ───┼──► coil A-
  GND ───────►│ EN            OB1 ───┼──► coil B+
              │               OB2 ───┼──► coil B-
UART bus─────►│ PDN_UART             │
  MS1* ──────►│ MS1           BRA ───┼──── 110mΩ ──── GND   ← RSENSE: 1%, 1/4W 0805
  MS2* ──────►│ MS2           BRB ───┼──── 110mΩ ──── GND
  GND ───────►│ SPREAD               │
  GND ───────►│ STDBY                │
              │                      │
see below  ──►│ VREF                 │
              │      TMC2209         │
              └──────────────────────┘
```

The Standard Application Circuit in Fig. 3.1 of the [TMC2209 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/tmc2209_datasheet_rev1.09.pdf) and [TM2209 EVAL Schematics](https://www.analog.com/media/en/evaluation-documentation/evaluation-design-files/TMC2209-EVAL_Layout_Data_V1.1.zip) show a typical Stepper Driver using the TMC2209. The design follows their recommendations:

To start with the **obvious pins**, per §2.2 of the datasheet:
- `ENN` should be connected to signal `STEP_PDIS`, so that the firmware can disable the driver for a "Silent Read".
- A 22nF / 50V cap should be connected between the charge pump pins `CP0` and `CP1`.
- A 100nF cap should be placed between the charge pump voltage `VCP` and `VS`.
- `SPREAD` should be connected to GND to select StealthChop mode, per architecture.
- A 2.2μF cap should be connected to `5VOUT` stabilize the 5V.
- `CLK` should be tied to GND to select the internal clock.
- `STEP` input should be connected to a dedicated signal, e.g. `STEP_PH_DH`.
- `DIR` may be left unconnected, because it has an internal pull-down. A step impulse during `DIR=0` increases the microstep counter, per §1.3.1.  **Or, it it: ??** DIR hardwired to 3.3V. Peristaltic pumps are self-sealing — the rollers pinch the tube closed when stopped, so backflow cannot occur and direction reversal is never needed. If a pump runs backwards on first install, swap the coil A wires (OA1 ↔ OA2) on the connector.
- `STDBY` input can disable the internal supply regulator.  It has an internal pull-down, and may be left unconnected. `IHOLD=0` handles standstill power saving without the register-reset complication of STDBY.
 - The motor supply voltage `VS` requires filtering with two parallel ceramic low-ESR 100nF caps to handle the transients, and a 220µF electrolytic local bulk cap to keep the current spikes from appearing as voltage transients on the VM rail, per §3.1.
- Connect the `Exposed Die Pad` to a GND plane. Provide as many as possible vias for heat transfer to GND plane.
- `DIAG` open-drain output. Goes high when StallGuard4 detects a motor stall or when a driver error occurs (overtemperature, short circuit). Leave unconnected, because in UART mode, stall detection is preferred via the `DRV_STATUS` register rather than the DIAG pin — this is more informative (gives a numeric stall load value, not just a binary flag). If we end up with a free GPIO, we can use this to allow interrupt-driven stall detection without polling.
- `INDEX` pulse output — by default emits one pulse per electrical period (every 4 full steps at 1× microstepping). Can be reconfigured via UART `IOIN` register to signal other events (e.g. first microstep position, stepper index). For dosing pumps, step count is controlled directly by the ESP32 (counted steps = known volume), so `INDEX` adds no value in normal operation, leave the pin floating. Place a DNP 1kΩ series + test point footprint for debugging if needed.

Using a **single UART bus** with the MS1 and MS2 pins for addressing is the most "EZO-like" way to handle the **TMC2209** drivers — it keeps the pin count low and control digital:
- `AD1` and `AD0` assigns a driver an unique UART node address.  These pins have internal pull-down resistors.
   - for pH Dn, set address 0b00 → `AD1` and `AD0` unconnected
   - for NUT A, set address 0b10 → `AD1` to 3V3 and `AD0` unconnected
   - for NUT B, set address 0b11 → `AD1` and `AD0` tied to 3V3
- `PDN_UART`should connect to the `STEP_BUS` signal, that then connects to the `RXD` on the MCU, and via a 1kΩ resistor to its `TXD`.  PDN_UART is an open-drain bidirectional pin. When the ESP32 TX drives HIGH to send a command, and the TMC2209's open-drain output momentarily pulls the bus LOW to begin its response (a brief overlap before software tri-states TX), a low-impedance conflict occurs between TX driving HIGH and the open-drain pulling LOW. The 1kΩ on TX limits the fault current during this window to (3.3V / 1kΩ) = 3.3 mA — safe for both the ESP32 output driver and the TMC2209 PDN_UART. 
- The firmware should set `SENDDELAY` to ≥2 for all nodes. Otherwise, a non-addressed node might detect a transmission error upon read access to a different node. 
- The firmware should configure ESP32-C6 UART1 in **half-duplex / single-wire mode** so TX is tri-stated (high-impedance) during the receive window. The TMC2209 then pulls the bus LOW open-drain to transmit its response, with no conflict from TX.
- Some suggest adding a 100Ω series resistor on each PDN_UART pinc reates a small voltage drop that decouples each driver's input from the bus during contention, and limits the current path between drivers if two open-drain outputs are momentarily both active. We're not doing that because it is not listed in the datasheet or used in the EVAL board.

The **output current** is set by:
- The **R<sub>SENSE</sub>** shunt resistors measure the output currents. The TMC2209 measures the voltage drop across this resistor to determine actual coil current, then adjusts its PWM chopper duty cycle to regulate current to the `IRUN/IHOLD target`. §8 suggests 120 mΩ low-inductance resistors. Instead we use a 110 mΩ 1/4W to ensure it will not exceed the full-scale voltage of 325mV.
- Set a hard limit using the V<sub>REF</sub> input of the TMC2209. This linearly scales the maximum current. The value for voltage $V_{REF}$, follows from the architecture that specifies that $V_{REF}$ should be set for a current corresponding to 90% of the maximum stepper current of 1.7 A<sub>RMS</sub>. 
The formula from chapter 9 of the data sheet, shows that the current depends on $CS$, $V_{FS}$ and $V_{REF}$ and can be calculated as: 
$$
    \begin{align}
        I_{RMS}  &= \frac{CS+1}{32} \times \frac{V_{FS}}{R_{SENSE} + 20 \rm{\ mΩ}} \times \frac{1}{\sqrt 2} \times \frac{V_{VREF}}{2.5 \rm{\ V}} \\
        \rm{where\ \ } 
        CS  &= \rm{current\ scale\ setting\ as\ set\ by\ the\ IHOLD\ and\ IRUN\ (default=31)} \nonumber \\
        V_{FS}  &= \rm{full\textnormal{-}scale\ voltage\ set\ by\ vsense\ control\ bit\ (default=325\ mV)} \nonumber \\
        R_{SENSE}  &= \rm{resistance\ of\ the\ sense\ resistors} = 110\ m\Omega \nonumber \\
        V_{VREF} &= \rm{linearly\ scales\ the\ output\ current\ to\ the\ motor\ (2.5\ V\ for\ 100\%) } \nonumber
    \end{align}
$$
With register $CS=31$ and the default $\textnormal{vsense control bit}$, the required $V_{VREF}$ follows as:
$$
    \begin{align}
        0.9 \times 1.7\rm{\ A}  &= \frac{32}{32} \times \frac{325 \rm{\ mV}}{120 \rm{\ m\Omega} + 20 \rm{\ mΩ}} \times \frac{1}{\sqrt 2} \times \frac{V_{VREF}}{2.5 \rm{\ V}} \nonumber \\
        \Rightarrow
        V_{VREF} &= 0.9 \times 1.7\rm{\ A} \times \frac{120 \rm{\ m\Omega} + 20 \rm{\ mΩ}}{325 \rm{\ mV}} \times \sqrt 2 \times 2.5 \rm{\ V} 
        \approx 2.16 \rm{\ V} \nonumber
    \end{align}
$$
To create this voltage, use the 5V<sub>OUT</sub> pin with a a R<sub>H</sub> and R<sub>L</sub> **voltage divider**. Taking into account a $R_{VREF}=240 \rm\ M\Omega$, the required resistors follow as $R_{H} = 14 \rm{\ k\Omega}$ and $R_{L} = 10.7 \rm{\ k\Omega}$:
$$
    \begin{align}
        V^{'}_{VREF} &= \frac{R_{L}}{R_{L}+R_{H}} \times 5 \rm{\ V} = \frac{10.7 \rm{\ k\Omega}}{10.7 \rm{\ k\Omega} + 14 \rm{\ k\Omega}} \times 5 \rm{\ V} \approx 2.16 \rm{\ V} \nonumber
    \end{align}
$$
- The firmware try to to use an operating range of 70% to 80% corresponding to setting the **CS to 24 or 27**. Increase to 85–90% only if stalling occurs on aged tubing.

CS value | Current limit| Target range
--------:|-------------:|-------------
24       |      1.19A   | 70%
25       |      1.24A   | 73%
26       |      1.29A   | 76%
27       |      1.34A   | 79%
28       |      1.43A   | 81%
29       |      1.39A   | 84%
30       |      1.48A   | 87%
31       |      1.53A   | 90%

#### Firmware Considerations 

Talking about firmware, use *[TMCStepper](https://github.com/teemuatlut/TMCStepper)** for all TMC2209 driver configuration and status monitoring. It provides full UART register access: write IRUN=18, IHOLD=0, IHOLDDELAY=6, TPWMTHRS=0 at startup; read DRV_STATUS.SG_RESULT and temperature flags during operation. No alternative library provides this capability.

Key UART registers to configure at startup are:

| Register     | Value | Purpose 
|--------------|-------|---------
| `IHOLD`      |     0 | Zero standstill current (EN tied to GND — this is essential)
| `IRUN`       |    24 | Run current ≈ 70% (CS=24 → 1.19A; increase to 27 for ~79% if stalling occurs — see CS table above) |
| `IHOLDDELAY` |     6 | Steps between IRUN→IHOLD transition after last STEP pulse
| `TPWMTHRS`   |     0 | StealthChop2 active at all speeds
| `SENDDELAY`  |    ≥2 | Required for multi-driver bus. See note above.

STEP pulses must be generated by hardware peripherals, not software loops. If the ESP32 is busy with a Wi-Fi request, SSL/TLS handshake, a software-timed pulse loop can stall for tens of milliseconds. A single missed or late pulse causes the stepper to lose a step — and since dosing accuracy is derived from step count × tube displacement constant, one lost step per dose accumulates into measurable calibration error over time.

The recommended ESP32-C6 hardware options is to use the **RMT (Remote Control Transceiver):** The RMT peripheral generates arbitrary pulse sequences from a preloaded buffer with nanosecond resolution, independent of the CPU. Configure it to output N pulses at the target step frequency, then trigger it once per dose. When the burst completes it fires
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
It supports up to 4 independent TX channels on ESP32-C6 → one per STEP pin with one spare.

#### Connectors

The A200SX motor cable carries coil wires only (4 pins). the TMC2209 H-bridge drives the coils directly.

| Parameter | Specification |
|-----------|---------------|
| Motor body connector | JST PH 2.0mm 4-pin (female, on pump body) |
| Cable free-end connector | JST XH 2.5mm 4-pin (female) — PCB side |
| Source | [ankoproducts.com/products/a200sx](https://ankoproducts.com/products/a200sx) |

According to the NEMA 17 convention — JST PH 2.0mm 4-pin on motor body; cable free end terminates in JST XH 2.5mm 4-pin (commonly mislabelled "XH2.54"); XH series is 2.5mm pitch, not 2.54mm DuPont). PCB footprint: B4B-XH-A; verify on receipt [ankoproducts.com](https://ankoproducts.com/products/a200sx)



JST XH 2.5mm 4-pin Assignment (verify against A200SX datasheet on receipt):
┌─────┬────────────────┬─────────────────────────────────────┐
│ Pin │ Signal         │ PCB connection                      │
├─────┼────────────────┼─────────────────────────────────────┤
│  1  │ Coil A+  (OA1) │ TMC2209 OA1                         │
│  2  │ Coil A−  (OA2) │ TMC2209 OA2                         │
│  3  │ Coil B+  (OB1) │ TMC2209 OB1                         │
│  4  │ Coil B−  (OB2) │ TMC2209 OB2                         │
└─────┴────────────────┴─────────────────────────────────────┘
⚠ Verify pin order from A200SX datasheet before PCB layout. Coil swap (A↔B or polarity) only affects rotation direction; the TMC2209 handles both.

Dosing Pump Connector (×3, PCB side): JST B4B-XH-A (4-position XH male header, 2.5mm pitch, right-angle TH, PCB mount) ×3
- Mates with: JST XH 2.5mm 4-pin female housing on pump cable free end
- Pitch: 2.5mm
- 4 pins: coil A+, coil A−, coil B+, coil B−  (no VCC/GND)
- Silkscreen label: "pH DN", "NUT A", "NUT B"
- Right-angle orientation: cable exits horizontally toward board edge
- Alternative: B4B-XH-AM (vertical TH) if cables must exit upward
- Verify exact part on receipt — ARCHITECTURE.md notes connector mislabelled "XH 2.54mm" in 3D printer community; XH series is 2.5mm pitch


---


### 2.2. "Silent Read"

The dosing sequence is:
1. Turn OFF the TMC2209 drivers (using the !EN pin) while reading the sensors to ensure 100% electrical silence
2. Read pH/EC (EZO sensors) and calculate Dose.
4. Enable Drivers and Step the motors.
5. Wait for the reservoir to mix before reading again.

The schematic or firmware should use **StealthChop2** for dosing. It generates significantly less Electrical Noise (EMI) than the high-torque SpreadCycle mode, which improves EZO-EC data integrity.

Engineering note: the firmware can use the **TeensyStep** or **TMCStepper** library (by Peter Polidoro/teemuatlut).


---


### 2.3. Capacitor to the Rescue
The existing 220µF bulk caps at VM also suppress the **medium-frequency** switching ripple by providing charge locally, within the short trace between cap and VM pin, before the inductance of the supply path has time to cause a voltage dip.

Recommended MF capacitors:

Rail | Place               | Peak Current | Value / Voltage | Dielectric             | Purpose
----:|---------------------|--------------|----------------:|------------------------|--------
 24V | Main power entry    | ~4.7A        |   10µF / 50V    | MLCC X7R[^2]           | MF bypass
 24V | Each TMC2209 VM pin | ~1.5A        |  220µF / 50V    | Aluminium electrolytic | MF bypass
 24V | Main Pump MOSFET    | ~1.2A        |  220µF / 50V    | Aluminium electrolytic | MF bypass
  5V | Buck output         | ~0.75A       |   10µF / 10V    | MLCC X7R[^3]           | MF bypass

[^2]: e.g. Murata GRM31CR61H106KA12L (SMD Comm X7R). DC bias derating is better for 1206 package.
[^3]: e.g. Murata GRM21BR61C106KE15L. Use 0805 package.

Note that the Benewake TF-Luna LiDAR includes a 100nF capacitor to debounce signals and prevent EMI-induced false triggers on the safety interlock lines.

For **high-frequency bypass** (decoupling), the goal is to present the lowest possible impedance at the target frequencies. The capacitor value sets the resonant frequency with its parasitic inductance (ESL).

Recommended HF/VHF bypass capacitors:

Rail | Value / Voltage | Dielectric | Package   | Purpose
----:|----------------:|------------|-----------|---------
 24V | 100nF / 50V     | MLCC X7R   | 0402/0603 | HF bypass
  5V | 100nF / 16V     | MLCC X7R   | 0402/0603 | HF bypass per IC
3.3V | 100nF / 10V     | MLCC X7R   | 0402/0603 | HF bypass per IC
3.3V |  10nF / 10V     | MLCC X7R   | 0402      | VHF bypass for sensitive pins

The Engineering:
- *Why 100nF:* Self-resonant frequency of a 100nF 0402 MLCC[^4] is SRF=~30MHz, while the equivalent series resistance ESR=~0.2mΩ at 1 MHz → it operates as an effective bypass to ground up from about ~1 Mhz to ~30MHz — covering the HF-part of the switching harmonics.
- *Why 10nF:* a similar 10nF cap[^5] as the is SRF=~85MHz and ESR=~0.2mΩ at 1 MHz → it operates as bypass to ground up from ~1MHz to ~85MHz — covering the VHF-end of switching harmonics.
- *Why X7R not X5R:* X7R holds capacitance better across temperature (−55°C to +125°C, ±15%). X5R is acceptable on low-voltage rails but degrades more with temperature and DC bias.
- *Why those pesky small 0402/0603:* Smaller package = lower ESL = lower impedance at high frequency. 0805 and larger have noticeably higher ESL and are less effective as HF bypass caps.

[^4]: Such as the Murata GRM155R71C103KA01D
[^5]: Such as the Murata GRM155R71C104KA88J

Long PCB traces or component leads add inductance, which reduces the SRF. The placement priority order is:
1. 10nF ceramics: <2mm from IC pins
1. 100nF ceramics: <5mm from IC pins
2. 10-22µF ceramics: <10mm from IC
3. electrolytics: <20mm from load

For added protection, use **ferrite beads** on power inputs to further reject high-frequency noise.


### 2.4 PCB Layout Strategy

At 1.0A RMS, the TMC2209 drivers generate only a 1/4 of the heat compared to their 2.0A limit.
- **A "Thermal Chimney":** Use a large GND plane on the bottom layer as a heatsink. Use a 4×4 array of 16 thermal vias, 0.3mm diameter, spaced 1mm apart under the TMC2209 center pad connecting to the GND plane to pull heat away.
- **EMI Shielding:** By keeping high-speed switching (stepper drivers) **on the bottom** (L4) and sensitive logic on the top (L1), the internal Ground and Power planes act as a Faraday shield, preventing motor noise from "leaking" into the pH and EC readings. 


---


## 3. Maintaining Signal Integrity via Isolation

In a conductive nutrient solution, multiple probes (pH, EC, RTD) can create ground loops, where small currents leak between probes and distort readings.  

Mitigation strategy:
   - *Isolation circuit:* Isolated DC and I2C via the ADM3260 chip, providing a physical air gap to eliminate ground loops.  
   - *Physical distance*: Separate the Noisy and Sensitive neighbors.
   - *Pi-Filters:* Ensures noise of the isolation chip itself does not "leak" into the high-impedance analog front-end of the pH and EC circuits.

To prevent Ground Loops, the architecture uses Isolated I2C via the ADM3260 chip, providing a physical air gap to eliminate these loops.  


---


### 3.1. Isolation Circuit (ADM3260)

The Typical Applcation Diagram in Fig. 20 of the [ADM3260 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/adm3260.pdf) and [UG-724](https://www.analog.com/media/en/technical-documentation/user-guides/EVAL-ADM3260MEBZ_UG-724.pdf) show a typical Isolated I2C Interface using the ADM3260. The design follows their recommendations[^MOREAMD3260] :

[^MOREAMD3260]: See also, Analog Devices ADM3260 Datasheet: The definitive source for "Layout Guidelines" and "EMI Considerations" (See pages 16-18); Atlas Scientific USB Isolator Schematic: Their public hardware documentation shows the ADM3260 implementation for I2C isolation; AN-0971 Application Note: "Recommendations for Control of Radiated Emissions with isoPower Devices."

- **V<sub>SEL</sub>** sets the isolated output voltage V<sub>ISO</sub>. For V<sub>ISO</sub>=3.3V, create a voltage divider matches so that V<sub>SEL</sub> matches the 1.25V reference voltage: 
$$
  V_{SEL} = V_{ISO} \cdot \frac{\rm{R_{19}}}{\rm{R_{17}}+\rm{R_{19}}}
  = 3.3\rm{\,V} \cdot \frac{10\,kΩ}{10\,kΩ+16.9\,kΩ} = 1.23\rm{V}
$$

- **I2C pullups** are required on the isolated side, just like the main side. A "stiff" 2.2kΩ here is better for fighting the noise. Use 1% tolerance resistors to ensures the I2C rise times are identical on SDA and SCL, preventing timing "jitter" that can occur in high-noise environments.

- **Bypass capacitors** are mandatory for the device to function correctly and provide stable isolated power.
  - 10 μF // 100 nF from V<sub>IN</sub> to GND<sub>P</sub>.
  - 10 μF // 100 nF from V<sub>ISO</sub> to GND<sub>ISO</sub>.
  - 100 nF // 10 nF from VDD<sub>P</sub> to GND<sub>P</sub>.
  - 100 nF // 10 nF from VDD<sub>ISO</sub> to GND<sub>ISO</sub>.
  - for 10 μF: use 0805 X7R capacitors within 4 mm of the pins (for power stability)
  - for 10 nF: use 0402 X7R capacitors within 1 or 2 mm of the pins (for noise suppression)
  - for 100 nF: use 0402 X7R capacitors within 1 or 2 mm of the pins (for noise suppression)
  - follow the suggested footprint (Fig. 23 in the [datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/adm3260.pdf)) for PCB placement

- The signal **`EZO_PDIS`** is intended for powering down sensors between long monitoring intervals. Power to the sensors need to be restored and stabilized well before the measurement is taken. It can also be used for fault recovery: pulse HIGH 100ms then LOW; wait ≥1.2s before sending I2C commands.


---


### 3.2. Physical distance

Physical distance is the most effective EMI mitigation. Separate the "Noisy" from the "Quiet."

The gold standard for this "Multi-EZO" PCB layout is the [Atlas Scientific i4 InterLink](https://files.atlas-scientific.com/i4-interlink-datasheet.pdf) and the [Whitebox Labs T3 schematics](https://github.com/whitebox-labs/tentacle-raspi-oshw).

[^^8]: Analog Devices AN-0971 (Recommendations for Control of Radiated Emissions with isoPower Devices). This document also details how to use PCB "Stitching Capacitance" to keep the board quiet.

1. **Zone A: Power Entry (Edge of Board)**
   - Components: DC Jack, 4A Fast Fuse, RPP, TVS Diode, Bulk Cap.
   - Goal: Kill spikes and provide bulk current immediately upon entry.
2. **Zone B: High-Power Drive (Bottom Half)**
   - Components: 3x TMC2209 drivers, 3x Bulk caps, Solenoid MOSFET.
   - Routing: Keep the 24V "VM" traces on L4 (Bottom).
   - Thermal: Place the drivers here to utilize the L2 GND plane as a heatsink.   
   - Noise profile: Extreme (source)
3. **Zone C: Digital Logic (Top Center)**
   - Components: MCU, LiDAR header, 5V/3.3V Regulators, EZO-RTD (Non-isolated).
   - Routing: Keep I2C/UART on L1 (Top), shielded by the L2 GND Plane.
   - Noise profile: Moderate (sensitive)
4. **Zone D: Isolated Islands (Top Corners)**
   - Components: 2x ADM3260, EZO-pH/EC sockets, BNC connectors.
   - Noise profile: zero tolerance


To visualize the ADM3260 on a 4-layer stack-up, imagine the chip sitting like a bridge over a **Moat**. The goal is to ensure that no electrical path exists between the Mainland and the Island except through the silicon of the chip itself. Ensure the Moat is at least 6mm wide for high-voltage safety (creepage).

Below is how the layers should be carved to maintain 2.5kV isolation:

Layer    | Mainland               | The Moat                  | The Island (pH or EC)
---------|------------------------|---------------------------|----------------------
L1 (Top) | MCU, LiDAR             | No Copper                 | EZO Socket, BNC
L2 (GND) | Solid Main GND Plane   | Stitching Cap[^STITCHCAP] | Floating GND_ISO
L3 (PWR) | 3.3V / 5V / 24V Planes | Stitching Cap             | Floating V_ISO (3.3V)
L4 (Bot) | Steppers and glue      | No Copper                 | (Keep empty for signal)


[^STITCHCAP]: See the next paragraph.


---


### 3.3. Self Defense (π-filters)

Although disabling the stepper motors eliminates external EMI, the ADM3260 itself is a switching power supply. A pi-filter at the V_ISO ensures that the internal noise of the isolation chip does not "leak" into the high-impedance analog front-end of the pH and EC circuits.

>The ADM3260 uses an internal isoPower transformer switching at ~180MHz, it can cause the "Island" to act like a radio antenna.

To mitigate the Electromagnetic Interference (EMI):
- Add footprints for **Ferrite beads** (but for now: populate with 0Ω)
  - FB from V<sub>ISO</sub> to the EZO mezzanine.
  - FB from GND<sub>ISO</sub> to the EZO mezzanine.
  - Use 0603-sized beads that have high impedance at 100MHz and low DC resistance.[^BLM18]
  - The adding ferrite beads makes creates a π-filter to futher limit EMI.
      ```
        V_ISO ─────┬───────┬──►── [FB]─────┬─────► VCC_EZO
                   │       │               │
                 [10uF]  [100nF]       [EZO Cap]
                   │       │               │
        GND_ISO ───+───────+───────────────+─────
      ```

- Use the **"Stitching Capacitance" trick**: place a small amount of "stitching capacitance" across the isolation barrier. This is often achieved by overlapping internal PCB layers or using a dedicated Y-rated capacitor. Extend GND<sub>P</sub> and GND<sub>ISO</sub> on seperate inner layers into the moat. The capacitive coupling of the structure is calculated with the following basic relationships for parallel plate capacitors:[^A-0971]
$$
    \begin{align}
      C  &= \frac{A\varepsilon}{d} \rm{\ and\ } \varepsilon=\varepsilon_0\times\varepsilon_r  \\
      \rm{where\ \ } 
      A  &= \rm{area\ of\ the\ overlapping\ reference\ planes} \nonumber \\
      C  &= \rm{total\ stiching\ capacitance} \nonumber \\
      d  &= \rm{thickness\ of\ the\ insulation\ layer\ in\ the\ PCB} \nonumber \\
      \varepsilon_0 &= \rm{permittivity\ of\ free\ space} = 8.854\times10^{-12} \rm{\ F/m} \nonumber \\
      \varepsilon_r &= \rm{relative\ permittivity\ of\ the\ PCB\ insulation\ material\ } \approx 4.5\rm{\ for\ FR4} \nonumber \\
    \end{align}
$$

[^BLM18]: Murata EMI Guide: Recommends the BLM18 series ferrite beads for suppressing high-frequency noise in isolated DC/DC converters.
[^A-0971]: [A-0971](https://www.analog.com/en/resources/app-notes/an-0971.html)

- To reduce, consider using a **Via Fence and Guard Ring** to limit edge radiation.[^A-0971]


---



## 4. Reservoir Level Circuits



### 4.1. LiDAR Circuit

#### Circuit

Follow the guidance from the [Datasheet](https://github.com/May-DFRobot/DFRobot/blob/master/TF-Luna%20LiDAR%EF%BC%888m%EF%BC%89%20Datasheet.pdf)

- LiDAR `5V`  to 3V3
- LiDAR `RX/SDA` to signal I2C_SDA
- LiDAR `TX/SCL` to signal I2C_SCL
- LiDAR `GND` to GND
- LiDAR `!I2C` to GND
- LiDAR `RDY` left floating
- LiDAR 100μF electrolytic local bulk cap between 3V3 and GND

#### Connector

- 6-pin Molex picoblade connector (1.25mm), P/N 0532610671 [^LiDARCONN]
- Pin 1: VCC (5V &pm;0.1V)
- Pin 2: RX/SDA
- Pin 3: TX/SCL
- Pin 4: GND
- Pin 5: Configuration (floating/high for UART; GND for I2C)
- Pin 6: Data Ready (I2C mode)

[^LiDARCONN]: See [RobotShop Community](https://community.robotshop.com/forum/t/whats-the-electrical-connector-on-the-tf-luna-lidar-sensor/99629)


---


### 4.2 Float Switches

The two float switches use opposite pull directions so that both GPIO signals are *active-HIGH when their cutoff condition is triggered* — consistent logic for both software and the hardware NPN cutoff transistors.

#### Circuit

OPNhydro uses normally-open (hinge DOWN) for both switches.
- When water rises to the switch, the float arm lifts → magnet nears the reed switch → circuit closes.
- When water drops below the switch, the float arm falls → magnet nears the reed switch → circuit opens.

For Low-Level Float:
- Mount so that it triggers at the 10% of the 100L fill mark.
- Connect one lead to the `FLOAT_LOW` signal, and the other lead to GND.
- Pull-up the `FLOAT_LOW` signal with a 10kΩ resistor to 3V3.
- Debounce the `FLOAT_LOW` signal with a 100nF cap to ground.

For Low-Level Float:
- Mount so that it triggers at the 100L fill mark.
- Connect one lead to the `FLOAT_HIGH` signal, and the other lead to 3V3.
- Pull-down the `FLOAT_HIGH` signal with a 10kΩ resistor to GND.
- Debounce the `FLOAT_HIGH` signal with a 100nF cap to 3V3.

#### Connector

Both switches come with 2' (61cm) bare wire leads. Terminate each wire into the screw terminal on the PCB.
- Phoenix Contact, Series COMBICON MKDS (P/N 1751264)
- 4 Position Header
- Pitch 3.5mm
- Pin 1 to 3V3, pin 2 to high-level float, pin 3 to low level float, pin 4 to GND


---


## 5. Main Pump and OTA Solenoid Drivers


All pumps and the ATO valve use the same 24V rail and identical driver circuits.

Standard electrical practices suggest the following for 24V DC systems:
- **Individual Actuators (Pumps and Solenoids):** 20 AWG or 22 AWG is sufficient for the individual 1.2A to 1.5A loads of the pumps and valves.


### 5.1. Main Pump

1. Pump must be fully submerged in water before power-on (prevents dry-run damage)
2. Mount pump vertically or horizontally, avoid inverted position
4. Add inline strainer/filter to prevent debris clogging impeller
5. Test PWM control at low duty cycles to find minimum stable speed
6. Allow 10-15 second startup delay in software for motor initialization

#### Driver

The obvious:
- Place the IRLR2905 MOSFET between the pumps's GND terminal and GND.
- Add a 10kΩ pull-up resistor to the MOSFET gate to ensure the motor stays on during MCU reset.
- Add a low-ESR 100nF / 50V cap between source and drain to handle the transients.
- Add a 220µF / 50V electrolytic bulk cap between source and drain to keep the current spikes from appearing as voltage transients on the 24V rail, per power architecture.

The main pump supports PWM speed control via the 24V power input. For PWM Drive and Signal Integrity:
- Place a 100Ω gate resistor between `PUMP_MAIN` signal and the gate to help manage the inrush current to the MOSFET's gate capacitor. This protects the ESP32-C6 while allowing for the fast switching speeds required for variable pump control.
- Add a SS34 Schottky diode (3A) as Flyback Protection across the pump terminals.The SHYSKY DC40F-2460 pump is said to have internal BLDC electronics limiting the inductive kickback, but still..
- Firmware suggestions:
  - Minimum: ~30-40% duty recommended to prevent stall.
  - Frequency: 25 kHz (above audible range, smooth motor control)

The float switch drives a small NPN transistor that directly clamps the MOSFET gate to GND when the cutoff condition fires. This is independent of firmware — the pump shut down in hardware even if the MCU is hung or misbehaving.
- Place a BT3904 PNP transistor between gate and ground.
- Place a 4k7 resistor between `FLOAT_HIGH` signal to limit the current.

#### Connector

- Phoenix Contact, Series COMBICON MC (P/N 1836189), avoid compatibility with 24V PSU.
- 2 Position Header
- Pitch 0.2" (5.08mm)
- Pin 1 to 24V, pin 2 to switched GND
- Mating plug: Phoenix Contact P/N 1836079


---


### 5.2. ATO Solenoid Valve

Notes:
- Most solenoid valves have 2-wire leads (polarity doesn't matter for DC)
- Arrow on valve body indicates flow direction
- Use thread sealant (Teflon tape or pipe dope) on NPT threads
- Mount valve with coil vertical (prevents water ingress)
- Recommend: inline manual shutoff valve for maintenance
- Recommend: firmware timeout prevents flooding if all level sensors fail

#### Driver

The obvious:
- Place the AO3400A MOSFET between the valve's GND terminal and GND.
- Place a 100Ω gate resistor between `ATO_VALVE` signal and the gate to manage the inrush current to the MOSFET's gate capacitor.
- Add a 10kΩ pull-down resistor to the gate to ensure the valve stays closed during MCU reset.
- Add a low-ESR 100nF / 50V cap between source and drain to handle the transients.
- ?? Add a 220µF / 50V electrolytic bulk cap between source and drain to keep the current spikes from appearing as voltage transients on the 24V rail, per power architecture.
- Add a SS34 (3A) or 1N5819 (1A) Schottky diode as Flyback Protection across the valve terminals.

The safety interlock:
- Place a BT3904 PNP transistor between gate and ground.
- Place a 4k7 resistor between `FLOAT_HIGH` signal and the base to limit the current.

#### Connector

- Phoenix Contact, Series COMBICON MC (P/N 1803277)
- 2 Position Header
- Pitch 0.15" (3.81mm), to make it incompatible with the Main Pump header
- Pin 1 to 24V, pin 2 to switched GND
- Mating plug: Phoenix Contact P/N 1803578


---


## 6. I2C and Optional Sensors

The default I2C addresses of the sensors are:
- EZO-pH:  0x63
- EZO-EC:  0x64
- EZO-RTD: 0x66
- BME280 air temp/humidity sensor:  0x76/0x77
- BH1750 light sensor: 0x23/0x5C
- SSD1306 OLED display: 0x3C/0x3D


### 6.1. Optional Sensors

Included are two I2C headers for future expansion with e.g. a air temp/humidity sensor (BME200), light sensor (BH1750) or OLED display (SSD1306).

#### Circuit

-  Add a low-ESR 100nF ceramic cap between 3V3 and GND to handle the transients.
 - Add a low-ESR 10µF ceramic cap between 3V3 and GND has a bulk cap and MF bypass.

#### Connector

There is no standard for I2C connectors.  Follow the Grove (Seeed Studio) and STEMMA (Adafruit):
- Phoenix Contact, Series JST PH (P/N 1751264)
- 4-Position Header, 3.5mm Pitch
   - Pin 1: GND
   - Pin 2: VCC
   - Pin 3: SCL
   - Pin 4: SDA


---


## 7. ESP32-C6 Hookup


The ESP32-C6-DevKitC-1-N8 mounts to the carrier PCB via 2×20 pin headers. USB-C, boot/reset buttons, antenna, RGB LED (WS2812B) and power regulation are on the DevKit.


### 7.1 Pin Assignments

Power:
- `5V0` - Power in. → Connect to 5V rail.
- `3V3` - Regulated power out. Not needed → Leave floating.
- `GND` - Ground. → Connect to GND.
- `~RST` — Reset input (internal pull-up). → Leave floating.

Strapping pins:
- `GPIO4` — Used as JTAG pin. Ensure no low-impedance devices pull it low during startup to avoid booting issues. → Use as bidirectional. Connect to `I2C_SDA` signal.
- `GPIO5` — Used as JTAG pin. Ensure no low-impedance devices pull it low during startup to avoid booting issues. →  Use as bidirectional. Connect to `I2C_SCL` signal.
- `GPIO8` — Controls the boot mode. It is also used for the on-board RGB LED. → Do not connect to an external load.  → Leave floating.
- `GPIO9` — Controls the boot mode. Ensure no low-impedance devices pull it low during startup to avoid booting issues. → Leave floating.
- `GPIO15` — Controls peripheral voltage or JTAG. Ensure no low-impedance devices pull it low during startup to avoid booting issues. Used as output. → Connect to `STEP_NUT_A` signal.

USB-C ports:
- `GPIO16` — Connects UART0 TX to the CP2102N USB-UART Bridge RX (reserved): 
UART0 may transmit ROM boot messages and other serial data. → Leave floating.
- `GPIO17` — Connects CP2102N USB-UART Bridge TX to UART0 RX (reserved). Any external connection would fight the CP2102N output. → Leave floating. 
- `GPIO12`/`GPIO13` — USB `D−`/`D+` (reserved). These pins are used for Serial logging, code upload, JTAG. → Do not use.

Other General Purpose I/O pins:
- `GPIO0` — Used as input. → Connect to `FLOAT_LOW` signal.
- `GPIO1` — Used as input. → Connect to `FLOAT_HIGH` signal.
- `GPIO2` — Used as output. → Connect to `ATO_VALVE` signal.
- `GPIO3` — Not used. → Leave floating.
- `GPIO6` — Used as output.  → Connect to `EZO_PDIS` signal.
- `GPIO7` — Not used. → Leave floating.
- `GPIO10` — Used as output. → Connect to `PUMP_MAIN` signal.
- `GPIO11` — Used as output. → Connect to `STEP_PH_DN` signal.
- `GPIO18` — Not used. → Leave floating.
- `GPIO19` — Used as output. → Connect to `STEP_NUT_B` signal.
- `GPIO20` — Used as output. → Connect to `STEP_PDIS` signal.
- `GPIO21` —  UART1 RX. Receives responses from the addressed TMC2209 over the one-wire shared UART bus. → Connect directly to the `STEP_BUS` signal.
- `GPIO22` —  UART1 TX. Drives the one-wire shared UART bus. → Connect with 1kΩ resistor to the `STEP_BUS` signal.
- `GPIO23` — Not used. → Leave floating.


---


### 7.2. I2C

   - **Pull-up Resistors:** I2C requires pull-up resistors 4.7k to 10k tied to the microcontroller's 3.3V.
  - (VERIFY!) For the I2C bus, scatter 0.1µF near pull-up the resistors to keep the SDA/SCL lines quiet.

How to Properly Fix noisy SDA/SCL lines, use these methods:[^I2CNOISE]
- Small Shunt Capacitors: Use 22pF to 100pF caps to ground to filter RF noise.
- Series Resistors: Place small resistors (e.g., 10Ω - 100Ω) in series with the SDA/SCL lines, as close to the master/slave pins as possible, to damp reflections.
- Strengthen Pull-ups: Reduce the value of your pull-up resistors (e.g., from 10kΩ to 2.2kΩ) to drive the lines high faster, but ensure your slave devices can still sink enough current to pull it low (max 3mA).
- Proper Decoupling: Use 0.1µF capacitors to ground for the power supply (VDD to GND) of the ICs. 

[^I2CNOISE]: [I2C Design Mathematics: Capacitance and Resistance](https://www.allaboutcircuits.com/technical-articles/i2c-design-mathematics-capacitance-and-resistance/#:~:text=The%20NXP%20specification%20states%20that,cases%20the%20effect%20is%20negligible.)


---


## 8. EZO Circuits for the Probes


### 8.1 Switching EZO Circuits to I2C Mode

EZO circuits ship in **UART mode** (green LED). They must be switched to **I2C mode** (blue LED) before connecting to OPNhydro. This is done by briefly shorting two pins at power-on:[^ATLASI2C]
- Short the TX against PGND to switch to I2C mode
- A Green LED indicates UART mode, while Blue indicates I2C mode.
1. Place the EZO on a breadboard.
1. Connect `VCC` to 3V3.
2. Disconnect `GND` (power off the EZO circuit).
2. Disconnect `RX/SDA` and `TX/SCL` from the microcontroller.
3. Connect `TX/SCL` to `PGND` using a jumper wire.
5. Connect `GND` (power on).
6. Wait for LED to change from Green → Blue (takes ~2 seconds; indicates I2C mode is now active)
7. Note that this also resets the I2C address.
7. Disconnect `GND` (power off)
8. Remove the jumper wire.
9. Move the EZO on the PCB

[^ATLASI2C]: From Atlas Scientific EZO pH datasheet, p.37


---


### 8.2 EZO Circuit Calibration

All calibration is performed over I2C by sending ASCII command strings to each circuit's address.
After sending a command, wait **300 ms** before reading the response.

General I2C Calibration Notes:
1. Write command string to EZO address (e.g., 0x63). 
   e.g.,  `i2c_write(0x63, "Cal,mid,7")`
2. Wait 300 ms minimum before reading response
3. Read 1+ bytes from EZO address
   Response byte 1 = status code:
     `1` = success (`*OK`)
     `2` = syntax error
     `254` = still processing (wait longer)
     `255` = no data
4. If status = 254, wait another 100 ms and retry read

Query current calibration status at any time with `Cal,?` → returns `?Cal,<n>` where `n` = number
of calibration points stored (0 = uncalibrated).

#### EZO-pH — 3-Point Calibration (address 0x63)

Calibration solutions needed: pH 4.00, 7.00, 10.00 buffers
Order is mandatory: mid → low → high. Starting over with `Cal,mid` clears all stored points.

1. Step 1 — Mid-point (pH 7.00)
   - Place probe in pH 7.00 buffer.
   - Wait for readings to stabilize (~1–2 min).
   - Send:  `Cal,mid,7`
   - Wait:  300 ms
   - Read:  response (should be "*OK")

2. Step 2 — Low-point (pH 4.00)
   - Rinse probe with DI water, dry gently.
   - Place probe in pH 4.00 buffer.
   - Wait for readings to stabilize (~1–2 min).
   - Send:  `Cal,low,4`
   - Wait:  300 ms
   - Read:  response

3. Step 3 — High-point (pH 10.00)
   - Rinse probe with DI water, dry gently.
   - Place probe in pH 10.00 buffer.
   - Wait for readings to stabilize (~1–2 min).
   - Send:  `Cal,high,10`
   - Wait:  300 ms
   - Read:  response

4. Verify
   - Send `Cal,?`  →  expect `?Cal,3`

Notes:
- Recalibrate: Every 6–12 months, or when probe response drifts >0.1 pH.
- Storage: Keep Gen 3 probe tip submerged in storage solution when not in use.

#### EZO-EC — 2-Point Calibration (address 0x64, K=1.0 probe)

Calibration solutions needed: 12,880 µS/cm and 80,000 µS/cm standards
(Atlas Scientific COND-12880 and COND-80000, or equivalent NIST-traceable solutions)

1. Step 1 — Dry calibration
   - Remove probe from any liquid. Ensure probe is completely dry.
   - Send:  `Cal,dry`
   - Wait:  300 ms
   - Read:  response (`*OK`)

2. Step 2 — Low-point (12,880 µS/cm)
   - Place probe in 12,880 µS/cm standard.
   - Wait for readings to stabilize (~1 min).
   - Send:  `Cal,low,12880`
   - Wait:  300 ms
   - Read:  response

3. Step 3 — High-point (80,000 µS/cm)
   - Rinse probe with DI water, dry gently.
   - Place probe in 80,000 µS/cm standard.
   - Wait for readings to stabilize (~1 min).
   - Send:  `Cal,high,80000`
   - Wait:  300 ms
   - Read:  response

4. Verify
   - Send `Cal,?`  →  expect `?Cal,2`

Notes:
- Recalibrate: Annually or when probe is replaced.
- K value: Confirm probe is K=1.0 (`K,?` should return `?K,1.00`). If not, set with `K,1.0`.


---

### 8.3 Temperature Effect on Sensors

Temperature Effect on Sensors:
- pH: ±0.003 pH per °C (Nernst equation)
- EC: ±2% per °C (ion mobility changes)

Firmware Integration:
```
void update_ezo_temperature_compensation(void) {
    // read water temperature
    float water_temp = _read_temp();

    // format command
    char temp_cmd[16];
    snprintf(temp_cmd, sizeof(temp_cmd), "T,%.1f", water_temp);

    // send to all EZO circuits
    ezo_send_command(I2C_EZO_PH, temp_cmd);  // Address 0x63
    ezo_send_command(I2C_EZO_EC, temp_cmd);  // Address 0x64

    // EZO circuits now automatically compensate all readings
}
```

Recommendation:
- update the temperature `T,%.1f` every measurement cycle,
- Or only when temp changes >0.5°C (power saving)


---


## 9. Hand-Soldering

Hand-soldering a 4-layer PCB with an ADM3260 (SSOP package) and EZO modules is a fun challenge, but the internal copper planes act like a giant heat sink. If you aren't careful, you'll get "cold solder joints" where the solder balls up instead of flowing into the hole.

- **Thermal Reliefs:** Because your **Layer 2 (Ground Plane)** is a massive sheet of copper, it will "suck" the heat away from your soldering iron. Ensure your PCB design software uses Thermal Reliefs (spokes) for ground pads, or you will struggle to get the solder to melt.
- **Flux is Mandatory:** When soldering the **ADM3260** (SSOP-20 package), use plenty of liquid flux. It prevents bridges between the tiny pins and makes the solder flow onto the pads instantly.
- **The "Island" Connectors:** For your **pH/EC BNC connectors**, use Through-Hole versions. Surface-mount BNCs can easily tear off the board if you accidentally tug on a probe cable.
- **Height Clearance:** Place tall **electrolytic caps** and the **EZO-PMP headers** near the edges of the board so they don't block your iron when you try to solder the smaller components in the center.
- **Soldering the ADM3260 (SSOP-20)**
This is the hardest part. The pins are close together (0.65mm pitch). Use the "Tack and Drag" Method:
Use a **"Hoof" or "Chisel" tip**, not a needle-point tip. Needle tips don't hold enough thermal mass for 4-layer boards.
   1. Tack one corner pin to align the chip.
   2. Flood all 10 pins on one side with Tacky Flux.
   3. Put a small "blob" of solder on your iron tip.
   4. Drag the iron across the pins. The flux will magically pull the solder onto the pads and off the green solder mask.

For a 4-layer PCB that you are soldering by hand, you need to balance two competing needs: high-voltage safety (creepage) and the physical reality of a soldering iron tip. In a mineral-heavy reservoir environment, humidity can cause "tracking" (electricity jumping across the board surface), so your Moats must be wider than a standard digital gap.

#### "Safety Moat" Clearance

Set your **Design Rule Check (DRC)** for the following minimums specifically around the **ADM3260** and the **pH/EC Islands**:
   - **Minimum Moat Width: 6 mm:** While 2.5 mm is technically enough for 2.5kV isolation, an 6 mm gap ensures that a stray "solder splash" or a drop of nutrient-rich condensation won't bridge the gap.
   - **Copper-to-Board-Edge: 1 mm:** This prevents the V-cut or router bit from smearing copper across the isolation boundary during manufacturing.
   - **Solder Mask Expansion: 0.05 mm:** This ensures the green "paint" (solder mask) stays as close to the pad as possible, preventing solder from bridging between the tight SSOP-20 pins of the ADM3260.

#### "Keep-Out" Zones

Since you are soldering by hand, the tip of your iron (usually 1.5mm–2.4mm wide) needs "elbow room."
   - **The "Shadow" Zone:** Do not place the 1206 Bulk Capacitors (10µF) directly in front of the ADM3260 pins. Leave at least 3 mm of horizontal clearance. If they are too close: You won't be able to lay your iron flat enough to "drag solder" the chip pins without melting the plastic end of the capacitor.
   - **The BNC Overhang:** Most *Through-Hole BNC connectors** have large metal legs. Ensure the "Moat" starts at least **2 mm** away from the BNC pads. If the BNC leg is right on the edge of the moat, it's very easy to accidentally bridge to the "Mainland" ground plane with a blob of solder.

#### Moat Integrity Checklist

Before you hit "Generate Gerbers," run these three manual checks in your PCB software:
   - **The "Ghost" Check:** Turn off all layers except Layer 2 (GND) and Layer 3 (PWR). Ensure the "canyon" is completely empty of copper. No floating traces, no vias, no text.
   - **The "Stitching" Check:** Ensure your internal Ground (Mainland) and Isolated Ground (Island) overlap slightly on different layers (e.g., L2 Mainland overlaps L3 Island) to create that EMI-filtering capacitance, but check that they are separated by the board substrate.
   - **The Silkscreen Labels:** Since we have three EZO-PMPs and two sensors, label the "Island" side clearly on the silkscreen (e.g., "ISO-PH" and "ISO-EC"). This prevents you from accidentally plugging a non-isolated sensor into an isolated port during assembly.

**Summary Table for DRC Settings**

Parameter            | Hand-Solder Value
---------------------|------------------
Track to Track       | 8 mils (0.2 mm)
Track to Pad         | 8 mils (0.2 mm)
Moat (Isolation Gap) | 250 mils (6.35 mm)
Minimum Via Drill    | 12 mils (0.3 mm)
Via Pad Diameter     | 24 mils (0.6 mm)

If your software allows, add a **"Route Keep-Out"** area over the moats. This prevents the "Auto-Router" from trying to be "helpful" by running a 24V line across your isolation gap!






## Block Diagram

```
                           ┌─────────────┐
                           │  ESP32-C6   │
                           │             │
                           └──────┬──────┘
                                  │
         ┌──────────────────┬─────┴───────────────┐
         │                  │                     │
    ┌────┴────┐        ┌────┴────┐         ┌──────┴──────┐
    │  I2C    │        │  GPIO   │         │    UART     │
    │  Bus    │        │         │         │    Bus      │
    └────┬────┘        └────┬────┘         └──────┬──────┘
         │                  │──────────────┐      │
    ┌────┴───────┐  ┌───────┴────────┐     │      │
    │ pH EZO     │  │ LiDAR          │  ┌──┴──────┴───────┐
    │ EC EZO     │  │ Float switches │  │ Dosing steppers │
    │ RTD EZO    │  │ Main pump      │  └─────────────────┘
    └────────────┘  │ OTA valve      │
                    └────────────────┘
```

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
