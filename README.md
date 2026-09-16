# Five-Stage Pipelined MIPS32 CPU

Course project — Computer Organization and Architecture, BIT.
27 MIPS32 instructions, five stages, full hazard handling.

**Status: single-cycle CPU working and fully verified. Pipelining is next.**

Design reference (instruction encodings, control tables, hazard rules):
see the proposal document, or the online spec sheet.

---

## Repository layout

```
rtl/        synthesisable Verilog        <- you write these
tb/         testbenches                  <- do NOT edit, they are the spec
tests/      MIPS assembly + hex dumps
docs/       design documents
build.tcl   regenerates the Vivado project from source
```

**Never commit the Vivado project.** `.xpr` files and the `*.sim`, `*.runs`,
`*.cache` directories are version-locked and three people editing them will
conflict constantly. `build.tcl` regenerates everything from the sources.

---

## Current status

| Module | Testbench | Result |
|---|---|---|
| `alu.v` | `tb/alu_tb.v` — 41 checks | **passing** |
| `regfile.v` | `tb/regfile_tb.v` — 13 checks | **passing** |
| `control.v` | `tb/control_tb.v` — 28 checks | **passing** |
| `sign_extend.v` | `tb/leaf_tb.v` — 21 checks | **passing** |
| `imem.v` | `tb/leaf_tb.v` | **passing** |
| `dmem.v` | `tb/leaf_tb.v` | **passing** |
| `cpu_single.v` | `tb/cpu_single_tb.v` — 20 checks | **passing** |
| `alu_control.v` | merged into `control.v` | n/a |
| IF/ID, ID/EX, EX/MEM, MEM/WB | — | not started |
| `forwarding_unit.v` | — | not started |
| `hazard_unit.v` | — | not started |
| `cpu_pipelined.v` | — | not started |
| `perf_counters.v` | — | not started |

123 checks passing across seven modules.

**Do not modify `cpu_single.v` from here on.** It is the performance
baseline: the pipelined CPU's speedup is measured against it, and running
the same program on both is how we show they produce identical results.

Update this table in every commit that changes a module's status. It is the
fastest way for three people to see where the project actually is.

---

## Test programs

| File | Purpose |
|---|---|
| `tests/01_load_use.asm` | load-use hazard — one bubble required |
| `tests/02_forwarding.asm` | data hazards at distance 1 and 2, both operands |
| `tests/03_single_cycle.asm` | integration — 18 instructions end to end |
| `tests/03_single_cycle.hex` | assembled form of the above |

`03_single_cycle` is reused unchanged on the pipelined CPU. Same program,
same final register state, fewer cycles — that is the result the report
needs.

---

## Running a testbench

### Vivado (official — use for anything that goes in the report)

Generate the project once:

**Tools → Run Tcl Script…** → select `build.tcl`

That creates `vivado_project/`, adds every file in `rtl/` and `tb/`, sets the
include path for `defines.vh`, and sets the simulation top. Then:

1. **File → Project → Open** → `vivado_project/mips_pipeline.xpr`
2. Sources panel → Simulation Sources → right-click a testbench → **Set as Top**
3. Flow Navigator → **Run Simulation → Run Behavioral Simulation**
4. Read the **Tcl Console** for the pass/fail summary

If the project ever misbehaves, delete `vivado_project/` and run `build.tcl`
again. Nothing is lost — it is generated entirely from the sources.

### Icarus (fast — use while developing)

Two seconds instead of forty-five. Same results.

```
iverilog -I rtl -o alu.out  rtl/alu.v     tb/alu_tb.v     && vvp alu.out
iverilog -I rtl -o rf.out   rtl/regfile.v tb/regfile_tb.v && vvp rf.out
iverilog -I rtl -o ctl.out  rtl/control.v tb/control_tb.v && vvp ctl.out

iverilog -I rtl -o leaf.out rtl/sign_extend.v rtl/imem.v rtl/dmem.v \
                            tb/leaf_tb.v && vvp leaf.out

iverilog -I rtl -o cpu.out  rtl/*.v tb/cpu_single_tb.v && vvp cpu.out
```

Download: <https://bleyer.org/icarus/>

`cpu_single_tb.v` has an absolute path to the hex file at the top of the
file — check it matches your clone before the first run.

---

## Ground rules

**One module, one testbench, one commit.** Do not start the next module
until the current one passes every check.

**The testbenches are the specification.** If you think a testbench is
wrong, the discussion is about the control table in the proposal, not
about the test. Change the table first, then the test, then the RTL —
in that order, and tell the other two.

**Sequential logic uses `<=`. Combinational logic uses `=`.** Mixing them
produces a design that simulates one way and synthesises another, and the
failure appears weeks later during implementation.

**Drive every output on every path** in an `always @(*)` block. An output
left unassigned on some path infers a latch. Vivado warns about it; believe
the warning.

**Save the file before you run the testbench.** An editor buffer is not a
file. If results look impossible, check the file actually changed on disk.

---

## Deviations from the proposal

Record these in the mid-term report rather than letting a marker find them.

**`alu_control` is merged into `control.v`.** The proposal lists them as
separate modules. The decoder already sees both the opcode and the funct
field, so a second module would only re-decode them.

**`add`/`addu`, `sub`/`subu` and `addi`/`addiu` map to identical hardware.**
They differ only in whether signed overflow raises an exception, and
exceptions are outside the project's scope. There is deliberately no
separate ALU operation for the unsigned variants.

**`lui` zero-extends its immediate.** Table 5a lists this as a don't-care,
which is correct — `lui` shifts the immediate left by 16, so the upper bits
are discarded either way. The implementation pins it to zero-extend, and the
table should be updated to match.

---

## MARS configuration

All three of you must use identical settings, or your test programs will
not agree:

- Settings → **Permit extended (pseudo) instructions and formats** — **OFF**
- Settings → **Delayed branching** — **OFF**
- Settings → Memory Configuration → **Compact, Text at Address 0**

That configuration puts `.text` at `0x00000000` and `.data` at `0x00002000`.
Check it by trying to assemble `li $t1, 10` — MARS must reject it.

To produce a hex file for `$readmemh`:
File → Dump Memory → `.text` → **Hexadecimal Text**.
The result must be bare 8-digit words, one per line, with no `0x` prefix.

---

## Git from mainland China

GitHub is frequently unreachable on campus networks. If a push times out,
point Git at your proxy — scoped to GitHub only, so domestic mirrors stay
direct:

```
git config --global http.https://github.com.proxy http://127.0.0.1:<port>
```

Use whatever local port your proxy client listens on. If the client runs in
TUN mode, traffic is already routed and no Git configuration is needed at
all — in that case remove the setting, because a stale proxy entry fails
exactly like no network.

```
git config --global --get-regexp proxy      # show what is set
git config --global --unset http.https://github.com.proxy
```

---

## Build order

1. ~~**ALU** — 12 operations, self-contained, proves the test loop works~~ **done**
2. ~~**Register file** — negedge write, `$zero` hardwired~~ **done**
3. ~~**Control decoder** — transcription of Tables 5a and 5b~~ **done**
4. ~~**Sign extender, memories**~~ **done**
5. ~~**Single-cycle integration** — validates the control table before
   pipelining can hide control faults~~ **done**
6. **Pipeline registers** — test with `nop`-padded programs, no hazards yet
7. **Forwarding** — EX/MEM and MEM/WB into the ALU inputs
8. **Load-use stall** — the one hazard forwarding cannot solve
9. **Branch and jump flush**
10. **Performance counters, benchmarks, synthesis**

Steps 6 through 9 are the whole project. Do them one at a time, each with
its own test program. Teams that enable all hazard handling at once and
then start debugging do not finish.
