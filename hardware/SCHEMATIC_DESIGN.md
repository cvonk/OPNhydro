# Schematic Design Guide

This document answers **"How?"** — the companion to the Architecture document, which answers "Why?". It covers the schematics, component selection, and PCB layout rules for the **OPNhydro** board.

The central problem is coexistence. On one side: a pH probe measuring millivolt-level electrochemical potentials, an EC probe and an ESP32 that needs a clean analog reference. On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve slamming on and off. Everything shares the same 100 mm × 80 mm board. The sections that follow explain how the design lets these worlds coexist.

This document starts with the most critical parts of the Schematic and PCB Layout:
1. Stability Under Peak Loads
2. Integration of Precision Dosing and EMI Mitigation
3. Maintaining Signal Integrity via Isolation

It then continues to fill in the details:
<ol start="4">
<li>Reservoir Level Circuits
<li>Main Pump and ATO Solenoid Drivers
<li>ESP32-C6, UART and I2C
<li>EZO Circuits and Calibration
<li>Hand-Soldering
</ol>

![Protection Gauntlet Schematic](../media/infographics/electronic-noise.png)


---


[TOC]


---


## 1. Stability Under Peak Loads

The board runs from a single 24V DIN rail PSU rated at 6.5A. Under normal operation the load is modest, but worst-case — main pump, ATO solenoid, and two dosing pumps all active simultaneously — the peak draw reaches approximately **4.7A**. The PSU can handle this, but the board itself must be designed to tolerate it without rail sag, noise, or damage.

Three concerns drive this section. First, the supply must be protected: against reverse polarity, overvoltage transients, and a fault that exceeds the PSU's rating. Second, the 24V rail must be converted cleanly to 5V and 3.3V for the logic and sensor circuits. Third, the sharp current pulses from the stepper drivers must be absorbed locally before they degrade the rail for everything else. Each of these is handled in a subsection below.

**Topology**


![Three Tier Power](../media/infographics/power-architecture.png)


---


### 1.1. Protection Gauntlet

The 24V enters the board and passes through a "protection gauntlet" before it reaches the motor drivers and the sensitive sensor logic:

1. **18 AWG Wire** for the Main Power Input (from PSU to PCB), according to standard electrical practices for currents up to 10A over short runs.
2. **Main Fuse (F):** 7A Fast-Acting Fuse provides a 50% headroom over the 4.7A peak, while still being close to 6.5A rating of the PSU. Not using PTC, because of its slow response time and voltage drop. 
3. **TVS Diode (D<sub>tvs</sub>):** If a massive overvoltage event occurs, the TVS diode will shunt the excess current to ground, potentially blowing the fuse but saving the rest of the PCB.
4. **Reverse Polarity Protection (P-CH):** If power is connected in reverse polarity, this stops current instantly, saving the remainder of the board.

**Circuit**

![Protection Gauntlet Schematic](../media/schematics/Protection-Gauntlet.svg)

**Part Selection**

Reference       | Specs                                     | Manufacturer / Details          | Package
----------------|-------------------------------------------|---------------------------------|-----
FB              | 12A / 50Ω(100Mhz) Ferrite Bead            | Murata BLM31-series             | 1206
F               | 7A / 125VAC Fast Fuse                     | Littelfuse NANO451-series       | 2-SMD
P-CH            | 30V / 32A, P-CH MOSFET                    | Alpha & Omega AON6407           | 8-DFN (5x6)
D<sub>tvs</sub> | 28V<sub>rs</sub> TVS / 13.2A(peak)        | Diodes SMBJ-series SMBJ28A-13-F | DO-214AA
D<sub>z</sub>   | 12V / 200mW zener                         | Diodes BZT52C12S-7-F            | SOD-323
R<sub>gs</sub>  | 33kΩ ±1% / 1/8W                           | Yageo RC_L-series               | 0805
C<sub>b</sub>   | 1000µF ±20% / 50V  elec. (see §1.2)       | TDK B41866-series               | Radial
HDR             | 12A / 400V, 2P 0.2" pitch R/A header      | Phoenix Contact MSTA-series     | 
PLG             | 12A / 630V / 12-30AWG, 2P 0.2" pitch plug | Phoenix Contact MSTB-series     | 
Wire            | 18AWG, 10A over short runs                |                                 |

**Engineering Notes**
- Reverse Polarity Protection explained:
    1. Normal polarity (+24V at Source): 33kΩ pulls gate toward +24V → Zener clamps gate at +12V → V<sub>gs</sub> = 12 − 24 = −12V → **Fully ON** ✓. Current through Zener: (24−12) / 33k = 0.36mA → 4.3mW dissipation → trivial.
    2. Reverse polarity (supply plugged backwards → Source at −24V): 33kΩ pulls gate toward 0V - Zener anode is now at +24V → clamps gate at 24−12 = +12V → V<sub>gs</sub> = 12 − 0 = +12V → **Stays OFF** ✓. +12V is within the ±20V V<sub>gs</sub>(max) rating — safe ✓.


---


### 1.2. Bulk Caps are Your Friend

Every wire and PCB trace has inductance, and inductance resists instantaneous changes in current: $U = L \frac{dI}{dt}$. When a load demands a sudden surge of current, the inductance of the supply path creates a momentary voltage drop — the rail sags. The further the current has to travel, the worse the sag. The solution is to keep a local energy reservoir close to the load so it can deliver charge instantly when demand spikes, before the bulk supply can respond.

The strategy is hierarchical: a large capacitor at the power entry handles slow, high-energy demands, while smaller capacitors placed directly at each load handle fast, local transients. This keeps peak currents as local as possible, reducing noise on the shared rail.

**Theory**

The TMC2209 stepper driver is of special concern here. It chops current to the stepper coils at 20–50 kHz — every switching cycle draws a sharp current pulse from the VM pin. Without a local capacitor, these pulses propagate back through trace inductance all the way to the main bulk cap at the power entry, coupling switching noise onto the 24V rail. A local 220 µF cap at each VM pin absorbs these pulses before they leave the immediate area.

Besides capacitance and voltage, Equivalent Series Resistance $R_s$ and maximum Ripple Current $I_{ac}$ are the key selection critea for bulk capacitors.

**Recommended bulk capacitors**

Rail | Place               | Peak Current | Value               | Type  | Voltage | Package    | R<sub>s</sub> | I<sub>ac</sub> | Purpose
----:|---------------------|--------------|--------------------:|-------|--------:|------------|---------------|----------------|--------
 24V | Main power entry    | ~4.7A        | 1000µF [^1000UF50V] | Elec. |  50V    | Radial TH  | 39mΩ(100kHz)  | 2.454(100kHz)  | Primary reservoir
 24V | Each TMC2209 VM pin | ~1.5A        |  220µF  [^220UF50V] | Elec. |  50V    | Radial TH  | 42mΩ(100kHz)  | 1.37A(100kHz)  | Local reservoir
 24V | Main Pump MOSFET    | ~1.2A        |  220µF  [^220UF50V] | Elec. |  50V    | Radial TH  | 42mΩ(100kHz)  | 1.37A(100kHz)  | Local reservoir
  5V | Buck output         | ~0.75A       |  220µF  [^220UF10V] | Poly. |  10V    | Radial SMD | 22mΩ          | 1.04A(100kHz)  | ESP32 WiFi Tx
3.3V | LDO output          | ~0.15A       |   22µF  [^22UF10V]  | X7R   |  16V    | 1206 SMD   | 90mΩ          | 1.06A(100kHz)  | Low current

[^1000UF50V]: TDK B41866D6108M000
[^220UF50V]: KEMET ESY227M050AH2AA
[^220UF10V]: Panasonic 16SVPK220M
[^22UF10V]: Murata GRM31CR71A226KE15L

**Engineering Notes**

- Given the acceptable ripple and transient duration, the required capacitance follows as: $C = I × \Delta t / \Delta U$. If $\Delta t$ or $\Delta U$ are unknown, use a rule of thumb: provide 100-200µF electrolytic capacitors for every 1A of current. 
- To reduce aging, use electrolytic capacitors that are rated for 150% to 200% of the expected voltage.
- Use low-ESR capacitors: e.g. Panasonic OSCOM-SVPK-series or Kemet A750/A758-series for Aluminium polymer.
- Aluminium polymer is low-ESR, but hard to find at above 25V. Aluminium electrolytic capacitors are a pragmatic choice for 50V: e.g. TDK B41866-series for Aluminium electrolytic.
- Place local bulk capacitance as close to the load as possible.


### 1.3. Buck Converter

The system needs 5V for TTL logic, and the only available rail coming off the DIN PSU is 24V. A synchronous buck converter is the right tool: it steps the voltage down efficiently with minimal heat, unlike a linear regulator which would waste over 2W at the same load. The TPS62933 was chosen for its wide input range (3.8–30V), 3A continuous output, and compact SOT-583 package.

The design follows Figure 10.1 of the [TPS62933 Datasheet](https://www.ti.com/lit/ds/symlink/tps62933.pdf?ts=1773728788941), with component values confirmed using the [WEBENCH Power Designer](https://webench.ti.com/power-designer/switching-regulator). Bulk capacitors on the input and output are sized per §1.2.

**Circuit**

![Buck Converter Schematic](../media/schematics/Buck-Converter.svg)

**Part Selection**

Reference       | Specs                                         | Manufacturer / Details     | Package
----------------|-----------------------------------------------|----------------------------|------
U               | 3.8–30V / 3A Buck Converter                   | T.I. TPS62933DRLR          | SOT-583
L               | 10µH / 3A ±20% R<sub>DC</sub><50mΩ            | Bourns SDR1307-series      | Nonstandard
R<sub>rt</sub>  | 21kΩ ±1% / 1/8W (calc. below)                 | Yageo RC_L-series          | 0805   
R<sub>t</sub>   | 52.3kΩ ±1% / 1/8W (calc. below)               | Yageo RC_L-series          | 0805
R<sub>b</sub>   | 10kΩ ±1% / 1/8W (calc. below)                 | Yageo RC_L-series          | 0805
C<sub>mf1</sub> | 10µF ±10% / 50V, cer. X5R                     | Murata GRT-series          | 1206
C<sub>mf2</sub> | (3×) 10µF ±10% / 10V cer. X5R                 | Murata GRM-series          | 0805
C<sub>bst</sub> | 100nF ±10% / 100V, cer. X7R                   | Murata GRM-series          | 0603
C<sub>ss</sub>  | 33nF ±10%  / 50V, cer. X7R (calc. below)      | Kemet SMD-Comm-X7R-series  | 0603
C<sub>b1</sub>  | 1000µF ±20% / 50V, elec. ESR=39mΩ, (see §1.2) | TDK B41866-series          | Radial
C<sub>b2</sub>  | 220µF ±20% / 10V, poly. ESR=22mΩ, (see §1.2)  | Panasonic SVPK-series      | Radial

**Engineering Notes**

- Given the internal reference voltage $V_{r} = 0.8 \rm{\ V}$, we selected $R_{b}=10 \rm{\ k\Omega}$ and $R_{t}=52.3 \rm{\ k\Omega}$ for the voltage divider. The output voltage $V_o$ follows, per §9.3.4 of the datasheet:
$$
  \begin{align}
    V_o &= V_r \times \frac{R_b + R_t}{R_b} \\
        &= 0.8 \rm{\ V} \times \frac{10\rm{\ k\Omega} + 52.3\rm{\ k\Omega}}{10\rm{\ k\Omega}} \approx 5 \rm{\ V} \nonumber
  \end{align}
$$
- For a switching frequency $f_{s} \approx 1 \rm{\ MHz}$, we select $R_{rt} = 21 \rm{\ kΩ}$, per §9.3.5:
$$
  \begin{align}
  f_{s} &= 17.293 \times 10^6 \times \left(\frac{R_{rt}}{10^3}\right)^{-0.942} \\
  &= 17.293 \times 10^6 × 21^{-0.942} \approx 1 \rm{\ MHz} \nonumber
  \end{align}
$$
- We use the soft-start feature to minimize inrush current for driving capacitive load. For a soft-start $t_{ss} = 5 \rm{\ ms}$, where $V_{r} = 0.8 \rm{\ V}$ and a typical $I_{ss}=5.5 \rm{\ \mu A}$, the required $C_{ss}$ follows per §9.3.6:
$$
  \begin{align}
    C_{ss} &= \frac{t_{ss} \times I_{ss}}{V_r} \\
    &= \frac{5 \rm{\ ms} \times 5.5 \rm{\ \mu A}}{0.8 \rm{\ V}} \approx 33 \rm{\ nF} \nonumber
  \end{align}
$$

**PCB Layout Notes** [^BUCKPCB]

- **Minimize the switching loops.** The two critical loops are: the *on-loop* (C<sub>b1</sub> → TPS62933 → L → C<sub>b2</sub>) and the *off-loop* (L → C<sub>b2</sub> → internal N-CH diode). Keep both loops as small and tight as possible — loop area directly determines radiated EMI.
- **Keep high-frequency components together.** Place C<sub>b1</sub>, C<sub>b2</sub>, L, and the TPS62933 on the same layer, close to each other.
- **Use short, wide traces** for all high-current paths.
- **Route the feedback line carefully.** The FB pin senses the output voltage with millivolt precision. Keep its trace short, away from the inductor, and away from any switching node, possibly even on the other side of the GND layer.
- **Place a ground plane directly under the TPS62933** for thermal relief and a low-impedance return path.

[^BUCKPCB]: [Switching Regulator PCB Design - Phil's Lab #60](https://youtu.be/AmfLhT5SntE?si=4bg8blk9iI0T82Y5&t=883)


---


### 1.4. Linear Regulator LDO (3.3V)

The 3.3V rail powers the ADM3260 isolation chips, the EZO-RTD circuit, and the optional expansion sensors (BME280, BH1750). The current draw on this rail is low — at most ~150 mA peak — so a linear regulator is the right choice here. Dropping 1.7V at 150 mA dissipates only ~250 mW, which is trivial. A second switching converter would add complexity and switching noise for no benefit.

The input is taken from the 5V buck output rather than directly from 24V. A 5V→3.3V drop keeps the LDO dissipation low; a 24V→3.3V LDO at the same current would waste over 3W as heat. The design follows the typical application circuit from the [AZ1117 Datasheet](https://www.diodes.com/assets/Datasheets/AZ1117I.pdf).

**Circuit**

![Linear Regulator Schematic](../media/schematics/Linear-Regulator.svg)

**Part Selection**

Reference       | Specs                                       | Manufacturer / Details  | Package
----------------|---------------------------------------------|-------------------------|--------
U               | 3.3V / 1A, Linear Regulator                 | Diodes AZ1117IH-3.3TRG1 |
C<sub>b1</sub>  | Not needed (already part of buck converter) |                         |
C<sub>b2</sub>  | 22µF ±20% / 10V, cer. X7R                   | Murata GRM-Series       | 1206


**OR???**
spx3819ms-l-3-3

**AND???**
Place TVS diodes on inputs for ESD protection
Add https://www.lcsc.com/ part numbers?


---


### 1.5. PCB Guidelines

The PCB has two hard constraints that drive most of the other design decisions. First, the 4.7A peak current on the 24V rail requires copper heavy enough to carry that current continuously without excessive resistive heating. Second, the isolation moats around the pH and EC islands must be maintained through all four layers, which means the layer stack-up cannot be an afterthought.

The design specifies a **4-layer PCB with 2 oz copper on the outer layers**. The heavier copper on L1 and L4 keeps resistance and heat low on the high-current 24V traces. The two inner layers (L2 and L3) use standard 1 oz copper, which is sufficient for the ground and power planes they carry.

**Layer stack-up**

The layer assignment is not arbitrary — L2 is the EMI shield that separates the noisy switching circuits on L4 from the sensitive signal traces on L1.

Layer | Name   | Function                | Components
------|--------|-------------------------|--------------------------
L1    | Top    | Signal layer            | ESP32, LiDAR, I2C, UART, EZO, BNC
L2    | GND    | Solid ground plane      | One uninterrupted copper pour — the EMI shield
L3    | PWR    | Power planes            | Separate copper pours for 3.3V, 5V, and 24V
L4    | Bottom | High-current switching  | Stepper drivers, MOSFETs, 24V power traces

**Enclosure and mechanical**

The board targets a ~100 mm × 80 mm footprint, which fits standard off-the-shelf enclosures. Recommended specifications:

- **Enclosure:** IP65-rated ABS, approximately 150 × 100 × 70 mm. The IP65 rating keeps moisture and insects out of the electronics.
- **Cable glands:** Use glands for every wire entering the enclosure — probe cables, pump leads, and the PSU input.
- **BNC connectors:** Mount three panel-mount BNC connectors on the enclosure face for the pH, EC, and RTD probes. Panel-mount rather than PCB-mount prevents mechanical stress on the isolation islands if a probe cable is tugged.
- **PCB finish:** HASL (Hot Air Solder Leveling) is sufficient and lowest cost. ENIG (Electroless Nickel Immersion Gold) is a worthwhile upgrade for the fine-pitch SSOP-20 pads of the ADM3260.
- **Optional:** A clear lid panel allows status LED visibility without opening the enclosure.

### 1.5.1. Trace Widths

The trace widths can be calculated using the IPC-2221 empirical formula for external conductors.[^1]
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

The table below uses a conservative $ΔT = 10°\rm{C}$ (IPC-2221 permits 20°C for most PCB classes). 

Net                     | Target Current    | Internal Trace Width | External Trace Width | Rationale
------------------------|-------------------|----------------------|----------------------|----------
24V input (PSU→TVS→RPP) | 6.5A (Peak)       | 5.0mm (200mil)       |  2.0mm (80mil)       | Reduce sag
24V main pump           | 1.2A (Continuous) | 1.0mm  (40mil)       |  0.4mm (15mil)       | Manage heat
24V each dosing pump    | 1.53A (Peak)      | 1.0mm  (40mil)       |  0.4mm (15mil)       | Lower inductance
24V ATO valve           | 0.3A (Peak)       | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum
5V rail (post-buck)     | 0.75A (Peak)      | 0.5mm  (20mil)       |  0.2mm  (8mil)       | Stable power
3.3V rail (post-LDO)    | 0.15A (Peak)      | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum


### 1.5.2. PCB Layout Strategy

- **Star Power**: Run a dedicated pair of 24V wires from your main power input connector directly to the stepper section, and a separate pair to the logic regulator. Do not "daisy chain" the power from the motors to the sensors.
- **Ground Plane:** Make sure you have an uninterrupted ground plane, to minimize current loops (inductance).
- **Ground Vias:** Give each ground connection its own via to the ground plane, so the impedance of the via doesn't cause the a sag parts nearby. (and no common impedance crosstalk)
- **Via Stitching:** If you must switch the 24V rail between layers, use multiple vias (at least 3–4 vias per 2A connection). A single standard 10-mil via is only rated for about 0.5A–1A before it acts like a fuse.
- **Antenna Support:** The ground plane should not extend under the ESP32-C6 antenna keep-out area to ensure proper wireless performance.
- **Analog/Digital Isolation:** The layout must keep analog traces physically isolated from switching power supplies and high-current motor traces.


---


## 2. Integration of Precision Dosing and EMI Mitigation

The high precision steppers generate significant **Electromagnetic Interference (EMI)** through high-speed PWM switching. To mitigate this:
- A **"Silent Read" Strategy** protects sensitive probes from the electromagnetic interference (EMI) generated by stepper PWM switching. The firmware shuts down the stepper drivers during sensor reads (via STEP_PDIS) to create a "blackout" of switching noise for the sensitive pH and EC probes
- **Bypass Capacitors** suppress the middle and high frequency noise.
- **PCB Layout Strategy**, thermal relief and EMI shielding.

The **main pump**, **stepper motors**, the **solenoid** and **buck converter** turn the PCB into a high-noise environment. Stepper drivers are notorious for creating Electromagnetic Interference (EMI) and ground bounce that can "ghost" the I2C bus or cause pH readings to jump.


---


### 2.1. Stepper Driver Circuit (TMC2209)

Three TMC2209 drivers are used — one each for the pH Down, Nutrient A, and Nutrient B peristaltic pumps. All three use the same schematic; they share a single UART bus and are distinguished by their `AD0`/`AD1` address pins.

> [!IMPORTANT]
> All currents in this section are RMS currents.

**Circuit**

The Standard Application Circuit in Fig. 3.1 of the [TMC2209 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/tmc2209_datasheet_rev1.09.pdf) and [TM2209 EVAL Schematics](https://www.analog.com/media/en/evaluation-documentation/evaluation-design-files/TMC2209-EVAL_Layout_Data_V1.1.zip) show a typical Stepper Driver using the TMC2209. The design follows their recommendations:

The circuit shown below is for the pH Down stepper pump. Circuits for the other stepper pumps are identical, except that instead of the `STEP_PH_DN` signal, they connect to `STEP_NUT_A` and `STEP_NUT_B` signals for respectively the Nutrient A and B stepper pumps.

![Stepper Driver Schematic](../media/schematics/Stepper-Driver.svg)

**Part Selection**

Reference       | Specs                                           | Manufacturer / Details | Package
----------------|-------------------------------------------------|------------------------|----------
U               | 4.75-28V / 2A, TMC2209 Motor Driver             | Analog Devices stallGuard-series TMC2209-LA-T | 28-VFQFN
R<sub>t</sub>   | 14kΩ ±1% / 1/8W (calc. below)                   | Yageo RC_L-series      | 0805
R<sub>b</sub>   | 10.7kΩ ±1% / 1/8W (calc. below)                 | Yageo RC_L-series      | 0805
R<sub>s</sub>   | (2×) 110mΩ ±1% / 1/3W (calc. below)             | Susumu RL-series       | 0805
C<sub>cp</sub>  | 22nF ±10% / 100V cer. X7R                       | Murata GRM-series      | 0603
C<sub>vcp</sub> | 100nF ±10% / 100V cer. X7R                      | Murata GRM-series      | 0603
C<sub>mf1</sub> | 100nF ±10% / 100V cer. X7R                      | Murata GRM-series      | 0603
C<sub>mf2</sub> | (2×) 100nF ±10% / 100V, cer. X7R                | Murata GRM-series      | 0603
C<sub>b1</sub>  | 2.2μF ±10% / 10V, cer. X7R                      | Murata GRM-series      | 0603
C<sub>b2</sub>  | 220µF ±20% / 50V, ESR=22mΩ, elec. (see §1.2)    | Kemet ESY-series       | Radial
HDR             | 3A / 250V 4-pin XH 2.5mm, R/A header            | JST XH-series S4B-XH-A |
PLG housing     | 3A / 250V 4-pin XH 2.5mm, plug housing[^NEMA17] | JST XH-series XHP-4    |
PLG contacts    | (4×) 22-28 AWG / 3A / 250V XH, plug contact     | JST XH-series SXH-001T-P0.6 |

[^NEMA17]: Commonly mislabelled "XH2.54"); XH series is 2.5mm pitch, not 2.54mm DuPont. [ankoproducts.com](https://ankoproducts.com/products/a200sx). Also compatible with Molex KK 0.1"

**Engineering Notes**
- The header follows the NEMA 17 convention. The pin convention is: Coil A+, Coil A-, Coil B+, Coil B-[^STEPPERHEADER]
- `SPREAD` tied to GND to select StealthChop mode, per architecture.
- `CLK` tied to GND, to select the internal clock.
- `STEP` tied to dedicated input signal, e.g. `STEP_PH_DN`.
- `DIR` left unconnected (int. pull-down) to select increasing count
- `STDBY` left unconnected (int. pull-down) to enable the internal supply regulator.
- `INDEX` left unconnected. Adds no value in normal operation.
- **Die Pad** must be wired to GND plane; provide as many vias as possible for heat transfer.
- Peristaltic pumps are self-sealing — the rollers pinch the tube closed when stopped, so backflow cannot occur and direction reversal is never needed.
- `STEP_PDIS` allows the firmware to disable the driver for a "Silent Read".
- Register `IHOLD=0` handles standstill power saving without the register-reset complication of STDBY.
- `DIAG` left unconnected. Stall detection is preferred via the `DRV_STATUS` register.
- If we end up with a free GPIO, we can use this to allow interrupt-driven stall detection using the `DIAG`-pin without polling.

[^STEPPERHEADER]: ⚠ Verify pin order from A200SX datasheet before PCB layout. Coil swap (A↔B or polarity) only affects rotation direction; the TMC2209 handles both.


### 2.1.1. UART Device Address

Using a **Single Wire UART Bus** with the `AD0` and `AD1` pins for addressing is the most "EZO-like" way to handle the TMC2209 drivers — it keeps the pin count low and control digital.

The TMC2209 I2C Device Address is set using pins `AD1` and `AD0`. These pins have internal pull-down resistors:
   - for pH Dn, set address 0b00 → leave `AD1` and `AD0` unconnected
   - for NUT A, set address 0b10 → tie `AD1` to 3V3 and leave `AD0` unconnected
   - for NUT B, set address 0b11 → tie `AD1` and `AD0` to 3V3

### 2.1.2. Output Current

The **Output Current** is limited by:
1. The **R<sub>s</sub>** shunt resistors measure the output currents. The TMC2209 measures the voltage drop across this resistor to determine actual coil current, then adjusts its PWM chopper duty cycle to regulate current to the `IRUN/IHOLD target`. §8 suggests 120mΩ low-inductance resistors. Instead we use a 110mΩ to ensure it will not exceed the full-scale voltage of 325mV.
2. Set a hard limit using the **V<sub>REF</sub>** input of the TMC2209. This linearly scales the maximum current. The value for voltage $V_{REF}$, follows from the architecture that specifies that $V_{REF}$ should be set for a current corresponding to 90% of the maximum stepper current of 1.7 A<sub>RMS</sub>.  The formula from the Motor Current Control chapter (§9) of the data sheet, shows that the current depends on $CS$, $V_{FS}$ and $V_{REF}$ and can be calculated as: 
$$
    \begin{align}
        I_{RMS}  &= \frac{CS+1}{32} \times \frac{V_{FS}}{R_{s} + 20 \rm{\ mΩ}} \times \frac{1}{\sqrt 2} \times \frac{V_{VREF}}{2.5 \rm{\ V}} \\
        \rm{where\ \ } 
        CS  &= \rm{current\ scale\ setting\ as\ set\ by\ the\ IHOLD\ and\ IRUN\ (default=31)} \nonumber \\
        V_{FS}  &= \rm{full\textnormal{-}scale\ voltage\ set\ by\ vsense\ control\ bit\ (default=325\ mV)} \nonumber \\
        R_{s}  &= \rm{resistance\ of\ the\ sense\ resistors} = 110\ m\Omega \nonumber \\
        V_{VREF} &= \rm{linearly\ scales\ the\ output\ current\ to\ the\ motor\ (2.5\ V\ for\ 100\%) } \nonumber
    \end{align}
$$
Without software throttling ($CS=31$) and the default $\textnormal{vsense control bit}$, the required $V_{VREF}$ follows as:
$$
    \begin{align}
        0.9 \times 1.7\rm{\ A}  &= \frac{32}{32} \times \frac{325 \rm{\ mV}}{110 \rm{\ m\Omega} + 20 \rm{\ mΩ}} \times \frac{1}{\sqrt 2} \times \frac{V_{VREF}}{2.5 \rm{\ V}} \nonumber \\
        \Rightarrow
        V_{VREF} &= 0.9 \times 1.7\rm{\ A} \times \frac{110 \rm{\ m\Omega} + 20 \rm{\ mΩ}}{325 \rm{\ mV}} \times \sqrt 2 \times 2.5 \rm{\ V} 
        \approx 2.16 \rm{\ V} \nonumber
    \end{align}
$$
To create this voltage, use the 5V<sub>OUT</sub> pin with a R<sub>H</sub> and R<sub>L</sub> Voltage Divider. Ignoring the $R_{VREF}=240 \rm\ M\Omega$, the required resistors follow as $R_{t} = 14 \rm{\ k\Omega}$ and $R_{b} = 10.7 \rm{\ k\Omega}$:
$$
    \begin{align}
        V^{'}_{VREF} &= \frac{R_{b}}{R_{b}+R_{t}} \times 5 \rm{\ V} = \frac{10.7 \rm{\ k\Omega}}{10.7 \rm{\ k\Omega} + 14 \rm{\ k\Omega}} \times 5 \rm{\ V} \approx 2.16 \rm{\ V} \nonumber
    \end{align}
$$
3. The firmware **CS Register** (see below).


The **firmware** should aim for an **operating range of 70% to 80%** corresponding to setting the CS register accordingly. Increase to 85–90% only if stalling occurs on aged tubing.

CS value | Current limit| Target range
:-------:|:------------:|:-----------:
24       |      1.19A   | 70%
25       |      1.24A   | 73%
26       |      1.29A   | 76%
27       |      1.34A   | 79%
28       |      1.43A   | 81%
29       |      1.39A   | 84%
30       |      1.48A   | 87%
31       |      1.53A   | 90%


### 2.1.3. Firmware Considerations

Two libraries cover everything needed for the stepper drivers. [TMCStepper](https://github.com/teemuatlut/TMCStepper) configures the TMC2209 over UART — setting silent mode, current limits, and microstepping. [TeensyStep](https://github.com/luni64/TeensyStep) handles step generation — defining when and how fast to pulse the STEP pin. They operate independently: TMCStepper talks to the driver's registers, TeensyStep talks to the motor through timing.

Key UART registers to configure at startup are:

| Register     | Value | Purpose
|--------------|-------|---------
| `IHOLD`      |     0 | Zero standstill current (EN tied to GND — this is essential)
| `IRUN`       |    24 | Run current ≈ 70% (CS=24 → 1.19A; increase to 27 for ~79% if stalling occurs — see CS table above) |
| `IHOLDDELAY` |     6 | Steps between IRUN→IHOLD transition after last STEP pulse
| `TPWMTHRS`   |     0 | StealthChop2 active at all speeds
| `SENDDELAY`  |    ≥2 | Required for multi-driver bus. See note above.

STEP pulses must be generated by a hardware peripheral, not a software loop. If the ESP32 is busy with a Wi-Fi request or SSL handshake, a software-timed loop can stall for tens of milliseconds. A single missed or late pulse causes the stepper to lose a step — and since dosing accuracy is derived from step count × tube displacement, even occasional step loss accumulates into measurable calibration error over time.

The recommended approach on the ESP32-C6 is the **Remote Control Transceiver (RMT)**. It generates arbitrary pulse sequences from a preloaded buffer with nanosecond resolution, entirely independent of the CPU. Configure it to output N pulses at the target step frequency and trigger it once per dose. When the burst completes it fires an interrupt; the CPU is free throughout. The ESP32-C6 provides up to 4 independent RMT TX channels — one per STEP pin with one spare.


---


### 2.2. "Silent Read"

The "Silent Read" strategy is a fundamental coordination technique in the OPNhydro architecture designed to ensure the highest possible data integrity for sensitive electrochemical sensors. Its importance is rooted in the need to manage the conflicting requirements of high-precision dosing and high-accuracy monitoring within the same electrical environment.

The dosing sequence is:
1. Turn OFF the TMC2209 drivers (using the !EN pin) while reading the sensors to ensure 100% electrical silence.
2. Read pH/EC (EZO sensors) and calculate dose.
3. Enable drivers and step the motors.
4. Wait for the reservoir to mix before reading again.

The schematic or firmware should use **StealthChop2** for dosing. It generates significantly less Electrical Noise (EMI) than the high-torque SpreadCycle mode, which improves EZO-EC data integrity.



---


### 2.3. Capacitors to the Rescue

Switching noise from the TMC2209 drivers and the buck converter spans a wide frequency range — from the fundamental chopping frequency (~20–50 kHz for the steppers, 1 MHz for the buck) up through many harmonics into the tens of MHz. No single capacitor type covers this entire range effectively. The strategy is to use two tiers of decoupling in parallel, each tuned to a different frequency band.

**Medium-frequency bypass (10 µF and 220 µF)**

The bulk electrolytic and ceramic caps from §1.2 serve a double duty here. At medium frequencies (roughly 40 kHz–1 MHz), the large-value caps at the VM pins provide charge locally — within the short trace between cap and load — before the inductance of the supply path has time to cause a voltage dip.

Rail | Place               | Peak Current | Value / Voltage | Dielectric             | Purpose
----:|---------------------|--------------|----------------:|------------------------|--------
 24V | Main power entry    | ~4.7A        |   10µF / 50V    | MLCC X7R[^2]           | MF bypass
 24V | Each TMC2209 VM pin | ~1.5A        |  220µF / 50V    | Aluminium Electrolytic | MF bypass
 24V | Main Pump MOSFET    | ~1.2A        |  220µF / 50V    | Aluminium Electrolytic | MF bypass
  5V | Buck output         | ~0.75A       |   10µF / 10V    | MLCC X7R[^3]           | MF bypass

[^2]: e.g. Murata GRM31CR61H106KA12L (SMD Comm X7R). DC bias derating is better for 1206 package.
[^3]: e.g. Murata GRM21BR61C106KE15L. Use 0805 package.

Note: the Benewake TF-Luna LiDAR includes a 100 nF capacitor to debounce signals and prevent EMI-induced false triggers on the safety interlock lines.

**High-frequency bypass (100 nF and 10 nF)**

Above 1 MHz, the large electrolytics become inductive and stop helping. Small ceramic caps take over. A bypass cap is effective from the frequency at which its capacitive reactance drops to a few ohms, up to its self-resonant frequency[^MURATASRF] $f_{sr}$ — beyond the $f_{sr}$ it becomes inductive.

The effective bypass range follows as:

$$
    \begin{align}
        \Rightarrow f_{\rm{bypass}} &= \frac{1}{10\pi  C} \ \cdots\  f_{\rm{sr}}
    \end{align}
$$

Applying this to the selected Murata parts[^MURATASIMSURF]:
- **100nF 0603** X7R[^100NF0603]: effective ~300 kHz to 24 MHz — covers the HF switching harmonics.
- **10nF 0603** X7R[^10NF0603]: effective ~3 MHz to 69 MHz — covers the VHF end.
- **10nF 0402** X7R[^10NF0402]: effective ~3 MHz to 89 MHz — slightly wider due to lower parasitic inductance $L_s$.



Rail | C     | Type | Voltage  | Package | f<sub>sr</sub> | R<sub>s</sub> | L<sub>s</sub> | Purpose
----:|-------|------|----------|---------|-------|--------|-------|-----------
 24V | 100nF | X7R  |     50V  | 0603    | 23MHz | 0.04mΩ | 480pH | HF bypass
  5V | 100nF | X7R  |     50V  | 0603    | 23MHz | 0.04mΩ | 480pH | HF bypass per IC
3.3V | 100nF | X7R  |     50V  | 0603    | 23MHz | 0.04mΩ | 480pH | HF bypass per IC
3.3V |  10nF | X7R  |    100V  | 0603    | 68MHz | 0.08mΩ | 545pH | VHF bypass for sensitive pins
3.3V |  10nF (alt.) | X7R  | 50V | 0402  | 89MHz | 0.06mΩ | 318pH | VHF bypass for sensitive pins

[^MURATASRF]: [Murata: "What are impedance/ESR frequency characteristics in capacitors?"](https://article.murata.com/en-eu/article/impedance-esr-frequency-characteristics-in-capacitors)
[^MURATASIMSURF]: [Murata SimSurfing Design Support Tool](https://www.murata.com/en-us/tool/simsurfing)
[^100NF0603]: Murata GRM188R72A104KA35D
[^10NF0603]: Murata GRM188R72A103KA01J
[^10NF0402]: Murata GRM155R71H103KA88D

A few notes on part selection:
- Use **X7R** dielectric, not X5R. X7R holds capacitance well across temperature (−55°C to +125°C, ±15%); X5R degrades more with temperature and DC bias.
- Smaller package means lower parasitic inductance (ESL) and a higher $f_{res}$. 0603 strikes the best balance for this design — lower ESL than 0805, and more practical to hand-solder than 0402.

**Unknown???**
Regarding the the 3.3V rail: what if the 100nF be in its inductive region (>23MHz), while the 10nF is in its capacitive region (<89MHz). Do you get resonance / ringing?  Would it be better to just use two 100nF caps instead?  Or, reduce the $Q$-factor (indicating of how good it is at resonating) by choosing a higher $R_s$?
$$
    Q = \frac{1}{R_s} \sqrt{\frac{L_s}{C}}
$$

**Placement**

A bypass cap only works if it is close to the load. Long traces add inductance that shifts the $f_{res}$ down and reduces effectiveness. Place caps in this priority order:

Capacitor value  | Maximum distance from IC
-----------------|--------------------------
10 nF ceramics   | 2 mm
100 nF ceramics  | 5 mm
10–22 µF ceramics| 10 mm
Electrolytics    | 20 mm

For additional high-frequency rejection, add **ferrite beads** on power inputs to the most sensitive ICs (see §3.1 for the ADM3260 pi-filter).


### 2.4. PCB Layout Strategy

At 1.0A RMS, the TMC2209 drivers generate only one quarter of the heat compared to their 2.0A limit.
- **A "Thermal Chimney":** Use a large GND plane on the bottom layer as a heatsink. Use a 4×4 array of 16 thermal vias, 0.3mm diameter, spaced 1mm apart under the TMC2209 center pad connecting to the GND plane to pull heat away.
- **EMI Shielding:** By keeping high-speed switching (stepper drivers) **on the bottom** (L4) and sensitive logic on the top (L1), the internal Ground and Power planes act as a Faraday shield, preventing motor noise from "leaking" into the pH and EC readings. 


---


## 3. Maintaining Signal Integrity via Isolation

Water is conductive, so multiple probes immersed in the same reservoir can form **ground loops** — small currents that circulate between probes through the solution and distort their readings. The problem has an additional wrinkle: the isolation chip chosen to break those loops (the ADM3260) is itself a switching converter that generates its own high-frequency noise. The mitigation strategy therefore has three layers:

- **Isolation circuit:** The ADM3260 provides galvanic isolation on both the I2C signals and the power supply, inserting a physical air gap into every ground path between probes.
- **Physical distance:** The PCB layout separates noisy circuits (stepper drivers, buck converter) from quiet ones (EZO circuits, BNC connectors) to minimise conducted and radiated coupling.


---


### 3.1. Isolation Circuit (ADM3260)

**Circuit**

The Typical Application Diagram in Fig. 20 of the [ADM3260 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/adm3260.pdf) and [UG-724](https://www.analog.com/media/en/technical-documentation/user-guides/EVAL-ADM3260MEBZ_UG-724.pdf) show a typical Isolated I2C Interface using the ADM3260. The design follows their recommendations[^MOREAMD3260] :

[^MOREAMD3260]: See also, Analog Devices ADM3260 Datasheet: The definitive source for "Layout Guidelines" and "EMI Considerations" (See pages 16-18); Atlas Scientific USB Isolator Schematic: Their public hardware documentation shows the ADM3260 implementation for I2C isolation; AN-0971 Application Note: "Recommendations for Control of Radiated Emissions with isoPower Devices."

>The ADM3260 uses an internal isoPower transformer switching at ~180MHz, it can cause the "Island" to act like a radio antenna.

Although disabling the stepper motors eliminates external EMI, the ADM3260 itself is a switching power supply. A pi-filter at the V_ISO ensures that the internal noise of the isolation chip itself does not "leak" into the high-impedance analog front-end of the pH and EC circuits. 

![Isolation-Circuit Schematic](../media/schematics/Isolation-Circuit.svg)

**Part Selection**

Reference       | Specs                           | Manufacturer / Details      | Package
----------------|---------------------------------|-----------------------------|--------
U               | 2.5kV, I2C isolator              | Analog Devices ADM3260ARSZ  | 20-SSOP
FB              | R<sub>DC</sub>=20mΩ Z=60Ω(100MHz), ferrite bead | TDK MPZ-series MPZ1608S600ATDH5 | 0603
C<sub>b</sub>   | 10μF ±10% / 16V cer. X5R        | Murata GRM-series           | 0805  
C<sub>mf</sub>  | 100nF 10% / 100V, cer. X7R      | Murata GRM-series           | 0603
C<sub>hf</sub>  | 10nF 10% / 110V cer. X7R        | Murata GRM-series           | 0603
R<sub>t</sub>   | 16.9kΩ ±1% / 1/8W (calc. below) | Yageo RC_L-series           | 0805
R<sub>b</sub>   | 10kΩ ±1% / 1/8W (calc. below)   | Yageo RC_L-series           | 0805
R<sub>up</sub>  | 2.2kΩ ±1% / 1/8W (calc. below)  | Yageo RC_L-series           | 0805

**Engineering Notes**

- **V<sub>SEL</sub>** sets the isolated output voltage V<sub>ISO</sub>. For V<sub>ISO</sub>=3.3V, create a voltage divider so that V<sub>SEL</sub> matches the 1.25V reference voltage: 
$$
  \begin{align}
    V_{SEL} &= V_{ISO} \cdot \frac{\rm{R_{l}}}{\rm{R_{l}}+\rm{R_{h}}}
    \\
    & = 3.3\rm{\,V} \cdot \frac{10\,kΩ}{10\,kΩ+16.9\,kΩ} \approx 1.25\rm{V} \nonumber
  \end{align}
$$
- **I2C pullups** are required on the isolated side, just like the main side. A "stiff" 2.2kΩ here is better for fighting the noise. Use ±1% tolerance resistors to ensure the I2C rise times are identical on SDA and SCL.
- **Bypass capacitors** are mandatory for the device to function correctly and provide stable isolated power.
  - for 10 nF: place cap within 1 or 2 mm of the pins
  - for 100 nF: place cap within 1 or 2 mm of the pins
- For caps and resistors, follow the **footprint** from Fig. 23 in the [Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/adm3260.pdf).
- The signal **`EZO_PDIS`** is intended for powering down sensors between long monitoring intervals. Power to the sensors need to be restored and stabilized well before the measurement is taken.[^FAULTRECOVERY] 
- The **Ferrite beads** may help mitigate the Electromagnetic Interference (EMI). The bead surrounded by capacitors on both sides forms a π-Filter. 
- Limit the effect of the **floating isolated groundplane** by using the **"Stitching Capacitance" trick**: achieved by overlapping internal PCB layers or using a dedicated Y-rated capacitor. Extend GND<sub>P</sub> and GND<sub>ISO</sub> on separate inner layers into the moat. The capacitive coupling of the structure is calculated with the following basic relationships for parallel plate capacitors:[^A-0971]
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
- To reduce edge radiation, consider using a **Via Fence and Guard Ring**.[^A-0971]

[^FAULTRECOVERY]: It can also be used for fault recovery: pulse HIGH 100ms then LOW; wait ≥1.2s before sending I2C commands.
[^BLM18]: Murata EMI Guide: Recommends the BLM18 series ferrite beads for suppressing high-frequency noise in isolated DC/DC converters.
[^A-0971]: [A-0971](https://www.analog.com/en/resources/app-notes/an-0971.html)

---


### 3.2. Physical distance

After isolation and bypass capacitors, physical separation is the most effective remaining tool against EMI. The board is divided into four zones, arranged so that the noisiest circuits are as far as possible from the most sensitive ones. The gold standard for this kind of multi-EZO layout is the [Atlas Scientific i4 InterLink](https://files.atlas-scientific.com/i4-interlink-datasheet.pdf) and the [Whitebox Labs T3 schematics](https://github.com/whitebox-labs/tentacle-raspi-oshw).

**Zone A — Power Entry (board edge)**
The DC jack, fuse, reverse-polarity protection, TVS diode, and main bulk capacitor sit at the board edge. Placing these components here means transients and inrush current are absorbed before they can propagate into the rest of the board.

**Zone B — High-Power Drive (bottom half)**
The three TMC2209 drivers, their local bulk caps, and the main pump MOSFET sit on the bottom half of the board. Keep the 24V VM traces on L4 so the L2 ground plane acts as an EMI shield between the stepper switching and the signal layer above. The L2 plane also serves as a heatsink for the driver die pads.

**Zone C — Digital Logic (top centre)**
The ESP32, LiDAR header, 5V/3.3V regulators, and EZO-RTD circuit sit in the top centre. Route I2C and UART on L1 (Top), where they are shielded from the stepper zone below by the L2 ground plane. The EZO-RTD does not need galvanic isolation because the PT-1000 is a passive resistive element with no electrochemical potential.

**Zone D — Isolated Islands (top corners)**
The two ADM3260 chips, EZO-pH and EZO-EC sockets, and BNC connectors sit in the top corners, as far from Zone B as the board allows. These islands have zero tolerance for conducted noise — the isolation moat is the only permitted electrical path between mainland and island.

**The isolation moat**
Think of each ADM3260 as a bridge spanning a moat. The mainland and the island are electrically connected only through the silicon of the chip itself — no copper of any kind may cross the moat on any layer. Make the moat at least 6 mm wide to satisfy both the 2.5 kV creepage requirement and the practical hazards of hand soldering (solder splash, condensation).

Below is how the layers should be carved to maintain 2.5kV isolation:

Layer       | Mainland               | The Moat                  | The Island (pH or EC)
------------|------------------------|---------------------------|----------------------
L1 (Top)    | ESP32, LiDAR           | No Copper                 | EZO Socket, BNC
L2 (GND)    | Solid Main GND Plane   | Stitching Cap[^STITCHCAP] | Floating GND_ISO
L3 (PWR)    | 3.3V / 5V / 24V Planes | Stitching Cap             | Floating V_ISO (3.3V)
L4 (Bottom) | Steppers and glue      | No Copper                 | (Keep empty for signal)


[^STITCHCAP]: See the next paragraph.


---


## 4. Reservoir Level Circuits

Tight water level control is about chemical stability. A LiDAR circuit measures the water level, so that the firmware can add water to the reservoir when needed.  Two Float Switches function as alarms if the firmware fails to refill the reservoir.


### 4.1. LiDAR Circuit

**Circuit**

The circuit follows the guidance from the [LiDAR Datasheet](https://github.com/May-DFRobot/DFRobot/blob/master/TF-Luna%20LiDAR%EF%BC%888m%EF%BC%89%20Datasheet.pdf).

![LiDAR Schematic](../media/schematics/LiDAR.svg)

**Part Selection**

Reference     | Specs                                    | Manufacturer / Details | Package
--------------|------------------------------------------|------------------------|--------
C<sub>b</sub> | 100μF ±20% / 10V, ESR=24mΩ, elec.        | Kemet A750-series      | Radial
HDR           | 6-pin Molex 1.25mm, R/A header           | Molex PicoBlade-51021-series 0532610671 [^LiDARCONN]
PLG housing   | 6-pin Molex 1.25mm, plug housing         | Molex PicoBlade-51021-series 0510210600
PLG contacts  | (6×) 26-28AWG Molex 1.25mm, plug contact | Molex PicoBlade-50079-series 0500798000

[^LiDARCONN]: See [RobotShop Community](https://community.robotshop.com/forum/t/whats-the-electrical-connector-on-the-tf-luna-lidar-sensor/99629)


**Engineering notes**

- Connector pin assignments: VCC, RX/SDA, TX/SCL, GND, Config, (unconnected for UART; GND for I2C), Data Ready (I2C mode).


---


### 4.2. Float Switches

The two float switches use opposite pull directions so that both GPIO signals are *active-HIGH when their cutoff condition is triggered* — consistent logic for both software and the hardware NPN cutoff transistors.

**Circuit**

![Float Switches Schematic](../media/schematics/Float-Switches.svg)

**Part Selection**

Reference | Specs                                     | Manufacturer / Details | Package
----------|-------------------------------------------|------------------------|---------
J         | 4-pin 3.5mm, side-entry screw terminal    | Same Sky TB0011-350-series 2223-TB0011-350-04BE-ND
R         | (2×) 10kΩ ±1% / 1/8W                      | Yageo RC_L-series      | 0805 
C         | (2×) 100nF ±10% / 100V, cer. X7R          | Murata GRM-series      | 0603

**Engineering notes**

- Connector pin assignments: 3V3, high-level float, low level float, GND
- Mount both float switches with the hinge DOWN.
    - When water rises to the switch, the float arm lifts → magnet nears the reed switch → circuit closes.
    - When water drops below the switch, the float arm falls → magnet nears the reed switch → circuit opens.


---


## 5. Main Pump and ATO Solenoid Drivers

The main pump runs continuously to circulate the nutrient film, while the ATO valve fires only on demand to top off the reservoir. Both use the same 24V rail and the same N-channel MOSFET driver circuit, and both include a hardware safety interlock — an NPN transistor wired to the relevant float switch — that pulls the MOSFET gate to ground regardless of ESP32 state. Use 20 AWG or 22 AWG wire for the individual runs; the 1.2A–1.5A loads are well within their rating.

**Main pump installation**

The SHYSKY DC40F-2460 is a brushless pump with internal motor electronics. It must be fully primed before running and requires a short initialization sequence at power-on.

- Mount the pump vertically or horizontally — not inverted. Ensure it is fully submerged before switching power on; the brushless motor is not designed to run dry.
- Add an inline strainer upstream of the pump to prevent debris from reaching the impeller.
- The pump accepts PWM speed control on its 24V supply line. Allow a 10–15 second delay in firmware at power-on for the internal motor controller to initialize before applying PWM commands. Test the minimum stable duty cycle on your specific unit — below roughly 30–40% most brushless pumps stall.

**ATO valve installation**

The DIGITEN solenoid valve is a standard 2-wire device — polarity does not matter for DC operation. Check the arrow cast into the valve body and install it in the correct flow direction.

- Seal NPT threads with Teflon tape or pipe dope before tightening.
- Mount the valve with its coil oriented vertically, so any condensation inside the coil housing drains out rather than pooling around the windings.
- Install an inline manual shutoff valve upstream so the ATO line can be isolated without draining the supply plumbing.
- Configure a firmware timeout on the valve open command. If both float switches fail simultaneously, the timeout is the last line of defence against flooding.


---


### 5.1. Main Pump Driver

The main pump supports PWM speed control via the 24V power input.

The float switch drives a small NPN transistor that directly clamps the MOSFET gate to GND when the cutoff condition fires. This is independent of firmware — the pump shuts down in hardware even if the ESP32 is hung or misbehaving.

**Circuit**

![Main Pump Circuit](../media/schematics/Main-Pump.svg)

**Part Selection**

Reference       | Specs                                        | Manufacturer / Details | Package
----------------|----------------------------------------------|------------------------|--------
N-CH            | 55V / 42A, N-CH MOSFET                       | Infineon HEXFET-series IRLR2905TRPBF | DPAK
NPN             | 40V / 0.2A, NPN transistor                   | Onsemi MMBT3904LT1G    | SOT-23-3
D               | 40V / 3A, Schottky diode                     | Onsemi SS34            | DO-214AB
R<sub>g</sub>   | 100Ω ±1% / 1/8W                              | Yageo RC_L-series      | 0805
R<sub>b</sub>   | 4.7kΩ ±1% / 1/8W                             | Yageo RC_L-series      | 0805
R<sub>h</sub>   | 10kΩ ±1% / 1/8W                              | Yageo RC_L-series      | 0805
C<sub>mf</sub>  | 100nF ±10% / 100V, X7R                       | Murata GRM-series      | 0603
C<sub>b</sub>   | 220µF ±20% / 50V, elec. ESR=22mΩ  (see §1.2) | Kemet ESY-series       | Radial
HDR             | 2-pos MC 0.2", R/A header                    | Phoenix Contact MC-series 1836189 |
PLG             | 2-pos MC 0.2", plug                          | Phoenix Contact MC-series 1836079 |

**Engineering Notes**

- Connector pin assignments: 24V, switched GND
- Header chosen to avoid compatibility with 24V PSU header.
- The IRLR3636 remains a valid drop-in efficiency upgrade if desired.
- R<sub>up</sub> ensures the motor stays on during ESP32 reset.
- C<sub>b</sub> for bulk over the 24V rails to help with inrush, which for a 200mA solenoid is modest — maybe 600mA for 1–2ms.
- R<sub>g</sub> helps manage the inrush current to the MOSFET's gate capacitor. This protects the ESP32-C6 while allowing for the fast switching speeds required for PWM speed control.

**Firmware Suggestions**

- Minimum: ~30-40% duty recommended to prevent stall.
- Frequency: 25 kHz (above audible range, smooth motor control)


---


### 5.2. ATO Valve Driver

**Circuit**

![ATO Valve Circuit](../media/schematics/ATO-Valve.svg)

**Part Selection**

Reference       | Specs                            | Manufacturer / Details | Package
----------------|----------------------------------|------------------------|--------
N-CH            | 30V / 5.7A, N-CH MOSFET          | Alpha & Omega AO3400A  | SOT-23-3
NPN             | 40V / 0.2A, NPN transistor       | Onsemi MMBT3904LT1G    | SOT-23-3
D               | 40V 3A Schottky Diode            | Onsemi SS34            | DO-214AB
R<sub>g</sub>   | 100Ω ±1% / 1/8W                  | Yageo RC_L-series      | 0805  
R<sub>b</sub>   | 4.7kΩ ±1% / 1/8W                 | Yageo RC_L-series      | 0805
R<sub>l</sub>   | 10kΩ ±1% / 1/8W                  | Yageo RC_L-series      | 0805
C<sub>mf</sub>  | 100nF ±10% / 100V, cer. X7R      | Murata GRM-series      | 0603
C<sub>b</sub>   | 47µF ±20% / 50V, elec. ESR=150mΩ | KEMET ESY-series       | Radial
HDR             | 2-pos MC 0.2" R/A header         | Phoenix Contact MC-series 1836189 |
PLG             | 2-pos MC 0.2" plug               | Phoenix Contact MC-series 1836079 |

**Engineering notes**
- Header chosen to avoid compatibility with 24V PSU header.
- Header pins: 24V, switched GND


---


## 6. ESP32-C6, UART and I2C

The ESP32-C6 is the controller. It drives the three stepper drivers over UART, controls the pump and valve MOSFETs via GPIO, reads all sensors over I2C, and communicates with Home Assistant over Wi-Fi. The DevKit module is used rather than a bare chip to avoid designing the antenna, USB-C bridge, and power regulation onto the carrier board.

The ESP32-C6-DevKitC-1-N8 mounts to the carrier PCB via 2×20 pin headers. USB-C, boot/reset buttons, antenna, RGB LED (WS2812B) and power regulation are on the DevKit.

**Circuit**

![ESP32-C6 Circuit](../media/schematics/ESP32-C6.svg)


**Part Selection**

Reference       | Specs                         | Manufacturer / Details                  | Package
----------------|-------------------------------|-----------------------------------------|--------
M*              | ESP32-C6 Development Board    | Espressif Systems ESP32-C6-DEVKITC-1-N8 |
R<sub>h</sub>   | (2×) 2.2kΩ ±1% 1/8W (see I2C) | Yageo RC_L-series                       | 0805
R<sub>tx</sub>  | (2×) 1kΩ ±1% 1/8W (see below) | Yageo RC_L-series                       | 0805

**Engineering Notes**

- Power/reset pins:
   - `3V3` — Regulated power out. Not needed → Leave unconnected.
   - `~RST` — Reset input (internal pull-up). → Leave unconnected.

- The ESP32-C6 chip provides for JTAG debugging using the following pins:
    - `GPIO4` — Ensure no low-impedance devices pull it low during startup to avoid booting issues. → Used as bidirectional I2C pin.
    - `GPIO5` — Ensure no low-impedance devices pull it low during startup to avoid booting issues. → Used as bidirectional I2C pin.

- The chip allows for configuring boot parameters through strapping pins. At Chip Reset, latches the values:
    - `GPIO8` — Controls the boot mode. It is also used for the on-board RGB LED. → Do not connect to an external load.
    - `GPIO9` — Controls the boot mode. Ensure no low-impedance devices pull it low during startup to avoid booting issues.
    - `GPIO15` — Controls peripheral voltage or JTAG. Ensure no low-impedance devices pull it low during startup to avoid booting issues. → Used as output.

- USB-C ports:
    - `GPIO16` — Connects UART0 TX to the CP2102N USB-UART Bridge RX (reserved). UART0 may transmit ROM boot messages and other serial data. → Leave unconnected.
    - `GPIO17` — Connects CP2102N USB-UART Bridge TX to UART0 RX (reserved). Any external connection would fight the CP2102N output. → Leave unconnected. 
    - `GPIO12`/`GPIO13` — USB `D−`/`D+` (reserved). These pins are used for Serial logging, code upload, JTAG. → Leave unconnected.

- General Purpose I/O pins with no restrictions:
    - `GPIO0` → Used as input.
    - `GPIO1` → Used as input.
    - `GPIO2` → Used as output.
    - `GPIO3` → Not used.
    - `GPIO6` → Used as output.
    - `GPIO7` → Not used.
    - `GPIO10` → Used as output.
    - `GPIO11` → Used as output.
    - `GPIO18` → Not used.
    - `GPIO19` → Used as output.
    - `GPIO20` → Used as output.
    - `GPIO21` → Used as input. See §6.1.
    - `GPIO22` → Used as tri-state output. See §6.1.
    - `GPIO23` → Not used.


---

### 6.1. UART Single Wire Bus

The TMC2209 supports a single-wire UART interface that shares the transmit and receive lines, similar to an RS-485 half-duplex bus. This allows full bidirectional control and diagnostics over a single signal.

The bus is shared between all three stepper drivers, with one driver addressed at a time. Each driver's address is set using its `AD0` and `AD1` pins. These addresses are assigned using the `AD0` and `AD1` pins.

**Engineering Notes**

- The ESP32-C6 `TX1` pin is connected to the bus through a 1kΩ resistor, while the `RX1` pin is connected directly. This limits the fault current that might occur, when ESP32 `TX1` drives HIGH to send a command, and the TMC2209's open-drain output momentarily pulls the bus LOW to begin its response (a brief overlap before software tri-states TX) → A low-impedance **conflict** occurs. The 1kΩ resistor then limits the fault current to a safe level of 3.3V / 1kΩ = 3.3 mA. 

- Along the same lines: the firmware should configure ESP32 UART1 in **half-duplex / single-wire mode**, so `TX1` is tri-stated during the receive window. The TMC2209 then pulls the bus LOW open-drain to transmit its response, with no conflict from TX.

- The firmware should set **`SENDDELAY` to ≥2** for all nodes. Otherwise, a non-addressed node might detect a transmission error upon read access to a different node. 


---


### 6.2. I2C Bus

All digital sensors communicate over I2C. The bus runs at 3.3V and is shared between the EZO circuits (via their ADM3260 isolation islands), the LiDAR, and the optional expansion sensors. The default I2C addresses are:

Device  | Function                           | Address
--------|------------------------------------|--------
EZO-pH  | pH Probe                           | 0x63
EZO-EC  | Electrical Conductivity Probe      | 0x64
EZO-RTD | Water Temperature Probe            | 0x66
BME280  | Outside Air Temp / Humidity Sensor | 0x76 / 0x77
BH1750  | Light Sensor                       | 0x23 / 0x5C
SSD1306 | OLED Display                       | 0x3C / 0x3D

To **fix noisy** SDA/SCL lines, use one or more of these methods:[^I2CNOISE]
- **Strengthen Pull-ups:** Use lower resistance values (instead of 10kΩ) to increase current and ensure the signal reaches a logic high quickly, especially with high bus capacitance. → Use 2.2kΩ pull-ups.
- **Series Resistors:** Place a small (100 to 300Ω) resistor in series with the SDA/SCL lines to reduce ringing and improve RF noise immunity. The resistor along with the pin capacitance forms a low pass filter and filters out any high frequency signals which may get coupled to the I2C lines.
- **Proper Decoupling:** Use 0.1µF capacitors to ground for the power supply (VDD to GND) of the ICs. 
- **Physical Layout:** Keep I2C traces short and separated from noise sources.
- **Shunt Capacitors:** Place small capacitors (10 - 50pF) on the SDA and SCL lines to ground to create a low-pass filter, reducing high-frequency noise.

[^I2CNOISE]: [I2C Design Mathematics: Capacitance and Resistance](https://www.allaboutcircuits.com/technical-articles/i2c-design-mathematics-capacitance-and-resistance/#:~:text=The%20NXP%20specification%20states%20that,cases%20the%20effect%20is%20negligible.)


---


### 6.3. Optional I2C Sensors

Included are two I2C headers for future expansion with e.g. a air temp/humidity sensor (BME280), light sensor (BH1750) or OLED display (SSD1306).

#### Circuit

![Optional I2C Circuits](../media/schematics/Optional-I2C.svg)

**Part Selection**

Reference       | Specs                                 | Manufacturer / Details       | Package
----------------|---------------------------------------|------------------------------|--------
C<sub>mf</sub>  | 100nF ±10% / 100V, cer. X7R           | Murata GRM-series            | 0603
C<sub>b</sub>   | 10µF ±10% / 16V cer. X5R              | Murata GRM-series            | 0805
HDR             | 2A / 100V 4-Pos PH, R/A header        | JST PH-Series S4B-PH-K-S     |
PLG housing     | 2A / 100V 4-Pos PH, housing           | JST PH-Series PHR-4          |
PLG contacts    | (4×) 24-30AWG / 2A / 100V PH, contact | JST PH-Series SPH-002T-P0.5S |

**Engineering Notes**

- There is no standard for I2C connectors. Follow the Grove (Seeed Studio) or STEMMA (Adafruit) pinout convention.
- Connector pin assignments: GND, VCC, SCL, SDA


---


## 7. EZO Circuits and Calibration

Atlas Scientific EZO circuits are modules designed to interface with and process data from specific sensors, such as pH, Electrical Conductivity (EC), and Temperature (RTD). They serve as the bridge between raw probe signals and the microcontroller, converting electrochemical potentials into digital data.

### 7.1. EZO Circuits

### 7.1.1. pH Level

In a mineral-heavy reservoir, ground loops are the hidden enemy of probe accuracy. Because water is conductive, multiple probes (pH, EC) in the same tank each develop their own electrochemical potential relative to the nutrient solution. When multiple probes share a common reference ground, small currents circulate between them, biasing readings.

The pH Probe connects to a dedicated electrical isolation circuit.

**Circuit**

![EZO pH Circuit](../media/schematics/EZO-pH-EC.svg)

**Part Selection**

Reference | Specs                                         | Manufacturer / Details    | Package
----------|-----------------------------------------------|---------------------------|--------
M         | EZO Evaluation Expansion Board for pH Circuit | Atlas Scientific EZO-PH   |
J         | BNC Jack, 50Ω panel mount R/A                 | TE Connectivity 5227161-6 |


### 7.1.2. Electrical Conductivity

**Circuit**

Like the pH probe, the Electrical Conductivity probe connects to a dedicated electrical isolation circuit.

![EZO EC Circuit](../media/schematics/EZO-pH-EC.svg)

**Part Selection**

Reference | Specs                                         | Manufacturer / Details    | Package
----------|-----------------------------------------------|---------------------------|--------
M         | EZO Evaluation Expansion Board for EC Circuit | Atlas Scientific EZO-EC   |
J         | BNC Jack, 50Ω panel mount R/A                 | TE Connectivity 5227161-6 |


### 7.1.3. Temperature

The PT-1000 temperature probe is immune to the electrical noise that affects electrochemical probes, meaning it does not require the same isolation strategy as the pH and EC sensors.

**Circuit**

![EZO RTD Circuit](../media/schematics/Water-Temperature.svg)

**Part Selection**

Reference | Specs                                          | Manufacturer / Details    | Package
----------|------------------------------------------------|---------------------------|--------
M         | EZO Evaluation Expansion Board for RTD Circuit | Atlas Scientific EZO-RTD  |
J         | BNC Jack, 50Ω panel mount R/A                  | TE Connectivity 5227161-6 |


---


### 7.2. Temperature Effect on Sensors

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

    // EZO circuits will now automatically compensates all readings
}
```

Recommendation:
- Update the temperature `T,%.1f` every measurement cycle,
- or at least when temp changes >0.5°C (power saving)


---


### 7.3. Switching to I2C Mode

EZO circuits ship in **UART mode** (green LED). They must be switched to **I2C mode** (blue LED) before connecting to OPNhydro. This is done by briefly shorting `TX/SCL` to `PGND` at power-on.[^ATLASI2C]

1. Place the EZO on a breadboard.
2. Connect `VCC` to 3V3.
3. Disconnect `GND` (power off the EZO circuit).
4. Disconnect `RX/SDA` and `TX/SCL` from the microcontroller.
5. Connect `TX/SCL` to `PGND` using a jumper wire.
6. Connect `GND` (power on).
7. Wait for LED to change from Green → Blue (~2 seconds). This also resets the I2C address.
8. Disconnect `GND` (power off).
9. Remove the jumper wire.
10. Mount the EZO on the carrier PCB.

[^ATLASI2C]: From Atlas Scientific EZO pH datasheet, p.37


---


## 8. Hand-Soldering

This board has two properties that make hand-soldering more demanding than a typical PCB. First, the 4-layer stackup uses solid copper planes on L2 and L3 that act as heat sinks — a standard iron tip loses heat rapidly and produces cold joints unless the design includes thermal reliefs. Second, the isolation moats around the ADM3260 islands must survive the physical hazards of hand assembly: solder splash, iron slippage, and tall component bodies near fine-pitch pads. The design guidelines in §3.2 already set the moat widths for this; the rules below translate those requirements into concrete PCB design settings and soldering technique.


### 8.1. PCB Design for Hand-Soldering

These settings should be applied in your PCB layout tool before generating Gerbers.

**Thermal reliefs**

Enable thermal relief spokes on all ground-connected through-hole and SMD pads. Without them, the L2 ground plane will sink heat faster than a standard iron tip can supply it, producing cold joints on every ground pin. Most tools default to thermal reliefs for through-hole pads but not SMD — check both.

**Component placement rules**

- **Electrolytic capacitors:** Place tall electrolytics near the board edges, away from the center. A tall cap close to a fine-pitch IC blocks the iron angle needed for drag-soldering.
- **ADM3260 clearance:** Leave at least 3 mm of horizontal clearance between the ADM3260 SSOP-20 pins and any neighbouring 1206 capacitors. A cap placed directly in front of the pins prevents the iron from lying flat enough to drag across them.
- **BNC connectors:** Use through-hole BNC connectors for the pH, EC, and RTD probe connections. Surface-mount BNCs pull off the board if a probe cable is tugged. Keep the moat boundary at least 2 mm from any BNC pad to prevent a solder blob from bridging across the isolation gap.

**Isolation moat DRC settings**

In a humid reservoir environment, moisture on the board surface can cause "tracking" — a small leakage current that creeps across the surface between conductors. The moat widths below are wider than the theoretical minimum for 2.5 kV isolation, specifically to survive a solder splash or a drop of condensation.

Parameter            | Hand-Solder Value
---------------------|------------------
Track to Track       | 8 mils (0.2 mm)
Track to Pad         | 8 mils (0.2 mm)
Moat (Isolation Gap) | 250 mils (6.35 mm)
Minimum Via Drill    | 12 mils (0.3 mm)
Via Pad Diameter     | 24 mils (0.6 mm)

- Set the copper-to-board-edge clearance to **1 mm** to prevent the V-cut or router bit from smearing copper across the isolation boundary during fabrication.
- Set the solder mask expansion to **0.05 mm** to keep the mask as close to the SSOP-20 pads as possible and reduce the risk of solder bridging across the 0.65 mm pitch.
- Add a **Route Keep-Out** zone over every moat. This prevents an auto-router from routing a signal across the isolation gap.

**Pre-Gerber moat checks**

Before exporting Gerbers, run these three checks manually in your PCB tool:

1. **Copper check:** Turn off all layers except L2 (GND) and L3 (PWR). The moat region must be completely empty — no traces, no vias, no copper pours, no text.
2. **Stitching check:** Confirm that the mainland GND pour (L2) and the isolated GND pour overlap slightly on different layers to form the stitching capacitance (see §3.3). Verify the two pours are separated by the board substrate, not connected.
3. **Silkscreen labels:** Label each isolated island on the silkscreen (e.g., `ISO-PH`, `ISO-EC`). This prevents plugging a non-isolated sensor into an isolated socket during assembly.


### 8.2. Soldering Technique

Solder the board in order from lowest to tallest component. This keeps the work surface flat and prevents tall caps from blocking access to shorter parts nearby.

**General notes**

- Use a **hoof or chisel tip**, not a conical needle tip. Needle tips lack the thermal mass to heat pads quickly on a 4-layer board, and the result is either a cold joint or an overheated IC.
- Apply **tacky flux liberally**. On a 4-layer board, flux is not optional — it prevents bridges on fine-pitch pads and ensures the solder flows onto the pad rather than balling up on the pin.
- Use **0.5 mm solder** or thinner. Thicker solder deposits too much material per touch on small pads.

**Soldering the ADM3260 (SSOP-20, 0.65 mm pitch)**

This is the most demanding component on the board. Use the drag-solder method:

1. Apply a thin layer of tacky flux to all pads on one side before placing the chip.
2. Place the chip and tack one corner pin to align it. Verify alignment under magnification before continuing.
3. Tack the diagonally opposite corner to lock the chip in place.
4. Flood all 10 pins on one side with additional tacky flux.
5. Melt a small amount of solder onto the iron tip — enough to wet the tip but not a large blob.
6. Draw the iron slowly and steadily across all 10 pins in one continuous pass. The flux draws the solder onto the pads and off the solder mask between pins.
7. Inspect under magnification. Wick away any bridges with desoldering braid and reflux if needed.
8. Repeat for the other side.

Magnification is strongly recommended — at minimum a 10× loupe, ideally a stereo microscope or a USB camera. At 0.65 mm pitch, a bridge is difficult to see with the naked eye.


---

## Appendix B: EZO Calibration

Probe calibration is essential to maintain the chemical and thermal stability required for a 50-plant NFT setup. Accuracy is important because the system performs micro-dosing (as little as 0.2 mL of acid in 100L of water), and uncalibrated sensors would cause the PID control loop to become unstable, leading to "pH yo-yoing" or overshooting.

All calibration is performed over I2C by sending ASCII command strings to each circuit's address:
1. Write command string to EZO address. E.g.,  `i2c_write(0x63, "Cal,mid,7")`.
2. Wait ≥300 ms before reading response.
3. Read 1+ bytes from EZO address. The first byte is the status code:
     `1` = success (`*OK`)
     `2` = syntax error
     `254` = still processing (wait longer)
     `255` = no data
4. If `status==254`, wait another 100 ms and retry read

Calibration status can be queried at any time using `Cal,?` → returns `?Cal,<n>` where `n` = number of calibration points stored (`0` = uncalibrated).

#### B.1. pH Level

Calibration solutions needed: pH 4.00, 7.00 and 10.00 buffers.
Order is mandatory: mid → low → high. Starting over with `Cal,mid` clears all stored points.

1. Step 1 — Mid-point (pH 7.00)
   - Place probe in pH 7.00 buffer.
   - Wait for readings to stabilize (~1–2 min).
   - Send:  `Cal,mid,7`
   - Wait:  300 ms
   - Read:  response (should be `*OK`)

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
- Recalibrate every 6–12 months, or when probe response drifts >0.1 pH.

#### B.2. Electro Conductivity

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


#### B.3. Temperature

Calibration reference needed: a known temperature source — boiling water (100.0°C at sea level) is the most practical option.

Single-point calibration. Atlas Scientific recommends recalibrating every 2–3 years.

1. Step 1 — Single-point (100.00°C)
   - Place probe in vigorously boiling water.
   - Wait for readings to stabilize (~1–2 min).
   - Send:  `Cal,100`
   - Wait:  300 ms
   - Read:  response (should be `*OK`)

2. Verify
   - Send `Cal,?`  →  expect `?Cal,1`

Notes:
- Boiling point varies with altitude (~0.34°C per 100 m above sea level). At significant elevation, use a calibrated reference thermometer instead.
- Recalibrate every 2–3 years, or when the probe is replaced.
