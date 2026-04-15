# Board Design Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, and follow-up to the Schematic Design document. It covers the Printed Circuit Board (PCB) selection and layout rules for **OPNhydro**.

As in the Schematic Design document, the central problem remains **coexistence**.
- On one side: a pH probe measuring millivolt-level electrochemical potentials, an EC probe, and an ESP32 — all of which need a clean, quiet supply.
- On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve.

After the PCB selection and general layout rules, the document covers the different sections of the schematic.

Rather than presenting layout rules as a checklist to memorise, this guide starts from the underlying electromagnetic theory and derives the rules as consequences. It serves as a bridge between the high-level Architecture goals and the specific Schematic Design requirements.

Let's start with a puzzle. You flip a light switch, and the bulb lights up almost instantly. But if you could tag a single electron at the switch and watch it, you would find it drifting toward the bulb at roughly one meter per hour — the speed of a snail. At that rate it would take days to arrive. So what turned the light on?

Not the electrons. The electromagnetic field did. And once you understand that, PCB layout starts making intuitive sense.

The treatment draws heavily on:
- Physics classes at HTD Dordrecht from Dipl.-Ing. J.J. Senff
- Walter Lewin's physics lectures at MIT
- *Signal and Power Integrity* by Eric Bogatin

---


## 1. Field Theory

**Circuit theory**, as we learned as undergrads, is a simplified, low-frequency approximation of field theory. It assumes that the physical size of components is much smaller than the wavelength of the signal, so we can ignore wave propagation and use simple circuit laws — Ohm's Law, Kirchhoff's laws. In that era, a typical device might output signals with 10 ns rise times at 10 MHz — and the circuits worked with the crudest of interconnects.

### 1.1. EM Wave in the Dielectric

As clock frequencies increase, rise times shorten — as a rule of thumb, the rise time $t_r$ is roughly 10% of the clock period:
$$
  t_r \approx \frac{1}{10\,f_{clk}}
$$

A 100 MHz clock demands 1 ns. At these short rise times, the wavelength of the signal's frequency content approaches the physical dimensions of the PCB traces, and the circuit-theory assumptions fail. **Field theory** is now required to account for radiation, retardation and wave propagation. 

PCB design shifts from drawing paths for current to designing transmission lines that contain EM fields, manage parasitic inductance and capacitance, and control radiated emissions. Those physics classes about electromagnetic fields and transmission lines are no longer reserved for RF engineers — they become practical for anyone designing a fast PCB.

A microstrip has two regions: the dielectric between the conductors, and the copper itself. §1.1 looks at the dielectric — that is where the wave lives and where the energy flows. §1.2 then turns to the copper, where the free electrons respond.
<br />

#### From Voltage to EM Wave

> "Electromagnetic (EM) field theory based on [Maxwell's equations](https://coertvonk.com/physics/electromagnetism/magnetism/materials-and-maxwells-equations-30453), is the fundamental description of electrical phenomena (fields, waves, radiation)."  -- Dr. Eric Bogatin [^BOGATIN] and Kenneth Wyatt [^WYATTS].

[^BOGATIN]: [Signal and Power Integrity, simplified 2nd (2010) - Eric Bogatin](https://www.oldfriend.url.tw/article/SI_PI_book/Signal%20and%20Power%20Integrity%20-%20simplified_2nd_Eric%20Bogatin_Prentice%20Hall%20PTR_2010.pdf)
[^WYATTS]: [PCB Design for Low EMI - Kenneth Wyatt](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)

As we will see, Maxwell's equations tell the full story in four lines, but the key insight is in two of them — Faraday's Law and the Ampère-Maxwell Law — with Gauss's law providing the source-free boundary condition.

![Courtesy: Patrick André](../media/infographics/microstrip-fields-2.png)

> **A note on field lines.** Textbook diagrams show fields as lines with arrows. These *field lines* are a visualization invented by Faraday, not physical objects. They are drawn by stepping from point to point in the direction the field vector points, with line density representing field strength. The field itself exists at *every* point in space — between the lines too. Where this document says "the $\vec E$ field points downward" or "the $\vec B$ field curls around the trace," it is shorthand for: the field vector at each point in that region has that direction and magnitude.

**Microstrip geometry**

Consider a signal trace running above a ground return plane, separated by a thin dielectric — the basic microstrip geometry of every PCB. In the dielectric region ($\rho = 0, \vec J = \vec 0$ — no free charges between the conductors), when a voltage step is applied at one end, the following chain of events unfolds:

1. When the voltage is applied, an **electric field** $\vec{E}$ appears between trace and return plane, pointing vertically (from trace down to return plane). But this field cannot remain localised.
[*Add some nifty graphic here, showing a sideview of the trace and return plane, with battery and initial E-field on the left*]
<br />

2. The moment $\vec E$ appears, it is rising from zero — i.e. **changing in time**. Since the dielectric carries no conduction current ($\vec J = \vec 0$), [Ampere-Maxwell's Law](https://coertvonk.com/physics/electromagnetism/magnetism/displacement-current-30269) reduces to the displacement-current term — a time-changing electric field **produces a spatially varying magnetic field**:
$$    
    \nabla \times \vec B =
    \underbrace{\cancel{\mu_0 \ \vec J}}_{\substack{\text{conduction} \\ \text{current}}}
    +\ 
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \vec E}{\partial t}}_{\substack{\text{displacement}\\ \text{current}}}
    \tag{\text{Ampère-Maxwell}}
$$
The time-changing $\vec E$ (right side) forces $\vec B$ to vary spatially (left side).
<br />

3. The $\vec B$ field created in step 2 is also rising from zero — i.e. **changing in time**. [Faraday's Law](https://coertvonk.com/physics/electromagnetism/magnetism/electromagnetic-induction-30157) says a time-changing magnetic field **produces a spatially varying electric field** — extending $\vec E$ slightly ahead of where it began:
$$
    \nabla \times \vec E = -\frac{\partial \vec B}{\partial t}
    \tag{\text{Faraday}}
$$
The time-changing $\vec B$ (right side) forces $\vec E$ to vary spatially (left side). $\vec E$ points vertically (trace to return plane), but its magnitude changes as you move horizontally along the trace — field direction and variation are perpendicular. That is a wave front advancing.

To summarise: once the electric field appears, a magnetic field arises alongside it. That changing magnetic field extends the electric field slightly ahead, which in turn extends the magnetic field further still. **Each field regenerates the other**. The wave is self-sustaining — it needs no electrons to carry it forward.

> **What is the curl operator?** The curl $\nabla \times$ is a spatial derivative — it measures how much a field changes from one point to the next in a perpendicular direction. It does not mean the field lines form circles. The perpendicularity between $\vec E$ (vertical) and its variation (horizontal) described in step 3 is exactly what $\nabla \times$ captures.
<br />

#### Propagation

Steps 1–3 showed the first cycle. The same coupling, applied repeatedly, guarantees indefinite propagation. In the source-free dielectric, the two laws simplify to:

$$
    \nabla \times \vec{B} = \mu_0\varepsilon_0 \frac{\partial \vec{E}}{\partial t}
    \tag{\text{Ampere-Maxwell}}
$$
$$
    \nabla \times \vec{E} = -\frac{\partial \vec{B}}{\partial t}
    \tag{\text{Faraday}}
$$

These two equations couple spatial variation to time variation — and that coupling is what makes propagation inevitable. If $\vec E$ is changing in time at some point, the first equation forces $\vec B$ to have a spatial gradient there — so $\vec B$ at the neighbouring point is different. At that neighbouring point, $\vec B$ is now changing in time, and by the second equation this forces spatial variation in $\vec E$ — so $\vec E$ at the *next* point is different. And so on.

No mechanism "pushes" the wave forward. A time change here forces a spatial difference here, which means a different value there, which forces a time change there. The disturbance has no choice but to spread. The wave propagates because the mathematics forbid a localised disturbance from remaining localised.

<details>
  <summary>Expand to see the math.</summary>

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

  Apply Gauss's law:
  $$
      \nabla \cdot \vec E = \frac{\rho}{\varepsilon_0}
      \tag{\text{Gauss's law}}
  $$

  In the source-free dielectric there are no charges ($\rho = 0$), so this becomes $\nabla \cdot \vec E = 0$. The first term vanishes:
  $$
      \nabla^2 \vec E = \underbrace{\mu_0\,\varepsilon_0}_{1/v^2} \frac{\partial^2 \vec E}{\partial t^2}
  $$

  Recognize the standard wave equation for any quantity propagating at speed $v$:
  $$
      \nabla^2 f = \frac{1}{v^2} \frac{\partial^2 f}{\partial t^2}
      \tag{\text{standard wave equation}}
  $$

  Comparing the two, term by term, gives the speed of the wave propagation:
  $$
      \frac{1}{v^2} = \mu_0 \varepsilon_0
      \quad \Rightarrow \quad
      v = \frac{1}{\sqrt{\mu_0 \varepsilon_0}}
  $$
</details>
<br />

**Takeaway:** combining Faraday and Ampère-Maxwell yields the standard wave equation with speed $v$. This speed of the EM wave follows directly from the constants for permeability ($\mu_0$) and permittivity ($\varepsilon_0$):
$$
    v = \frac{1}{\sqrt{\mu_0 \varepsilon_0}}
$$

The constants $\mu_0$ and $\varepsilon_0$ follow from independent magnetic and electric experiments, respectively — neither involving light.

$$
  \left.
    \begin{align*}
      \mu_0 &= 4\pi \times 10^{-7} \text{ H/m} \\
      \varepsilon_0 &= 8.854 \times 10^{-12} \text{ F/m}
    \end{align*}
  \right\}
$$

Substituting the constants:
$$
    v = \frac{1}{\sqrt{4\pi \times 10^{-7} \times 8.854 \times 10^{-12}}} \approx 299.8 \times 10^6 \text{ m/s}
$$

That is the speed of light $c$ — derived entirely from electric and magnetic constants.

This was Maxwell's 1865 result.  He started with two equations about how electric and magnetic fields change in space and time, combined them, and out fell the speed of light. That is one of the most remarkable results in all of physics.

For a typical PCB dielectric FR-4, we need to replace $\varepsilon_0$ with $\varepsilon_r \varepsilon_0$, where $\varepsilon_r \approx 4.2$.
$$
    v' = \frac{1}{\sqrt{4\pi \times 10^{-7} \times 4.2 \times 8.854 \times 10^{-12}}} \approx 146.3 \times 10^6 \text{ m/s}
$$

The **propagation speed in FR-4** is therefore **~15 cm/ns**. This is the bulk-FR-4 (or stripline) speed. On a microstrip, roughly half the field is in air above the trace, so the effective permittivity is lower and the speed rises to ~17–18 cm/ns.


#### Where the energy flows

> "Energy and signals travel in the spaces not the traces"  -- Ralph Morrison

Maxwell's equations describe the fields, but where does the energy actually flow? The Poynting vector $\vec{S}$ answers this directly — it points in the direction of energy flow:
$$
    \vec{S} = \frac{1}{\mu_0}\left( \vec{E} \times \vec{B} \right)
$$

Distinguish the **wave front** from the **fields themselves**. The wave front is the leading edge — the boundary between where the fields have arrived and where they have not. Behind that front, the $\vec E$ and $\vec B$ fields are fully established and steady (for a DC step) or oscillating (for an AC signal). The Poynting vector describes the energy flow in this established region, not just at the front.

Behind the wave front on a PCB microstrip, $\vec{E}$ points vertically from trace to return plane, $\vec{B}$ wraps around the trace in the plane perpendicular to propagation — in the dielectric gap, it points across the trace width — and $\vec{E} \times \vec{B}$ therefore points forward, through the dielectric between trace and return plane, in the direction of propagation. The energy flows through the dielectric, not through the copper. The copper guides and confines the wave, but the energy is in the fields between the conductors.

---


### 1.2. Conductors as Waveguide

§1.1 looked at the dielectric — the wave, the energy, the propagation. Now look at the copper. Inside the metal, there are free electrons, and they are not passive bystanders.

#### Components of the Electric Field

The electric field between trace and return plane is not perfectly vertical — it tilts slightly forward in the direction of propagation. That tilt decomposes into two components:
$$
    \vec E = \hat x \, E_x + \hat z \, E_z
$$

where $\hat x$ points along the trace (the propagation direction) and $\hat z$ points from the trace to the return plane.

The free electrons in the copper respond to each component differently:

- **Horizontal component $E_x$** (small) arises from the fact that the wave is *travelling*. The voltage is not the same everywhere along the trace at the same instant: the wave has arrived here but not yet at the next point down the line. That spatial gradient in voltage is a horizontal electric field: $E_x = -\frac{\partial V}{\partial x}$. It drives a sustained current that we measure with instruments, and converts a small fraction of the field energy into heat.
<br />

- **Vertical component $E_z$** (dominant) drives a transient surface-charge redistribution that **confines** the wave to the dielectric. It comes from the charge separation across the gap. The wave deposits positive charge on the trace and negative charge on the return plane (or vice versa half a cycle later). These opposite surface charges create an electric field pointing from one conductor to the other, just like a parallel-plate capacitor.

The two subsections below unpack each component in detail, starting with the horizontal.

**Horizontal component $E_x$ → sustained current**

As the wave front reaches a section of the conductor, $E_x$ there rises from zero to some value. The free electrons — previously drifting only thermally, with no net motion — feel a force and begin to move horizontally:
$$
  F_x = q \, E_x
  \tag{\text{Lorentz force law}}
$$

> Note: physics uses the vector **current density** $\vec J$ — how charge moves through a specific area at a specific point — rather than the scalar current $I$, which is just the total charge flow in a wire.

This collective drift of many electrons is what we measure as current density $\vec J$, and in a linear conductor it is proportional to $\vec E$:
$$
    \vec J = \sigma \vec E
$$

where $\sigma$ is the conductivity (~$5.8 \times 10^7$ S/m for copper). This is Ohm's law in its field form. A larger $\vec E$ means more force, more drift, more current.

In other words: the field arrives first; the **current is the electrons' response to the electric field**. This is backwards from how most of us learned it. We were taught "apply a voltage, current flows." That is not wrong, but it hides what is actually happening. The voltage is just a way of describing the strength of the electric field. The "current flowing" is the electrons reacting to that field. The energy is not being transported by the electrons — it is in the field, described by the Poynting vector $\vec E \times \vec B$, which points from the source toward the load, through the dielectric between the conductors.

**Vertical component $E_z$ → transient redistribution of surface charge → confines the wave**

As the wave front reaches a section of the conductor, $E_z$ there rises from zero to some value. The force on an electron is $-q\vec E$, so with $E_z$ pointing from trace down to return plane, electrons in *both* conductors are pushed *upward*: in the trace, they move away from the dielectric-facing surface, leaving it positively charged; in the return plane, they move toward the dielectric-facing surface, making it negatively charged (or the reverse half a cycle later). By moving, these electrons create their own electric field that opposes the one that pushed them. The electrons keep moving until their self-generated field exactly cancels the incoming field inside the conductor.

In other words, the electrons rearrange themselves to **cancel the electric field** inside the metal. These electrons respond so quickly that $E_z$ at the surface is nearly cancelled; what little field penetrates the metal decays within one skin depth (~66 µm at 1 MHz, ~2 µm at 1 GHz).

This cancellation is what **confines the wave**. The field cannot penetrate the copper, so it is forced to exist only in the dielectric between the trace and the return plane. Without this electron response, the field would not be confined — the wave would radiate away instead of propagating along the line.


#### Sources of the Magnetic Field

The horizontal current $\vec J$ in the trace creates a $\vec B$ field curling around it. A natural question: is this a separate magnetic field competing with the wave's own $\vec B$? No — it is the *same* field. Ampere–Maxwell makes this explicit:

$$
    \nabla \times \vec B =
    \underbrace{\mu_0 \, \vec J}_{\substack{\text{conduction current}\\ \text{in the copper}}} 
    \;+\;
    \underbrace{\mu_0\,\varepsilon_0\, \frac{\partial \vec E}{\partial t}}_{\substack{\text{displacement current} \\ \text{in the dielectric}}}
$$

There is one continuous $\vec B$ field, but it has two sources depending on where you are. Inside the copper, the conduction term ($\mu_0 \vec J$) dominates — free electrons are moving, and their motion sustains $\vec B$. In the dielectric, there are no free electrons ($\vec J = 0$), so the displacement term takes over — the changing $\vec E$ field sustains $\vec B$ just the same. At the copper-dielectric boundary, the two sources hand off seamlessly. The $\vec B$ field does not care which term is producing it; it is one smooth, continuous solution across the interface.

#### One System, Two Views

It is tempting to think of "the wave in the dielectric" and "the current in the copper" as two separate things that happen to coexist. They are not. They are two views of a single electromagnetic solution, and neither can exist without the other.

- Without the surface-charge redistribution, the boundary condition that cancels $\vec E$ inside the metal would not be satisfied. The field would not be confined. There would be no guided wave — just radiation.
- Without the propagating field, there would be nothing to drive the electrons. No $E_x$ means no $\vec J$. The current would not exist.

The field drives the current. The current shapes the field. They are mutually dependent — one self-consistent system, seen from different sides of the copper surface.


---


### 1.3. Rail Noise in the Power Distribution Network

Signal integrity is not the only concern. The power and ground paths that feed every chip on the board are themselves transmission lines with impedance — and when the current through them changes, that impedance produces voltage noise.

Every time a chip switches its outputs or its internal gates toggle, it draws a sharp pulse of current from the power rail. That current passes through the inductance $L_{\text{PDN}}$ of the power distribution network (PDN) — the planes, traces, vias, and decoupling capacitors between the voltage regulator and the chip. The resulting voltage drop is:

$$\Delta V = L_{\text{PDN}} \times \frac{dI}{dt}$$

This is trace and via inductance resisting sudden changes in current. The chip sees its supply rail sag momentarily, reducing the voltage between its power and ground pins. If the sag is large enough, the chip misinterprets logic levels or produces timing errors. The design goal is to minimise $L_{\text{PDN}}$ across the full frequency range the chip draws current at — the details are covered in §2.1.


---


### 1.4. Crosstalk

Crosstalk is what happens when the EM field of one trace overlaps with the EM field of another. In circuit theory we talk about parasitic capacitance and mutual inductance as if they are discrete components accidentally added to the circuit. In field theory the picture is more honest: there is one EM field in the dielectric, and that field does not know which trace "owns" it. If two traces share the same dielectric volume, their fields overlap, and the overlap is the crosstalk. $C_m$ and $L_m$ are just circuit-theory approximations of that field overlap.

There are two coupling mechanisms — capacitive and inductive — and both are direct consequences of Maxwell's equations.

![Courtesy: Intel](../media/infographics/capacitive-and-inductive-coupling.png)

#### Capacitive (electric field)

The $\vec E$ field from a signal trace does not terminate exclusively on its own return plane. Some field lines — especially the fringing fields at the edges of the trace — terminate on nearby conductors instead: an adjacent trace, a via, a component pad.

When the aggressor trace changes voltage, its $\vec E$ field changes. That changing field induces a displacement current ($\varepsilon_0 \varepsilon_r \frac{\partial \vec E}{\partial t}$) onto the victim trace — depositing charge on it, just as it would on a capacitor plate. The victim trace sees a current spike proportional to the rate of change of the aggressor's voltage $V_a$:
$$
    I_C = C_m \ \frac{dV_a}{dt}
$$

where $C_{\text{m}}$ is the mutual parasitic capacitance between the two traces — determined by their overlap area, separation distance, and the dielectric constant of the material between them. Closer traces, longer parallel runs, and higher $\varepsilon_r$ all increase the coupling.

This is purely Gauss's law at work: electric field lines must terminate on a conductor, and if another trace is closer or more convenient than the return plane, some of them will land there instead.

#### Inductive (magnetic field)

The current in the aggressor trace creates a $\vec B$ field curling around it. That field extends into the surrounding space — including through the loop formed by the victim trace and its return plane. When the aggressor's current $I_a$ changes, the $\vec B$ field through the victim's loop changes. Faraday's law says a changing magnetic flux through a loop induces a circulating electric field — which drives a voltage:

$$
    \nabla \times \vec{E} = -\frac{\partial \vec{B}}{\partial t} 
    \tag{\text{Faraday}}
$$

The induced voltage $V_L$ is proportional to the rate of change of the aggressor's current:
$$
    V_L = -L_m \frac{dI_a}{dt}
$$

where $L_m$ is the mutual inductance between the two trace-return-plane loops. It depends on how much of the aggressor's $\vec B$ field threads through the victim's loop — set by the physical distance between traces, the height above the return plane, and the length of the parallel run.

Inductive crosstalk is worst where the return path is constrained. On a PCB with a continuous return plane, the return current mirrors directly under the trace, keeping the loop area small. But through connectors, packages, and vias, multiple signals often share a single return pin instead of a wide plane. The return currents are forced through a common impedance, the loop areas grow, and the mutual inductance between aggressor and victim increases sharply.


#### Both Matter

The capacitive and inductive coupled signals arrive at the victim differently:

- **Capacitive coupling** injects current into the victim trace. That current splits and travels in both directions — toward the near end and the far end. Both ends see a pulse of the same polarity.

- **Inductive coupling** induces a voltage that drives current in a specific direction (Lenz's law — opposing the change). The near end sees a pulse of opposite polarity to the aggressor; the far end sees a pulse of the same polarity.

At the **near end** (closest to the aggressor's source), the capacitive and inductive components have opposite polarity — they partially cancel. At the **far end**, they have the same polarity — they add. For long parallel runs on a microstrip, this is why far-end crosstalk (FEXT) often exceeds near-end crosstalk (NEXT); for short runs, NEXT still dominates.

---

### 1.5. Electromagnetic Interference

Sections §1.1 through §1.4 describe what happens when the EM field stays where it belongs — confined between a trace and its return plane. EMI is what happens when it escapes.

A current loop is an antenna. The power it radiates is proportional to the loop area $A$ and the square of the frequency $f$. For a small loop (perimeter ≪ wavelength), the radiated electric field at distance $r$ is:[^EMCLOOP]
$$
    E \;\propto\; \frac{f^2 \, A \, I}{r}
$$

Every signal on the board has a forward path (the trace) and a return path (the current in the return plane directly beneath it). When both paths are intact and close together, the loop area is tiny — just the trace length times the dielectric thickness. The fields from the forward and return currents are equal and opposite, and they cancel at a distance. Almost no energy escapes.

EMI appears when that cancellation breaks down:

- **Broken return path.** A slot in the return plane, a missing via at a layer transition, or a signal crossing between power islands forces the return current to detour. The loop area grows — and since radiated power scales with $A^2$, even a modest detour has outsized consequences.

- **Common-mode currents.** If the return current cannot mirror the signal current exactly — because of an asymmetry, a ground impedance, or a cable acting as a second antenna — the imbalance becomes a common-mode current. Common-mode currents flow on the outside of cables and along board edges, where there is no equal-and-opposite field to cancel them. Even a few microamps of common-mode current at VHF frequencies can exceed emission limits.

- **Board-edge fringing.** The EM field guided by a microstrip trace extends laterally beyond the trace edges. If a high-speed trace runs near the board perimeter, those fringing fields reach the edge of the return plane and radiate — there is no copper beyond the edge to contain them.

- **Connector and cable radiation.** Every conductor that leaves the board — a power cable, a sensor wire, a USB connection — is a potential antenna. The board's internal switching noise couples onto the cable as common-mode current, and the cable radiates it. This is typically the dominant EMI path in a system like OPNhydro, where multiple cables connect to off-board sensors and motors.

The physics comes from the same Maxwell's equations as §1.1. The difference is context: signal integrity asks whether the field arrives at the receiver correctly; EMI asks whether the field arrives somewhere it should not.

[^EMCLOOP]: Derived from the magnetic dipole radiation formula. The full expression includes constants ($\mu_0$, $c$), but the proportionality to $f^2$, $A$, and $I$ captures the design levers.



---

## 2. From Physics to Layout

Chapter 1 established how signals actually travel on a PCB — as EM waves guided by copper boundaries, with energy in the dielectric and currents as the electrons' response to the field. This chapter turns that physics into layout decisions.

The sections proceed from rules to physical build to final strategy:

- **§2.1** distils the field theory into layout rules covering signal quality, crosstalk, rail collapse, and EMI.
- **§2.2** explains the OPNhydro stack-up — a Low-EMI four-layer arrangement driven by the 4.7 A peak on the 24 V rail and the isolation moats around the pH and EC islands.
- **§2.3** specifies the dielectric and copper.
- **§2.4** separates the noisy motor-control, digital, and sensitive analog domains.
- **§2.5** covers enclosure and mechanical constraints.
- **§2.6** derives trace widths from current, impedance, and thermal limits.
- **§2.7** assembles all of the above into a concrete layout strategy.

Each rule in this chapter ties back to a specific result from Chapter 1. The aim is that no rule is a folklore prescription — every one has a physical reason behind it.


### 2.1. PCB Design Rules

Everything in §1.1 through §1.5 leads to a single conclusion: the signal energy travels as an EM wave through the dielectric, guided by the copper boundaries. The trace is one wall, the return plane is the other. The copper confines the field ($E_z$ cancellation), the dielectric carries it forward (displacement current), and the return current in the return plane provides the equal-and-opposite $\vec B$ that prevents radiation (field cancellation at a distance).

When that field structure breaks down, the consequences fall into four categories: degraded signal quality on a single net (reflections, ringing), crosstalk between adjacent nets (§1.4), rail collapse in the power distribution network (§1.3), and radiated EMI. Every PCB layout rule exists to prevent one or more of these — by keeping the field confined, the return path intact, and the coupling between unrelated fields to a minimum.

#### Signal Quality

A signal travelling along a trace is an EM wave guided by the trace and its return plane. Anything that disrupts the wave's propagation — an impedance discontinuity, a missing return path, a stub — causes part of the energy to reflect back toward the source. The reflected wave interferes with the forward wave, producing ringing, overshoot, and timing uncertainty on the net.

**Rule 1 — Maintain a continuous return plane.** The $\vec B$ field from the forward current in the trace and the return current in the return plane are equal and opposite. They cancel at a distance, keeping the energy confined. Gauss's law for magnetism ($\nabla \cdot \vec B = 0$) requires magnetic field lines to close: with a continuous plane, they close tightly. Interrupt the plane — a slot, a cutout, a missing pour — and the loop area grows, the impedance changes, and the wave partially reflects.

![Courtesy: Kenneth Wyatt, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/trace-crossing-gap-in-return-plane.png)

> "Forget the word ground. Every signal has a return path. Think return path and you will train your intuition to look for and treat the return path as carefully as you treat the signal path." -- Eric Bogatin

**Rule 2 — Provide return vias at layer transitions.** When a trace passes through a via, the EM wave transfers between layers. The wave is not just the trace — it is the field between the trace and its reference plane. If the return plane changes (say, from L2 to L3), the return current must also transition. Without a nearby ground via, the return path detours, the loop area grows, and the wave leaks between the return planes — causing both reflections on the signal net and interference with other signals in that space.

![Courtesy: Kenneth Wyatt, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/trace-passing-through-two-planes-with-via.png)

If the planes are the same potential, prevent leakage with nearby stitching vias between them. If they are different potentials, place stitching capacitors as close to the signal via as possible.

#### Crosstalk

Both coupling mechanisms — capacitive ($C_m$, from overlapping $\vec E$ fields) and inductive ($L_m$, from overlapping $\vec B$ fields) — depend on how much of the aggressor's field volume overlaps with the victim's. Every mitigation strategy reduces that overlap.

**Rule 3a — Increase trace spacing.** The fringing $\vec E$ field that causes capacitive coupling falls off roughly as $1/d^2$ with distance. The $\vec B$ field that causes inductive coupling falls off as $1/d$. The 3W rule (space traces at least 3× the trace width apart) is a practical approximation of this. For critical traces (analog sensors, clocks), use $5W$.

**Rule 3b — Minimise parallel run length.** Both $C_m$ and $L_m$ are proportional to the length over which two traces run in parallel. The coupling is cumulative — every millimetre of shared dielectric adds to the total. Where two sensitive traces must be routed near each other, cross them at 90° rather than running them in parallel.

**Rule 3c — Reduce trace height above the return plane.** The closer a trace is to its return plane, the more tightly the $\vec E$ and $\vec B$ fields are confined directly underneath. Less field energy spills sideways into the neighbouring trace's volume.

**Rule 3d — Interpose a return plane between signal layers.** A grounded conductor between two signal layers terminates $\vec E$ field lines from traces above (Gauss's law — the lines land on the return plane instead of reaching the layer below) and provides a local return path that contains the $\vec B$ field, blocking inter-layer coupling.

**Rule 3e — Separate functional domains.** Motor control traces and analog sensor traces must not share the same dielectric space. Keep traces on adjacent layers perpendicular to each other to minimise the parallel run length between layers.

#### Rail Collapse

Every time a chip switches, it draws a sharp current pulse from the power rail. That pulse passes through the inductance of the power distribution network, producing a voltage drop $\Delta V = L_{\text{PDN}} \times \frac{dI}{dt}$. The goal is to minimise the PDN inductance across the full frequency range the chip draws current at.

**Rule 4a — Tightly couple power and return planes.** A power plane and return plane separated by a thin dielectric (2–3 mil) form a parallel-plate capacitor with very low inductance. This provides broadband decoupling across the entire board area — the EM field between the planes can supply current before the discrete capacitors or the regulator can respond. This design uses two GND planes (L2, L3) with power routed as traces rather than a dedicated plane, so broadband plane decoupling is achieved through discrete capacitors instead (see §2.2).

**Rule 4b — Use multiple, low-inductance decoupling capacitors.** A single capacitor has parasitic lead and via inductance that limits its effectiveness above its self-resonant frequency. Multiple smaller capacitors in parallel reduce the effective inductance (inductances in parallel divide). Place them as close to the chip's power pins as physically possible — every millimetre of trace adds inductance.

**Rule 4c — Minimise power and ground lead length in packages.** The inductance of the bond wires and package leads between die and PCB is often the dominant contributor to $L_{\text{PDN}}$ at high frequencies. Packages with multiple, short power and ground pins (QFN, BGA) have lower inductance than those with long leads (SOIC, DIP).

**Rule 4d — Rely on on-chip decoupling for the highest frequencies.** Above ~100 MHz, no external capacitor can respond fast enough — the path inductance from capacitor to die is too high. Modern ICs include on-die decoupling for this reason. The PCB designer's job is to keep $L_{\text{PDN}}$ low at the frequencies below that.

#### EMI — Radiated Emissions

EMI is not a separate problem — it is the consequence of every other problem listed above. When a return path is broken, the $\vec B$ fields stop cancelling and the loop radiates. When crosstalk couples energy onto an unintended trace, that trace becomes an unintentional antenna. When a rail collapses, the transient current loop radiates at the switching frequency and its harmonics.

**Rule 5a — Minimise loop area.** Every current — signal, power, return — forms a loop. The radiated power from a loop is proportional to the loop area squared and to the frequency squared: $P_{\text{rad}} \propto A^2 f^2$. Keep traces close to their return planes. Use ground vias at every layer transition. Route power close to its return.

**Rule 5b — Contain the fields at board edges.** EM fields that reach the edge of the PCB can radiate freely — there is no conductor to confine them. Pull traces and pours back from the board edge by at least 20× the dielectric thickness (the 20H rule). Place ground stitching vias along the board perimeter to create a continuous shield.

**Rule 5c — Filter at I/O boundaries.** Every cable attached to the board is a potential antenna. Place filtering (ferrite beads, capacitors, common-mode chokes) at the point where signals enter or leave the board, before the field has a chance to propagate onto the cable.


---


### 2.2. PCB Stack-up

The PCB has two hard constraints that drive most of the other design decisions. First, the 4.7A peak current on the 24V rail requires copper heavy enough to carry that current continuously without excessive resistive heating. Second, the isolation moats around the pH and EC islands must be maintained through all four layers, which means the layer stack-up cannot be an afterthought.

The **typical 4-layer stack-up** is SIG/GND/PWR/SIG. This design does not use it for two reasons. First, the power and return planes would be separated by the full core distance — too far apart for effective high-frequency decoupling (2–3 mil max is needed). Second, signals on Layer 4 would be referenced to the power plane rather than GND, which only works if the power and return planes are tightly coupled with adequate decoupling capacitors.

Instead, we opt for the **Low EMI 4-layer stack-up** as shown below.

Layer | Name   | Function                         | Components
------|--------|----------------------------------|--------------------------
L1    | Top    | Sensitive signals / routed power | ESP32, LiDAR, I2C, UART, EZO, BNC, 3V3/5V power traces
L2    | GND    | Ground return plane              | Primary return reference for L1 signals
L3    | GND    | Ground return plane              | Primary return reference for L4 signals
L4    | Bottom | Noisy signals / routed 24V power | Stepper drivers, MOSFETs, 24V power traces

![Courtesy: Kenneth Wyatt, [PCB Design for Low EMI](https://www.protoexpress.com/webinars/pcb-design-for-low-emi/?watch-now)](../media/infographics/lower-emi-4-layer-pcb.png)


---


### 2.3. PCB Materials

The design specifies a **4-layer PCB with 2 oz copper on the outer layers**. The heavier copper on L1 and L4 keeps resistance and heat low on the high-current 24V traces. The two inner layers (L2 and L3) use standard 1 oz copper, which is sufficient for the return planes they carry.


**PCB finish:** HASL (Hot Air Solder Leveling) is sufficient and lowest cost. ENIG (Electroless Nickel Immersion Gold) is a worthwhile upgrade for the fine-pitch SSOP-20 pads of the ADM3260.



### 2.4. Segregating Functional Regions

The board layout separates functional domains to minimise coupling between noise sources and sensitive circuits:

1. Keep analog traces (EZO sensors, pH/EC probes) away from motor control and digital switching sections.
2. Place power conversion (buck converter) and motor control (TMC2209 drivers) near the power entry point, so high-current loops stay short.
3. Filter and transient-protect all power and I/O connectors at the board boundary.
4. Group all power and I/O connectors along one edge of the board where possible, to contain cable radiation (Rule 5c).


---


### 2.5. Enclosure and Mechanical

The board targets a ~100 mm × 80 mm footprint, which fits standard off-the-shelf enclosures. Recommended specifications:

- **Enclosure:** IP65-rated ABS, approximately 150 × 100 × 70 mm. The IP65 rating keeps moisture and insects out of the electronics.
- **Cable glands:** Use glands for every wire entering the enclosure — probe cables, pump leads, and the PSU input.
- **BNC connectors:** Mount three panel-mount BNC connectors on the enclosure face for the pH, EC, and RTD probes. Panel-mount rather than PCB-mount prevents mechanical stress on the isolation islands if a probe cable is tugged.
- **Optional:** A clear lid panel allows status LED visibility without opening the enclosure.


### 2.6. Trace Widths

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

The table below uses a conservative $ΔT = 10°\rm{C}$ (IPC-2221 permits 20°C for most PCB classes). The inner-layer widths assume 1 oz copper; the outer-layer widths assume 2 oz copper per §2.3. Power nets are routed on the outer layers in this stack-up (§2.2), so the inner-layer column is reference-only — a 200 mil inner trace at 1 oz carries only ~3.9 A, which is **not** sufficient for the 6.5 A peak on the 24 V input. If any power net must be routed internally, size from the external column or widen accordingly.

Net                     | Target Current    | Internal Trace Width | External Trace Width | Rationale
------------------------|-------------------|----------------------|----------------------|----------
24V input (PSU→TVS→RPP) | 6.5A (Peak)       | 5.0mm (200mil)       |  2.0mm (80mil)       | Reduce sag
24V main pump           | 1.2A (Continuous) | 1.0mm  (40mil)       |  0.4mm (15mil)       | Manage heat
24V each dosing pump    | 1.53A (Peak)      | 1.0mm  (40mil)       |  0.4mm (15mil)       | Lower inductance
24V ATO valve           | 0.3A (Peak)       | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum
5V rail (post-buck)     | 0.75A (Peak)      | 0.5mm  (20mil)       |  0.2mm  (8mil)       | Stable power
3.3V rail (post-LDO)    | 0.15A (Peak)      | 0.2mm   (8mil)       |  0.2mm  (8mil)       | Fab minimum


### 2.7. PCB Layout Strategy

- **Star power distribution** — Run a dedicated pair of 24V traces from the power entry connector directly to the stepper section, and a separate pair to the logic regulator. Do not daisy-chain power from the motors to the sensors.
- **Via stitching for high-current transitions** — When the 24V rail transitions between layers, use at least 3–4 vias per 2A connection. A single standard 10 mil via carries only 0.5–1A before excessive heating.
- **Antenna keep-out** — The return plane must not extend under the ESP32-C6 antenna keep-out area to ensure proper wireless performance.


---


## 3. Functional Areas


### 3.1. Power Distribution Network (PDN)

The PDN traces are transmission lines and require adjacent return planes. In this stack-up the GND planes (L2, L3) serve as return for both signals and power, provided power traces and sensitive-signal traces are spatially segregated on the shared layer (see §2.4).

Ferrite chokes should not be placed in the PDN — the design requires low target impedance throughout. The exception is filters for analog, RF, or PLL circuits, where isolation from switching noise takes priority over low impedance.


### 3.2. I2C Sensors

### 3.3. Peristaltic Pump Drivers

### 3.4. Main Pump and Valve Drivers

### 3.5. Water Level Sensor and Switches

### 3.6. SoC, Test Points and Fiducials




