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
  - MUST have counters available for debugging and statistics (USB Packet RX/TX, PCIe TLP RX/TX, etc...)
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

### FPGA Design
#### USB Loopback
FT601 => FPGA => FT601 is implemented in order to verify the USB comms channel.

##### USB Packet RX
The 245 bus mode on the FT601 has the following read state machine. All FT601 signals change on the negative clock edge and should be clocked on the positive edge.

1. `BUS_IDLE`
  - The default state of the bus
  - This will transition to either `RX_READY` or `TX_READY` depending on which signal is asserted by the FT601. `BUS_IDLE` will also check the state of the RX/TX FIFO to make sure there's either space to receive or data to transfer.
2. `RX_READY`
  - Wait state before asserting `FT601_OE`
3. `RX_START`
  - Asserts `FT601_OE`
  - Wait state before asserting `FT601_RD`
4. `RX_WORD_1`
  - Asserts `FT601_OE` and `FT601_RD`
  - Wait state before clocking valid data into the RX fifo
5. `RX_WORD_2`
  - Same as `RX_WORD_1`, but clocks valid data into the RX FIFO
  - Seems like the FT601 will keep valid data on the bus for an extra cycle, so we only want to clock one copy
  - Moves to `RX_COMPLETE` when either there is no more data from the FT601 or
    the RX FIFO is full
6. `RX_COMPLETE`
  - Delay state to de-assert `FT601_OE` and `FT601_RD` before going back to `BUS_IDLE`
7. `TX_READY`
  - Wait state before asserting `FT601_WR`
8. `TX_WORD`
  - Transmits a word on the FT601 bus
9. `TX_COMPLETE`
  - Wait state before going back to `BUS_IDLE`

The controller for FT601 transfers is implemented in `tlp_streamer_ft601.vhd` and provides two FIFOs (one RX from host and one TX to host) as an interface to the rest of the FPGA design.

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
