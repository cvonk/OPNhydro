When a **voltage step** is applied at the the left end, the following chain of events unfolds:

1. The sudden voltage change creates an **electric field** $\mathbf{E}$ between the trace and the return plane, pointing vertically (from trace down to return plane). $\mathbf{E}$ is called a vector field because it has an intensity and direction at every point in space. Initially, this electric field exists only near the source end of the microstrip, but it cannot remain localized. 
<br />

2. The moment the $\mathbf E$-field appears, it is rising from zero → **changing in time**. According to Ampère-Maxwell's Law, a time-changing electric field $\mathbf E$ (right hand side) **forces the magnetic field $\mathbf B$ to vary spatially** (LHS).
<br />

3. The $\mathbf B$-field created in step 2 is also rising from zero → **changing in time** (RHS). According to Faraday's Law this time-changing magnetic field **forces the electric field $\mathbf E$ to vary spatially** (LHS) — extending $\mathbf E$ slightly ahead of where it began.

The electric field $\mathbf E$ points vertically (trace to return plane), but its magnitude changes as you move horizontally along the trace — field direction and variation are perpendicular. That is a wave front advancing.

Maxwell's curl equations link the two: a time change *here* forces a spatial difference *here*, which means the neighboring point has a different value, which forces *it* to change in time, and so on. A field that changed only in time would just pulse in place; one that changed only in space would be a frozen pattern. It is the coupling — time-derivative on one side, spatial-derivative on the other — that makes the disturbance *move*.

**To summarize:** once the electric field appears, a magnetic field arises alongside it. That changing magnetic field extends the electric field slightly ahead, which in turn extends the magnetic field further still. **Each field regenerates the other**. The wave is self-sustaining — it needs no electrons to carry it forward.


This continuous coupling between $\mathbf{E}$ and $\mathbf{B}$ fields, guarantees indefinite propagation. This is essential, so we'll describe this coupling once more.

As we have seen, in the source-free dielectric, the two laws simplify to:

$$
  \begin{align}
    \nabla \times \mathbf{B} &= \color{red}\cancel{\color{black}\mu \, \mathbf{J}} \color{black} + \mu\,\varepsilon \frac{\partial \mathbf{E}}{\partial t}
    \tag{\text{source-free Ampère-Maxwell}} \\
    \nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t}
    \tag{\text{Faraday}}
  \end{align}
$$

These two equations **couple time variation to spatial variation** — and that coupling is what makes propagation inevitable. For more details, refer to Appendix A.

So, if $\mathbf E$ is changing in time at some point, the Ampère-Maxwell equation forces $\mathbf B$ to have a spatial gradient there — so $\mathbf B$ at the neighboring point is different. At that neighboring point, $\mathbf B$ is now changing in time, and by the second equation this forces spatial variation in $\mathbf E$ — so $\mathbf E$ at the *next* point is different. And so on.
