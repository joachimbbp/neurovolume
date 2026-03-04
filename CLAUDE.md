# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Neurovolume is a Python library with a Zig backend for converting volumetric scientific data (especially neuroimaging files like NIfTI1) into VDB files for 3D visualization. The VDB writer is a custom implementation of OpenVDB's 5-4-3 tree structure with no external dependencies.

## Commands

All commands use `uv`. Install dependencies first:
```bash
uv sync
```

**Build the Zig native library** (required before running Python code):
```bash
uv run python -m ziglang build
```
This compiles the Zig source and copies the output to `src/neurovolume/_native/libneurovolume.dylib`.

**Run Zig tests:**
```bash
uv run python -m ziglang build test
```

**Run Python tests:**
```bash
uv run pytest -s tests
```

**Run a single Python test:**
```bash
uv run pytest -s tests/test_integration.py::test_hello
```

Note: Python integration tests download large NIfTI files from OpenNeuro on first run.

## Architecture

The project is a two-layer system:

**Python layer** (`src/neurovolume/`): Pure Python using `ctypes` to call into the Zig dynamic library. `core.py` loads `_native/libneurovolume.dylib` at import time and defines all public functions as ctypes wrappers. `__init__.py` re-exports everything with `from neurovolume.core import *`.

**Zig layer** (`src/zig/`): Compiled to a C-compatible dynamic library. Key modules:
- `c_root.zig` — C FFI entry points (functions with `pub export`); this is what Python calls
- `volume.zig` — `Volume` struct: the central abstraction holding `raw_data` (format-specific bytes), `format` enum (`ndarray`/`nifti1`), `transform` (4×4 affine), `dims` (x,y,z,t), fps, and `SaveConfiguration`
- `nifti1.zig` — Parses NIfTI1 headers and data; `getAt4D` retrieves voxels from 4D data; `toVolume` constructs a `Volume` from a filepath
- `ndarray.zig` — Handles numpy C-contiguous float32 arrays; `getAt4D` retrieves voxels (WIP on `interpolate` branch)
- `vdb543.zig` — Custom VDB writer: builds a 5-4-3 node tree (`Node5` → `Node4` → `Node3`) and serializes it to bytes in OpenVDB format. All voxel values are `f32`. Currently no sparsity and single-grid only.
- `save.zig` — File/folder versioning utilities (`versionFile`, `versionFolder`, `elementName` for frame sequences)
- `effects.zig` — Frame-based post-processing effects (normalize, frame_difference); intended to be applied before writing VDB
- `interpolation.zig` — WIP: frame interpolation modes (currently only `direct`)
- `config.zig.zon` — **Machine-specific config** with hardcoded absolute paths to test data files and output directories. Must be updated per machine.

**Build system** (`build.zig`): Produces `libneurovolume` as a dynamic library from `c_root.zig`, then copies it to `src/neurovolume/_native/libneurovolume.dylib`. Also builds a `demo` executable (currently minimal). Currently macOS-only (`.dylib`).

## Important conventions

- VDB data must be `f32` normalized between 0.0 and 1.0. Use `prep_ndarray()` or pass `normalize=True` to convert before writing.
- The `config.zig.zon` file contains absolute paths — update them when working on a new machine.
- Code annotations used throughout: `//LLM:` marks AI-generated code, `//BOOKMARK:` marks WIP stopping points, `//WARN:` flags known issues, `//FIX:` marks bugs, `//DEPRECATED:` marks unused code left for reference. In Python files use `#LLM:` instead.
- When Claude Code writes or substantially modifies a function, annotate it with `#LLM: claude wrote this function` (Python) or `//LLM: claude wrote this function` (Zig) on the line before `def`/`pub fn`.
- The `interpolate` branch is the active development branch for frame interpolation. The pattern being established is that every data format (`nifti1`, `ndarray`) needs a `getAt4D` function so the interpolation code can access voxels uniformly.
- Test data files (`.nii`, `.nii.gz`) are gitignored and must be downloaded separately (links in README and `test_integration.py`).
