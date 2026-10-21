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
In order to replicate the results, one must run all LTspice simulations and save the following traces to text: 

Single cap: 
V(en2) V(inout_nrg)/1V*1J V(pow_in) V(pow_out) V(strd_nrg)/1V*1J V(t1) V(t2) V(t3) V(t4) V(t5) V(t6) I(Eh_out_pow_trace) I(Load_out) V(eof) V(clk_reg)
Capdyn: 
V(en1)	V(en2_cap) V(clk_reg) V(on_stg) V(V_in) V(pow_out) V(q1_p) V(q2_p) V(q3_p) V(q4_p) V(q5_p) V(strd_nrg)/1V*1J V(t1) V(t2) V(t3) V(t4) V(t5) V(t6) V(v_bck) V(v_cpdn) V(vddrsig) I(C7) I(D2) I(D3) I(I_in) I(Load_out) V(inout_nrg)/1V*1J 

Match the name of the saved data file to the name of the LTspice simulation - then run the analysis script on Matlab.
