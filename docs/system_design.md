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
    /** Padding */
    uint8_t   tsh_reserved_2[2];
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
enum tlp_streamer_write_options {
    /** PCIe config space read */
    TSWO_READ  = (0 << 0),
    /** PCIe config space write */
    TSWO_WRITE = (1 << 0),
    /**
     * Write enable to treat any Read Only bit in the current write
     * as RW, not including bits set by attributes, reserved bits and
     * status bits.
     */
    TSWO_WRITE_READONLY = (1 << 1),
    /**
     * Indicates the current write operation should treat any RW1C bit as
     * RW. Normally a RW1C bit is cleared by writing 1 to it and can normally
     * only be set by internal core conditions. During a configuration write
     * with this flag set, for every bit in tspcc_cfg_reg_data that is 1, a
     * corresponding RW1C configuration register bit is set to 1. A value of
     * 0 during this operation has no effect and non-RW1C bits are
     * unaffected regardless of the data in tspcc_cfg_reg_data.
     */
    TSWO_WRITE_RW1C = (1 << 2),
}

struct tlp_streamer_pcie_cfg_cmd {
    /**
     * Configuration register to read from, see page 109+ from pg054.
     * Only 10 bits are used.
     */
    uint16_t tspcc_cfg_reg_addr;
    /** Read vs. write */
    uint8_t  tspcc_cfg_write;
    /** Which bytes are valid during a cfg_reg write. 4-bits used. */
    uint8_t  tspcc_cfg_reg_be;
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

# Notes on manual testing
## How to trigger rescan after upgrading the bitstream
0) Flash new bitstream to the card

1) Get the PCI slot from `lspci`:
```
$ lspci -d 13a8:7021
0b:00.0 Serial controller: Exar Corp. Device 7021
```

2) Remove the device (as root):
```
$ echo 1 > /sys/bus/pci/devices/0000\:0b\:00.0/remove
```

3) Re-scan the PCI bus (as root):
```
$ echo 1 > /sys/bus/pci/rescan
```

## Enabling MMIO for MRd/MWr TLP Generation
0) Get the PCI slot from `lspci`:
```
$ lspci -d 13a8:7021
0b:00.0 Serial controller: Exar Corp. Device 7021
```

1) Enable MMIO for the slot (as root):
```
$ setpci -s 0b:00.0 COMMAND=0x2
```

2) Verify the `BAR` is enabled
  - There should not be `[virtual]` or `[disabled]` in the output of lspci
Working output:
```
$ lspci -d 13a8:7021 -v | grep "Memory at"
  Memory at fcc00000 (32-bit, non-prefetchable) [size=2K]
```

Non-working output:
```
$ lspci -d 13a8:7021 -v | grep "Memory at"
  Memory at fcc00000 (32-bit, non-prefetchable) [disabled] [size=2K]
```

## Trigger a MRd/MWr TLP
0) Get the PCI slot from `lspci`:
```
$ lspci -d 13a8:7021
0b:00.0 Serial controller: Exar Corp. Device 7021
```

1) Find the sysfs path to the PCIe device
```
$ find /sys/devices -name '0000:0b:00.0' | grep -v iommu
/sys/devices/pci0000:00/0000:00:03.2/0000:0b:00.0
```
1) Trigger a MRd TLP (as root)
  - Requires pcimem - https://github.com/billfarrow/pcimem
  - If the kernel has loaded a driver for the PCIe device, it may need to be unloaded first
  - The `resource0` file corresponds to `BAR0`, adjust as necessary for the appropriate `BAR` address.
```
$ ./pcimem /sys/devices/pci0000\:00/0000\:00\:03.2/0000\:0b\:00.0/resource0 0 w
/sys/devices/pci0000:00/0000:00:03.2/0000:0b:00.0/resource0 opened.
Target offset is 0x0, page size is 4096
mmap(0, 4096, 0x3, 0x1, 3, 0x0)
PCI Memory mapped to address 0x7fe58be8c000.
0x0000: 0xFFFFFFFF

```
