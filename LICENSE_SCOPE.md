# Licenses, third-party notices, and content scope

## Software

`LICENSE` at repository root and `firmware/LICENSE` reproduce the existing
**MIT license** of the publicly available upstream `CapDyn_Scheduler`
project, copyright (c) 2026 KubriksCodeTN. The MIT license permits
commercial and noncommercial use. This repository does **not** change the
license of the original source or remove any notices.

Individual files in the firmware are also subject to **third-party
licenses**, including:

- `firmware/components/hm0360/`: Arduino SA, **LGPL-3.0-or-later**.
- `firmware/components/sx1262/`: Semtech, **Clear BSD**; see its `LICENSE.txt`.
- `firmware/components/sht4x/`: Sensirion, BSD-style terms in file headers.
- `firmware/components/tsl2591/`: third-party **MIT** terms in file headers.
- `firmware/lnk_msp430fr5994.cmd`: TI BSD-style terms in header.
- `firmware/driverlib/`: check each redistributed vendor component's terms.

These notices are indicative and **not** an exhaustive legal audit. The
reference LGPL-3.0 and GPL-3.0 texts (relevant to LGPL-3.0-or-later) are
included in `THIRD_PARTY_LICENSES/`. Any redistribution or modification
must honor all applicable terms, particularly LGPL requirements for the
HM0360 driver.

