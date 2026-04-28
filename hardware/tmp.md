##### Boundary-condition view 1

Consider the EM wave traveling, through the dielectric, in the $+z$ direction at speed $v$. Ahead of the front, $E_x = 0$. Behind the front, we have $E_x$. At the front, there is a "sheet" of surface charge $\sigma_s$ to terminate the field lines of $E_x$ as we saw before.

**Wavefront constraint.** Because the wave moves at speed $v$ without changing shape, the field follows the form $E_x(z-vt)$. This links the change in time to the change in space:
$$
  \frac{\partial E_x}{\partial t} = -v\, \frac{\partial E_x}{\partial z}
$$

**Gauss's law** sets the surface charge density at the wavefront:
<div class="quote">

$$
    \sigma_s = \varepsilon\, E_x, \quad \text{in }\left[ \rm{C/m^2} \right]
$$
</div>

**Charge conservation** on the trace surface relates the surface current $K_z$ (arriving from behind the wavefront) to the rate at which $\sigma_s$ is being deposited at the front:
$$
  \frac{\partial K_z}{\partial z} + \frac{\partial \sigma_s}{\partial t} = 0
$$

Apply the wavefront constraint to $\partial \sigma_s/\partial t$:
$$
    \frac{\partial K_z}{\partial z} = -\frac{\partial \sigma_s}{\partial t} = v\, \frac{\partial \sigma_s}{\partial z}
$$

Integrate (with $K_z = 0$ ahead of the wavefront, where $\sigma_s = 0$):
$$
    K_z = v\, \sigma_s = \varepsilon\, v\, E_x, \quad \text{in }\left[ \rm{A/m} \right]
$$


----

The wave's electric and magnetic field amplitudes are not independent — they are locked together by the wave speed (Appendix A.3):
<div class="quote">

$$
    E_x = v\,B_y \tag{TEM ratio}
$$
</div>

Substituting $B_y = E_x / v$ for the RHS in the $K$ equation:
$$
  K_z = \frac{(E_x/v)}{\mu} = \frac{E_x}{\mu v}
$$

Recall Gauss's law applied to a thin pillbox straddling the conductor surface, the surface charge density $\sigma_s$:
<div class="quote"">

$$
  \sigma_s = \varepsilon\, E_x
$$
</div>

Substitude $E_x = \sigma_s / \varepsilon$ in the last $K_z$ equation
$$
  K_z = \frac{(\sigma_s / \varepsilon)}{\mu v}
$$

$$
  \newcommand{\shaded}[1]{\colorbox{##F7F7D2}{$\displaystyle #1$}}
  K_z = \frac{\sigma_s}{\mu\varepsilon v}
$$


**Cross-check.** The Ampère result $K_z = B_y/\mu$ and the continuity result $K_z = v\,\sigma_s$ are the same statement, once you use the TEM ratio $E_x = v\,B_y$ and Gauss's law $\sigma_s = \varepsilon E_x$:
$$
    K_z = \frac{B_y}{\mu} = \frac{E_x}{\mu v} = \varepsilon\, v\, E_x = v\,\sigma_s
$$
Ampère, Gauss, charge conservation, and the wave's $|\mathbf E|/|\mathbf B|$ ratio all agree on the same surface current.


---

**The TEM ratio.** The wave's electric and magnetic field amplitudes are not independent — they are locked together by the wave speed (Appendix A.3):
<div class="quote">

$$
    E_x = v\,B_y \tag{TEM ratio}
$$
</div>


---

<figure>
  <center>
  <img src="../media/infographics/microstrip-fields-2.png" style="width: 40%; max-width:400px; height: auto;">
  <figcaption><i>Cross-section view of Microstrip fields.<br />(Courtesy: Patrick André)</i></figcaption>
  </center>
</figure>

> **A note on field lines.** Textbook diagrams show fields as lines with arrows. These *field lines* are a visualization invented by Faraday, not physical objects. They are drawn by stepping from point to point in the direction the field vector points, with line density representing field strength. The field itself exists at *every* point in space — between the lines too. Where this document says "the $\mathbf E$ field points downward" or "the $\mathbf B$ field curls around the trace," it is shorthand for: the field vector at each point in that region has that direction and magnitude.

---

