# ARC4 Decryption Hardware Accelerator

## Overview

This project implements a **hardware accelerator for ARC4 decryption and brute-force key search** on FPGA. The design is written in **SystemVerilog** and targets high throughput via **clock-rate optimization and massive parallelism**.

The accelerator implements the full ARC4 algorithm (state initialization, key-scheduling, and pseudo-random generation) and extends it with **parallel cracking cores** that autonomously search the key space. The design was optimized using a **PLL-generated 125 MHz clock** and scaled to **110 concurrent cracking cores**, achieving substantial speedup over a single-core implementation.

---

## Key Features

- **Full ARC4 hardware implementation**
  - State initialization (S-box setup)
  - Key-Scheduling Algorithm (KSA)
  - Pseudo-Random Generation Algorithm (PRGA)
  - Length-prefixed plaintext handling

- **Parallel brute-force cryptanalysis**
  - Autonomous key search without CPU intervention
  - ASCII-valid plaintext detection in hardware
  - Early termination on successful decryption

- **High-performance FPGA optimization**
  - PLL-generated **125 MHz internal clock**
  - Scaled to **110 parallel cracking cores**
  - Deterministic speedup proportional to core count

- **Modular architecture**
  - Ready/enable microprotocol for variable-latency modules
  - Clean separation between datapath, control FSMs, and memory arbitration
  - Scalable design parameterization

---

## Architecture Overview

At a high level, the system consists of:

- **ARC4 Core**
  - Dedicated FSMs for `init`, `ksa`, and `prga`
  - On-chip RAM for ARC4 state (`S`), ciphertext (`CT`), and plaintext (`PT`)

- **Cracking Engine**
  - Iterates over the 24-bit key space
  - Validates decrypted output using printable ASCII constraints
  - Signals success and outputs the recovered key

- **Parallel Controller**
  - Instantiates up to **110 cracking cores**
  - Distributes disjoint key ranges across cores
  - Handles memory sharing and result arbitration

- **Clocking**
  - External FPGA clock → **PLL → 125 MHz**
  - Internal logic optimized to meet timing at high fan-out

---

## Performance

| Configuration | Clock | Cores | Notes |
|--------------|-------|-------|------|
| Baseline | 50 MHz | 1 | Functional reference |
| Optimized | 125 MHz | 1 | PLL-accelerated |
| Parallel | 125 MHz | 110 | Full parallel cracking |

The final design achieves **orders-of-magnitude acceleration** over a naïve single-core hardware implementation and is suitable for demonstrating FPGA-based cryptographic acceleration and parallel search architectures.

---

## FPGA Toolchain

- **HDL:** SystemVerilog
- **Synthesis & Implementation:** Intel Quartus Prime
- **Simulation:** ModelSim / Questa
- **Target Platform:** Intel Cyclone-series FPGA
- **Clocking:** PLL-generated internal clock

---

## Repository Structure

.
├── src/            # RTL modules (ARC4, crack, multicore logic)
├── tb/             # RTL and post-synthesis testbenches
├── constraints/    # Timing and clock constraints
└── README.md

> Generated FPGA build artifacts are intentionally excluded from version control.

---

## Technical Highlights

- Demonstrates **fixed-function hardware acceleration**
- Shows practical **FPGA clock-domain optimization using PLLs**
- Illustrates **scalable parallelism** without software scheduling
- Emphasizes **clean control/data separation** and memory-centric design

---

## Disclaimer

ARC4 is considered cryptographically insecure and is used here **strictly for educational and architectural exploration purposes**, particularly to study hardware acceleration, parallel cryptanalysis, and FPGA design techniques.

---

## Author

**Jerome Wong**
Electrical Engineering  
FPGA / Digital Systems / Hardware Acceleration
