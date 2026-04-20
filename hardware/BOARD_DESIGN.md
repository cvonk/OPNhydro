# Board Design Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, and follow-up to the Schematic Design document. It covers the Printed Circuit Board (PCB) selection and layout rules for **OPNhydro**.

As in the Schematic Design document, the central problem remains **coexistence**.
- On one side: a pH probe measuring millivolt-level electrochemical potentials and an EC probe — both requiring a clean, quiet supply.
- On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, a solenoid valve, and the ESP32 itself — which needs a clean supply but also generates digital switching noise and Wi-Fi TX bursts.

After the PCB selection and general layout rules, the document covers the different sections of the schematic.

Rather than presenting layout rules as a checklist to memorize, this guide starts from the underlying electromagnetic theory and derives the rules as consequences. It serves as a bridge between the high-level Architecture goals and the specific Schematic Design requirements.

Consider a puzzle. You flip a light switch, and the bulb lights up almost instantly. But if you could tag a single electron at the switch and watch it, you would find it drifting toward the bulb at roughly one meter per hour — the speed of a snail. At that rate it would take days to arrive. So what turned the light on?

Not the electrons. The electromagnetic field did. And once you understand that, PCB layout starts making intuitive sense.

<style>
  .quote {
  position: relative;
  width: 95%;
  padding-left:4% !important;
  /*margin: 0 auto;*/
  /*line-height: 1.4;*/
  z-index: 600;
  overflow: visible;
  /*background-color: #f6f6f6;*/
}
.quote:before {
  position: absolute;
  top: -0.25em;
  left: 0;
  z-index: -300;
  font-family: Georgia, serif;
  content: "\201C";
  color: #999;
  opacity: 0.3;
  font-size: 2.3rem;
  font-weight: 600;
  text-shadow: none;
}
.quote cite {
  color: #bbb !important;
  display: block;
  font-style: normal;
  font-weight: 400;
  text-align: right;
  line-height: 1;
}
</style>

---



---

## 3. Functional Areas


### 3.1. Power Distribution Network (PDN)

The PDN traces are transmission lines and require adjacent return planes. In this stack-up the GND planes (L2, L3) serve as return for both signals and power, provided power traces and sensitive-signal traces are spatially segregated on the shared layer (see §2.4).

Ferrite chokes should not be placed in the PDN — the design requires low target impedance throughout. The exception is filters for analog, RF, or PLL circuits, where isolation from switching noise takes priority over low impedance.


---


### 3.2. I2C Sensors

### 3.3. Peristaltic Pump Drivers

### 3.4. Main Pump and Valve Drivers

### 3.5. Water Level Sensor and Switches

### 3.6. SoC, Test Points and Fiducials




<figure>
  <center>
  <img src="../media/infographics/signal-propagating-along-microstrip.png" style="width: 80%; height: auto;">
  <figcaption><i>Signal propagating along a microstrip.<br />(Courtesy: Kenneth Wyatt)</i></figcaption>
  </center>
</figure>

