# Published tabulated results

These CSV files transcribe values reported in the IEEE Sensors Journal paper.

- `task_profiles_from_paper_table_II.csv`: task average power/time/energy and
  task-to-stage assignments for exponential (`E`) and synthetic linear (`L`) workload.
  Data rows are taken directly from the paper's LaTeX source.
- `stage_capacity_energy_from_paper_table_III.csv`: nominal configurations
  and available stored energy for D1 and D2, 3 to 7 stages. Data values
  transcribed from paper Table III (two-decimal published precision).

**Important:** These are **published aggregate/tabulated values**, not raw
oscilloscope traces, per-run profiling observations or the 300+ GB of raw
LTspice waveforms. The linear workload is synthetic by design. The irradiance
input dataset is cited in the paper and must be obtained separately from its provider.
