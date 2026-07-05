# AES-128 Iterative Encryption Core (Verilog)

A synthesizable, from-scratch AES-128 encryption core in Verilog — verified
against NIST/FIPS-197 known-answer test vectors in simulation, synthesized
with both an open-source flow and the vendor (Gowin) toolchain, and
**confirmed running on real Tang Nano 9K hardware** (see `fpga/`).

## Architecture

**Iterative datapath**: a single AES round (SubBytes → ShiftRows →
MixColumns → AddRoundKey) is reused for all 10 rounds via an FSM, rather
than unrolling 10 rounds combinationally. This trades throughput for a
~10x smaller area footprint — the standard choice when area/power matters
more than raw speed (e.g. embedded, IoT, resource-constrained SoCs).

**On-the-fly key expansion**: each round key is computed one cycle before
it's needed and immediately consumed, so only a single 128-bit key
register is required instead of storing all 11 round keys (176 bytes) up
front.

```
rtl/
  sbox.v          - AES S-box (256-entry combinational lookup)
  sub_bytes.v     - SubBytes: 16x sbox instances over the state
  shift_rows.v    - ShiftRows: pure wiring (no logic)
  mix_columns.v   - MixColumns: GF(2^8) arithmetic, 4x per-column mixers
  key_expand.v    - On-the-fly AES-128 key schedule (one round per call)
  aes_core.v      - Top-level FSM tying the round datapath together
tb/
  aes_tb.v        - Self-checking testbench, 3 known-answer vectors
synth/
  synth.ys        - Yosys synthesis script (generic/technology-independent)
```

### Interface

```verilog
module aes_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,          // pulse 1 cycle to begin
    input  wire [127:0] key_in,
    input  wire [127:0] plaintext_in,
    output reg           done,          // pulses 1 cycle when result valid
    output reg  [127:0] ciphertext_out
);
```

Latency: ~11-13 clock cycles per 128-bit block (1 load + 10 rounds + 1
present), independent of key or plaintext values — this is a deliberate
property, not an accident: a data-dependent timing profile in a crypto
core is exactly the kind of side channel real hardware needs to avoid.

## Verification

`tb/aes_tb.v` runs the core against three independent known-answer
vectors and checks the output bit-for-bit:

| # | Source | Key | Result |
|---|--------|-----|--------|
| 0 | FIPS-197 Appendix B | `000102030405060708090a0b0c0d0e0f` | PASS |
| 1 | NIST SP 800-38A F.1.1, block 1 | `2b7e151628aed2a6abf7158809cf4f3c` | PASS |
| 2 | NIST SP 800-38A F.1.1, block 2 (same key) | `2b7e151628aed2a6abf7158809cf4f3c` | PASS |

```
$ iverilog -g2012 -o sim/aes_sim rtl/*.v tb/aes_tb.v
$ cd sim && vvp aes_sim
...
TESTBENCH SUMMARY: ALL 3 TESTS PASSED
```

## Synthesis results

Synthesized with Yosys (generic/technology-independent flow, no PDK):

| Metric | Value |
|---|---|
| Cell count (gate-level primitives) | 10,141 |
| Flip-flops | 399 |
| Combinational primitives | ~9,742 |

The 399 flip-flops decompose exactly as expected: 128 (state) + 128
(round key) + 8 (round constant) + 4 (round counter) + 2 (FSM) + 1
(done) + 128 (output register) = 399 — a useful sanity check that no
extra state accidentally got inferred.

No target cell library was used, so these are generic 2-input-equivalent
gate counts, not a real ASIC/FPGA area number.

### Real FPGA synthesis: open-source vs. vendor toolchain

The core has also been synthesized for the Tang Nano 9K (Gowin
GW1NR-LV9QN88PC6/I5) two ways, with a striking difference:

| Metric | Open-source (Yosys + nextpnr-gowin) | Vendor (Gowin IDE) |
|---|---|---|
| Logic (LUT+ALU) utilization | 87% (7567/8640 SLICEs) | **17%** (1431/8640) |
| BSRAM utilization | 0% (not used) | **77%** (20/26 blocks) |
| Registers | - | 801/6693 (12%) |
| Max Fmax | 50.56 MHz | (see `fpga/README.md` for latest) |

The gap comes down to one thing: **Gowin's synthesizer automatically
recognized the S-box's `case` statement as a ROM pattern and mapped it to
20 BSRAM (block RAM) primitives instead of LUTs.** The open-source
Yosys `synth_gowin` flow doesn't currently do this inference, so it
implements all 20 S-box instances (16 in SubBytes + 4 in key expansion)
as large LUT trees, which is why open-source logic utilization is so
much higher for an otherwise identical netlist. Same RTL, same device,
5x difference in logic-cell usage — a good illustration of how much
value inference passes in vendor synthesis tools can add for ROM-like
structures.

See `fpga/README.md` for the full real-hardware writeup (build steps,
flashing, and the "how do I even get a Gowin bitstream" walkthrough for
both toolchains).

## Roadmap (for extending this project)

1. **Decryption** (InvSubBytes/InvShiftRows/InvMixColumns/AddRoundKey,
   reverse key schedule) — straightforward extension of this structure.
2. ~~**FPGA target**~~ — done, see `fpga/`: running live on a Tang Nano 9K,
   button-triggered, result shown on LEDs and printed over UART.
3. **UART receive path**: currently the FPGA demo only ever encrypts one
   hardcoded test vector; adding UART RX so you can send in your own
   128-bit plaintext/key and get back a real ciphertext would make it a
   genuinely interactive demo instead of a fixed self-test.
4. **Pipelining**: unroll 2-4 rounds combinationally per stage to trade
   area for throughput; report Gbps and compare to this iterative
   version.
5. **Side-channel analysis**: simulate switching activity and run
   correlation power analysis (CPA) against this unprotected
   implementation to recover the key, then add a masking countermeasure
   and show the attack fail. This is the piece that differentiates the
   project most in an interview.

## Tools used

- Icarus Verilog 12.0 (simulation)
- Yosys 0.33 (open-source synthesis)
- nextpnr-gowin + Apicula (open-source Gowin place & route + bitstream)
- Gowin EDA (vendor IDE, used for comparison and the flashed hardware build)
- openFPGALoader (hardware programming)# AES-128 Iterative Encryption Core (Verilog)

A synthesizable, from-scratch AES-128 encryption core in Verilog — verified
against NIST/FIPS-197 known-answer test vectors in simulation, synthesized
with both an open-source flow and the vendor (Gowin) toolchain, and
**confirmed running on real Tang Nano 9K hardware** (see `fpga/`).

## Architecture

**Iterative datapath**: a single AES round (SubBytes → ShiftRows →
MixColumns → AddRoundKey) is reused for all 10 rounds via an FSM, rather
than unrolling 10 rounds combinationally. This trades throughput for a
~10x smaller area footprint — the standard choice when area/power matters
more than raw speed (e.g. embedded, IoT, resource-constrained SoCs).

**On-the-fly key expansion**: each round key is computed one cycle before
it's needed and immediately consumed, so only a single 128-bit key
register is required instead of storing all 11 round keys (176 bytes) up
front.

```
rtl/
  sbox.v          - AES S-box (256-entry combinational lookup)
  sub_bytes.v     - SubBytes: 16x sbox instances over the state
  shift_rows.v    - ShiftRows: pure wiring (no logic)
  mix_columns.v   - MixColumns: GF(2^8) arithmetic, 4x per-column mixers
  key_expand.v    - On-the-fly AES-128 key schedule (one round per call)
  aes_core.v      - Top-level FSM tying the round datapath together
tb/
  aes_tb.v        - Self-checking testbench, 3 known-answer vectors
synth/
  synth.ys        - Yosys synthesis script (generic/technology-independent)
```

### Interface

```verilog
module aes_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,          // pulse 1 cycle to begin
    input  wire [127:0] key_in,
    input  wire [127:0] plaintext_in,
    output reg           done,          // pulses 1 cycle when result valid
    output reg  [127:0] ciphertext_out
);
```

Latency: ~11-13 clock cycles per 128-bit block (1 load + 10 rounds + 1
present), independent of key or plaintext values — this is a deliberate
property, not an accident: a data-dependent timing profile in a crypto
core is exactly the kind of side channel real hardware needs to avoid.

## Verification

`tb/aes_tb.v` runs the core against three independent known-answer
vectors and checks the output bit-for-bit:

| # | Source | Key | Result |
|---|--------|-----|--------|
| 0 | FIPS-197 Appendix B | `000102030405060708090a0b0c0d0e0f` | PASS |
| 1 | NIST SP 800-38A F.1.1, block 1 | `2b7e151628aed2a6abf7158809cf4f3c` | PASS |
| 2 | NIST SP 800-38A F.1.1, block 2 (same key) | `2b7e151628aed2a6abf7158809cf4f3c` | PASS |

```
$ iverilog -g2012 -o sim/aes_sim rtl/*.v tb/aes_tb.v
$ cd sim && vvp aes_sim
...
TESTBENCH SUMMARY: ALL 3 TESTS PASSED
```

## Synthesis results

Synthesized with Yosys (generic/technology-independent flow, no PDK):

| Metric | Value |
|---|---|
| Cell count (gate-level primitives) | 10,141 |
| Flip-flops | 399 |
| Combinational primitives | ~9,742 |

The 399 flip-flops decompose exactly as expected: 128 (state) + 128
(round key) + 8 (round constant) + 4 (round counter) + 2 (FSM) + 1
(done) + 128 (output register) = 399 — a useful sanity check that no
extra state accidentally got inferred.

No target cell library was used, so these are generic 2-input-equivalent
gate counts, not a real ASIC/FPGA area number.

### Real FPGA synthesis: open-source vs. vendor toolchain

The core has also been synthesized for the Tang Nano 9K (Gowin
GW1NR-LV9QN88PC6/I5) two ways, with a striking difference:

| Metric | Open-source (Yosys + nextpnr-gowin) | Vendor (Gowin IDE) |
|---|---|---|
| Logic (LUT+ALU) utilization | 87% (7567/8640 SLICEs) | **17%** (1431/8640) |
| BSRAM utilization | 0% (not used) | **77%** (20/26 blocks) |
| Registers | - | 801/6693 (12%) |
| Max Fmax | 50.56 MHz | (see `fpga/README.md` for latest) |

The gap comes down to one thing: **Gowin's synthesizer automatically
recognized the S-box's `case` statement as a ROM pattern and mapped it to
20 BSRAM (block RAM) primitives instead of LUTs.** The open-source
Yosys `synth_gowin` flow doesn't currently do this inference, so it
implements all 20 S-box instances (16 in SubBytes + 4 in key expansion)
as large LUT trees, which is why open-source logic utilization is so
much higher for an otherwise identical netlist. Same RTL, same device,
5x difference in logic-cell usage — a good illustration of how much
value inference passes in vendor synthesis tools can add for ROM-like
structures.

See `fpga/README.md` for the full real-hardware writeup (build steps,
flashing, and the "how do I even get a Gowin bitstream" walkthrough for
both toolchains).

## Roadmap (for extending this project)

1. **Decryption** (InvSubBytes/InvShiftRows/InvMixColumns/AddRoundKey,
   reverse key schedule) — straightforward extension of this structure.
2. ~~**FPGA target**~~ — done, see `fpga/`: running live on a Tang Nano 9K,
   button-triggered, result shown on LEDs and printed over UART.
3. **UART receive path**: currently the FPGA demo only ever encrypts one
   hardcoded test vector; adding UART RX so you can send in your own
   128-bit plaintext/key and get back a real ciphertext would make it a
   genuinely interactive demo instead of a fixed self-test.
4. **Pipelining**: unroll 2-4 rounds combinationally per stage to trade
   area for throughput; report Gbps and compare to this iterative
   version.
5. **Side-channel analysis**: simulate switching activity and run
   correlation power analysis (CPA) against this unprotected
   implementation to recover the key, then add a masking countermeasure
   and show the attack fail. This is the piece that differentiates the
   project most in an interview.

## Tools used

- Icarus Verilog 12.0 (simulation)
- Yosys 0.33 (open-source synthesis)
- nextpnr-gowin + Apicula (open-source Gowin place & route + bitstream)
- Gowin EDA (vendor IDE, used for comparison and the flashed hardware build)
- openFPGALoader (hardware programming)