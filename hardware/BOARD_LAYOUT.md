# Board Design Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, and follow-up to the Schematic Design document. It covers the Printed Circuit Board (PCB) selection and layout rules for **OPNhydro**.

As in the Schematic Design document, the central problem remains **coexistence**.
- On one side: a pH probe measuring millivolt-level electrochemical potentials, an EC probe and an ESP32 that needs a clean analog supply. 
- On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve.

After the PCB selection and general layout rules, we'll cover the different sections of the schematic.


## 1. PCB Selection and General Rules

Since I personally like to understand design rules, we start with a highly technical guide that transitions from abstract electromagnetic theory to practical PCB design rules. It serves as a bridge between the high-level Architecture goals and the specific Schematic Design requirements.

Let's start with a puzzle. You flip a light switch, and the bulb lights up almost instantly. But if you could tag a single electron at the switch and watch it, you would find it drifting toward the bulb at roughly one metre per hour — the speed of a snail. At that rate it would take days to arrive. So what turned the light on?

Not the electrons. The electromagnetic field did. And once you understand that, PCB layout stops being a set of rules to memorise and starts making intuitive sense.


### 1.1. Electro Magnetic Wave in the Dielectric

> "Electromagnetic (EM) field theory based on [Maxwell's equations](https://coertvonk.com/physics/electromagnetism/magnetism/materials-and-maxwells-equations-30453), is the fundamental description of electrical phenomena (fields, waves, radiation)."  -- Dr. Eric Bogatin [^BOGATIN] and Kenneth Wyatts [^WYATTS].

[^BOGATIN]: [Signal and Power Ingegrity, simplified 2nd (2010) - Eric Bogatin](https://www.oldfriend.url.tw/article/SI_PI_book/Signal%20and%20Power%20Integrity%20-%20simplified_2nd_Eric%20Bogatin_Prentice%20Hall%20PTR_2010.pdf)
[^WYATTS]: [PCB Design for Low EMI - Kenneth Wyatts](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)

**Circuit theory**, as we learned as undergrads, is a simplified, low-frequency (<100 kHz) approximation of field theory. It assumes that the physical size of components is much smaller than the wavelength of the signal, so we can ignore wave propagation and use simple circuit laws — Ohm's Law, Kirchhoff's laws.

As signal rise times shorten and PCB frequencies increase, those assumptions fail. **Field theory** is required to account for radiation, retardation, and wave propagation. PCB design shifts from drawing paths for current to designing transmission lines that contain EM fields, manage parasitic inductance and capacitance, and control radiated emissions.

Those physics classes about Electromagnetic fields and transmission lines are no longer reserved for the few RF engineers — they become practical for anyone designing a fast PCB.

#### 1.1.1. From Voltage to EM Wave

Maxwell's equations tell the full story in four lines, but the key insight is in two of them.

![Courtesy: Patrick André](../media/infographics/microstrip-fields.png)

**Step by step:**
1. Applying a voltage between the trace and the ground plane creates an **Electric Field** $\vec{E}$ between them.  This vector $\vec{E}$ points in the direction of steepest voltage decrease:
$$
    \vec{E} = - \nabla V
$$

2. [Ampere's Law](https://coertvonk.com/physics/electromagnetism/magnetism/amperes-law-30007) with [Maxwell's crucial addition](https://coertvonk.com/physics/electromagnetism/magnetism/displacement-current-30269): There are two contributions to the $\vec{B}$ field. From the conduction current at the conductor surface, and from the displacement current in the dielectric. Together they form one continuous field.  We will come back to the conduction current later.  What is important now, is that a changing electric field produces a curling magnetic field, even when no conduction current  is present:
$$
    \nabla \times \vec B =
    \underbrace{\mu_0 \ \vec J}_{\substack{\text{conduction} \\ \text{current}}} 
    +\ 
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \vec E}{\partial t}}_{\substack{\text{displacement}\\ \text{current}}}
    \tag{\text{Ampère-Maxwell}}
$$


3. [Faraday's Law](https://coertvonk.com/physics/electromagnetism/magnetism/electromagnetic-induction-30157) says a changing magnetic field produces a electric field:
$$
    \nabla \times \vec E = -\frac{\partial \vec B}{\partial t}
    \tag{\text{Faraday}}
$$

So, once you disturb the electric field, it creates a magnetic field. That changing magnetic field recreates an electric field slightly ahead of it. Which creates a magnetic field ahead of that. Each field regenerates the other. The wave is self-sustaining.  This self-sustaining propagation is the electromagnetic wave — it needs no electrons to carry it forward.


**Where the energy flows**

> "Energy and signals travel in the spaces not the traces"  -- Ralph Morrison

Maxwell's equations tell us the fields exist, but there is a more direct way to see where the energy is going. The Poynting vector $\vec{S}$ points in the direction of the energy flow:
$$
    \vec{S} = \frac{1}{\mu_0}\left( \vec{E} \times \vec{B} \right)
$$

On a PCB microstrip, the geometry is: $\vec{E}$ points vertically from the trace down to the ground plane, $\vec{B}$ points horizontally curling around the current in the trace, and $\vec{E} \times \vec{B}$ therefore points forward — in the dielectric between the trace and the ground plane, in the direction of propagation. The energy is flowing through the dielectric between the conductors, not through the copper.


#### 1.1.2. Propagation

Maxwell's two curl equations couple spatial variation to time variation — and that coupling is what makes propagation inevitable.

In free space ($ρ = 0, \vec J = \vec 0$), the Ampère-Maxwell Law simplifies to:
$$
    \nabla \times \vec{B} = \mu_0\varepsilon_0 \frac{\partial \vec{E}}{\partial t}
    \tag{\text{simplified Ampere-Maxwell}}
$$
So, if $\vec E$ is changing in time at some point, then $\vec B$ must have a spatial gradient at that same point. But spatial variation means the field value at the neighbouring point is different. 

$$
    \nabla \times \vec{E} = -\frac{\partial \vec{B}}{\partial t} 
    \tag{\text{Faraday}}
$$
That neighbouring point now has a changing $\vec B$, which by Faraday produces spatial variation in $\vec E$ there. Which means the next neighbouring point has a different $\vec E$. And so on.

The key is the curl operator — it is a spatial derivative. A time change here forces a spatial difference here, which means a different value there, which forces a time change there. The disturbance has no choice but to spread. It cannot stay put, because the equations link time derivatives to spatial derivatives at every point.

No mechanism "pushes" the wave forward. The wave propagates because the mathematics forbid a localised disturbance from remaining localised. A changing field at one point necessarily implies a different field at the adjacent point — and that is propagation.

<details>
  <summary>Expand to see the math</summary>

  Take the curl of Faraday's law
  $$
      \nabla \times (\nabla \times \vec E) = -\frac{\partial}{\partial t}(\nabla \times \vec B)
  $$

  Substitute the simplified Ampere–Maxwell into the right side
  $$
      \nabla \times (\nabla \times \vec E) = -\mu_0\varepsilon_0 \frac{\partial^2 \vec E}{\partial t^2}
  $$

  Recall the vector identity
  $$
      \nabla \times (\nabla \times \vec E) = \nabla(\nabla \cdot \vec E) - \nabla^2\vec E
      \tag{\text{vector identity}}
  $$

  Expand the left side using this vector identity
  $$
      \nabla(\nabla \cdot \vec E) - \nabla^2\vec E = -\mu_0\varepsilon_0 \frac{\partial^2 \vec E}{\partial t^2}
  $$

  Apply Gauss' Law:
  $$
      \nabla \cdot \vec E = \frac{\rho}{\varepsilon_0}
      \tag{\text{Gauss's law}}
  $$

  In free space there are no charges ($\rho$), so this becomes $\nabla \cdot \vec E = 0$. The first term vanishes:
  $$
      \nabla^2 \vec E = \underbrace{\mu_0\,\varepsilon_0} \frac{\partial^2 \vec E}{\partial t^2}
  $$

  Recognize the standard wave equation for any quantity propagating at speed $v$:
  $$
      \nabla^2 f = \underbrace{\frac{1}{v^2}} \frac{\partial^2 f}{\partial t^2}
      \tag{\text{standard wave equation}}
  $$

  Comparing the two, term by term, gives the speed of the wave propagation:
  $$
      \frac{1}{v^2} = \mu_0 \varepsilon_0
      \quad \Rightarrow \quad
      v = \frac{1}{\sqrt{\mu_0 \varepsilon_0}}
  $$
</details>


The speed at which the EM wave propagates in free space (ρ = 0, J = 0) follows directly out of the constants for permeability ($\mu_0$) and permittivity ($\varepsilon_0$):
$$
    v = \frac{1}{\sqrt{\mu_0 \varepsilon_0}}
$$

The constant $\mu_0$ and $\varepsilon_0$ follow from independent experiments with respectively magnetic and electric forces. Neither involves light.

$$
  \left.
    \begin{align*}
      \mu_0 &= 4\pi \times 10^{-7} \text{ H/m} \\
      \varepsilon_0 &= 8.854 \times 10^{-12} \text{ F/m}
    \end{align*}
  \right\}
$$

Entering in the constants:
$$
    v = \frac{1}{\sqrt{4\pi \times 10^{-7} \times 8.854 \times 10^{-12}}} \approx 299.8 \times 10^6 \text{ m/s} \equiv c
$$

That is the speed of light $c$ — derived entirely from electric and magnetic constants, with no reference to optics.

This was Maxwell's 1865 result.  He started with two equations about how electric and magnetic fields change in space and time, combined them, and out fell the speed of light. That is one of the most remarkable results in all of physics.

For a typical PCB dielectric FR-4, we need to replace $\varepsilon_0$ with $\varepsilon_r \varepsilon_0$, where $\varepsilon_r \approx 4.2$
$$
    v' = \frac{1}{\sqrt{4\pi \times 10^{-7} \times 4.2 \times 8.854 \times 10^{-12}}} \approx 146.3 \times 10^6 \text{ m/s}
$$

The **propagation speed in FR-4** dielectric follows as **~15 cm/ns**. 


---


### 1.2. What the Conductors do

So far the story has been about the fields — how they sustain each other and where the energy flows. But the wave does not exist in free space; it propagates between two copper conductors. Those conductors are not passive bystanders. 

The EM wave's electric field has two components — one vertical (across the gap) and one horizontal (along the trace) — and the free electrons in the copper respond to each one differently. The vertical component drives a transient surface-charge redistribution that *confines* the wave to the dielectric. The horizontal component drives a sustained current that we measure with instruments — and that converts a small fraction of the field energy into heat. Together, these two responses explain why trace geometry determines impedance, why copper has loss, and why the ground plane is not optional.

#### 1.2.1. The Electric Field has two Components

The electric field between trace and ground plane is not perfectly vertical — it tilts slightly forward in the direction of propagation. That tilt is small, but it explains both the conduction current and the resistive loss.

- **Vertical component $E_v$** (dominant) — comes from the charge separation across the gap. The wave deposits positive charge on the trace and negative charge on the ground plane (or vice versa half a cycle later). These opposite surface charges create an electric field pointing from one conductor to the other, just like a parallel-plate capacitor. This component stores energy.

- **Horizontal component $E_h$** (small) — comes from the fact that the wave is *travelling*. The voltage is not the same everywhere along the trace at the same instant: the wave has arrived here but not yet at the next point down the line. That spatial gradient in voltage is a horizontal electric field:
$$
    E_h = -\frac{\partial V}{\partial x}
$$

The vertical component confines the wave. The horizontal component drives the current and accounts for the loss. The following two subsections explain each.

**Horizontal component → sustained current**

> Note that physics uses the vector current density $\vec J$ instead of the scalar current $I$ to describe how charge moves through a specific area at a specific point in space, rather than just the total charge flow in a wire.

As the $E_h$ wave front reaches a section of the conductor, the electric field there goes from zero to some value. The electrons, which were sitting still (thermally jiggling, but no net drift), suddenly feel a force and begin to move horizontally.
$$
  F_h = q \, E_h
  \tag{\text{Lorentz force law}}
$$

In a conductor, the outer electrons are not bound to any particular atom. When $E_h$ appears, these free electrons move in response.  That net movement of charge is what we measure as current $\vec J$.  So, the field arrives first, and the **current is the electrons' response to the electric field changing**.
$$
    \vec J = \sigma \vec E
$$

where $\sigma$ is the conductivity (~$5.8 \times 10^7$ S/m for copper). This is Ohm's law in its field form. A larger $\vec E$ means more force, means more drift, means more current.

This is backwards from how most of us learned it. We were taught "apply a voltage, current flows." That is not wrong, but it hides what is actually happening. The voltage is just a way of describing the strength of the electric field. The "current flowing" is the electrons reacting to that field. The energy is not being transported by the electrons — it is in the field, described by the Poynting vector $\vec E \times \vec B$, which points from the source toward the load, through the dielectric space around the conductor.

**Vertical component → transient redistribution of surface charge → confines the wave**

As the $E_v$ wave front reaches a section of the conductor, the electric field there goes from zero to some value. On the trace, electrons are pushed to the bottom surface; on the ground plane, to the top surface — both facing the dielectric gap. By moving, these electrons create their own electric field that opposes the one that pushed them. The electrons keep moving until their self-generated field exactly cancels the incoming field inside the metal. 

In other words, the electrons move vertically to rearrange themselves to **cancel the electric field** inside the metal. These electrons respond so quickly that the $E_v$ field at the surface drops to nearly zero within a skin depth (~2 µm at 1 MHz).

This cancellation is what **confines the wave**. The field cannot penetrate the copper, so it is forced to exist only in the dielectric between the trace and the ground plane. Without this electron response, the field would pass right through and keep going, like an antenna.


#### 1.2.2. The Magnetic Field — One Field, Two Sources

The horizontal current $\vec J$ in the trace creates a $\vec B$ field curling around the conductor. A natural question: is this a separate magnetic field competing with the wave's own $\vec B$? No — it is the *same* field. Ampere–Maxwell makes this explicit:

$$
    \nabla \times \vec B =
    \underbrace{\mu_0 \, \vec J}_{\substack{\text{conduction current}\\ \text{in the copper}}} 
    \;+\;
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \vec E}{\partial t}}_{\substack{\text{displacement current} \\ \text{in the dielectric}}}
$$

There is one continuous $\vec B$ field, but it has two sources depending on where you are. Inside the copper, $\vec J$ dominates — free electrons are moving, and their motion sustains $\vec B$. In the dielectric, there are no free electrons, so $\vec J = 0$ — but the changing $\vec E$ field acts as a displacement current that sustains $\vec B$ just the same. At the copper-dielectric boundary, the two sources hand off seamlessly. The $\vec B$ field does not care which term is producing it; it is one smooth, continuous solution across the interface.

#### 1.2.3. The Key Insight — One Self-Consistent System

It is tempting to think of "the wave in the dielectric" and "the current in the copper" as two separate things that happen to coexist. They are not. They are two views of a single electromagnetic solution, and neither can exist without the other.

- Without the conduction current, the boundary condition that cancels $\vec E$ inside the metal would not be satisfied. The field would not be confined. There would be no guided wave — just radiation.
- Without the propagating field, there would be nothing to drive the electrons. No $E_h$ means no $\vec J$. The current would not exist.

The wave creates the current. The current shapes the wave. They are mutually dependent — one self-consistent system, seen from different sides of the copper surface.


---


### 1.3. PCB Design Rules

Everything in §1.1 and §1.2 leads to a single conclusion: the signal energy travels as an EM wave through the dielectric, guided by the copper boundaries. The trace is one wall, the ground plane is the other. The copper confines the field ($E_v$ cancellation), the dielectric carries it forward (displacement current), and the return current in the ground plane provides the equal-and-opposite $\vec B$ that prevents radiation (field cancellation at a distance).

Every PCB layout rule is a consequence of keeping that field structure intact. Break the structure — and the field escapes as EMI.

#### 1.3.1. The Return Path

The $\vec B$ field from the forward current in the trace and the $\vec B$ field from the return current in the ground plane are equal and opposite. At a distance, they cancel — the energy stays confined between the conductors. Gauss's law $\nabla \cdot \vec B = 0$ tells us magnetic field lines must always close. If the ground plane is continuous, they close tightly through the narrow gap between trace and plane. If the ground plane is interrupted — a slot, a cutout, a missing pour — the field lines must close through a larger loop. A larger loop means less cancellation at a distance, which means radiation.

**Rule 1:** Every signal trace needs an unbroken return plane directly below it — not because current needs a path home (though it does), but because the field needs a wall on the other side.

![Courtesy: Kenneth Wyatts, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/trace-crossing-gap-in-return-plane.png)


#### 1.3.2. Layer Transitions need Return Vias

When a trace passes through a via from one layer to another, the EM wave transfers between layers. But the wave is not just the trace — it is the field between the trace and its reference plane. If the reference plane changes (say, from L2 to L3), the return current must also transition. Without a nearby ground via, the return path detours around the edge of the plane, the loop area grows, and the field radiates.

**Rule 2:** Every signal via needs a ground via alongside it, stitching the two reference planes together at the point of transition.

![Courtesy: Kenneth Wyatts, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/trace-passing-through-two-planes-with-via.png)

Trace passing through two vias layers causes the wave to leak in between the reference planes.  May interfere with other signals in that space, and cause board edge radiation.  If the planes are the same potential, you can prevent this with nearby sticking vias between the ground planes.  If they are different potentials you can add stiching capacitance very close.


#### 1.3.3. Fields Couple through Shared Dielectric

The EM wave travels in the dielectric. If two signals share the same dielectric space — running parallel on the same layer, or overlapping on adjacent layers — their fields interact. The $\vec E$ field from one trace induces charge on the neighbouring trace (capacitive coupling). The $\vec B$ field from one trace's current induces current in the neighbouring trace (inductive coupling). This is crosstalk, and it is a direct consequence of overlapping field volumes.

**Rule 3:** Keep fields from different functional domains separated — physically, by distance, or by interposing a ground plane between them. Moreover, provide at least $3W$ to $5W$ spacings between critical traces, where $W$ is the width of a trace. Keep traces on perpendicular to adjacent layers.  Motor control traces and analog sensor traces must not share the same dielectric space.

#### 1.3.4. Power Planes Need Return Paths Too

A power plane carrying current creates its own $\vec B$ field, just like a signal trace. The same physics applies: that field must have a nearby return plane to cancel at a distance, or it radiates. A power plane separated from its ground plane by a thick core (>10 mil) is a poor high-frequency decoupling pair — the fields between them are weakly confined.

**Rule 4:** Every power plane or routed power trace needs an adjacent return plane, tightly coupled (2–3 mil dielectric separation) for effective high-frequency decoupling.


---


#### 1.4. Stack-up

The PCB has two hard constraints that drive most of the other design decisions. First, the 4.7A peak current on the 24V rail requires copper heavy enough to carry that current continuously without excessive resistive heating. Second, the isolation moats around the pH and EC islands must be maintained through all four layers, which means the layer stack-up cannot be an afterthought.

The **typical 4-layer stack-up** is SIG/GND/PWR/SIG as shown in the table below. We are not using this, because the Power and GND are too far separated (the core distance) for good high frequency decoupling. Should be 2-3 mill max.  Also, signals in Layer 4 are referenced to power, rather than GND. That is OK, if and only if, the power and return planes are tightly coupled together and with adequate decoupling capacitors.

Instead, we opt for the **Low EMI 4-layer stack-up** as shown below.

Layer | Name   | Function                         | Components
------|--------|----------------------------------|--------------------------
L1    | Top    | Sensitive signals / routed power | ESP32, LiDAR, I2C, UART, EZO, BNC, 3V3/5V power traces
L2    | GND    | Ground return plane              | Return plane for Layer 1
L3    | GND    | Ground return plane              | Return plane for Layer 4
L4    | Bottom | Noisy signals / routed 24V power | Stepper drivers, MOSFETs, 24V power traces

![Courtesy: Kenneth Wyatts, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/lower-emi-4-layer-pcb.png)


---


#### 1.5. Segregating Functional Regions

Segregating Functional Regions

1. keep analog traces away from motor control and digital sections
2. keep power conversions and motor control near the power entry point
3. all power and i/o connectors should be filtered and transient protected
4. all power and i/o connectors should be grouped together on one edge of the board, if possible for minimum EMI


Zl = 1 / j omega L
Xl = 1 / 2 pi f L

Z = ESR + Xc + Xl
the dip in |Z| is ESR



#### 1.2.4. PCB Guidelines


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




#### 1.2.5. Trace Widths

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


#### 1.2.6. PCB Layout Strategy

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




