# MicroPython firmware: where we are and what's next

Research done 2026-10-26 from this repo plus the old WSL build tree
(`\\wsl.localhost\Ubuntu-22.04\home\anfro`).

---

## 1. What the current (v1.19) firmware actually is

The `.bin` files in this repo were **not** built from the Dockerfile. They came from a
manual WSL build in Nov 2023:

| Piece | Exact version used |
|---|---|
| MicroPython | Fork `anfroholic/micropython`, commit `6921294dd` = **v1.19.1-529** (between 1.19 and 1.20) |
| Extra in fork | One commit: **`esp32.CAN`** driver (upstream PR #9532 by FeroxTL; never merged) |
| ESP-IDF | **v4.4.4** (gcc 8.4) |
| Camera | `lemariva/micropython-camera-driver` @ `d851677` + `espressif/esp32-camera` cloned **into `esp-idf/components/`** at its HEAD (commit not recorded) |
| Board names | Local, uncommitted edits: `MICROPY_HW_BOARD_NAME "Evezor Edge"` |

The build tree is still in WSL (`~/micropython`, with `build-GENERIC`, `build-GENERIC_SPIRAM`
and `build-ESP32_CAM`). `~/esp-idf` has been **deleted**, so that tree can't be rebuilt as-is.

Firmware files in the repo:

| File | Board | Notes |
|---|---|---|
| `Edge_v1_19.bin` | GENERIC | Same size as `build-GENERIC/firmware.bin` |
| `Edge_v1_19_SPIRAM.bin` | GENERIC_SPIRAM | |
| `Edge_v1_19_CAM.bin` | ESP32_CAM (custom) | SPIRAM, OV2640, **no Bluetooth**, heap reduced by 512 KB for frame buffers, custom partitions (2.5 MB app / 1 MB FS on 4 MB flash) |
| `iris_v0-2*.bin`, `iris_v1-17*.bin` | ? | Older; origin not traced (see open questions) |

**Preserved in this repo** (copied out of WSL because they existed nowhere else):

- `reference/v1.19_build/boards/ESP32_CAM/`: the working camera board definition
- `reference/v1.19_build/boards/board_name_changes.diff`: the "Evezor Edge" name edits
- `reference/v1.19_build/can_driver/`: `esp32_can.c/.h`, example, and how the driver was wired into the port
- `reference/v1.19_build/camera_driver/`: the old lemariva `modcamera.c` (reference only)

### Current CAN API (what your application code depends on)

```python
from esp32 import CAN
can = CAN(0, tx=4, rx=5, mode=CAN.NORMAL, baudrate=500000, extframe=False, auto_restart=False)
can.send(data, id, timeout=0, rtr=False, extframe=False)
can.recv(list=None, timeout=5000)
can.any(); can.state(); can.info(); can.restart()
can.setfilter(bank, mode, params, rtr=None, extframe=False); can.clearfilter()
can.rxcallback(...); can.clear_tx_queue(); can.clear_rx_queue()
# consts: NORMAL LOOPBACK SILENT SILENT_LOOPBACK, STOPPED ERROR_ACTIVE BUS_OFF RECOVERING,
#         FILTER_RAW_SINGLE FILTER_RAW_DUAL FILTER_ADDRESS
```

### Why the 2023 attempts to go newer kept failing

`modesp32.c` only registers CAN when `ESP_IDF_VERSION_MAJOR == 4`. On any ESP-IDF 5.x build
the CAN class **silently disappears** even though everything compiles. The bash history shows
attempts with IDF 5.0.2 and Ihor Nehrutsa's `machine.CAN` branch that ended with a return to
IDF 4.4.4. The camera driver also depended on the IDF 4 layout, because it needed the camera
component copied into `esp-idf/components`.

---

## 2. What changed upstream since then

| | Then (2023) | Now (Oct 2026) |
|---|---|---|
| Latest MicroPython | 1.19.1 | **v1.29.0** (24 Aug 2026) |
| ESP-IDF | 4.4.4 | **5.5.x**. v1.29.0 release uses 5.5.2; master README recommends 5.5.5; support starts at 5.3 |
| Board names | `GENERIC`, `GENERIC_SPIRAM` | `ESP32_GENERIC` + `BOARD_VARIANT=SPIRAM`; `ESP32_GENERIC_S3` + `BOARD_VARIANT=SPIRAM_OCT` (since 1.20) |
| Build system | make + IDF4 | make wrapper over `idf.py`/CMake; deps via **IDF Component Manager** (`main/idf_component.yml`, downloaded at build time) |
| C API changes | `STATIC`, old `mp_obj_type_t` | `static`, `MP_DEFINE_CONST_OBJ_TYPE(...)`; old out-of-tree C code needs porting |
| CAN | Fork only | Generic **`machine.CAN`** API finalized in v1.28 (stm32, alif, mimxrt). **ESP32 implementation is still an open PR (#19461)** |
| Camera | lemariva driver (abandoned) | **`cnadler86/micropython-camera-API`** (maintained; ESP32 + S3; uses component manager) |

### CAN options for the new build

| Option | API | IDF | Status | Effort |
|---|---|---|---|---|
| **A. Port your existing `esp32_can.c` to a `USER_C_MODULE`** | Same as today; app code unchanged | 5.x via the legacy `driver/twai.h` (still present in 5.5, deprecated) | Known code, already used on your hardware | Medium: drop the IDF==4 guard, `STATIC`→`static`, new type macro, build as a user module instead of forking |
| **B. Cherry-pick PR #19461 `machine.CAN`** | New upstream API (`CAN(n)`, `bitrate`, `sample_point`, `irq()`, `set_filters()`) | **≥ 5.4**, new node-based TWAI driver | Open. Tested on S3/C6/P4, **classic ESP32 untested**, reviewer reports failing multi-board tests, one filter only | Low build effort, but app code has to change and the PR may still change |
| C. `straga/micropython-esp32-twai` user module | Third API (`import CAN`, `send(data, id)`) | 5.4.1 / MP 1.25 tested | Community | Low build, app changes |

**Recommendation:** start with **A**. It gets current MicroPython on both chips without
touching application code. Keep a branch that tries **B**, then switch over (or ship a small
Python shim mapping `esp32.CAN` to `machine.CAN`) once #19461 merges. Moving CAN out of a
MicroPython fork into a user C module also means future upgrades are just a tag bump.

### Camera

- `cnadler86/micropython-camera-API`: latest release v0.6.2 (Jan 2026), built against **MP 1.27**. Requires MP ≥ 1.24 and IDF ≥ 5.2.
  Compatibility with 1.29 is **not verified yet**, so it's the first thing to test.
- Integration: add `espressif/esp32-camera: git: https://github.com/cnadler86/esp32-camera.git`
  to `ports/esp32/main/idf_component.yml`, then build with the module (repo has a `build.sh`).
  Pins come from `MICROPY_CAMERA_MODEL_xxx` or `MICROPY_CAMERA_PIN_*` in `mpconfigboard.h`.
- **Requires PSRAM**, so camera builds are always SPIRAM builds.
- **API is different** from lemariva (`from camera import Camera, FrameSize, PixelFormat`;
  `cam = Camera(...)`; `cam.capture()`; settings are properties). Camera app code needs updating.
- They publish prebuilt `ESP32_GENERIC-SPIRAM` and `ESP32_GENERIC_S3-SPIRAM_OCT` firmware, which is
  useful as a baseline to flash before adding CAN.

---

## 3. Proposed build matrix (draft; confirm against open questions)

| Output name | Chip | Board / variant | CAN | Camera | Notes |
|---|---|---|---|---|---|
| `Edge_vX.bin` | ESP32 | `ESP32_GENERIC` | ✓ | | name "Evezor Edge" |
| `Edge_vX_SPIRAM.bin` | ESP32 | `ESP32_GENERIC` / `SPIRAM` | ✓ | | |
| `Edge_vX_CAM.bin` | ESP32 | custom board (SPIRAM) | ✓? | ✓ | port old partition/heap settings |
| `Edge_S3_vX.bin` | S3 | `ESP32_GENERIC_S3` | ✓ | | |
| `Edge_S3_vX_SPIRAM.bin` | S3 | `ESP32_GENERIC_S3` / `SPIRAM_OCT` (or quad) | ✓ | | depends on module PSRAM type |
| `Edge_S3_vX_CAM.bin` | S3 | custom S3 board | ✓? | ✓ | |

Best layout: our own board folders (`boards/EVEZOR_EDGE`, `boards/EVEZOR_EDGE_S3`, with
variants) passed in via `BOARD_DIR=`, plus CAN and camera as `USER_C_MODULES`. **No MicroPython
fork needed.** Everything gets pinned (MP tag, IDF tag, module commits) in one place so builds
are reproducible.

## 4. Container plan

Problems with the current `Dockerfile` (don't build on it as-is):

- Clones MicroPython `master` unpinned, with IDF `v5.4.2`. Neither matches what actually worked.
- `install.sh esp32` installs **only the ESP32 toolchain** (S3 needs `esp32s3`).
- `RUN source ./esp-idf/export.sh` doesn't persist between layers (and `/bin/sh` has no `source`).
- apt build deps get installed *after* `install.sh`.

**Proposal:** base it on Espressif's official image, **`espressif/idf:v5.5.2`** (toolchains
for all chips preinstalled, IDF env set up). Add MicroPython at a pinned tag plus the module
repos. Mount `boards/`, `modules/` and `out/` from this repo, and keep a named volume for the
component-manager cache. A `build.sh` inside the container loops over the matrix and copies
renamed `.bin`s to `out/`.

---

## 5. ⚠️ At the airport (before boarding): everything that needs internet

Builds download a lot on the **first run**: IDF tools, git submodules, and the IDF Component
Manager deps (mdns, esp_tinyusb, esp32-camera…). None of that works offline. Do all of this on
the airport Wi-Fi before boarding:

```bash
# in WSL
docker pull espressif/idf:v5.5.2          # several GB

mkdir -p ~/mp-src && cd ~/mp-src
git clone https://github.com/micropython/micropython.git
cd micropython && git checkout v1.29.0
make -C mpy-cross
cd ports/esp32 && make submodules          # pulls the submodules esp32 needs
cd ~/mp-src

git clone https://github.com/cnadler86/micropython-camera-API.git
git clone https://github.com/cnadler86/esp32-camera.git
git clone https://github.com/straga/micropython-esp32-twai.git        # reference/fallback

# ESP32 machine.CAN PR, for option B
cd micropython && git fetch origin pull/19461/head:pr-19461-machine-can && cd ..
```

Then **run one full build per chip online** (inside the IDF container, mounting `~/mp-src`)
so the component manager fills its cache and `managed_components/`:

```bash
make BOARD=ESP32_GENERIC BOARD_VARIANT=SPIRAM
make BOARD=ESP32_GENERIC_S3 BOARD_VARIANT=SPIRAM_OCT
# and one camera build with esp32-camera added to idf_component.yml
```

After that, a no-network rebuild should work. Also grab offline docs worth having:
MicroPython `docs/` (in the clone), the ESP-IDF TWAI docs page, and the camera-API README.

Also: keep the old `~/micropython` WSL tree untouched. It's the only working v1.19 build
environment left.

---

## 6. Open questions to settle

1. **Which S3 module?** Flash/PSRAM size and type (e.g. N8R2 = quad PSRAM, N16R8 = octal) decide the variant and partitions.
2. **Camera boards:** still OV2640? Which pinout (AI-Thinker style, or custom Edge pins)? Does the camera build also need CAN?
3. **"A few add-ons":** what else goes in? (Other C modules, frozen `.py` libraries, BLE, etc.)
4. **CAN API:** OK to keep `esp32.CAN` for now (option A), or move to `machine.CAN` straight away?
5. **What are the `iris_*` binaries?** Same build, different board name? Do they need new versions too?
6. Does any app code depend on the lemariva camera API? It will need rewriting for the new driver.
7. Bluetooth: the CAM build disabled it to save RAM. Is it needed on the others?

## Sources

- MicroPython releases: https://github.com/micropython/micropython/releases
- esp32 port README (IDF versions, BOARD_VARIANT): https://github.com/micropython/micropython/blob/master/ports/esp32/README.md
- ESP32 `machine.CAN` PR #19461: https://github.com/micropython/micropython/pull/19461
- Original ESP32 CAN PR #9532 (the driver in the fork): https://github.com/micropython/micropython/pull/9532
- straga TWAI user module: https://github.com/straga/micropython-esp32-twai
- Camera API: https://github.com/cnadler86/micropython-camera-API (releases: …/releases)
