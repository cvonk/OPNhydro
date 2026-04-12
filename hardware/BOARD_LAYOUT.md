# Board Layout Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, and follow up to the Schematic Design document. It covers the Printed Circuit Board (PCB) selection and layout rules for **OPNhydro**.

As in the Schematic Design document, the central problem remains **coexistence**.
- **On one side:** a pH probe measuring millivolt-level electrochemical potentials, an EC probe and an ESP32 that needs a clean analog supply. 
- **On the other:** three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve.

After the PCB selection and general layout rules, we'll cover the different sections of the schematic.


## 1. PCB Selection and General Rules

Here is a puzzle. You flip a light switch, and the bulb lights up almost instantly. But if you could tag a single electron at the switch and watch it, you would find it drifting toward the bulb at roughly one meter per hour — the speed of a snail. At that rate it would take days to arrive. So what turned the light on?
Not the electrons. The electromagnetic field did. And once you understand that, PCB layout stops being a set of rules to memorise and starts making intuitive sense.


### 1.1. Field Theory

> "Electromagnetic (EM) field theory based on [Maxwell's equations](https://coertvonk.com/physics/electromagnetism/magnetism/materials-and-maxwells-equations-30453), is the fundamental description of electrical phenomena (fields, waves, radiation)."  -- Dr. Eric Bogatin [^Bogatin] and Kenneth Wyatts[^Wyatts].

[^Bogatin]: https://www.oldfriend.url.tw/article/SI_PI_book/Signal%20and%20Power%20Integrity%20-%20Simplified_2nd_Eric%20Bogatin_Prentice%20Hall%20PTR_2010.pdf
[^Wyatts]: https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now

**Circuit theory**, as we learned as undergrads, is a simplified, low-frequency (<100 kHz) approximation. It assumes that the physical size of components is much smaller than the wavelength of the signal, so we can ignore wave propagation and use simple circuit laws — Ohm's Law, Kirchhoff's laws.

As signal rise times ($dI/dt$) shorten and PCB frequencies increase, these simplifications fail.

**Field theory** is required to account for radiation, retardation, and wave propagation. PCB design shifts from drawing paths for current to designing transmission lines that contain EM fields, manage parasitic inductance and capacitance, and control radiated emissions. Those physics classes about EM fields and transmission lines are no longer reserved for RF engineers — they become practical for anyone designing a fast PCB.


### 1.1.1. From Voltage to Wave

Step by step:

1. **Voltage creates an electric field.** Apply a voltage between the trace and the ground plane. Positive charge accumulates on the trace, negative on the plane. Those separated charges produce an **electric field E** in the dielectric between them (Gauss's law).

2. **The electric field drives current.** The field exerts a force on the free electrons in the copper ($\mathbf{F} = q\mathbf{E}$). They accelerate — a **current** flows. The field is the cause; the current is the effect.

3. **Current creates a magnetic field.** Any moving charge produces a **magnetic field B** curling around it ([Ampere's law](https://coertvonk.com/physics/electromagnetism/magnetism/amperes-law-30007)). The forward current in the trace produces B; the return current in the ground plane produces equal-and-opposite B.

4. **A changing electric field also creates a magnetic field — even without current.** This was [Maxwell's crucial insight](https://coertvonk.com/physics/electromagnetism/magnetism/displacement-current-30269): the *displacement current* term $\mu_0\varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}$. In the FR-4 dielectric — where there are no free electrons — a changing E still produces B.

5. **A changing magnetic field creates an electric field.** [Faraday's law](https://coertvonk.com/physics/electromagnetism/magnetism/electromagnetic-induction-30157): a changing B produces a curling E at the neighbouring point in space.

6. **The two fields sustain each other forward.** Changing E → B (step 4). Changing B → E (step 5). Each regenerates the other, through the dielectric, with no electrons required. That self-sustaining propagation is the electromagnetic wave.

### (1.1.2. The Wave Equation and Propagation Speed)

Faraday's law and Ampere–Maxwell together, in free space (J = 0):

$$
    \nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t} \qquad \nabla \times \mathbf{B} = \mu_0\varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
$$

Taking the curl of the first and substituting the second yields the wave equation:

$$\nabla^2\mathbf{E} = \mu_0\varepsilon_0 \frac{\partial^2 \mathbf{E}}{\partial t^2}$$

Matching to the standard form $\nabla^2 f = \frac{1}{v^2} \frac{\partial^2 f}{\partial t^2}$ gives the propagation speed directly from the constants of nature:

$$c = \frac{1}{\sqrt{\mu_0\varepsilon_0}} \approx 3 \times 10^8 \text{ m/s}$$

Maxwell derived this in 1865 — purely from algebra. The match to the measured speed of light was not a coincidence: light *is* an electromagnetic wave. In FR-4, the higher permittivity $\varepsilon_r$ slows the wave:

$$v_p = \frac{c}{\sqrt{\varepsilon_r}}, \quad \varepsilon_r \approx 4.2 \text{ for FR-4} \quad\Rightarrow\quad v_p \approx 15 \text{ cm/ns}$$

### 1.1.3. Where the Energy Flows — the Poynting Vector

> "Energy and signals travel in the spaces not the traces"  -- Ralph Morrison

The **Poynting vector** tells us where the energy goes:

$$
    \mathbf{S} = \frac{1}{\mu_0}(\mathbf{E} \times \mathbf{B}),\quad \left[ \rm{W/m^2} \right]
$$

It points in the direction of energy flow; its magnitude is the power per unit area crossing any surface. Because it is a cross product, **E**, **B**, and the propagation direction are always mutually perpendicular.

![Courtesy: Patrick André](../media/infographics/microstrip-fields.png)

On a PCB microstrip: **E** points vertically from trace to ground plane, **B** points horizontally curling around the current, so **E × B** points *forward* — through the dielectric between the conductors. The energy is in the space between the trace and the plane, not in the copper.

If you compute **S** inside the copper, it points inward — energy flowing into the metal and converting to heat. That is resistive loss: the small fraction of field energy absorbed by the conductor walls as the wave travels past.

### 1.1.4. What the Conductors Do

The trace and ground plane are not pipes for electrons. They are **walls for the field**.

The electric field originates on the positive charge of the trace and terminates on the negative charge of the ground plane — confined to the dielectric between them. The magnetic fields from the forward current (trace) and the return current (ground plane) are equal and opposite; they cancel at a distance, keeping the energy trapped rather than radiating.

The electrons themselves are in violent thermal motion at roughly $10^6$ m/s. Superimposed on that chaos is a tiny net drift of perhaps a centimetre per second — driven by the electric field of the wave passing through. That drift is what we call current. It is the mechanical response to the field, not what carries the energy. [^FEYNMAN]

[^FEYNMAN]: https://www.feynmanlectures.caltech.edu/II_13.html#:~:text=We%20have%20seen%20that%20there,then%2C%20produce%20a%20magnetic%20field.

- The **field** carries the energy — fast, at a fraction of the speed of light.
- The **electrons** respond to the field — slow; that response is what we call current.
- The **conductor** gives the field a boundary and converts a fraction of the field energy into heat (resistance).

A perfect conductor with zero resistance would still need a return path and would still radiate if the loop area were large. Resistance only determines how much energy is lost as heat — it does not govern whether the field propagates.

### 1.1.5. What This Means for Layout

Remove the ground plane — or cut a slot through it — and the electric field lines have nowhere to terminate. The magnetic field cancellation breaks down. The Poynting vector, which was pointing neatly forward along the trace, now has components pointing outward. That outward energy is EMI.

Every layout rule follows from this:
- Every signal trace needs a return plane directly below it — not because current needs a path home (though it does), but because the field needs a wall on the other side.
- A via that crosses layers needs a ground via alongside it — the field transfers with the signal, and the return field must transfer too.
- A slot in a ground plane is not an inconvenience for return current — it is a gap in the wall that lets the field escape.

The energy is in the fields. The dielectric is the medium. The copper is the boundary condition that keeps it all in place.


---









### 1.2.2. Low EMI Rules

When different signals cross paths in the dielectric they interact and we experience this as interference, cross talk.

If we allow fields from one circuit section A (motor control) to crosscouple with fields from circuit section B (analog) - this will lead to EMI, crosstalk and poor circuit performance.


1. every signal trace needs an adjacent return plane (or trace)
2. Every power trace (or plane) needs an adjacent return path (trace or plane)
3. This includes return paths (vias) up/down through layers


**The typical stackup**

L1 signals
L2 Ground return plane
L3 power plane
L4 signals

This is also very high EMI risk.
- power and gnd are too far separated for good high frequency decoupling. Should be 2-3 mill max.
- signals in layer 4 are ferenced to power, rather than signal return. That is OK, if and only if, the power and return planes are tightly coupled together and with adequate decoupling capacitors.  Still wouldn't recommend it.
power and gnd separed by core distance

**Lower EMI four layer board stack up**

L1 Signals / Routed power
L2 Ground return plane
L3 Ground return plane
L4 Signals / Routed power

Prevent discontinuous signal return paths

Trace passing through two vias layers causes the wave to leak in between the reference planes.  May interfere with other signals in that space, and cause board edge radiation.  If the planes are the same potential, you can prevent this with nearby sticking vias between the ground planes.  If they are different potentials you can add stiching capacitance very close.





Segregating Functional Regions

1. keep analog traces away from motor control and digital sections
2. keep power conversions and motor control near the power entry point
3. all power and i/o connectors should be filtered and transient protected
4. all power and i/o connectors should be grouped together on one edge of the board, if possible for minimum EMI


Zl = 1 / j omega L
Xl = 1 / 2 pi f L

Z = ESR + Xc + Xl
the dip in |Z| is ESR






1. Choose a stack-up
2. Partition circuit functons
3. Layout power plane
4. Place local decoupling caps
5. Route (minimize) clock traces
6. Route data & address
7. Check return paths
8. Route low-speed traces


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

**EMI Considerations**




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


## 2. Power Distribution Network (PDN)


Remember PDN are transmission lines, therefore require adjacent power return planes.  Can use the signal return, for as long as the power and signal don't share the same dielectic space.

Don't use ferrite chokes in the PDN, as we desire a low target impedance  throughout.  The exception might be filters for analog, RF or PLL circuits. 


---

## 3. I2C Sensors

---

## 4. Peristaltic Pump Drivers

---

## 5. Main Pump and Valve Drivers

---

## 6. Water Level Sensor and Switches

---

## 7. SoC, Test Points and Ficucials




i