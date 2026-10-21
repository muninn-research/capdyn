# LTspice models 

This folder holds the LTspice schematics, libraries, simulation input files (p1_tablong2.txt) and
analysis script (capdyn_merge_with_unaware_benchmark.m) used to compute the results. 

The paper evaluates 3–7 CapDYN stages with D1/D2 banks, compares against
S0/S1/S2/AB, and uses a photovoltaic irradiance trace over 18,000 s with
input power disabled during each active task. Detailed task profiles and
stage values transcribed from the paper appear under `../data/`.

Per the authors, individual LTspice simulations take approximately 3–5 days,
and the complete raw simulation output exceeds 300 GB. Only executable
model/configuration inputs, not those raw outputs, are intended for release.
