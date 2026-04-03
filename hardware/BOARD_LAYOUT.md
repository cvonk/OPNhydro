# Board Layout Guide

This is the second document that answers **"How?"** — the companion to the Architecture document, which answers "Why?". It covers the Printed Circuit Board (PCB) layout rules for the **OPNhydro** board.

As in the Schematic Design document, the central problem remains **coexistence**.
- On one side: a pH probe measuring millivolt-level electrochemical potentials, an EC probe and an ESP32 that needs a clean analog reference. 
- On the other: three stepper drivers chopping current at 20–50 kHz, a buck converter switching at 1 MHz, and a solenoid valve slamming on and off.

Everything shares the same board. The sections that follow explain how the design lets these worlds coexist.

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


## 1. Stability Under Peak Loads

---

## 2. Integration of Precision Dosing and EMI Mitigation

---

## 3. Maintaining Signal Integrity via Isolation


