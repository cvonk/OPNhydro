# Bill of Materials (BOM)

## Summary

| Category | Budget Option | Recommended Option |
|----------|---------------|-------------------|
| Microcontroller | $8 | $8 |
| Power Management | $12 | $15 |
| Sensors | $80 | $180 |
| Actuators | $45 | $65 |
| Connectors & PCB | $25 | $40 |
| Enclosure | $15 | $25 |
| **Total** | **~$185** | **~$333** |

---

## Microcontroller Module

| Qty | Part | Description | Budget Source | Price |
|-----|------|-------------|---------------|-------|
| 1 | ESP32-C6-WROOM-1-N8 | WiFi 6 + BLE 5 module, 8MB flash | LCSC, Digikey | $4-8 |

Alternative: ESP32-C6-DevKitC-1 ($10-15) for prototyping without custom PCB.

---

## Power Management

| Qty | Part | Description | Notes | Price |
|-----|------|-------------|-------|-------|
| 1 | XL4015 module | 24V→12V buck, 5A | Dosing pumps | $3 |
| 1 | MP1584EN module | 24V→5V buck, 3A | Logic power | $2 |
| 1 | AMS1117-3.3 | 5V→3.3V LDO, 1A | ESP32 power | $0.50 |
| 1 | B5819W | Schottky diode, reverse protection | Or SS54 | $0.20 |
| 1 | SI2301 | P-MOSFET, reverse polarity | SOT-23 | $0.30 |
| 2 | 100µF/35V | Electrolytic capacitor | Input/output | $0.50 |
| 4 | 10µF/25V | Ceramic capacitor | Decoupling | $0.40 |
| 1 | 5.5×2.1mm jack | Barrel connector, panel mount | 24V input | $1 |
| 1 | PTC fuse 2A | Resettable fuse | Protection | $0.50 |

**Subtotal: ~$8-15**

---

## Sensors

### Water Quality (Recommended: EZO-compatible I2C circuits)

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 1 | Atlas Scientific EZO-pH | pH circuit, I2C | Atlas Scientific | $42 |
| 1 | Atlas Scientific EZO-EC | Conductivity circuit, I2C | Atlas Scientific | $42 |
| 1 | Atlas Scientific EZO-DO | Dissolved oxygen circuit | Atlas Scientific | $48 |
| 1 | pH Probe | Lab grade, BNC | Atlas / Amazon | $20-80 |
| 1 | EC Probe K=1.0 | Conductivity probe | Atlas / Amazon | $15-60 |
| 1 | DO Probe | Galvanic DO probe | Atlas Scientific | $108 |

**Budget Alternative: DFRobot or Keyestudio**

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 1 | DFRobot SEN0161-V2 | Gravity pH sensor kit | DFRobot | $30 |
| 1 | DFRobot DFR0300 | Gravity EC sensor kit | DFRobot | $35 |
| 1 | Generic DO kit | Analog DO sensor | AliExpress | $25 |

### Environmental

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 2 | DS18B20 waterproof | Water temperature probe | Amazon | $3 ea |
| 1 | BME280 module | Temp/humidity/pressure | Amazon/AliExpress | $4 |
| 1 | BH1750 module | Light intensity (lux) | Amazon/AliExpress | $2 |
| 1 | HC-SR04 | Ultrasonic distance | Amazon/AliExpress | $2 |
| 2 | Float switch | Water level, vertical | Amazon | $3 ea |

**Sensors Subtotal: $80-180**

---

## Actuators

### Main Circulation Pump

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 1 | 24V DC pump | Brushless, 800L/H min | Amazon/AliExpress | $15-25 |

Recommended models:
- Jebao DCP series (controllable)
- Generic brushless 24V submersible

### Dosing Pumps

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 4 | Peristaltic pump 12V | ~100mL/min, 3mm tubing | AliExpress | $6-12 ea |

Recommended:
- Kamoer KFS (quality, $20 ea)
- Generic 12V peristaltic (budget, $6 ea)

**Actuators Subtotal: $45-65**

---

## Pump Driver Components

| Qty | Part | Description | Notes | Price |
|-----|------|-------------|-------|-------|
| 5 | IRLZ44N | N-MOSFET, logic level | TO-220 | $0.50 ea |
| 5 | 10kΩ resistor | Gate pull-down | 0805 | $0.05 ea |
| 5 | 100Ω resistor | Gate series | 0805 | $0.05 ea |
| 5 | 1N5819 | Flyback diode | DO-214 | $0.10 ea |

**Subtotal: ~$5**

---

## Connectors

| Qty | Part | Description | Notes | Price |
|-----|------|-------------|-------|-------|
| 5 | Screw terminal 2P | 5.08mm pitch | Pumps | $0.30 ea |
| 3 | BNC panel mount | For probes | pH/EC/DO | $2 ea |
| 4 | JST-PH 4P | I2C sensors | Qwiic compat | $0.20 ea |
| 2 | JST-PH 3P | 1-Wire, float | | $0.15 ea |
| 1 | JST-XH 4P | Ultrasonic | | $0.20 |
| 1 | USB-C receptacle | Programming | Mid-mount | $0.50 |
| 1 | 4-pin header | OLED display | 2.54mm | $0.20 |

**Subtotal: ~$10**

---

## PCB Fabrication

| Item | Description | Source | Price |
|------|-------------|--------|-------|
| PCB | 100×80mm, 2-layer, 5pcs | JLCPCB | $5-10 |
| Assembly | Optional SMT assembly | JLCPCB | $15-30 |

**Subtotal: $5-40**

---

## Enclosure

| Qty | Part | Description | Source | Price |
|-----|------|-------------|--------|-------|
| 1 | ABS enclosure | 158×90×60mm, IP65 | Amazon/AliExpress | $8-15 |
| 6 | Cable gland PG7 | Waterproof cable entry | Amazon | $0.50 ea |
| 3 | BNC bulkhead | Panel mount adapters | Amazon | $2 ea |

**Subtotal: $15-25**

---

## Optional Accessories

| Qty | Part | Description | Price |
|-----|------|-------------|-------|
| 1 | SSD1306 OLED 0.96" | Local status display | $4 |
| 1 | WS2812B LED | Status indicator | $0.50 |
| 1 | Buzzer (passive) | Alarm notification | $0.50 |
| 1 | 24V 3A power supply | Mean Well or equiv | $15-25 |
| 4 | Silicone tubing 3mm | Dosing pump tubing, 1m each | $2/m |
| 1 | Calibration solutions | pH 4, 7, 10 + EC standards | $15-25 |

---

## Recommended Vendors

| Vendor | Best For | Notes |
|--------|----------|-------|
| LCSC | Components, ESP32 modules | Cheap shipping to CN/EU/US |
| Digikey/Mouser | Quality components | Fast US shipping |
| Atlas Scientific | Water quality sensors | Premium quality |
| DFRobot | Budget sensors | Good documentation |
| AliExpress | Modules, enclosures | 2-4 week shipping |
| Amazon | Quick delivery items | Higher prices |
| JLCPCB | PCB fab + assembly | Best value for prototypes |

---

## Purchasing Notes

1. **Start with DevKit**: Use ESP32-C6-DevKitC for initial prototyping before committing to custom PCB.

2. **Sensor Quality Matters**: For pH and EC, cheap sensors drift quickly. Budget sensors are OK for learning but plan to upgrade.

3. **Probe Lifespan**:
   - pH probes: 1-2 years typical
   - EC probes: 2-5 years
   - DO membranes: 6-12 months

4. **Tubing**: Use only food-grade silicone for dosing pumps. Cheap tubing degrades with nutrients/acids.

5. **Power Supply**: Don't skimp on the 24V supply. A quality Mean Well supply prevents noise issues.
