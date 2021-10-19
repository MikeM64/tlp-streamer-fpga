# PCIe TLP Streamer

## Architecture

### HW:
PCIe (Target) <=> FPGA <=> FT601 <= (USB3) => Host Computer

### SW:
FT601 Driver <=> Server Process <= (UDP Socket) => Client

## Functionality

Client could be any PCIe emulator:
  - NVMe
  - Ethernet
  - Etc...

## Requirements
  - MUST be able to handle both regular and config TLPs
  - MAY be hot-restart capable to change VID/PID/device class from the client software (dependent on FPGA support)

## Open Tasks
  - FT601 USB Loopback

## Design
### USB to FPGA Design
The FT601 supports both synchronous single-channel and multi-channel operation. Maximum of 8 channels - 4 IN and 4 OUT.

Does it make sense to use the multi-channel feature here? One per PCIe data, PCIe config, board config/mgmt.

Pros:
  - Don't need to decode part of the user packet in HW to determine where the data is supposed to go

Cons:
  - More complex software to manage where to send the packet
  - More complex bus interactions with the FT601

Neutral:
  - More FIFO resources needed to buffer the three channels (turns out that an RX buffer for each channel is still needed to quickly drain the FT601 FIFO buffer)

Questions:
  - Is the screamer wired up for multichannel FIFO?
  - Are the FT601 GPIOs writeable from the FPGA or are they hardwired to a specific config?
  - Is it cheaper to decode part of the user packet to determine where to send it or cheaper to implement multi-channel FIFOs?

**It probably doesn't make sense when starting out to go multi-channel. The design should be modular enough to go multi-channel if required.**

To start, implement a loopback on the USB3 side (which can be kept for later debugging)

### FPGA Design
#### USB Loopback
FT601 => FIFO => FT601 is the goal

The 245 bus mode on the FT601 has the following read state machine. All FT601 signals change on the negative clock edge.
1. Idle
2. RX FIFO Full (at RXF_N from FT601)
3. Controller FIFO Ready (at FIFO ready from controller)
4. Read word
5. Transfer Complete

#### Configuration Block
This block manages configuration of the FPGA device. It manages the following features:
  - FPGA hot reset for PCIe reconfiguration
  - USB loopback enable/disable
  - PCIe attributes that may be changed dynamically

Q: Should all other requests be stopped during a config change?
Q: Should the in-flight requests be handled first without starting any new ones?

#### PCIe Data Management
This block manages regular TLP transfers to and from the PCIe IP. It needs to pull data and feed the FIFO in front of the FT601.

#### PCIe Configuration Management
This block manages configuration TLP transfers to and from the PCIe IP. It also needs to pull data and feed the FIFO in fron of the FT601 at a higher priority than regular data traffic.
