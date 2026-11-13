# Sid Meier's Colonization source recovery
First pass · 12 November 2026

The installed DOS files contain enough to start recovering the original game's logic. The main target is the 16-bit x86 machine code in `MPS\COLONIZE\VICEROY.EXE`. Disassembly gives us instructions and control flow, and decompilation can produce approximate pseudocode. Original names, comments, types, and source file structure generally cannot be reconstructed from an executable. I found no MicroProse source tree in the loose files or the archive listings I inspected.

## What the bundle contains

| Location | What I verified |
| --- | --- |
| `MPS\COLONIZE` | The readme identifies version 3.0. Both the batch file and the Steam launch configuration start `OPENING -g`. `OPENING.EXE`, `VICEROY.EXE`, `CLOSING.EXE`, and `MAPEDIT.EXE` have DOS MZ headers. The opening and closing programs cover presentation, and the map editor is a useful second implementation to consult for map handling. |
| `dosbox_windows` | The Steam launch config mounts the installed directory and CD image, then runs the DOS game. Both `source.7z` archives list DOSBox source trees, including CPU, DOS, and debugger modules. |
| `CD\COLONIZE.ISO` | `COL_DOS` holds installer data and split `MPSLABS` archives. `INSTALL` holds a separate Windows edition. Its readme identifies Colonization for Windows, and I verified Win16 NE headers in `COLDATA0.DLL` and `COLTEXT0.DLL`. The 448,483-byte `COLONIZE._00` starts with the `ARCV` signature and a directory entry for `colonize.exe`. I inspected the archive header and left its payload compressed. |
| Manuals and bonus content | The manuals can help check expected behavior. The soundtrack is supplied as MP3s. |

## DOS executable inspection

| Field | Local value |
| --- | --- |
| File size | 494,910 bytes |
| SHA-256 | `a17ed64c27671e5e95236e54a7ddc85803a96ba822fbed05e1dad34d3917e2e3` |
| Header size and relocation entries | `0x2400` bytes and 2,260 entries |
| Initial image-relative CS:IP | `110D:071D`, file offset `0x13BED` |
| End of MZ-declared image, exclusive | `0x20665` |
| Data after declared image | 362,201 bytes |

The entry bytes decode as a far call to `110D:0727` followed by a far jump to `0D1D:0150`, using the segment words stored in the file before relocation. The large tail matters because the game loads overlays, which are code segments brought into memory as needed. OpenColo documents a v3.0 pipeline that translates the executable and 31 overlays into C# operating on a virtual x86 CPU. I verified the local file's layout and a published offset below. I have not generated the C# or independently counted the overlays. [OpenColo DOS project](https://github.com/nan0desu/OpenColo)

### A local check against a published routine

OpenCol documents a DOS map loader at **file offset `0x71106`**, well beyond the MZ-declared image. At that exact offset in your file I found `C8 06 00 00 C7 46 FE 01 00`. In 16-bit x86 those bytes decode to `ENTER 6, 0` followed by `MOV word ptr [BP-2], 1`. That is consistent with a function entry. I also found the literal `AMER2.MP` at file offset `0x1FB06`. The opening instructions alone do not establish the function's behavior. [OpenCol map-loader analysis](https://opencol.github.io/docs/formats/shared/mp-map/)

I parsed the map itself and verified a **58 × 72, version 4** header and three consecutive 4,176-byte planes. The total is exactly 12,534 bytes. The planes have 87, 1, and 15 distinct byte values, respectively. The middle plane is all zero. The copy inside the CD's Windows installer is byte-for-byte identical. I also verified that `TERRAIN.SS` begins with `MADSPACK 2.0` and that `COLONY00.SAV` begins with `COLONIZE` and carries the same map dimensions at `0x0C`. These give us local fixtures for later format readers. [OpenCol format documentation](https://opencol.github.io/docs/)

## Proposed next pass

1. **Recover one full routine using the DOS overlay tooling.** Start with the [Colonization branch of Disassembler](https://github.com/nan0desu/Disassembler/tree/colonization) referenced by OpenColo. Generate its output against a workspace copy of the installed DOS files and locate the map loader by file offset. The published build targets .NET 9, and this machine's SDK listing showed only 5.0.101. The generator build and compatibility with this exact executable remain unverified.
2. **Trace the map loader through a complete read.** Keep a record of file offsets, overlay identities, and relocated segment:offset addresses. Verify the version check and three plane reads against the local map. Ghidra's DOS MZ loader is an option for inspecting the resident code, and any manual Ghidra pass needs to account for the overlays. Use DOSBox as the behavior reference and a debugger-capable build if a trace is needed. The bundled DOSBox debugger capability was not tested. [Ghidra MZ loader](https://ghidra.re/ghidra_docs/api/ghidra/app/util/opinion/MzLoader.html)
3. **Turn recovered behavior into a Godot implementation.** Begin with a small map reader and fixture checks, then choose a gameplay rule such as colony production and verify it with before-and-after saves from DOS. The Windows edition can corroborate formats and mechanics where they match. Use the DOS v3.0 executable and observed DOS behavior to settle version differences. [OpenCol version and format research](https://opencol.github.io/docs/)

The first pass used local file reads, archive inspection, header parsing, and a short manual instruction decode. No end-to-end decompiler or emulator run was performed.
