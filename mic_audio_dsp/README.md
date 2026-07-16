# MVSilicon BP1048B1 / BP1048B2 Audio DSP for Amateur Radio

This repository documents my work on adapting the inexpensive **MVSilicon BP1048B1** and **BP1048B2** Bluetooth Audio DSP modules as standalone **microphone audio processors** for amateur radio.

The goal is to obtain high-quality microphone processing (EQ, compression, noise suppression, exciter, etc.) without requiring a Windows PC running software such as Voice Shaper.

> **Disclaimer**
>
> This is an unofficial reverse-engineering project. None of the documentation is mine. Credit belongs to the original manufacturers and authors. This repository simply collects publicly available information together with my own findings and experiments.

---

# Why?

A few months ago I discovered **Voice Shaper**, an interesting DSP application by DXAtlas.

https://www.dxatlas.com/VShaper/

Video tutorial:

https://www.youtube.com/watch?v=VpiIqWhXbqk

Although the project is rather old, it demonstrates how proper audio processing can dramatically improve speech intelligibility under QRN and QRM conditions through:

- Equalization
- Dynamic compression
- Automatic voice adaptation

The only drawback is that it requires:

- Windows PC
- Sound card
- Dedicated microphone

I started wondering whether something similar could be built as a **small standalone hardware device** sitting directly between the microphone and the transceiver.

That search eventually led me to the MVSilicon BP1048 DSP family.

---

# Supported boards

## BP1048B1

![BP1048B1](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/BP1048B1_img.png)

## BP1048B2

![BP1048B2](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/BP1048B2_img.png)

Both boards cost around **10–20 €** and already include a surprisingly capable audio DSP.

---

# Repository contents

- Schematics
- Datasheets
- ACP Workbench documentation
- SDK
- Hardware modifications
- AUX input enable procedure
- Electret microphone connection
- DSP configuration examples
- Example processing presets (coming soon)

---

# Documentation

## BP1048B1 schematic

https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/BP1048B1_schematics.pdf

## BP1048B1/BP1048B2 connection schematic

https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/BP1048B2_schematics.pdf

## English datasheet

https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/MVSilicon_BP1048B2_ENG.pdf

## ACP Workbench manual

https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/ACPWorkbench_USER_MANUAL_Version_2.21.6.pdf

## BP1048B1 SDK

https://github.com/leadercxn/bp1048_sdk_v0.1.12/tree/master/MVsB1_Base_SDK

---

# Main differences

## BP1048B1

- Fewer DSP effects
- Supports TWS (True Wireless Stereo)

## BP1048B2

- Significantly more DSP effects
- Supports external potentiometers for real-time parameter adjustment

Both provide analog audio inputs, making them excellent candidates for microphone processing.

---

# Where to buy

## BP1048B1

Approximately **10 €**

https://it.aliexpress.com/item/1005010569429082.html

## BP1048B2

Approximately **11 €**

https://it.aliexpress.com/item/1005009652509097.html

---

# Enabling the AUX input

While studying the schematics I noticed something interesting.

Both boards physically contain dedicated microphone inputs.

However, the firmware keeps them disabled.

Initially I considered modifying the firmware, but after examining the SDK it became clear that this would require considerable work.

There is also a karaoke board based on the BP1048B2 (ZK-1001UM) which actually uses these microphone inputs.

https://it.aliexpress.com/item/1005009477052647.html

Using that firmware might be possible, but I decided to look for a simpler solution.

Eventually I returned to the AUX input.

After several days of testing—and after translating the original Chinese schematic—I discovered that enabling AUX input requires only a single modification:

**Connect the M (Mute) pin to GND.**

After doing so, AUX input becomes fully operational.

![Enable AUX](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_M_enable_auxin.jpeg)

---

## Electret microphone connection

The electret microphone is powered from the board's **AVDD 3.3 V** supply.  
A **1 kΩ resistor** and **10 µF capacitor** form a simple supply filter.

```text
AVDD 3.3 V
    │
   R1 1 kΩ
    │
    ●──────────── R2 4.7 kΩ ─────────── MIC OUT +
    │                         │
  + │                         └──── AUX / LINE IN L
  10 µF
  - │
    │─────────────────────────────── MIC OUT -
   GND
```

The **10 µF capacitor is connected between the output of the 1 kΩ resistor and ground**:

- Capacitor positive terminal → filtered 3.3 V node
- Capacitor negative terminal → GND
- 4.7 kΩ resistor → between the filtered supply and microphone output node
- Microphone output node → AUX / LINE IN Left

Values between **2.2 kΩ and 10 kΩ** for R2 also work.

If you're using an external microphone preamplifier, connection is even simpler:

- AUX Left
- GND

That's all.

An external preamp generally provides better audio quality because the onboard 3.3 V supply carries some digital noise from the Bluetooth circuitry and the 24 MHz crystal oscillator.

The 10 µF capacitor significantly reduces this noise and provides a good compromise for a minimal circuit.

Prepared boards:

![Boards](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_e_B2_img.jpeg)

---

# ACP Workbench configuration

![ACP](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_ACP_img.png)

ACP Workbench is not particularly well documented, but for microphone processing only a few blocks are important.

Use:

**PGA0**

Do **not** use PGA1.

PGA1 corresponds to the hardware microphone inputs, which remain disabled in the standard firmware.

Recommended parameters:

- ADC0 Line_4_5 → Analog gain
- ADC0 Gain → ADC gain
- DAC0 Digital → Final output level

I personally use only **DAC0 (left channel)**.

DAC1 includes a hardware low-pass filter, making DAC0 the cleaner choice.

---

# Available DSP effects

![DSP Effects](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_audio_effects_img.png)

The most useful effects for amateur radio are:

- Equalizer
- Dynamic Range Compressor (DRC)
- Noise Suppression
- Exciter
- Wet/Dry controls

These are conceptually similar to the processing performed by Voice Shaper.

---

# Compressor

![DRC](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_ACP_DRC_img.png)

---

# Equalizer

![EQ](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B1_ACP_EQ_img.png)

---

# BP1048B2 advantages

The BP1048B2 includes many more DSP blocks.

![Effects](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B2_list_of_effects.png)

One particularly useful feature is real-time control of DSP parameters using external potentiometers.

For example:

- PRE EQ F1
- PRE EQ F2

can be adjusted directly from the front panel between **−12 dB and +12 dB**.

![Potentiometer](https://github.com/miladinovic/share/raw/refs/heads/main/mic_audio_dsp/B2_pot_pre_eq.png)

This makes it easy to adapt your transmit audio:

- Increase presence for DX work
- Reduce emphasis during local QSOs

The BP1048B1 offers similar flexibility through stored presets, while the BP1048B2 allows continuous adjustment.

---

# Future work

The following will be added to this repository:

- Optimized DSP presets for SSB
- Optimized DSP presets for FM
- Audio comparison recordings
- Recommended compressor settings
- Equalizer presets
- Noise suppression tuning
- Complete microphone interface schematics

---

# Contributions

If you have additional documentation, firmware information, ACP projects, or hardware modifications, feel free to open an issue or submit a pull request.

The goal is to build the most complete English-language resource for the BP1048 DSP family.
