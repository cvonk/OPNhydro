# Board Layout Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, and follow up to the Schematic Design document. It covers the Printed Circuit Board (PCB) selection and layout rules for **OPNhydro**.

As in the Schematic Design document, the central problem remains **coexistence**.
- On one side: a pH probe measuring millivolt-level electrochemical potentials, an EC probe and an ESP32 that needs a clean analog supply. 
- On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve.

After the PCB selection and general layout rules, we'll cover the different sections of the schematic.


## 1. PCB Selection and General Rules

Here is a puzzle. You flip a light switch, and the bulb lights up almost instantly. But if you could tag a single electron at the switch and watch it, you would find it drifting toward the bulb at roughly one metre per hour — the speed of a snail. At that rate it would take days to arrive. So what turned the light on?

Not the electrons. The electromagnetic field did. And once you understand that, PCB layout stops being a set of rules to memorise and starts making intuitive sense.


### 1.1. Field Theory

> "Electromagnetic (EM) field theory based on [Maxwell's equations](https://coertvonk.com/physics/electromagnetism/magnetism/materials-and-maxwells-equations-30453), is the fundamental description of electrical phenomena (fields, waves, radiation)."  -- Dr. Eric Bogatin [^Bogatin] and Kenneth Wyatts[^Wyatts].

[^Bogatin]: https://www.oldfriend.url.tw/article/SI_PI_book/Signal%20and%20Power%20Integrity%20-%20Simplified_2nd_Eric%20Bogatin_Prentice%20Hall%20PTR_2010.pdf
[^Wyatts]: https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now

**Circuit theory**, as we learned as undergrads, is a simplified, low-frequency (<100 kHz) approximation of field theory. It assumes that the physical size of components is much smaller than the wavelength of the signal, so we can ignore wave propagation and use simple circuit laws — Ohm's Law, Kirchhoff's laws.

As signal rise times shorten and PCB frequencies increase, those assumptions fail. **Field theory** is required to account for radiation, retardation, and wave propagation. PCB design shifts from drawing paths for current to designing transmission lines that contain EM fields, manage parasitic inductance and capacitance, and control radiated emissions.

Those physics classes about Electromagnetic fields and transmission lines are no longer reserved for the few RF engineers — they become practical for anyone designing a fast PCB.

### 1.1.1. How the wave starts

Maxwell's equations tell the full story in four lines, but the key insight is in two of them.

![Courtesy: Patrick André](../media/infographics/microstrip-fields.png)

**Step by step, from voltage to wave:**
1. Applying a voltage between the trace and the ground plane creates an **Electric Field** $\overrightarrow{E}$ between them.  This vector $\overrightarrow{E}$ points in the direction of steepest voltage decrease:
$$
    \overrightarrow{E} = - \nabla V
$$

2. [Ampere's law](https://coertvonk.com/physics/electromagnetism/magnetism/amperes-law-30007) with [Maxwell's crucial addition](https://coertvonk.com/physics/electromagnetism/magnetism/displacement-current-30269): There are two contributions to the $\mathbf{\overrightarrow{B}}$ field. From the conduction current at the conductor surface, and from the displacement current in the dielectric. Together they form one continuous field.  We will come back to the conduction current later.  What is important now, is that a changing electric field produces a curling magnetic field, even when no conduction current  is present:
$$
    \nabla \times \mathbf{\overrightarrow{B}} =
    \underbrace{\mu_0 \ \mathbf{\overrightarrow{J}}}_{\substack{\text{conduction} \\ \text{current}}} 
    +\ 
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \mathbf{\overrightarrow{E}}}{\partial t}}_{\substack{\text{displacement}\\ \text{current}}}
$$


3. [Faraday's law](https://coertvonk.com/physics/electromagnetism/magnetism/electromagnetic-induction-30157) says a changing magnetic field produces a electric field:
$$
    \nabla \times \mathbf{\overrightarrow{E}} = -\frac{\partial \mathbf{\overrightarrow{B}}}{\partial t}
$$

So once you disturb the electric field, it creates a magnetic field. That changing magnetic field recreates an electric field slightly ahead of it. Which creates a magnetic field ahead of that. The two fields traverse through the dielectric, each one regenerating the other. That self-sustaining leapfrog is the electromagnetic wave — it needs no electrons to carry it forward.

Each field regenerates the other. The wave is self-sustaining. The speed at which it propagates in a vacuum follows directly out of the constants $\mu_0$ and $\varepsilon_0$:

$$c = \frac{1}{\sqrt{\mu_0\, \varepsilon_0}}$$

For the typical PCB dielectric FR-4, replace $\varepsilon_0$ with $\varepsilon_r \varepsilon_0$ and you get a propagation speed of ~15 cm/ns. 

**Analogy:**

The copper trace and ground plane are not conductors of the signal — they are its **walls**. Think of a still pond. Drop a pebble in, and ripples spread outward in all directions, carrying the energy of your throw. The water molecules themselves barely move; they just bob in place as the wave passes through. Now lay two parallel planks on the surface and drop the pebble between them. The ripples are forced to travel along the channel between the planks — contained, directed, not spreading sideways into the rest of the pond.

The trace is one plank. The ground plane is the other. The FR-4 between them is the water. The signal is the ripple. Remove one plank — cut a slot in the ground plane, reroute the return path — and the wave spreads out. That spreading is EMI.


### 1.1.3. Where the energy flows

> "Energy and signals travel in the spaces not the traces"  -- Ralph Morrison

Maxwell's equations tell us the fields exist, but there is a more direct way to see where the energy is going. The Poynting vector $\mathbf{\overrightarrow{S}}$ points in the direction of the energy flow:
$$
    \mathbf{\overrightarrow{S}} = \frac{1}{\mu_0}\left(\mathbf{\overrightarrow{E}} \times \mathbf{\overrightarrow{B}}\right)
$$

Its magnitude is the power per unit area passing through any surface you choose to draw. Because it is a cross product, $\mathbf{\overrightarrow{E}}$, $\mathbf{\overrightarrow{B}}$, and the direction of propagation $\mathbf{\overrightarrow{S}}$ are always mutually perpendicular.

On a PCB microstrip, the geometry is: $\mathbf{\overrightarrow{E}}$ points vertically from the trace down to the ground plane, $\mathbf{\overrightarrow{B}}$ points horizontally curling around the current in the trace, and $\mathbf{\overrightarrow{E}}\times\mathbf{\overrightarrow{E}}$ therefore points forward — in the dielectric between the trace and the ground plane, in the direction of propagation. The energy is flowing through the dielectric between the conductors, not through the copper.

So, electromagnetic fields carry energy and information: When you apply a voltage or change a circuit, the resulting change in the electric and magnetic fields propagates along the wire at a substantial fraction of the speed of light (typically 0.5–0.99 c, depending on geometry and dielectric). That field propagation behaves like a wave and is what transmits the signal and most of the energy rapidly.


### 1.1.4.  What the conductors do

When the EM wave's electric field hits the conductor surface, it drives electrons. Those electrons rearrange themselves to do one specific thing: cancel the electric field inside the metal. Copper is not a perfect conductor, but it is close enough — the electrons respond so quickly that the tangential E field at the surface drops to nearly zero within a skin depth (~2 µm at 1 MHz).
This cancellation is what confines the wave. The field cannot penetrate the copper, so it is forced to exist only in the dielectric between the trace and the ground plane. Without this electron response, the field would pass right through and keep going.

**The magnetic field from the conduction current:**

The current in the trace creates its own \mathbf{\overrightarrow{B}} field curling around the conductor. This is not a separate, competing magnetic field — it is the same \mathbf{\overrightarrow{B}} field that is part of the wave. Together the \mathbf{\overrightarrow{B}} field in the dielectric (from ∂\mathbf{\overrightarrow{E}}/∂t, the displacement current) and the \mathbf{\overrightarrow{B}} field at the conductor surface (from \mathbf{\overrightarrow{J}}, the conduction current) are the same continuous field, satisfying boundary conditions at the interface.
$$
    \nabla \times \mathbf{\overrightarrow{B}} =
    \underbrace{\mu_0 \ \mathbf{\overrightarrow{J}}}_{\substack{\text{conduction current}\\ \text{at the surface}}} 
    +
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \mathbf{\overrightarrow{E}}}{\partial t}}_{\substack{\text{displacement current} \\ \text{in the dielectric}}}
$$

Think of it this way: in the dielectric, changing \mathbf{\overrightarrow{E}} sustains \mathbf{\overrightarrow{B}}. At the conductor surface, \mathbf{\overrightarrow{J}} sustains \mathbf{\overrightarrow{B}}. The field does not care which source is providing it — it is one continuous magnetic field with two sources that hand off seamlessly at the boundary.

**What the conduction current actually changes about the wave:**

Two things:

1. **Confinement.** The electron response forces the E field to zero at the conductor surface, which defines the geometry of the wave — the mode shape, the impedance, the propagation characteristics. This is why trace width and height above the ground plane matter: they set the boundary conditions that determine the field pattern.

2. **Loss.** The electrons are not perfect — copper has finite conductivity. The current flowing through the resistance of the metal converts some field energy to heat. This shows up as the Poynting vector pointing slightly into the conductor at the surface, rather than purely forward. That inward component is the energy being absorbed. This is the dominant loss mechanism in PCB traces at high frequencies (skin-effect loss).

**The key insight**

The wave in the dielectric and the current in the conductor are not two separate phenomena that happen to coexist. They are one self-consistent electromagnetic solution. The wave requires the conduction current to exist — without it, the boundary condition that confines the field would not be satisfied, and you would not have a guided wave at all. And the conduction current requires the wave — without the propagating field, there is nothing to drive the electrons.




### 1.1.5.  On a PCB


On a PCB, the same physics applies. The signal energy travels as an EM wave through the **FR-4 dielectric** between the trace and the ground plane — not through the copper itself. The propagation speed is:

$$
  \left.
    \begin{align*}
      v_p &= \frac{c}{\sqrt{\varepsilon_r}} \nonumber \\
      \rm{where\ } \varepsilon_r &\approx 4.2 \text{\ for\ FR-4}
    \end{align*}
  \right\} \Rightarrow v_p \approx \frac{c}{\sqrt{4.2}} \approx 15 \ \text{cm/ns}
$$

The trace and the ground plane are not pipes for the electrons. They are walls for the field. The electric field originates on the positive charge of the trace and terminates on the negative charge of the ground plane — confined to the dielectric between them. The magnetic field curls around the forward current in the trace and the return current in the plane; seen from a distance, these two fields are equal and opposite and cancel. The energy is trapped between the conductors and guided forward.

Remove the ground plane — or cut a slot through it — and the field lines have nowhere to land. They spray outward. The cancellation of the magnetic fields breaks down. The energy that was supposed to travel from source to load instead radiates into space. That radiation is EMI, and it is the direct consequence of losing control of the fields.

**What this means for layout**

Every trace needs a return plane directly below it, not because current needs a path home (though it does), but because the field needs a wall on the other side. A via that crosses layers must have a ground via next to it for the same reason — the field transfers with the signal, and the return field must transfer too. A slot in a ground plane is not just an inconvenience for the return current; it is a gap in the wall that lets the field escape.

The energy is in the fields. The dielectric is the medium. The copper is just the boundary condition that keeps it all in place.




### 1.1.3. How the Field and the Electrons Cooperate






So for the EM field propagating cause the current
Yes, exactly. The field arrives first, and the current is the electrons' response to it.

When the EM wave propagates along the trace, its electric field exerts a force on the free electrons in the copper — F = qE. The electrons accelerate in response to that force, and that net movement of charge is what we measure as current. The field is the cause; the current is the effect.

This is backwards from how most of us learned it. We were taught "apply a voltage, current flows." That is not wrong, but it hides what is actually happening. The voltage is just a way of describing the strength of the electric field. The "current flowing" is the electrons reacting to that field. The energy is not being transported by the electrons — it is in the field, described by the Poynting vector (E × H), which points from the source toward the load, through the dielectric space around the conductor.

A useful way to think about it: the field is the supervisor giving instructions, the electrons are the workers carrying them out. You measure the workers (current), but the supervisor (field) is running the operation.

This is also why the return path matters so much. The forward field and the return field are two halves of the same wave. If the return path is interrupted or forced to detour, the field structure breaks down — the loop area grows, the fields no longer cancel at a distance, and the energy radiates instead of being delivered.




**On the PCB specifically:**
The forward current in the trace creates a magnetic field curling around the trace. The return current in the ground plane creates an equal and opposite magnetic field. Seen from a distance, these two fields cancel — the energy is "trapped" in the space between trace and plane rather than radiating outward. Interrupt the return path, and the cancellation breaks down. The fields no longer cancel. The loop radiates.

The short version: the electric field drives the current, the current produces the magnetic field, and the two fields then sustain each other forward through space without needing the electrons to move anywhere.





**Back to the PCB:**
- Gauss (eq. 1): the voltage on the trace creates E between trace and plane.
- Ampere (eq. 4): the current in the trace creates B curling around it; the return current in the plane creates equal-and-opposite B below.
- Faraday (eq. 3) + Ampere (eq. 4): E and B leapfrog forward through the FR-4.
- Gauss for B (eq. 2): B loops are always closed — which is why the return path is not optional. The magnetic field loop must close somewhere; if the ground plane is interrupted, it closes through a large loop, and a large loop radiates.


Changing E → B → changing B → E, entirely through the field terms. This works in the dielectric, in free space, everywhere. It is what Maxwell's displacement current term was invented to capture, and it is why electromagnetic waves can propagate through a vacuum.

So, the wave propagates driven by the coupling between ∂E/∂t and ∂B/∂t. The conduction current J in the copper happens simultaneously — the electric field at the conductor surface drives electrons, which produce their own B — but this is a boundary effect that shapes and guides the wave, not what propagates it.

Option 1 describes what is happening at the conductors. Option 2 describes what is happening in the dielectric. Since the energy travels in the dielectric, option 2 is the right mental model for understanding propagation.


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




