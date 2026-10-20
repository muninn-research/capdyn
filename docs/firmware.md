# MSP430 reference firmware

The `firmware/` folder contains the upstream source archive of CapDyn Scheduler.

## Source layout

- `scheduler.c`, `scheduler.h`: atomic task execution and next-task choice.
  `next_task()` is a **weak** function using round-robin by default.
- `scheduler_pins.h`: MSP430 GPIO definitions for the storage interface.
- `hibernus.c`, `hibernus.h`: snapshot and shutdown support.
- `main.c`: demonstration application and board pin setup.
- `components/`: HM0360, SHT4x, TSL2591, SX1262, I2C/SPI drivers.
- `driverlib/`, `lnk_msp430fr5994.cmd`: MSP430FR5994 support and linker file.

## API excerpts

```c
err_t task_create(task_t* task, task_function_t fptr, void* args,
                  energy_level_t en);
void scheduler_init(task_t* tasks, uint16_t size,
                    task_handle_t first_id);
err_t next_task(task_handle_t previous_id,
                task_handle_t* new_id);
void scheduler_start(void);
```

The bundled source uses energy levels from 1 to 8, represented through a
shift-register interface. Adapt the energy-level-to-stage mapping to the
physical capacitor-bank configuration actually used.

## Build and hardware requirements

This is a **reference source snapshot**, not a confirmed one-click build.
You will need a compatible MSP430 development environment (e.g., TI Code
Composer Studio), the target MSP430FR5994 toolchain and header files,
the correct board/CapDYN wiring, and the required compiler/linker settings.
This repository does not include a CCS `.project` / `.cproject` build workspace.
