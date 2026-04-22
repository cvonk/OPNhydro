#### Vertical Component $E_z$

As the wave front reaches a section of the conductor, $E_z$ there rises from zero to some value. The force on an electron is $\mathbf F = (-e)\,\mathbf E$, where $e \approx 1.602 \times 10^{-19}$ C is the elementary charge; the minus sign reflects the electron's negative charge and flips the force opposite to $\mathbf E$.

With $E_z$ pointing from trace down to return plane, electrons in *both* conductors are pushed *upward*:
- *in the trace*, they move away from the dielectric-facing surface, leaving it positively charged;
- *in the return plane*, they move toward the dielectric-facing surface, making it negatively charged.

The local redistribution of charge caused by $E_z$ charges the distributed capacitance of the line.

The result is a pair of opposite surface charges that act like a parallel-plate capacitor. Inside each conductor, the field from the nearby surface charge opposes the incoming $E_z$ — pointing upward in the trace (away from the positive surface) and downward in the return plane (away from the negative surface). The electrons keep moving until their self-generated field exactly cancels the incoming field, driving the net $\mathbf E$ inside the metal to zero.

<figure>
  <center>
  <img src="../media/infographics/microstrip-ez-confinement.svg" style="width: 100%; height: auto;">
  <figcaption><i>Microstrip E<sub>z</sub> confinement.</i></figcaption>
  </center>
</figure>

The cancellation happens almost instantly. What little field penetrates the metal decays within one skin depth $\delta = \sqrt{2/(\omega \mu \sigma)}$ (~66 µm at 1 MHz, ~2 µm at 1 GHz). 

Because the field cannot extend into the copper, it is forced to remain in the dielectric between the two conductors. This is what **confines the wave**: without the electron response, the field would radiate away instead of propagating along the line.

**Assuming no stray field above the trace**, the displaced electrons don't accumulate on the top surface — there is no field above to demand a charge there. They drain out of this section **horizontally** instead, flowing back along the trace toward the source. This horizontal outflow *is* the transmission-line current in the trace, driven by the horizontal field component $E_x$ examined in the next subsection. The return plane sees the mirror picture: the electrons that accumulate on its top (dielectric-facing) surface flow in horizontally from the source side along the return plane.


---

These charges don't appear by electrons moving vertically within each conductor. They appear via **horizontal** flow along the line:
- *in the trace*, electrons drain out of this section along the trace, flowing back toward the source — the depletion leaves a net positive charge on the bottom surface;
- *in the return plane*, electrons arrive at this section from the source side, piling up on the top surface as the negative charge.

This horizontal electron flow *is* the transmission-line current, driven by the small horizontal field $E_x$ examined in the next subsection. The accumulating surface charge charges the distributed capacitance of the line.


---
#### Horizontal Component $E_x$

So far we have described how $E_x$ arises at the wavefront itself. But the conductor is resistive, and that changes the picture behind the wavefront as well.

The drifting electrons scatter off nuclei, converting drift kinetic energy to lattice vibrations (heat). This is a drag force opposing the current. If nothing compensated for this drag, the current would decay. But the current can't just decay — the wavefront is still advancing, still demanding current to charge the next section. So the system has to sustain it. Here's how:

The scattering drains energy from the wave. That means the wave amplitude (voltage) drops slightly with distance along the line. A voltage that decreases with $x$ means there's a spatial gradient — the same relation as before, now in a different context:
$$
    E_x = -\frac{\partial V}{\partial x}
$$

This $E_x$ is what re-accelerates the electrons against the drag.

The resistance is the root cause. $E_x$ is the system's response to resistance — the "cost" of pushing current through a lossy conductor. On a superconducting line (no scattering), there would be no drag, no voltage drop, no $E_x$, and no loss.

**Behind the wavefront**, the surface charge at any given section is already established. But current still flows through those sections — not to charge them, but to supply the wavefront that's still advancing ahead.

Think about what happens at the wavefront right now, at section $x_3$:
- $E_z$ pushes electrons upward in the trace → bottom surface becomes positive (electron deficit).
- Those displaced electrons don't pile up at the top — they flow back through the conductor toward the source
- That flow of electrons through all the sections behind the wavefront is $J_{fwd}$.

So each already-charged section behind the wavefront is acting as a conduit. Its own surface charges are set, but current passes through it to feed the front. It's like a pipe that's already full of water — water still flows through it to supply whatever is at the end.

The moment the wavefront stops advancing (reaches a matched load), the current doesn't vanish — it continues, now supplying the load instead of charging new sections.

This also clarifies why "surface charge established" and "current flowing" aren't contradictory. In any DC circuit, the wire has stable surface charges (they guide the current), yet current flows through it continuously. The transmission line behind the wavefront is in exactly that state — a quasi-DC condition where the surface charges steer the current, and $E_x$ sustains it against resistive drag.
