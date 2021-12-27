# TLP Streamer
## Overview
This project is a PCIe TLP Streamer intended to support device emulation from an attached host computer.

Please refer to [system_design.md](docs/system_design.md) for details of the design.

The current board target is the [Screamer M.2](https://shop.lambdaconcept.com/home/43-screamer-m2.html) from LambdaConcept.

## Progress
 - [x] - FT601 RX/TX Loopback
 - [ ] - Host Packet RX Dispatch
 - [ ] - FPGA Packet TX Arbitration
 - [x] - PCIe Link Up
   - [ ] - PCIe configuration space R/W
   - [ ] - PCIe TLP R/W
   - [ ] - Host software
