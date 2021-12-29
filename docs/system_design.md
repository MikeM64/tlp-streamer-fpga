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

## Design
### Clock Domains
There are three clock domains for the design logic (except for the internals of Xilinx IP):
1) ft601_clk
  - This clock is driven by the FT601 and is used to clock incoming/outgoing data towards the host
  - Drives the RX/TX FIFOs
2) sys_clk
  - This is the external 100MHz clock
  - Drives the majority of the internal logic
3) pcie_user_clk
  - User clock output from the PCIe IP
  - Used to clock all data reads/writes related to the PCIe IP

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

##### USB Packet TX
Similar to the USB Packet RX state machine, this control the TX process

1. `TX_READY`
  - Wait state before asserting `FT601_WR`
2. `TX_WORD`
  - Transmits a word on the FT601 bus
3. `TX_COMPLETE`
  - Wait state before going back to `BUS_IDLE`

The controller for FT601 transfers is implemented in `tlp_streamer_ft601.vhd` and provides two FIFOs (one RX from host and one TX to host) as an interface to the rest of the FPGA design.

#### Host-to-FPGA communications
Packets sent/received by the FPGA are encoded in network order (Big-endian) for ease of communication with the PCIe core. The host is responsible for translating the packet before sending it.

Each packet MUST have the following header prepended to any data:

```
typedef enum tsh_msg_type_et {
    /** Loopback the packet back to the host */
    TSH_MSG_LOOPBACK = 0,
    /** PCIe Configuration Space packet */
    TSH_MSG_PCIE_CONFIG,
} __attribute__ ((packed));

/*
 * NOTE: The header must ALWAYS be size which is a multiple of a uint32_t to
 * allow for easy decoding on the FPGA.
 */
struct tlp_streamer_header {
    /** @enum tsh_msg_type_et */
    uint8_t   tsh_msg_type;
    /** Padding */
    uint8_t   tsh_reserved_1;
    /** Number of DWORDs in the packet, including the header */
    uint16_t  tsh_msg_len;
    /** Host-defined sequence number, for debugging */
    uint16_t  tsh_seq_num;
} __attribute__((packed));
```

#### Host Packet Processing
1) Parse header
  - Determine which component deals with the request
2) Dispatch request
  - Write header + packet into component FIFO

#### PCIe Configuration Space Requests
First step in bringing up a PCIe device is respnding to configuration space requests. Refer to "User-Implemented Configuration Space" on page 119 of PG054.

Most of this is handled by the IP hard block in the FPGA. For NVMe emulation,
BAR0 and BAR1 are of interest. BAR2 is an optional register for NVMe (see 2.1.12 in the NVMe 1.4c specification.) BAR0/1 need to be exposed to the host PC in order to generate TLP requests for the correct memory addresses.

Per the 7-series FPGA documentation, only PCI config space addresses 0xA8 -> 0xFF are able to be handled by user logic. This means that the host software MUST request BAR addresses during its initialization process by querying the configuration interface.

The following structure is used to contain configuration space requests from the host.

```
struct tlp_streamer_pcie_cfg_cmd {
    /** Configuration register to read from, see page 109+ from pg054. */
    uint16_t tspcc_cfg_reg_addr;
    /** Read vs. write */
    uint8_t  tspcc_cfg_write;
    /** Which bytes are valid during a cfg_reg write */
    uint8_t  tspcc_cfg_reg_be;
    /** uint32_t padding alignment */
    uint8_t  tspcc_padding;
    /** Data returned from the register, or data to write to the register */
    uint32_t tspcc_cfg_reg_data;
};
```

For example, a request to read BAR0 would be sent as:
```
{
    .tspcc_cfg_reg_addr = 0x04,
    .tspcc_cfg_write = 0,
    /* tspcc_cfg_reg_data and tspcf_cfg_reg_be may be uninitialized */
}
```

And the FPGA would respond:
```
{
    .tspcc_cfg_reg_addr = 0x4,
    .tspcc_cfg_write = 0,
    .tspcc_cfg_reg_data = 0xdeadbeef,
    .tspcc_cfg_reg_be = 0xf,
}
```

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
