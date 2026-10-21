clc; close all; clear;

%% ============================================================
%% CapDYN benchmark merger - minimal merge of the four scripts
%%
%% Final visible plot per CapDYN case:
%%   tile 1: Benchmark 0 single capacitor, unaware
%%   tile 2: Benchmark 1 single capacitor, no sleep mode
%%   tile 3: Benchmark 2 single capacitor, sleep mode
%%   tile 4: CapDYN ablation benchmark, file name = bench_<CapDYN case>
%%   tile 5: CapDYN benchmark
%%
%% Ablation files are loaded and analyzed exactly like normal CapDYN files.
%% ============================================================

%% ============================================================
%% User options
%% ============================================================

% Choose {'exp'}, {'lin'}, or {'exp','lin'}.
taskSetsToRun = {'exp','lin'};

% Empty cell means plot all common CapDYN cases for each task set.
% Example: finalCasesToPlot = {'cpdn_6stage_dim','cpdn_6stage_dim_D2'};
% Example: finalCasesToPlot = {'cpdn_6stage_dim_lin','cpdn_6stage_dim_lin_D2'};
finalCasesToPlot = {};
badAblationCases = {}; 
makeDiagnosticPlots = false;     % original check figures, hidden unless true
makeFinalPlots      = true;
makeFinalPlotsVisible = true;
exportFinalPlots    = true;
outputDir           = 'merged_outputs';
xMaxFinal           = 18000;

benchmarkRunOrder = [2 3 1];   % run: bench1, bench2, then bench0

%% ============================================================
%% Setup
%% ============================================================
set(0,'defaulttextinterpreter','latex')
set(groot, 'defaultAxesTickLabelInterpreter','latex');
set(groot, 'defaultLegendInterpreter','latex');

set(0,'defaultAxesFontSize',15)
set(0,'DefaultLegendFontSize',15)

addpath('sim_results_raws')

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

metricRows = newmetrics_init_rows();

%% ============================================================
%% Run selected task sets
%% ============================================================
allSuites = struct();

for tsIdx = 1:numel(taskSetsToRun)

    taskSet = lower(taskSetsToRun{tsIdx});
    suiteCfg = make_suite_config(taskSet, true);

    fprintf('\n\n============================================================\n');
    fprintf('RUNNING TASK SET: %s\n', upper(taskSet));
    fprintf('============================================================\n');

    suiteResults = struct();
    suiteAblResults = struct();
    suiteCompareResults = struct();
    suiteRaw = struct();
    suiteAblRaw = struct();

    for ord = 1:numel(benchmarkRunOrder)

        b = benchmarkRunOrder(ord);
        B = suiteCfg.benchmarks(b);
        fprintf('\n\n------------------------------------------------------------\n');
        fprintf('Benchmark: %s\n', B.label);
        fprintf('Single file: %s\n', B.singleFile);
        fprintf('------------------------------------------------------------\n');

        suiteResults.(B.id) = struct();
        suiteAblResults.(B.id) = struct();
        suiteCompareResults.(B.id) = struct();

        if ~file_exists_anywhere(B.singleFile)
            warning('Single-cap benchmark file not found: %s. Skipping benchmark %s for task set %s.', ...
                B.singleFile, B.id, taskSet);
            continue;
        end

        S = load_single_case(B.singleFile, B.singleFormat, taskSet);

        suiteRaw.(B.id).S = S;
        suiteRaw.(B.id).singlePlotField = B.singlePlotField;
        suiteRaw.(B.id).label = B.label;
        suiteRaw.(B.id).C = struct();
        suiteRaw.(B.id).caseNames = struct();

        suiteAblRaw.(B.id).C = struct();
        suiteAblRaw.(B.id).caseNames = struct();
        suiteAblRaw.(B.id).fileNames = struct();

        for k = 1:numel(B.cpdnFiles)

            cpdnFile = B.cpdnFiles{k};
            [~, caseName, ~] = fileparts(cpdnFile);
            caseField = matlab.lang.makeValidName(caseName);

            fprintf('\n############################################################\n');
            fprintf('Running analysis for %s / %s\n', B.id, caseName);
            fprintf('############################################################\n');

            if ~file_exists_anywhere(cpdnFile)
                warning('CapDYN file not found: %s. Skipping this case and continuing.', cpdnFile);
                continue;
            end

            C = load_cpdn_case(cpdnFile, taskSet);

            opts = struct();
            opts.makeDiagnosticPlots = makeDiagnosticPlots;
            opts.singlePlotField = B.singlePlotField;
            opts.taskSet = taskSet;

            R = analyze_single_vs_cpdn(S, C, caseName, opts);

            suiteResults.(B.id).(caseField) = R;
            suiteRaw.(B.id).C.(caseField) = C;
            suiteRaw.(B.id).caseNames.(caseField) = caseName;

            % ------------------------------------------------------------
            % Ablation benchmark: processed like a normal CapDYN file.
            % File name convention: bench_<caseName>, optionally with .txt.
            % ------------------------------------------------------------
            ablationFile = make_ablation_filename(cpdnFile);

            if file_exists_anywhere(ablationFile)
                [~, ablationCaseName, ~] = fileparts(ablationFile);

                fprintf('\n############################################################\n');
                fprintf('Running ABLATION analysis for %s / %s\n', B.id, ablationCaseName);
                fprintf('############################################################\n');

                Cabl = load_cpdn_case(ablationFile, taskSet);
                Rabl = analyze_single_vs_cpdn(S, Cabl, ablationCaseName, opts);

                suiteAblResults.(B.id).(caseField) = Rabl;
                suiteAblRaw.(B.id).C.(caseField) = Cabl;
                suiteAblRaw.(B.id).caseNames.(caseField) = ablationCaseName;
                suiteAblRaw.(B.id).fileNames.(caseField) = ablationFile;

                Rcmp = compare_capdyn_vs_ablation(R, Rabl);
                suiteCompareResults.(B.id).(caseField) = Rcmp;
                print_capdyn_ablation_comparison(caseName, ablationCaseName, B.label, Rcmp);

            else
                warning('Ablation file not found for %s. Expected %s, %s.txt, or the same under sim_results_raws. Skipping ablation for this case and continuing.', ...
                    caseName, ablationFile, ablationFile);
            end
        end

        print_compact_summary(suiteResults.(B.id), [B.label ' - CapDYN']);
        print_compact_summary(suiteAblResults.(B.id), [B.label ' - ablation']);
        print_compare_summary(suiteCompareResults.(B.id), [B.label ' - CapDYN vs ablation']);
    end

    allSuites.(taskSet).results = suiteResults;
    allSuites.(taskSet).ablationResults = suiteAblResults;
    allSuites.(taskSet).compareResults = suiteCompareResults;
    allSuites.(taskSet).raw = suiteRaw;
    allSuites.(taskSet).ablationRaw = suiteAblRaw;
    allSuites.(taskSet).cfg = suiteCfg;

    %% ========================================================
    %% Final visible plots
    %% ========================================================
    if makeFinalPlots

        bench0 = suiteCfg.benchmarks(1).id;
        bench1 = suiteCfg.benchmarks(2).id;
        bench2 = suiteCfg.benchmarks(3).id;

        fields0 = fieldnames(suiteResults.(bench0));
        fields1 = fieldnames(suiteResults.(bench1));
        fields2 = fieldnames(suiteResults.(bench2));

        ablFields0 = fieldnames(suiteAblResults.(bench0));
        ablFields1 = fieldnames(suiteAblResults.(bench1));
        ablFields2 = fieldnames(suiteAblResults.(bench2));
        cmpFields0 = fieldnames(suiteCompareResults.(bench0));
        cmpFields1 = fieldnames(suiteCompareResults.(bench1));
        cmpFields2 = fieldnames(suiteCompareResults.(bench2));

        commonFields = fields0(ismember(fields0, fields1));
        commonFields = commonFields(ismember(commonFields, fields2));

        commonFields = commonFields(ismember(commonFields, ablFields0));
        commonFields = commonFields(ismember(commonFields, ablFields1));
        commonFields = commonFields(ismember(commonFields, ablFields2));

        commonFields = commonFields(ismember(commonFields, cmpFields0));
        commonFields = commonFields(ismember(commonFields, cmpFields1));
        commonFields = commonFields(ismember(commonFields, cmpFields2));
        if isempty(finalCasesToPlot)
            fieldsToPlot = commonFields;
        else
            requestedFields = cellfun(@matlab.lang.makeValidName, finalCasesToPlot, 'UniformOutput', false);
            fieldsToPlot = requestedFields(ismember(requestedFields, commonFields));

            missing = requestedFields(~ismember(requestedFields, commonFields));
            if ~isempty(missing)
                warning('Some requested final cases are missing from either single-cap benchmark, CapDYN result, or ablation result and will be skipped.');
                disp(missing(:));
            end
        end

        for k = 1:numel(fieldsToPlot)

            caseField = fieldsToPlot{k};
            caseName = suiteRaw.(bench0).caseNames.(caseField);
            ablationCaseName = suiteAblRaw.(bench0).caseNames.(caseField);

            rec = struct();
            rec.bench0Label = suiteRaw.(bench0).label;
            rec.bench1Label = suiteRaw.(bench1).label;
            rec.bench2Label = suiteRaw.(bench2).label;

            rec.S0 = suiteRaw.(bench0).S;
            rec.S1 = suiteRaw.(bench1).S;
            rec.S2 = suiteRaw.(bench2).S;
            rec.singlePlotField0 = suiteRaw.(bench0).singlePlotField;
            rec.singlePlotField1 = suiteRaw.(bench1).singlePlotField;
            rec.singlePlotField2 = suiteRaw.(bench2).singlePlotField;

            % The single-cap detections are identical for all CapDYN cases
            % inside the same benchmark, so reuse this case's R.single.
            rec.Rsingle0 = suiteResults.(bench0).(caseField).single;
            rec.Rsingle1 = suiteResults.(bench1).(caseField).single;
            rec.Rsingle2 = suiteResults.(bench2).(caseField).single;

            % Ablation and CapDYN panels use the CapDYN detection internals.
            rec.Cabl = suiteAblRaw.(bench0).C.(caseField);
            rec.Rabl = suiteAblResults.(bench0).(caseField).cpdn;
            rec.ablationCaseName = ablationCaseName;

            rec.C = suiteRaw.(bench0).C.(caseField);
            rec.Rcpdn = suiteResults.(bench0).(caseField).cpdn;
            rec.caseName = caseName;

            % ------------------------------------------------------------
            % Explicit comparison matrix for this physical case.
            % CapDYN and ablation are each compared against all single-cap
            % benchmarks, then full CapDYN is compared directly to ablation.
            % ------------------------------------------------------------
            print_case_comparison_matrix( ...
                caseName, ablationCaseName, ...
                suiteRaw.(bench0).label, suiteResults.(bench0).(caseField), suiteAblResults.(bench0).(caseField), ...
                suiteRaw.(bench1).label, suiteResults.(bench1).(caseField), suiteAblResults.(bench1).(caseField), ...
                suiteRaw.(bench2).label, suiteResults.(bench2).(caseField), suiteAblResults.(bench2).(caseField), ...
                suiteCompareResults.(bench0).(caseField));

            plotOpts = struct();
            plotOpts.visible = makeFinalPlotsVisible;
            plotOpts.export = exportFinalPlots;
            plotOpts.outputDir = outputDir;
            plotOpts.xMax = xMaxFinal;
            plotOpts.taskSet = taskSet;

            plot_final_four_tiles(caseName, rec, plotOpts);
        end
    end

    metricRows = newmetrics_collect_taskset( ...
    metricRows, taskSet, suiteCfg, suiteResults, suiteAblResults, xMaxFinal, badAblationCases);
end

%% ============================================================
%% Generate LaTeX efficiency / effective-efficiency tables
%% ============================================================
generate_paper_latex_tables(allSuites, outputDir);
newmetrics_write_latex_tables(metricRows, outputDir);

%% ========================================================================
%% FUNCTIONS
%% ========================================================================


function metricRows = newmetrics_init_rows()

rowTemplate = newmetrics_empty_row();
metricRows = repmat(rowTemplate, 0, 1);

end


function metricRows = newmetrics_collect_taskset(metricRows, taskSet, suiteCfg, suiteResults, suiteAblResults, Ttest, excludeAblationCaseFields)

if nargin < 7 || isempty(excludeAblationCaseFields)
    excludeAblationCaseFields = {};
end

if nargin < 6 || isempty(Ttest)
    Ttest = 18000;
end

bench0 = suiteCfg.benchmarks(1).id;   % S0: unaware
bench1 = suiteCfg.benchmarks(2).id;   % S1: no sleep
bench2 = suiteCfg.benchmarks(3).id;   % S2: sleep

benchIds = {bench0, bench1, bench2};

caseFields = {};
for b = 1:numel(benchIds)
    bid = benchIds{b};
    if isfield(suiteResults, bid)
        caseFields = union(caseFields, fieldnames(suiteResults.(bid)));
    end
end

for iCase = 1:numel(caseFields)

    caseField = caseFields{iCase};

    row = newmetrics_empty_row();
    row.taskSet = lower(taskSet);
    row.taskLabel = newmetrics_task_label(taskSet);
    row.caseField = caseField;
    row.caseName = caseField;

    [row.nStages, row.bank] = newmetrics_parse_case(caseField);

    R0 = newmetrics_get_case_result(suiteResults, bench0, caseField);
    R1 = newmetrics_get_case_result(suiteResults, bench1, caseField);
    R2 = newmetrics_get_case_result(suiteResults, bench2, caseField);

    % ------------------------------------------------------------
    % Aggregate first-execution advance vs S0/S1/S2.
    % Positive = earlier under CapDYN.
    % ------------------------------------------------------------
    if ~isempty(R0)
        row.A_S0 = newmetrics_aggregate_first_advance(R0.t_exec_cpdn, R0.t_exec_single);
    end

    if ~isempty(R1)
        row.A_S1 = newmetrics_aggregate_first_advance(R1.t_exec_cpdn, R1.t_exec_single);
    end

    if ~isempty(R2)
        row.A_S2 = newmetrics_aggregate_first_advance(R2.t_exec_cpdn, R2.t_exec_single);
    end

    % ------------------------------------------------------------
    % S0 efficiency penalty table.
    % ------------------------------------------------------------
    if ~isempty(R0)
        row.eta_S0 = 100 * R0.eff_s;
        row.etaEff_S0 = 100 * R0.effeff_s;

        row.etaEff_CapDYN = 100 * R0.effeff_c;
        row.dEtaEff_S0 = 100 * (R0.effeff_c - R0.effeff_s);
    end

    % ------------------------------------------------------------
    % Effective-efficiency deltas vs S1/S2.
    % Deltas are percentage points.
    % ------------------------------------------------------------
    if ~isempty(R1)
        etaEffCpdn1 = 100 * R1.effeff_c;
        etaEffS1 = 100 * R1.effeff_s;

        if ~isfinite(row.etaEff_CapDYN)
            row.etaEff_CapDYN = etaEffCpdn1;
        end

        row.dEtaEff_S1 = etaEffCpdn1 - etaEffS1;
    end

    if ~isempty(R2)
        etaEffCpdn2 = 100 * R2.effeff_c;
        etaEffS2 = 100 * R2.effeff_s;

        if ~isfinite(row.etaEff_CapDYN)
            row.etaEff_CapDYN = etaEffCpdn2;
        end

        row.dEtaEff_S2 = etaEffCpdn2 - etaEffS2;
    end

    % ------------------------------------------------------------
    % Timely successful-task yield vs S0/S1/S2.
    % ------------------------------------------------------------
    if ~isempty(R0)
        Yc0 = newmetrics_timely_yield(R0.cpdn, Ttest);
        Ys0 = newmetrics_timely_yield(R0.single, Ttest);

        row.Y_CapDYN = Yc0;
        row.Ygain_S0 = newmetrics_relative_gain_pct(Yc0, Ys0);
    end

    if ~isempty(R1)
        Yc1 = newmetrics_timely_yield(R1.cpdn, Ttest);
        Ys1 = newmetrics_timely_yield(R1.single, Ttest);

        if ~isfinite(row.Y_CapDYN)
            row.Y_CapDYN = Yc1;
        end

        row.Ygain_S1 = newmetrics_relative_gain_pct(Yc1, Ys1);
    end

    if ~isempty(R2)
        Yc2 = newmetrics_timely_yield(R2.cpdn, Ttest);
        Ys2 = newmetrics_timely_yield(R2.single, Ttest);

        if ~isfinite(row.Y_CapDYN)
            row.Y_CapDYN = Yc2;
        end

        row.Ygain_S2 = newmetrics_relative_gain_pct(Yc2, Ys2);
    end

    % ------------------------------------------------------------
    % AB metrics.
    % Use the first benchmark where both CapDYN and ablation exist.
    % ------------------------------------------------------------
    if ~ismember(caseField, excludeAblationCaseFields)

        [RcapAB, RablAB] = newmetrics_get_capdyn_ablation_pair( ...
            suiteResults, suiteAblResults, benchIds, caseField);

        if ~isempty(RcapAB) && ~isempty(RablAB)

            row.A_AB = newmetrics_aggregate_first_advance(RcapAB.t_exec_cpdn, RablAB.t_exec_cpdn);
            row.abShift = newmetrics_per_task_shift(RcapAB.t_exec_cpdn, RablAB.t_exec_cpdn);
            row.dEtaEff_AB = 100 * (RcapAB.effeff_c - RablAB.effeff_c);

            YcapAB = newmetrics_timely_yield(RcapAB.cpdn, Ttest);
            YablAB = newmetrics_timely_yield(RablAB.cpdn, Ttest);
            row.Ygain_AB = newmetrics_relative_gain_pct(YcapAB, YablAB);
            row.Gthr_AB = newmetrics_relative_gain_pct(sum(RcapAB.n_cpdn), sum(RablAB.n_cpdn));
        end
    end

    % ------------------------------------------------------------
    % Successful-task throughput gains vs S0/S1/S2.
    % ------------------------------------------------------------
    if ~isempty(R0)
        row.N_CapDYN = sum(R0.n_cpdn);
        row.Gthr_S0 = newmetrics_relative_gain_pct(sum(R0.n_cpdn), sum(R0.n_single));
    end

    if ~isempty(R1)
        if ~isfinite(row.N_CapDYN)
            row.N_CapDYN = sum(R1.n_cpdn);
        end
        row.Gthr_S1 = newmetrics_relative_gain_pct(sum(R1.n_cpdn), sum(R1.n_single));
    end

    if ~isempty(R2)
        if ~isfinite(row.N_CapDYN)
            row.N_CapDYN = sum(R2.n_cpdn);
        end
        row.Gthr_S2 = newmetrics_relative_gain_pct(sum(R2.n_cpdn), sum(R2.n_single));
    end

    if isempty(metricRows)
        metricRows = row;
    else
        row = orderfields(row, metricRows);
        metricRows(end+1) = row; %#ok<AGROW>
    end
end

end


function newmetrics_write_latex_tables(metricRows, outputDir)

if isempty(metricRows)
    warning('No metric rows available. Skipping new metric LaTeX tables.');
    return;
end

if nargin < 2 || isempty(outputDir)
    outputDir = '.';
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

newmetrics_write_aggregate_first_exec_table(metricRows, fullfile(outputDir, 'table_aggregate_first_execution_advance.tex'));
newmetrics_write_s0_efficiency_penalty_table(metricRows, fullfile(outputDir, 'table_s0_efficiency_penalty.tex'));
newmetrics_write_effeff_delta_table(metricRows, fullfile(outputDir, 'table_effective_efficiency_s1_s2_ab.tex'));
newmetrics_write_timely_yield_table(metricRows, fullfile(outputDir, 'table_timely_successful_task_yield.tex'));
newmetrics_write_ab_only_scheduling_table(metricRows, fullfile(outputDir, 'table_ab_only_scheduling_shift.tex'));
newmetrics_write_throughput_gain_table(metricRows, fullfile(outputDir, 'table_throughput_gain.tex'));

fprintf('\nGenerated new metric LaTeX tables in: %s\n', outputDir);
fprintf('  table_aggregate_first_execution_advance.tex\n');
fprintf('  table_s0_efficiency_penalty.tex\n');
fprintf('  table_effective_efficiency_s1_s2_ab.tex\n');
fprintf('  table_timely_successful_task_yield.tex\n');
fprintf('  table_ab_only_scheduling_shift.tex\n');

end

function newmetrics_write_throughput_gain_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Successful-task throughput and relative throughput gain of \sysname with respect to the reference baselines.}');
newmetrics_writeln(fid, '\label{tab:throughput_gain}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{4pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N_{\mathrm{stg}}$ & $N_{\sysname}$ & S0 & S1 & S2 & AB \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_abs(r.N_CapDYN), ...
        newmetrics_fmt_pct(r.Gthr_S0), ...
        newmetrics_fmt_pct(r.Gthr_S1), ...
        newmetrics_fmt_pct(r.Gthr_S2), ...
        newmetrics_fmt_pct(r.Gthr_AB));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} $N_{\sysname}$ is the total number of successful task completions under \sysname. The S0, S1, S2, and AB columns report $G^{\mathrm{thr}}_{\sysname/r}$ in percent.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end
function row = newmetrics_empty_row()

row = struct();

row.taskSet = '';
row.taskLabel = '';
row.bank = '';
row.nStages = NaN;
row.caseField = '';
row.caseName = '';

row.A_S0 = NaN;
row.A_S1 = NaN;
row.A_S2 = NaN;
row.A_AB = NaN;

row.eta_S0 = NaN;
row.etaEff_S0 = NaN;
row.etaEff_CapDYN = NaN;

row.dEtaEff_S0 = NaN;
row.dEtaEff_S1 = NaN;
row.dEtaEff_S2 = NaN;
row.dEtaEff_AB = NaN;

row.Y_CapDYN = NaN;
row.Ygain_S0 = NaN;
row.Ygain_S1 = NaN;
row.Ygain_S2 = NaN;
row.Ygain_AB = NaN;

row.abShift = NaN(1,6);

row.N_CapDYN = NaN;
row.Gthr_S0 = NaN;
row.Gthr_S1 = NaN;
row.Gthr_S2 = NaN;
row.Gthr_AB = NaN;

end


function newmetrics_write_aggregate_first_exec_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Aggregate first-completion advance of \sysname relative to the reference baselines. Positive values indicate earlier first successful task completion under \sysname.}');
newmetrics_writeln(fid, '\label{tab:aggregate_first_completion_advance}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{4pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N$ & S0 & S1 & S2 & AB \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_pct(r.A_S0), ...
        newmetrics_fmt_pct(r.A_S1), ...
        newmetrics_fmt_pct(r.A_S2), ...
        newmetrics_fmt_pct(r.A_AB));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} Values report $A_{\sysname/r}$ in percent. Positive values indicate earlier first task completion under \sysname. AB denotes the ablation without energy-admissible task dispatch.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end


function newmetrics_write_s0_efficiency_penalty_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Efficiency penalty of the unaware single-capacitor baseline S0 and effective-efficiency comparison with \sysname.}');
newmetrics_writeln(fid, '\label{tab:s0_efficiency_penalty}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{3.5pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N$ & $\eta_{\mathrm{S0}}$ & $\eta^{\mathrm{eff}}_{\mathrm{S0}}$ & $\eta^{\mathrm{eff}}_{\sysname}$ & $\Delta\eta^{\mathrm{eff}}$ \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_pct(r.eta_S0), ...
        newmetrics_fmt_pct(r.etaEff_S0), ...
        newmetrics_fmt_pct(r.etaEff_CapDYN), ...
        newmetrics_fmt_dpp(r.dEtaEff_S0));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} Efficiencies are reported in percent. $\Delta\eta^{\mathrm{eff}}=\eta^{\mathrm{eff}}_{\sysname}-\eta^{\mathrm{eff}}_{\mathrm{S0}}$ is reported in percentage points.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end


function newmetrics_write_effeff_delta_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Effective-efficiency comparison of \sysname against the energy-aware baselines and ablation.}');
newmetrics_writeln(fid, '\label{tab:efficiency_s1_s2_ab}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{4pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N$ & $\eta^{\mathrm{eff}}_{\sysname}$ & $\Delta$S1 & $\Delta$S2 & $\Delta$AB \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_pct(r.etaEff_CapDYN), ...
        newmetrics_fmt_dpp(r.dEtaEff_S1), ...
        newmetrics_fmt_dpp(r.dEtaEff_S2), ...
        newmetrics_fmt_dpp(r.dEtaEff_AB));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} $\eta^{\mathrm{eff}}_{\sysname}$ is reported in percent. $\Delta$S1, $\Delta$S2, and $\Delta$AB report effective-efficiency differences in percentage points relative to the corresponding reference.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end


function newmetrics_write_timely_yield_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Timely successful-task yield gain of \sysname relative to the reference baselines. Positive values indicate higher time-weighted useful task yield.}');
newmetrics_writeln(fid, '\label{tab:timely_task_yield}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{4pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N$ & $Y_{\sysname}$ & S0 & S1 & S2 & AB \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_abs(r.Y_CapDYN), ...
        newmetrics_fmt_pct(r.Ygain_S0), ...
        newmetrics_fmt_pct(r.Ygain_S1), ...
        newmetrics_fmt_pct(r.Ygain_S2), ...
        newmetrics_fmt_pct(r.Ygain_AB));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} $Y_{\sysname}$ is the absolute timely successful-task yield of \sysname. The S0, S1, S2, and AB columns report $G^Y_{\sysname/r}$ in percent.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end


function newmetrics_write_ab_only_scheduling_table(rows, outFile)

fid = fopen(outFile, 'w');
assert(fid > 0, 'Could not open output file: %s', outFile);

newmetrics_writeln(fid, '\begin{table}[t]');
newmetrics_writeln(fid, '\centering');
newmetrics_writeln(fid, '\caption{Per-task first-completion shift of \sysname relative to the ablation baseline AB. Negative values indicate earlier first task completion under \sysname.}');
newmetrics_writeln(fid, '\label{tab:scheduling_ab_only}');
newmetrics_writeln(fid, '\scriptsize');
newmetrics_writeln(fid, '\setlength{\tabcolsep}{4pt}');
newmetrics_writeln(fid, '\renewcommand{\arraystretch}{1.12}');
newmetrics_writeln(fid, '\resizebox{\columnwidth}{!}{%');
newmetrics_writeln(fid, '\begin{tabular}{@{}llcrrrrrr@{}}');
newmetrics_writeln(fid, '\toprule');
newmetrics_writeln(fid, 'Task set & Bank & $N$ & $T_1$ & $T_2$ & $T_3$ & $T_4$ & $T_5$ & $T_6$ \\');
newmetrics_writeln(fid, '\midrule');

idx = newmetrics_sorted_indices(rows);
lastGroup = '';

for k = 1:numel(idx)
    r = rows(idx(k));
    group = [r.taskLabel '_' r.bank];

    if k > 1 && ~strcmp(group, lastGroup)
        newmetrics_writeln(fid, '\midrule');
    end

    fprintf(fid, '%s & %s & %d & %s & %s & %s & %s & %s & %s \\\\\n', ...
        r.taskLabel, r.bank, r.nStages, ...
        newmetrics_fmt_pct(r.abShift(1)), ...
        newmetrics_fmt_pct(r.abShift(2)), ...
        newmetrics_fmt_pct(r.abShift(3)), ...
        newmetrics_fmt_pct(r.abShift(4)), ...
        newmetrics_fmt_pct(r.abShift(5)), ...
        newmetrics_fmt_pct(r.abShift(6)));

    lastGroup = group;
end

newmetrics_writeln(fid, '\bottomrule');
newmetrics_writeln(fid, '\end{tabular}%');
newmetrics_writeln(fid, '}');
newmetrics_writeln(fid, '\vspace{2pt}');
newmetrics_writeln(fid, '\footnotesize');
newmetrics_writeln(fid, '\textbf{Notes.} Values report the first-completion shift $\Delta t_{i,\sysname/AB}$ in percent. AB denotes the ablation without energy-admissible task dispatch.');
newmetrics_writeln(fid, '\end{table}');

fclose(fid);

end


function [Rcap, Rabl] = newmetrics_get_capdyn_ablation_pair(suiteResults, suiteAblResults, benchIds, caseField)

Rcap = [];
Rabl = [];

for b = 1:numel(benchIds)
    bid = benchIds{b};

    Rc = newmetrics_get_case_result(suiteResults, bid, caseField);
    Ra = newmetrics_get_case_result(suiteAblResults, bid, caseField);

    if ~isempty(Rc) && ~isempty(Ra)
        Rcap = Rc;
        Rabl = Ra;
        return;
    end
end

end


function R = newmetrics_get_case_result(S, benchId, caseField)

R = [];

if isempty(S) || ~isstruct(S)
    return;
end

if ~isfield(S, benchId)
    return;
end

if ~isfield(S.(benchId), caseField)
    return;
end

R = S.(benchId).(caseField);

end


function A = newmetrics_aggregate_first_advance(tc, tr)

tc = double(tc(:)).';
tr = double(tr(:)).';

n = min(numel(tc), numel(tr));
tc = tc(1:n);
tr = tr(1:n);

shift = 100 .* (tc - tr) ./ tr;
valid = isfinite(shift) & isfinite(tc) & isfinite(tr) & tc > 0 & tr > 0;

if any(valid)
    A = -mean(shift(valid));
else
    A = NaN;
end

end


function shift = newmetrics_per_task_shift(tc, tr)

tc = double(tc(:)).';
tr = double(tr(:)).';

n = min(numel(tc), numel(tr));
tc = tc(1:n);
tr = tr(1:n);

shift = 100 .* (tc - tr) ./ tr;
shift(~isfinite(shift) | ~isfinite(tc) | ~isfinite(tr) | tc <= 0 | tr <= 0) = NaN;

if numel(shift) < 6
    shift(end+1:6) = NaN;
end

end


function Y = newmetrics_timely_yield(traceStruct, Ttest)

if nargin < 2 || isempty(Ttest)
    Ttest = 18000;
end

Y = NaN;

taskTimes = newmetrics_success_end_vectors(traceStruct, 6);

if isempty(taskTimes)
    return;
end

Ysum = 0;
hasAny = false;

for iTask = 1:numel(taskTimes)
    t = taskTimes{iTask};
    t = t(:);
    t = t(isfinite(t) & t >= 0);

    if isempty(t)
        continue;
    end

    contrib = 1 - (t ./ Ttest);
    contrib = max(0, contrib);

    Ysum = Ysum + sum(contrib);
    hasAny = true;
end

if hasAny
    Y = Ysum;
end

end


function tFirst = newmetrics_first_success_times(traceStruct)

taskTimes = newmetrics_success_end_vectors(traceStruct, 6);
tFirst = NaN(1,6);

if isempty(taskTimes)
    return;
end

for iTask = 1:6
    t = taskTimes{iTask};
    t = t(:);
    t = t(isfinite(t) & t > 0);

    if ~isempty(t)
        tFirst(iTask) = min(t);
    end
end

end


function taskTimes = newmetrics_success_end_vectors(traceStruct, nTasks)

if nargin < 2
    nTasks = 6;
end

taskTimes = cell(1,nTasks);

if isempty(traceStruct) || ~isstruct(traceStruct)
    taskTimes = {};
    return;
end

successEnd = [];

candidateFields = { ...
    'successEnd', ...
    'successEnds', ...
    'success_end', ...
    'success_end_times', ...
    'successfulEnd', ...
    'successfulEnds'};

for i = 1:numel(candidateFields)
    f = candidateFields{i};
    if isfield(traceStruct, f)
        successEnd = traceStruct.(f);
        break;
    end
end

if isempty(successEnd)
    taskTimes = {};
    return;
end

for iTask = 1:nTasks
    taskTimes{iTask} = newmetrics_extract_task_vector(successEnd, iTask);
end

end


function v = newmetrics_extract_task_vector(X, taskIdx)

v = [];

if isempty(X)
    return;
end

if iscell(X)
    if numel(X) >= taskIdx
        v = X{taskIdx};
    end

elseif isnumeric(X)
    if isvector(X)
        if numel(X) >= taskIdx
            v = X(taskIdx);
        end
    else
        if size(X,2) >= taskIdx
            v = X(:,taskIdx);
        elseif size(X,1) >= taskIdx
            v = X(taskIdx,:);
        end
    end

elseif isstruct(X)
    fieldCandidates = { ...
        sprintf('T%d', taskIdx), ...
        sprintf('t%d', taskIdx), ...
        sprintf('task%d', taskIdx), ...
        sprintf('Task%d', taskIdx)};

    for i = 1:numel(fieldCandidates)
        f = fieldCandidates{i};
        if isfield(X, f)
            v = X.(f);
            return;
        end
    end
end

if isempty(v)
    v = [];
else
    v = double(v(:));
end

end


function effPct = newmetrics_efficiency_pct(traceStruct, useEffective)

effPct = NaN;

if isempty(traceStruct) || ~isstruct(traceStruct)
    return;
end

if useEffective
    names = { ...
        'effectiveEfficiency', ...
        'effEfficiency', ...
        'eff_efficiency', ...
        'effective_efficiency', ...
        'etaEff', ...
        'eta_eff', ...
        'efficiencyEff'};
else
    names = { ...
        'efficiency', ...
        'eff', ...
        'eta', ...
        'rawEfficiency', ...
        'raw_efficiency'};
end

eff = newmetrics_pick_numeric(traceStruct, names);

if ~isfinite(eff)
    Ein = newmetrics_pick_numeric(traceStruct, {'Ein','E_in','energyIn','energyInput','Einput','E_input'});
    Eout = newmetrics_pick_numeric(traceStruct, {'Eout','E_out','energyOut','energyOutput','Eoutput','E_output'});

    if useEffective
        Ew = newmetrics_pick_numeric(traceStruct, {'Ewasted','E_wasted','Ew','E_w','wastedEnergy','failedEnergy'});
        if ~isfinite(Ew)
            Ew = 0;
        end

        if isfinite(Ein) && isfinite(Eout) && Ein > 0
            eff = (Eout - Ew) / Ein;
        end
    else
        if isfinite(Ein) && isfinite(Eout) && Ein > 0
            eff = Eout / Ein;
        end
    end
end

if ~isfinite(eff)
    return;
end

if abs(eff) <= 1.5
    effPct = 100 * eff;
else
    effPct = eff;
end

end


function value = newmetrics_pick_numeric(S, names)

value = NaN;

if isempty(S) || ~isstruct(S)
    return;
end

fns = fieldnames(S);

for i = 1:numel(names)
    idx = find(strcmpi(fns, names{i}), 1);

    if ~isempty(idx)
        tmp = S.(fns{idx});

        if isnumeric(tmp) && ~isempty(tmp)
            tmp = tmp(:);
            tmp = tmp(isfinite(tmp));

            if ~isempty(tmp)
                value = tmp(1);
                return;
            end
        end
    end
end

end


function g = newmetrics_relative_gain_pct(x, r)

if isfinite(x) && isfinite(r) && r > 0
    g = 100 * (x - r) / r;
else
    g = NaN;
end

end


function [nStages, bank] = newmetrics_parse_case(caseField)

nStages = NaN;
bank = 'D1';

tok = regexp(caseField, '(\d+)stage', 'tokens', 'once');
if ~isempty(tok)
    nStages = str2double(tok{1});
end

if contains(caseField, 'D2')
    bank = 'D2';
end

end


function label = newmetrics_task_label(taskSet)

switch lower(taskSet)
    case 'exp'
        label = 'Expon.';
    case 'lin'
        label = 'Linear';
    otherwise
        label = taskSet;
end

end


function idx = newmetrics_sorted_indices(rows)

n = numel(rows);
taskRank = zeros(n,1);
bankRank = zeros(n,1);
stageRank = zeros(n,1);

for i = 1:n
    switch rows(i).taskLabel
        case 'Expon.'
            taskRank(i) = 1;
        case 'Linear'
            taskRank(i) = 2;
        otherwise
            taskRank(i) = 99;
    end

    switch rows(i).bank
        case 'D1'
            bankRank(i) = 1;
        case 'D2'
            bankRank(i) = 2;
        otherwise
            bankRank(i) = 99;
    end

    stageRank(i) = rows(i).nStages;
    if ~isfinite(stageRank(i))
        stageRank(i) = 999;
    end
end

[~, idx] = sortrows([taskRank, bankRank, stageRank]);

end


function s = newmetrics_fmt_pct(x)

if ~isfinite(x)
    s = '--';
else
    s = sprintf('%.2f', x);
end

end


function s = newmetrics_fmt_dpp(x)

if ~isfinite(x)
    s = '--';
else
    s = sprintf('%.2f', x);
end

end


function s = newmetrics_fmt_abs(x)

if ~isfinite(x)
    s = '--';
else
    s = sprintf('%.3f', x);
end

end


function newmetrics_writeln(fid, line)
fprintf(fid, '%s\n', line);
end

function generate_efficiency_latex_tables(allSuites, outputDir)

if nargin < 2 || isempty(outputDir)
    outputDir = pwd;
end

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

banks = struct([]);

banks(1).name = 'D1';
banks(1).label = 'd1';
banks(1).captionName = 'D1';
banks(1).power_uW = [11.925, 12.309, 12.659, 13.029, 13.367];

banks(2).name = 'D2';
banks(2).label = 'd2';
banks(2).captionName = 'D2';
banks(2).power_uW = [12.463, 13.099, 14.755, 17.980, 29.206];

for b = 1:numel(banks)

    latexLines = build_efficiency_latex_table(allSuites, banks(b));

    fprintf('\n\n============================================================\n');
    fprintf('GENERATED LATEX EFFICIENCY TABLE - %s\n', banks(b).name);
    fprintf('============================================================\n');
    fprintf('%s\n', latexLines{:});

    outFile = fullfile(outputDir, sprintf('efficiency_table_%s.tex', banks(b).label));
    fid = fopen(outFile, 'w');

    if fid < 0
        warning('Could not open %s for writing.', outFile);
    else
        fprintf(fid, '%s\n', latexLines{:});
        fclose(fid);
        fprintf('\nSaved LaTeX table to: %s\n', outFile);
    end
end

end


function latexLines = build_efficiency_latex_table(allSuites, bank)

singlePower_uW = 0.720;
stages = 3:7;

latexLines = {};

latexLines{end+1} = '\begin{table}[t]';
latexLines{end+1} = '\centering';
latexLines{end+1} = sprintf(['\\caption{Efficiency and effective efficiency comparison for ' ...
    'single-cap baselines, ablation, and $N$-stage CapDYN, %s bank.}'], bank.captionName);
latexLines{end+1} = sprintf('\\label{tab:efficiency_%s}', bank.label);
latexLines{end+1} = '\scriptsize';
latexLines{end+1} = '\setlength{\tabcolsep}{2.2pt}';
latexLines{end+1} = '\renewcommand{\arraystretch}{1.12}';
latexLines{end+1} = '\resizebox{\columnwidth}{!}{%';
latexLines{end+1} = '\begin{tabular}{@{}llccccc@{}}';
latexLines{end+1} = '\toprule';
latexLines{end+1} = 'Reference & $N$ & Exp. Eff. (\%) & Exp. EEU (\%) & Lin. Eff. (\%) & Lin. EEU (\%) & Power ($\mu$W) \\';
latexLines{end+1} = '\midrule';

% ------------------------------------------------------------------------
% Single-cap benchmark rows: S0, S1, S2
% ------------------------------------------------------------------------
singleIDs = {'bench0_unaware', 'bench1_nosleep', 'bench2_sleep'};
singleNames = {'S0 unaware', 'S1 no sleep', 'S2 sleep'};

for i = 1:numel(singleIDs)

    [expEff, expEEU] = get_single_eff_pair(allSuites, 'exp', singleIDs{i});
    [linEff, linEEU] = get_single_eff_pair(allSuites, 'lin', singleIDs{i});

    latexLines{end+1} = sprintf('%s & -- & %s & %s & %s & %s & %.3f \\\\', ...
        singleNames{i}, ...
        fmt_pct(expEff), fmt_pct(expEEU), ...
        fmt_pct(linEff), fmt_pct(linEEU), ...
        singlePower_uW);
end

latexLines{end+1} = '\midrule';

% ------------------------------------------------------------------------
% Ablation rows
% ------------------------------------------------------------------------
for idx = 1:numel(stages)
    N = stages(idx);

    [expEff, expEEU] = get_candidate_eff_pair(allSuites, 'exp', 'ablationResults', N, bank.name);
    [linEff, linEEU] = get_candidate_eff_pair(allSuites, 'lin', 'ablationResults', N, bank.name);

    latexLines{end+1} = sprintf('Ablation & %d & %s & %s & %s & %s & %.3f \\\\', ...
        N, ...
        fmt_pct(expEff), fmt_pct(expEEU), ...
        fmt_pct(linEff), fmt_pct(linEEU), ...
        bank.power_uW(idx));
end

latexLines{end+1} = '\midrule';

% ------------------------------------------------------------------------
% Full CapDYN rows
% ------------------------------------------------------------------------
for idx = 1:numel(stages)
    N = stages(idx);

    [expEff, expEEU] = get_candidate_eff_pair(allSuites, 'exp', 'results', N, bank.name);
    [linEff, linEEU] = get_candidate_eff_pair(allSuites, 'lin', 'results', N, bank.name);

    latexLines{end+1} = sprintf('CapDYN & %d & %s & %s & %s & %s & %.3f \\\\', ...
        N, ...
        fmt_pct(expEff), fmt_pct(expEEU), ...
        fmt_pct(linEff), fmt_pct(linEEU), ...
        bank.power_uW(idx));
end

latexLines{end+1} = '\bottomrule';
latexLines{end+1} = '\end{tabular}%';
latexLines{end+1} = '}';
latexLines{end+1} = '\vspace{2pt}';
latexLines{end+1} = '\footnotesize';
latexLines{end+1} = ['\textbf{Notes.} Eff. denotes raw conversion efficiency; EEU denotes effective efficiency, ' ...
                     'i.e., conversion efficiency after subtracting energy wasted by failed executions. ' ...
                     'S0, S1, and S2 denote the unaware, no-sleep, and sleep-mode single-cap baselines, respectively.'];
latexLines{end+1} = '\end{table}';

end


function [eff, eeu] = get_single_eff_pair(allSuites, taskSet, benchID)

eff = NaN;
eeu = NaN;

if ~isfield(allSuites, taskSet)
    return;
end

if ~isfield(allSuites.(taskSet), 'results')
    return;
end

if ~isfield(allSuites.(taskSet).results, benchID)
    return;
end

caseFields = fieldnames(allSuites.(taskSet).results.(benchID));
if isempty(caseFields)
    return;
end

% Single-cap metrics are repeated for every case within the same benchmark.
R = allSuites.(taskSet).results.(benchID).(caseFields{1});

if isfield(R, 'eff_s')
    eff = R.eff_s;
end

if isfield(R, 'effeff_s')
    eeu = R.effeff_s;
end

end

function generate_paper_latex_tables(allSuites, outputDir)

if nargin < 2 || isempty(outputDir)
    outputDir = pwd;
end

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

banks = paper_bank_specs();

for b = 1:numel(banks)

    schedLines = paper_build_scheduling_shift_table(allSuites, banks(b));
    schedFile = fullfile(outputDir, sprintf('scheduling_shift_%s.tex', banks(b).label));
    paper_write_lines(schedFile, schedLines);
    fprintf('Saved scheduling-shift table to: %s\n', schedFile);

    effLines = paper_build_efficiency_table(allSuites, banks(b));
    effFile = fullfile(outputDir, sprintf('efficiency_%s.tex', banks(b).label));
    paper_write_lines(effFile, effLines);
    fprintf('Saved efficiency table to: %s\n', effFile);
end

end


function banks = paper_bank_specs()

banks = struct([]);

banks(1).name = 'D1';
banks(1).label = 'd1';
banks(1).captionName = 'D1';
banks(1).power_uW = [11.925, 12.309, 12.659, 13.029, 13.367];

banks(2).name = 'D2';
banks(2).label = 'd2';
banks(2).captionName = 'D2';
banks(2).power_uW = [12.463, 13.099, 14.755, 17.980, 29.206];

end


function paper_write_lines(outFile, lines)

fid = fopen(outFile, 'w');
if fid < 0
    warning('Could not open %s for writing.', outFile);
    return;
end

fprintf(fid, '%s\n', lines{:});
fclose(fid);

end


function latexLines = paper_build_scheduling_shift_table(allSuites, bank)

stages = 3:7;
taskSets = {'lin', 'exp'};
taskSetLabels = {'Linear', 'Expon.'};

refs = {'bench0_unaware', 'bench1_nosleep', 'bench2_sleep', 'AB'};
refLabels = {'S0', 'S1', 'S2', 'AB'};

latexLines = {};

latexLines{end+1} = '\begin{table}[t]';
latexLines{end+1} = '\centering';
latexLines{end+1} = ['\caption{First task-completion shift vs.\ reference baselines for the ' ...
    bank.captionName ' bank (negative = earlier execution).}'];
latexLines{end+1} = ['\label{tab:scheduling_' bank.label '}'];
latexLines{end+1} = '\tiny';
latexLines{end+1} = '\setlength{\tabcolsep}{1.2pt}';
latexLines{end+1} = '\renewcommand{\arraystretch}{1.12}';
latexLines{end+1} = '';
latexLines{end+1} = '\resizebox{\columnwidth}{!}{%';
latexLines{end+1} = '\begin{tabular}{@{}cc*{24}{c}@{}}';
latexLines{end+1} = '\toprule';
latexLines{end+1} = '&';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_1$}';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_2$}';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_3$}';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_4$}';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_5$}';
latexLines{end+1} = '& \multicolumn{4}{c}{$T_6$} \\';
latexLines{end+1} = '\cmidrule(lr){3-6}';
latexLines{end+1} = '\cmidrule(lr){7-10}';
latexLines{end+1} = '\cmidrule(lr){11-14}';
latexLines{end+1} = '\cmidrule(lr){15-18}';
latexLines{end+1} = '\cmidrule(lr){19-22}';
latexLines{end+1} = '\cmidrule(l){23-26}';

header = '& $N$';
for t = 1:6
    for r = 1:numel(refLabels)
        header = [header ' & ' refLabels{r}]; %#ok<AGROW>
    end
end
header = [header ' \\'];
latexLines{end+1} = header;
latexLines{end+1} = '\midrule';

for g = 1:numel(taskSets)

    taskSet = taskSets{g};
    taskSetLabel = taskSetLabels{g};

    for sIdx = 1:numel(stages)

        N = stages(sIdx);

        if sIdx == 1
            row = sprintf('\\multirow{%d}{*}{\\rotatebox[origin=c]{90}{\\textit{%s}}} & %d', ...
                numel(stages), taskSetLabel, N);
        else
            row = sprintf('& %d', N);
        end

        for taskIdx = 1:6
            for r = 1:numel(refs)
                val = paper_get_task_shift(allSuites, taskSet, N, bank.name, refs{r}, taskIdx);
                row = [row ' & ' paper_fmt_number(val)]; %#ok<AGROW>
            end
        end

        row = [row ' \\'];
        latexLines{end+1} = row;
        latexLines{end+1} = '';
    end

    if g < numel(taskSets)
        latexLines{end+1} = '\midrule';
    end
end

latexLines{end+1} = '\bottomrule';
latexLines{end+1} = '\end{tabular}%';
latexLines{end+1} = '}';
latexLines{end+1} = '';
latexLines{end+1} = '\vspace{2pt}';
latexLines{end+1} = '\footnotesize';
latexLines{end+1} = ['\textbf{Notes.} First-completion shift is computed as ' ...
    '$\displaystyle 100\cdot (t_{\mathrm{end},c}^{\mathrm{first}}-t_{\mathrm{end},r}^{\mathrm{first}})/t_{\mathrm{end},r}^{\mathrm{first}}$. ' ...
    'Negative values indicate earlier execution under CapDYN. ' ...
    'S0, S1, and S2 denote the single-cap baselines; AB denotes the CapDYN ablation.'];
latexLines{end+1} = '\end{table}';

end


function val = paper_get_task_shift(allSuites, taskSet, N, bankName, refName, taskIdx)

val = NaN;

caseName = paper_make_case_name(taskSet, N, bankName);
caseField = matlab.lang.makeValidName(caseName);

switch refName

    case {'bench0_unaware', 'bench1_nosleep', 'bench2_sleep'}

        if ~paper_has_result(allSuites, taskSet, 'results', refName, caseField)
            return;
        end

        R = allSuites.(taskSet).results.(refName).(caseField);

        if isfield(R, 'impr_pct') && numel(R.impr_pct) >= taskIdx
            val = R.impr_pct(taskIdx);
        end

    case 'AB'

        benchPriority = {'bench1_nosleep', 'bench2_sleep', 'bench0_unaware'};

        for b = 1:numel(benchPriority)

            benchID = benchPriority{b};

            hasCap = paper_has_result(allSuites, taskSet, 'results', benchID, caseField);
            hasAbl = paper_has_result(allSuites, taskSet, 'ablationResults', benchID, caseField);

            if ~hasCap || ~hasAbl
                continue;
            end

            Rcap = allSuites.(taskSet).results.(benchID).(caseField);
            Rabl = allSuites.(taskSet).ablationResults.(benchID).(caseField);

            if ~isfield(Rcap, 't_exec_cpdn') || ~isfield(Rabl, 't_exec_cpdn')
                return;
            end

            if numel(Rcap.t_exec_cpdn) < taskIdx || numel(Rabl.t_exec_cpdn) < taskIdx
                return;
            end

            tCap = Rcap.t_exec_cpdn(taskIdx);
            tAbl = Rabl.t_exec_cpdn(taskIdx);

            if isfinite(tCap) && isfinite(tAbl) && tAbl ~= 0
                val = 100 * ((tCap - tAbl) / tAbl);
            end

            return;
        end
end

end


function latexLines = paper_build_efficiency_table(allSuites, bank)

stages = 3:7;

latexLines = {};

latexLines{end+1} = '\begin{table}[t]';
latexLines{end+1} = '\centering';
latexLines{end+1} = ['\caption{Efficiency, EEU and infrastructural power consumption comparison for ' ...
    'single-cap baselines, ablation, and CapDYN, ' bank.captionName ' bank.}'];
latexLines{end+1} = ['\label{tab:efficiency_' bank.label '}'];
latexLines{end+1} = '\scriptsize';
latexLines{end+1} = '\setlength{\tabcolsep}{1.4pt}';
latexLines{end+1} = '\renewcommand{\arraystretch}{1.05}';
latexLines{end+1} = '\scalebox{1}{%';
latexLines{end+1} = '\begin{tabular}{@{}llccccc@{}}';
latexLines{end+1} = '\toprule';
latexLines{end+1} = '\multirow{2}{*}{Ref.} & \multirow{2}{*}{$N$}';
latexLines{end+1} = '& \multicolumn{2}{c}{Eff. (\%)}';
latexLines{end+1} = '& \multicolumn{2}{c}{EEU (\%)}';
latexLines{end+1} = '& \multirow{2}{*}{$P_\mathrm{INFR}$ ($\mu$W)} \\';
latexLines{end+1} = '\cmidrule(lr){3-4}';
latexLines{end+1} = '\cmidrule(lr){5-6}';
latexLines{end+1} = '& & Exp. & Lin. & Exp. & Lin. & \\';
latexLines{end+1} = '\midrule';

singleRows = { ...
    'S0', 'bench0_unaware', NaN; ...
    'S1', 'bench1_nosleep', 4.186; ...
    'S2', 'bench2_sleep',   1.635};

for i = 1:size(singleRows,1)

    refLabel = singleRows{i,1};
    benchID = singleRows{i,2};
    pInfr = singleRows{i,3};

    [effExp, eeuExp] = paper_get_single_eff_pair(allSuites, 'exp', benchID);
    [effLin, eeuLin] = paper_get_single_eff_pair(allSuites, 'lin', benchID);

    latexLines{end+1} = sprintf('%s & -- & %s & %s & %s & %s & %s \\\\', ...
        refLabel, ...
        paper_fmt_percent(effExp), ...
        paper_fmt_percent(effLin), ...
        paper_fmt_percent(eeuExp), ...
        paper_fmt_percent(eeuLin), ...
        paper_fmt_power(pInfr));
end

latexLines{end+1} = '\midrule';

for idx = 1:numel(stages)

    N = stages(idx);

    [effExp, eeuExp] = paper_get_candidate_eff_pair(allSuites, 'exp', 'ablationResults', N, bank.name);
    [effLin, eeuLin] = paper_get_candidate_eff_pair(allSuites, 'lin', 'ablationResults', N, bank.name);

    latexLines{end+1} = sprintf('Abl. & %d & %s & %s & %s & %s & %.3f \\\\', ...
        N, ...
        paper_fmt_percent(effExp), ...
        paper_fmt_percent(effLin), ...
        paper_fmt_percent(eeuExp), ...
        paper_fmt_percent(eeuLin), ...
        bank.power_uW(idx));
end

latexLines{end+1} = '\midrule';

for idx = 1:numel(stages)

    N = stages(idx);

    [effExp, eeuExp] = paper_get_candidate_eff_pair(allSuites, 'exp', 'results', N, bank.name);
    [effLin, eeuLin] = paper_get_candidate_eff_pair(allSuites, 'lin', 'results', N, bank.name);

    latexLines{end+1} = sprintf('CD & %d & %s & %s & %s & %s & %.3f \\\\', ...
        N, ...
        paper_fmt_percent(effExp), ...
        paper_fmt_percent(effLin), ...
        paper_fmt_percent(eeuExp), ...
        paper_fmt_percent(eeuLin), ...
        bank.power_uW(idx));
end

latexLines{end+1} = '\bottomrule';
latexLines{end+1} = '\end{tabular}';
latexLines{end+1} = '}';
latexLines{end+1} = '\end{table}';

end


function [eff, eeu] = paper_get_single_eff_pair(allSuites, taskSet, benchID)

eff = NaN;
eeu = NaN;

if ~isfield(allSuites, taskSet)
    return;
end

if ~isfield(allSuites.(taskSet), 'results')
    return;
end

if ~isfield(allSuites.(taskSet).results, benchID)
    return;
end

caseFields = fieldnames(allSuites.(taskSet).results.(benchID));
if isempty(caseFields)
    return;
end

R = allSuites.(taskSet).results.(benchID).(caseFields{1});

if isfield(R, 'eff_s')
    eff = R.eff_s;
end

if isfield(R, 'effeff_s')
    eeu = R.effeff_s;
end

end


function [eff, eeu] = paper_get_candidate_eff_pair(allSuites, taskSet, resultGroup, N, bankName)

eff = NaN;
eeu = NaN;

caseName = paper_make_case_name(taskSet, N, bankName);
caseField = matlab.lang.makeValidName(caseName);

benchPriority = {'bench1_nosleep', 'bench2_sleep', 'bench0_unaware'};

for b = 1:numel(benchPriority)

    benchID = benchPriority{b};

    if ~paper_has_result(allSuites, taskSet, resultGroup, benchID, caseField)
        continue;
    end

    R = allSuites.(taskSet).(resultGroup).(benchID).(caseField);

    if isfield(R, 'eff_c')
        eff = R.eff_c;
    end

    if isfield(R, 'effeff_c')
        eeu = R.effeff_c;
    end

    return;
end

end


function tf = paper_has_result(allSuites, taskSet, resultGroup, benchID, caseField)

tf = false;

if ~isfield(allSuites, taskSet)
    return;
end

if ~isfield(allSuites.(taskSet), resultGroup)
    return;
end

if ~isfield(allSuites.(taskSet).(resultGroup), benchID)
    return;
end

if ~isfield(allSuites.(taskSet).(resultGroup).(benchID), caseField)
    return;
end

tf = true;

end


function caseName = paper_make_case_name(taskSet, N, bankName)

switch lower(taskSet)
    case 'exp'
        taskSuffix = '';
    case 'lin'
        taskSuffix = '_lin';
    otherwise
        error('Unknown task set: %s.', taskSet);
end

switch upper(bankName)
    case 'D1'
        bankSuffix = '';
    case 'D2'
        bankSuffix = '_D2';
    otherwise
        error('Unknown bank name: %s.', bankName);
end

caseName = sprintf('cpdn_%dstage_dim%s%s', N, taskSuffix, bankSuffix);

end


function s = paper_fmt_number(x)

if isempty(x) || ~isfinite(x)
    s = '--';
else
    s = sprintf('%.2f', x);
end

end


function s = paper_fmt_percent(x)

if isempty(x) || ~isfinite(x)
    s = '--';
else
    s = sprintf('%.2f', 100*x);
end

end


function s = paper_fmt_power(x)

if isempty(x) || ~isfinite(x)
    s = '--';
else
    s = sprintf('%.3f', x);
end

end


function [eff, eeu] = get_candidate_eff_pair(allSuites, taskSet, resultGroup, N, bankName)

eff = NaN;
eeu = NaN;

if ~isfield(allSuites, taskSet)
    return;
end

if ~isfield(allSuites.(taskSet), resultGroup)
    return;
end

caseName = make_case_name_for_eff_table(taskSet, N, bankName);
caseField = matlab.lang.makeValidName(caseName);

benchPriority = {'bench0_unaware', 'bench1_nosleep', 'bench2_sleep'};

for b = 1:numel(benchPriority)

    benchID = benchPriority{b};

    if ~isfield(allSuites.(taskSet).(resultGroup), benchID)
        continue;
    end

    if ~isfield(allSuites.(taskSet).(resultGroup).(benchID), caseField)
        continue;
    end

    R = allSuites.(taskSet).(resultGroup).(benchID).(caseField);

    if isfield(R, 'eff_c')
        eff = R.eff_c;
    end

    if isfield(R, 'effeff_c')
        eeu = R.effeff_c;
    end

    return;
end

end


function caseName = make_case_name_for_eff_table(taskSet, N, bankName)

switch lower(taskSet)
    case 'exp'
        taskSuffix = '';
    case 'lin'
        taskSuffix = '_lin';
    otherwise
        error('Unknown task set: %s.', taskSet);
end

switch upper(bankName)
    case 'D1'
        bankSuffix = '';
    case 'D2'
        bankSuffix = '_D2';
    otherwise
        error('Unknown bank name: %s.', bankName);
end

caseName = sprintf('cpdn_%dstage_dim%s%s', N, taskSuffix, bankSuffix);

end


function s = fmt_pct(x)

if isempty(x) || ~isfinite(x)
    s = '--';
else
    s = sprintf('%.2f', 100*x);
end

end

function filesOut = keep_existing_case_files(filesIn, listLabel)

filesOut = {};

fprintf('\n------------------------------------------------------------\n');
fprintf('Checking available CapDYN files for: %s\n', listLabel);
fprintf('------------------------------------------------------------\n');

for k = 1:numel(filesIn)

    fname = filesIn{k};

    if file_exists_anywhere(fname)
        filesOut{end+1} = fname; %#ok<AGROW>
        fprintf('  OK      %s\n', fname);
    else
        warning('Missing CapDYN file in %s: %s. Removing it from this run.', listLabel, fname);
    end
end

if isempty(filesOut)
    warning('No available CapDYN files left for %s.', listLabel);
end

end

function suiteCfg = make_suite_config(taskSet, skipMissingCapdynFiles)

if nargin < 2
    skipMissingCapdynFiles = true;
end

switch lower(taskSet)

    case 'exp'
        suiteCfg.name = 'Experimental task set';

        cpdnFiles = { ...
            'cpdn_3stage_dim.txt', ...
            'cpdn_4stage_dim.txt', ...
            'cpdn_5stage_dim.txt', ...
            'cpdn_6stage_dim.txt', ...
            'cpdn_7stage_dim.txt', ...
            'cpdn_3stage_dim_D2.txt', ...
            'cpdn_4stage_dim_D2.txt', ...
            'cpdn_5stage_dim_D2.txt', ...
            'cpdn_6stage_dim_D2.txt', ...
            'cpdn_7stage_dim_D2.txt'};

        bench1Files = cpdnFiles;
        bench2Files = cpdnFiles;

        labelSuffix = '';
        bench0SingleFile = 'bench_0_unaware.txt';
        bench1SingleFile = 'bench_1_nosleepmode.txt';
        bench2SingleFile = 'bench_2_sleepmode.txt';

    case 'lin'
        suiteCfg.name = 'Linear task set';

        cpdnFiles = { ...
            'cpdn_3stage_dim_lin.txt', ...
            'cpdn_4stage_dim_lin.txt', ...
            'cpdn_5stage_dim_lin.txt', ...
            'cpdn_6stage_dim_lin.txt', ...
            'cpdn_7stage_dim_lin.txt', ...
            'cpdn_3stage_dim_lin_D2.txt', ...
            'cpdn_4stage_dim_lin_D2.txt', ...
            'cpdn_5stage_dim_lin_D2.txt', ...
            'cpdn_6stage_dim_lin_D2.txt', ...
            'cpdn_7stage_dim_lin_D2.txt'};

        bench1Files = cpdnFiles;
        bench2Files = cpdnFiles;

        labelSuffix = ' lin';
        bench0SingleFile = 'bench_0_unaware_lin.txt';
        bench1SingleFile = 'bench_1_nosleepmode_lin.txt';
        bench2SingleFile = 'bench_2_sleepmode_lin.txt';

    otherwise
        error('Unknown task set: %s. Use ''exp'' or ''lin''.', taskSet);
end

if skipMissingCapdynFiles
    bench1Files = keep_existing_case_files(bench1Files, [upper(taskSet) ' bench0/bench1 CapDYN list']);
    bench2Files = keep_existing_case_files(bench2Files, [upper(taskSet) ' bench2 CapDYN list']);
end

suiteCfg.benchmarks = struct([]);

suiteCfg.benchmarks(1).id = 'bench0_unaware';
suiteCfg.benchmarks(1).label = ['Benchmark 0: unaware' labelSuffix];
suiteCfg.benchmarks(1).singleFile = bench0SingleFile;
suiteCfg.benchmarks(1).singleFormat = 'nosleep';
suiteCfg.benchmarks(1).singlePlotField = 'pow_in';
suiteCfg.benchmarks(1).cpdnFiles = bench1Files;

suiteCfg.benchmarks(2).id = 'bench1_nosleep';
suiteCfg.benchmarks(2).label = ['Benchmark 1: no sleep mode' labelSuffix];
suiteCfg.benchmarks(2).singleFile = bench1SingleFile;
suiteCfg.benchmarks(2).singleFormat = 'nosleep';
suiteCfg.benchmarks(2).singlePlotField = 'pow_in';
suiteCfg.benchmarks(2).cpdnFiles = bench1Files;

suiteCfg.benchmarks(3).id = 'bench2_sleep';
suiteCfg.benchmarks(3).label = ['Benchmark 2: sleep mode' labelSuffix];
suiteCfg.benchmarks(3).singleFile = bench2SingleFile;
suiteCfg.benchmarks(3).singleFormat = 'sleep';
suiteCfg.benchmarks(3).singlePlotField = 'vin';
suiteCfg.benchmarks(3).cpdnFiles = bench2Files;

end

function R = analyze_single_vs_cpdn(S, C, caseName, opts)

if nargin < 4
    opts = struct();
end
if ~isfield(opts,'makeDiagnosticPlots'), opts.makeDiagnosticPlots = false; end
if ~isfield(opts,'singlePlotField'), opts.singlePlotField = 'vin'; end
if ~isfield(opts,'taskSet'), opts.taskSet = 'exp'; end

%% ============================================================
%% Detect executions - single
%% ============================================================
[s_t1_bin, ex_1,  m1s,  m1f,  t1_exec_start,  t1_exec_end,  t1_fail_start,  t1_fail_end,  t1_fail_dur] = detect_execs(S.t, S.en2, S.t1, S.t1_exec_nom, []); %#ok<ASGLU>
[s_t2_bin, ex_2,  m2s,  m2f,  t2_exec_start,  t2_exec_end,  t2_fail_start,  t2_fail_end,  t2_fail_dur] = detect_execs(S.t, S.en2, S.t2, S.t2_exec_nom, []); %#ok<ASGLU>
[s_t3_bin, ex_3,  m3s,  m3f,  t3_exec_start,  t3_exec_end,  t3_fail_start,  t3_fail_end,  t3_fail_dur] = detect_execs(S.t, S.en2, S.t3, S.t3_exec_nom, []); %#ok<ASGLU>
[s_t4_bin, ex_4,  m4s,  m4f,  t4_exec_start,  t4_exec_end,  t4_fail_start,  t4_fail_end,  t4_fail_dur] = detect_execs(S.t, S.en2, S.t4, S.t4_exec_nom, []); %#ok<ASGLU>
[s_t5_bin, ex_5,  m5s,  m5f,  t5_exec_start,  t5_exec_end,  t5_fail_start,  t5_fail_end,  t5_fail_dur] = detect_execs(S.t, S.en2, S.t5, S.t5_exec_nom, []); %#ok<ASGLU>
[s_t6_bin, ex_6,  m6s,  m6f,  t6_exec_start,  t6_exec_end,  t6_fail_start,  t6_fail_end,  t6_fail_dur] = detect_execs(S.t, S.en2, S.t6, S.t6_exec_nom, []); %#ok<ASGLU>

%% ============================================================
%% Detect executions - CapDYN
%% ============================================================
[c_t1_bin, ex_1c, m1cs, m1cf, t1c_exec_start, t1c_exec_end, t1c_fail_start, t1c_fail_end, t1c_fail_dur] = detect_execs(C.t, C.en2, C.t1, C.t1_exec_nom, 100); %#ok<ASGLU>
[c_t2_bin, ex_2c, m2cs, m2cf, t2c_exec_start, t2c_exec_end, t2c_fail_start, t2c_fail_end, t2c_fail_dur] = detect_execs(C.t, C.en2, C.t2, C.t2_exec_nom, 100); %#ok<ASGLU>
[c_t3_bin, ex_3c, m3cs, m3cf, t3c_exec_start, t3c_exec_end, t3c_fail_start, t3c_fail_end, t3c_fail_dur] = detect_execs(C.t, C.en2, C.t3, C.t3_exec_nom, 100); %#ok<ASGLU>
[c_t4_bin, ex_4c, m4cs, m4cf, t4c_exec_start, t4c_exec_end, t4c_fail_start, t4c_fail_end, t4c_fail_dur] = detect_execs(C.t, C.en2, C.t4, C.t4_exec_nom, 100); %#ok<ASGLU>
[c_t5_bin, ex_5c, m5cs, m5cf, t5c_exec_start, t5c_exec_end, t5c_fail_start, t5c_fail_end, t5c_fail_dur] = detect_execs(C.t, C.en2, C.t5, C.t5_exec_nom, 100); %#ok<ASGLU>
[c_t6_bin, ex_6c, m6cs, m6cf, t6c_exec_start, t6c_exec_end, t6c_fail_start, t6c_fail_end, t6c_fail_dur] = detect_execs(C.t, C.en2, C.t6, C.t6_exec_nom, 100); %#ok<ASGLU>

if opts.makeDiagnosticPlots
    plot_diagnostics(S, C, caseName, opts.singlePlotField, ...
        {s_t1_bin,s_t2_bin,s_t3_bin,s_t4_bin,s_t5_bin,s_t6_bin}, ...
        {c_t1_bin,c_t2_bin,c_t3_bin,c_t4_bin,c_t5_bin,c_t6_bin});
    plot_single_diagnostics(S, caseName, opts.singlePlotField, ...
    {s_t1_bin,s_t2_bin,s_t3_bin,s_t4_bin,s_t5_bin,s_t6_bin});
end

%% ============================================================
%% First successful completion shift over single capacitor
%%
%% NOTE:
%% R.t_exec_cpdn and R.t_exec_single are kept as legacy field names
%% because downstream table-generation code already uses them.
%% They now store the completion time of the First successful completion,
%% not the start time.
%% ============================================================

R.t_exec_cpdn = NaN(1,6);
idx = find(m1cs,1); if ~isempty(idx), R.t_exec_cpdn(1) = t1c_exec_end(idx); end
idx = find(m2cs,1); if ~isempty(idx), R.t_exec_cpdn(2) = t2c_exec_end(idx); end
idx = find(m3cs,1); if ~isempty(idx), R.t_exec_cpdn(3) = t3c_exec_end(idx); end
idx = find(m4cs,1); if ~isempty(idx), R.t_exec_cpdn(4) = t4c_exec_end(idx); end
idx = find(m5cs,1); if ~isempty(idx), R.t_exec_cpdn(5) = t5c_exec_end(idx); end
idx = find(m6cs,1); if ~isempty(idx), R.t_exec_cpdn(6) = t6c_exec_end(idx); end

R.t_exec_single = NaN(1,6);
idx = find(m1s,1); if ~isempty(idx), R.t_exec_single(1) = t1_exec_end(idx); end
idx = find(m2s,1); if ~isempty(idx), R.t_exec_single(2) = t2_exec_end(idx); end
idx = find(m3s,1); if ~isempty(idx), R.t_exec_single(3) = t3_exec_end(idx); end
idx = find(m4s,1); if ~isempty(idx), R.t_exec_single(4) = t4_exec_end(idx); end
idx = find(m5s,1); if ~isempty(idx), R.t_exec_single(5) = t5_exec_end(idx); end
idx = find(m6s,1); if ~isempty(idx), R.t_exec_single(6) = t6_exec_end(idx); end

R.impr_pct = NaN(1,6);
valid = isfinite(R.t_exec_single) & isfinite(R.t_exec_cpdn) & (R.t_exec_single ~= 0);
R.impr_pct(valid) = 100*((R.t_exec_cpdn(valid) - R.t_exec_single(valid)) ./ R.t_exec_single(valid));

%% ============================================================
%% Throughput
%% ============================================================
R.n_single = [sum(m1s), sum(m2s), sum(m3s), sum(m4s), sum(m5s), sum(m6s)];
R.f_single = [sum(m1f), sum(m2f), sum(m3f), sum(m4f), sum(m5f), sum(m6f)];

R.n_cpdn = [sum(m1cs), sum(m2cs), sum(m3cs), sum(m4cs), sum(m5cs), sum(m6cs)];
R.f_cpdn = [sum(m1cf), sum(m2cf), sum(m3cf), sum(m4cf), sum(m5cf), sum(m6cf)];

total_s = sum(R.n_single);
total_c = sum(R.n_cpdn);

if total_s == 0
    R.throughput_impr_pct = NaN;
else
    R.throughput_impr_pct = 100 * ((total_c - total_s) / total_s);
end

%% ============================================================
%% Wasted energy from failed executions
%% ============================================================
R.Ew_single = [ ...
    sum(t1_fail_dur) * S.p1, ...
    sum(t2_fail_dur) * S.p2, ...
    sum(t3_fail_dur) * S.p3, ...
    sum(t4_fail_dur) * S.p4, ...
    sum(t5_fail_dur) * S.p5, ...
    sum(t6_fail_dur) * S.p6];

R.Ew_single_total = sum(R.Ew_single);

R.Ew_cpdn = [ ...
    sum(t1c_fail_dur) * C.p1, ...
    sum(t2c_fail_dur) * C.p2, ...
    sum(t3c_fail_dur) * C.p3, ...
    sum(t4c_fail_dur) * C.p4, ...
    sum(t5c_fail_dur) * C.p5, ...
    sum(t6c_fail_dur) * C.p6];

R.Ew_cpdn_total = sum(R.Ew_cpdn);

if R.Ew_single_total == 0
    R.Ew_shift_pct = 0;
else
    R.Ew_shift_pct = 100*((R.Ew_cpdn_total - R.Ew_single_total)/R.Ew_single_total);
end

%% ============================================================
%% Efficiency / Effective efficiency
%% ============================================================
Pin_c  = C.vin  .* C.iin;
Pout_c = C.vout .* C.iload;

Pin_s  = S.vin  .* S.iin;
Pout_s = S.vout .* S.iload;

idx6c = find(m6cs, 1);
if isempty(idx6c)
    t_end_c = NaN;
else
    t_end_c = t6c_exec_end(idx6c);
end

idx6s = find(m6s, 1);
if isempty(idx6s)
    t_end_s = NaN;
else
    t_end_s = t6_exec_end(idx6s);
end

R.t_end_c = t_end_c;
R.t_end_s = t_end_s;

R.Ein_c  = integrate_upto(C.t, Pin_c,  t_end_c);
R.Eout_c = integrate_upto(C.t, Pout_c, t_end_c);

R.Ein_s  = integrate_upto(S.t, Pin_s,  t_end_s);
R.Eout_s = integrate_upto(S.t, Pout_s, t_end_s);

Ew_c = 0;
if ~isnan(t_end_c)
    Ew_c = Ew_c + sum(t1c_fail_dur(t1c_fail_end <= t_end_c)) * C.p1;
    Ew_c = Ew_c + sum(t2c_fail_dur(t2c_fail_end <= t_end_c)) * C.p2;
    Ew_c = Ew_c + sum(t3c_fail_dur(t3c_fail_end <= t_end_c)) * C.p3;
    Ew_c = Ew_c + sum(t4c_fail_dur(t4c_fail_end <= t_end_c)) * C.p4;
    Ew_c = Ew_c + sum(t5c_fail_dur(t5c_fail_end <= t_end_c)) * C.p5;
    Ew_c = Ew_c + sum(t6c_fail_dur(t6c_fail_end <= t_end_c)) * C.p6;
else
    Ew_c = NaN;
end

Ew_s = 0;
if ~isnan(t_end_s)
    Ew_s = Ew_s + sum(t1_fail_dur(t1_fail_end <= t_end_s)) * S.p1;
    Ew_s = Ew_s + sum(t2_fail_dur(t2_fail_end <= t_end_s)) * S.p2;
    Ew_s = Ew_s + sum(t3_fail_dur(t3_fail_end <= t_end_s)) * S.p3;
    Ew_s = Ew_s + sum(t4_fail_dur(t4_fail_end <= t_end_s)) * S.p4;
    Ew_s = Ew_s + sum(t5_fail_dur(t5_fail_end <= t_end_s)) * S.p5;
    Ew_s = Ew_s + sum(t6_fail_dur(t6_fail_end <= t_end_s)) * S.p6;
else
    Ew_s = NaN;
end

R.Ew_c_window = Ew_c;
R.Ew_s_window = Ew_s;

R.eff_c = R.Eout_c / R.Ein_c;
R.eff_s = R.Eout_s / R.Ein_s;

R.effeff_c = (R.Eout_c - Ew_c) / R.Ein_c;
R.effeff_s = (R.Eout_s - Ew_s) / R.Ein_s;

R.nStages = C.nStages;

%% Save useful internals for final plot
R.single.execStart = {t1_exec_start, t2_exec_start, t3_exec_start, t4_exec_start, t5_exec_start, t6_exec_start};
R.single.execEnd   = {t1_exec_end,   t2_exec_end,   t3_exec_end,   t4_exec_end,   t5_exec_end,   t6_exec_end};
R.single.failStart = {t1_fail_start, t2_fail_start, t3_fail_start, t4_fail_start, t5_fail_start, t6_fail_start};
R.single.failEnd   = {t1_fail_end,   t2_fail_end,   t3_fail_end,   t4_fail_end,   t5_fail_end,   t6_fail_end};
R.single.successStart = {t1_exec_start(m1s), t2_exec_start(m2s), t3_exec_start(m3s), t4_exec_start(m4s), t5_exec_start(m5s), t6_exec_start(m6s)};
R.single.successEnd   = {t1_exec_end(m1s),   t2_exec_end(m2s),   t3_exec_end(m3s),   t4_exec_end(m4s),   t5_exec_end(m5s),   t6_exec_end(m6s)};

R.cpdn.execStart = {t1c_exec_start, t2c_exec_start, t3c_exec_start, t4c_exec_start, t5c_exec_start, t6c_exec_start};
R.cpdn.execEnd   = {t1c_exec_end,   t2c_exec_end,   t3c_exec_end,   t4c_exec_end,   t5c_exec_end,   t6c_exec_end};
R.cpdn.failStart = {t1c_fail_start, t2c_fail_start, t3c_fail_start, t4c_fail_start, t5c_fail_start, t6c_fail_start};
R.cpdn.failEnd   = {t1c_fail_end,   t2c_fail_end,   t3c_fail_end,   t4c_fail_end,   t5c_fail_end,   t6c_fail_end};
R.cpdn.successStart = {t1c_exec_start(m1cs), t2c_exec_start(m2cs), t3c_exec_start(m3cs), t4c_exec_start(m4cs), t5c_exec_start(m5cs), t6c_exec_start(m6cs)};
R.cpdn.successEnd   = {t1c_exec_end(m1cs),   t2c_exec_end(m2cs),   t3c_exec_end(m3cs),   t4c_exec_end(m4cs),   t5c_exec_end(m5cs),   t6c_exec_end(m6cs)};

%% Console summary
print_metrics_summary(caseName, R);

%% Latex table fill up



end

function plot_single_diagnostics(S, caseName, singlePlotField, singleBins)

figure('Name',['Single-cap diagnostics - ' caseName], ...
    'Position',[0 0 1200 600], 'Visible','on')

tl = tiledlayout('vertical', 'TileSpacing','tight', 'Padding','tight');
title(tl,' ', 'interpreter','latex')

nexttile
plot(S.t, S.(singlePlotField), 'DisplayName','$V_{SNG}$')
box on; grid on
xlabel('Time [s]')
ylabel('Voltage [V]')
legend

nexttile
hold on; box on; grid on
for i = 1:6
    plot(S.t, singleBins{i}, 'DisplayName', sprintf('$T_{%d}$', i))
end
xlabel('Time [s]')
ylabel('Task binary')
legend
ylim([-0.3 1.3])

nexttile
plot(S.t, S.en2, 'DisplayName','$EN_{2}$')
box on; grid on
xlabel('Time [s]')
ylabel('Voltage [V]')
legend
ylim([-0.3 3.3])

end

function print_metrics_summary(caseName, R)

taskNames = {'T1','T2','T3','T4','T5','T6'};

fprintf('\n============================================================\n');
fprintf('METRICS SUMMARY - %s\n', caseName);
fprintf('============================================================\n');

fprintf('\nFirst successful completion time [s]\n');
for i=1:6
    fprintf('  %s: single = %.6g, capdyn = %.6g\n', taskNames{i}, R.t_exec_single(i), R.t_exec_cpdn(i));
end

fprintf('\nFirst-completion shift vs single [%%]\n');
for i=1:6
    fprintf('  %s: %.6g %%\n', taskNames{i}, R.impr_pct(i));
end
fprintf('  (negative = earlier first completion under CapDYN)\n');

fprintf('\nExecution counts (success / fail)\n');
fprintf('  Single cap:\n');
fprintf('    T1 %d/%d, T2 %d/%d, T3 %d/%d, T4 %d/%d, T5 %d/%d, T6 %d/%d\n', ...
    R.n_single(1),R.f_single(1), R.n_single(2),R.f_single(2), R.n_single(3),R.f_single(3), ...
    R.n_single(4),R.f_single(4), R.n_single(5),R.f_single(5), R.n_single(6),R.f_single(6));
fprintf('    Total success = %d, total fail = %d\n', sum(R.n_single), sum(R.f_single));

fprintf('  CapDYN:\n');
fprintf('    T1 %d/%d, T2 %d/%d, T3 %d/%d, T4 %d/%d, T5 %d/%d, T6 %d/%d\n', ...
    R.n_cpdn(1),R.f_cpdn(1), R.n_cpdn(2),R.f_cpdn(2), R.n_cpdn(3),R.f_cpdn(3), ...
    R.n_cpdn(4),R.f_cpdn(4), R.n_cpdn(5),R.f_cpdn(5), R.n_cpdn(6),R.f_cpdn(6));
fprintf('    Total success = %d, total fail = %d\n', sum(R.n_cpdn), sum(R.f_cpdn));

fprintf('\nThroughput improvement vs single [%%]: %.6g %%\n', R.throughput_impr_pct);

fprintf('\nWasted energy from failed executions [J]\n');
fprintf('  Single cap: T1 %.6g, T2 %.6g, T3 %.6g, T4 %.6g, T5 %.6g, T6 %.6g  | Total %.6g\n', ...
    R.Ew_single(1), R.Ew_single(2), R.Ew_single(3), R.Ew_single(4), R.Ew_single(5), R.Ew_single(6), R.Ew_single_total);
fprintf('  CapDYN    : T1 %.6g, T2 %.6g, T3 %.6g, T4 %.6g, T5 %.6g, T6 %.6g  | Total %.6g\n', ...
    R.Ew_cpdn(1), R.Ew_cpdn(2), R.Ew_cpdn(3), R.Ew_cpdn(4), R.Ew_cpdn(5), R.Ew_cpdn(6), R.Ew_cpdn_total);
fprintf('  Wasted-energy shift (CapDYN vs single) [%%]: %.6g %%\n', R.Ew_shift_pct);
fprintf('  (negative = less wasted energy under CapDYN)\n');

fprintf('\n============================================================\n');
fprintf('EFFICIENCY METRICS - %s\n', caseName);
fprintf('============================================================\n');

fprintf('\nIntegration end times:\n');
fprintf('  CapDYN:  t_end_c = %.6g s  (end of first successful T6)\n', R.t_end_c);
fprintf('  Single:  t_end_s = %.6g s  (end of first successful T6)\n', R.t_end_s);

fprintf('\nIntegrated energies [J]:\n');
fprintf('  CapDYN:  Ein = %.6g, Eout = %.6g, Ewasted = %.6g\n', R.Ein_c, R.Eout_c, R.Ew_c_window);
fprintf('  Single:  Ein = %.6g, Eout = %.6g, Ewasted = %.6g\n', R.Ein_s, R.Eout_s, R.Ew_s_window);

fprintf('\nEfficiencies:\n');
fprintf('  CapDYN:  efficiency = %.6g (%.3f%%)\n', R.eff_c, 100*R.eff_c);
fprintf('          eff. efficiency = %.6g (%.3f%%)\n', R.effeff_c, 100*R.effeff_c);
fprintf('  Single:  efficiency = %.6g (%.3f%%)\n', R.eff_s, 100*R.eff_s);
fprintf('          eff. efficiency = %.6g (%.3f%%)\n', R.effeff_s, 100*R.effeff_s);

fprintf('============================================================\n\n');

end

function print_compact_summary(resultsStruct, label)

caseFields = fieldnames(resultsStruct);

fprintf('\n\n============================================================\n');
fprintf('COMPACT SUMMARY - %s\n', label);
fprintf('============================================================\n');
fprintf('%-30s  %-8s  %-12s  %-12s  %-12s\n', 'Case', 'Stages', 'Thrp. [%]', 'Eff. [%]', 'EffEff. [%]');

for k = 1:numel(caseFields)
    name = caseFields{k};
    R = resultsStruct.(name);

    fprintf('%-30s  %-8d  %-12.4f  %-12.4f  %-12.4f\n', ...
        name, R.nStages, R.throughput_impr_pct, 100*R.eff_c, 100*R.effeff_c);
end
fprintf('============================================================\n');


end

function Q = compare_capdyn_vs_ablation(Rcap, Rabl)

Q = struct();

Q.t_exec_capdyn = Rcap.t_exec_cpdn;
Q.t_exec_ablation = Rabl.t_exec_cpdn;
Q.first_exec_shift_vs_ablation_pct = nan(1,6);
valid = ~isnan(Q.t_exec_capdyn) & ~isnan(Q.t_exec_ablation) & (Q.t_exec_ablation ~= 0);
Q.first_exec_shift_vs_ablation_pct(valid) = 100*((Q.t_exec_capdyn(valid) - Q.t_exec_ablation(valid)) ./ Q.t_exec_ablation(valid));

Q.n_capdyn = Rcap.n_cpdn;
Q.n_ablation = Rabl.n_cpdn;
Q.f_capdyn = Rcap.f_cpdn;
Q.f_ablation = Rabl.f_cpdn;
Q.total_success_capdyn = sum(Q.n_capdyn);
Q.total_success_ablation = sum(Q.n_ablation);
Q.total_fail_capdyn = sum(Q.f_capdyn);
Q.total_fail_ablation = sum(Q.f_ablation);

if Q.total_success_ablation == 0
    Q.throughput_impr_vs_ablation_pct = nan;
else
    Q.throughput_impr_vs_ablation_pct = 100*((Q.total_success_capdyn - Q.total_success_ablation) / Q.total_success_ablation);
end

Q.Ew_capdyn_total = Rcap.Ew_cpdn_total;
Q.Ew_ablation_total = Rabl.Ew_cpdn_total;
if Q.Ew_ablation_total == 0
    Q.Ew_shift_vs_ablation_pct = 0;
else
    Q.Ew_shift_vs_ablation_pct = 100*((Q.Ew_capdyn_total - Q.Ew_ablation_total) / Q.Ew_ablation_total);
end

Q.t_end_capdyn = Rcap.t_end_c;
Q.t_end_ablation = Rabl.t_end_c;
Q.Ein_capdyn = Rcap.Ein_c;
Q.Ein_ablation = Rabl.Ein_c;
Q.Eout_capdyn = Rcap.Eout_c;
Q.Eout_ablation = Rabl.Eout_c;
Q.Ew_window_capdyn = Rcap.Ew_c_window;
Q.Ew_window_ablation = Rabl.Ew_c_window;

Q.eff_capdyn = Rcap.eff_c;
Q.eff_ablation = Rabl.eff_c;
Q.eff_delta_pp = 100*(Q.eff_capdyn - Q.eff_ablation);
if Q.eff_ablation == 0 || isnan(Q.eff_ablation)
    Q.eff_rel_shift_vs_ablation_pct = nan;
else
    Q.eff_rel_shift_vs_ablation_pct = 100*((Q.eff_capdyn - Q.eff_ablation) / Q.eff_ablation);
end

Q.effeff_capdyn = Rcap.effeff_c;
Q.effeff_ablation = Rabl.effeff_c;
Q.effeff_delta_pp = 100*(Q.effeff_capdyn - Q.effeff_ablation);
if Q.effeff_ablation == 0 || isnan(Q.effeff_ablation)
    Q.effeff_rel_shift_vs_ablation_pct = nan;
else
    Q.effeff_rel_shift_vs_ablation_pct = 100*((Q.effeff_capdyn - Q.effeff_ablation) / Q.effeff_ablation);
end

end

function print_capdyn_ablation_comparison(caseName, ablationCaseName, label, Q)

taskNames = {'T1','T2','T3','T4','T5','T6'};

fprintf('\n============================================================\n');
fprintf('CAPDYN VS ABLATION - %s\n', label);
fprintf('  CapDYN   : %s\n', caseName);
fprintf('  Ablation : %s\n', ablationCaseName);
fprintf('============================================================\n');

fprintf('\nFirst successful completion time [s]\n');
for i = 1:6
    fprintf('  %s: ablation = %.6g, capdyn = %.6g, shift = %.6g %%\n', ...
        taskNames{i}, Q.t_exec_ablation(i), Q.t_exec_capdyn(i), Q.first_exec_shift_vs_ablation_pct(i));
end
fprintf('  (negative shift = earlier first completion under CapDYN)\n');

fprintf('\nExecution counts (success / fail)\n');
fprintf('  Ablation: total success = %d, total fail = %d\n', Q.total_success_ablation, Q.total_fail_ablation);
fprintf('  CapDYN  : total success = %d, total fail = %d\n', Q.total_success_capdyn, Q.total_fail_capdyn);
fprintf('  Throughput improvement vs ablation [%%]: %.6g %%\n', Q.throughput_impr_vs_ablation_pct);

fprintf('\nWasted energy from failed executions [J]\n');
fprintf('  Ablation total = %.6g\n', Q.Ew_ablation_total);
fprintf('  CapDYN total   = %.6g\n', Q.Ew_capdyn_total);
fprintf('  Wasted-energy shift vs ablation [%%]: %.6g %%\n', Q.Ew_shift_vs_ablation_pct);
fprintf('  (negative shift = less wasted energy under CapDYN)\n');

fprintf('\nEfficiency comparison\n');
fprintf('  Ablation: efficiency = %.6g (%.3f%%), eff. efficiency = %.6g (%.3f%%)\n', ...
    Q.eff_ablation, 100*Q.eff_ablation, Q.effeff_ablation, 100*Q.effeff_ablation);
fprintf('  CapDYN  : efficiency = %.6g (%.3f%%), eff. efficiency = %.6g (%.3f%%)\n', ...
    Q.eff_capdyn, 100*Q.eff_capdyn, Q.effeff_capdyn, 100*Q.effeff_capdyn);
fprintf('  Efficiency delta = %.6g percentage points, relative shift = %.6g %%\n', ...
    Q.eff_delta_pp, Q.eff_rel_shift_vs_ablation_pct);
fprintf('  Eff. efficiency delta = %.6g percentage points, relative shift = %.6g %%\n', ...
    Q.effeff_delta_pp, Q.effeff_rel_shift_vs_ablation_pct);

fprintf('============================================================\n\n');

end

function print_compare_summary(compareStruct, label)

caseFields = fieldnames(compareStruct);

fprintf('\n\n============================================================\n');
fprintf('COMPACT SUMMARY - %s\n', label);
fprintf('============================================================\n');
fprintf('%-26s  %-12s  %-12s  %-12s  %-12s\n', ...
    'Case', 'ThrpVsAbl[%]', 'EwVsAbl[%]', 'Eff dpp', 'EffEff dpp');

for k = 1:numel(caseFields)
    field = caseFields{k};
    Q = compareStruct.(field);
    fprintf('%-26s  %-12.4f  %-12.4f  %-12.4f  %-12.4f\n', ...
        field, Q.throughput_impr_vs_ablation_pct, Q.Ew_shift_vs_ablation_pct, ...
        Q.eff_delta_pp, Q.effeff_delta_pp);
end

fprintf('============================================================\n');

end

function print_case_comparison_matrix(caseName, ablationCaseName, label0, Rcap0, Rabl0, label1, Rcap1, Rabl1, label2, Rcap2, Rabl2, Q)

fprintf('\n\n============================================================\n');
fprintf('FULL COMPARISON MATRIX - %s\n', caseName);
fprintf('  Ablation: %s\n', ablationCaseName);
fprintf('============================================================\n');

fprintf('\nAgainst the single-cap benchmarks:\n');
print_vs_single_row('CapDYN',   label0, Rcap0);
print_vs_single_row('Ablation', label0, Rabl0);
print_vs_single_row('CapDYN',   label1, Rcap1);
print_vs_single_row('Ablation', label1, Rabl1);
print_vs_single_row('CapDYN',   label2, Rcap2);
print_vs_single_row('Ablation', label2, Rabl2);

fprintf('\nCapDYN directly vs ablation:\n');
fprintf('  Total success: ablation = %d, capdyn = %d, shift = %.6g %%\n', ...
    Q.total_success_ablation, Q.total_success_capdyn, Q.throughput_impr_vs_ablation_pct);
fprintf('  Total failed-exec energy: ablation = %.6g J, capdyn = %.6g J, shift = %.6g %%\n', ...
    Q.Ew_ablation_total, Q.Ew_capdyn_total, Q.Ew_shift_vs_ablation_pct);
fprintf('  Efficiency: ablation = %.6g, capdyn = %.6g, delta = %.6g percentage points\n', ...
    Q.eff_ablation, Q.eff_capdyn, Q.eff_delta_pp);
fprintf('  Effective efficiency: ablation = %.6g, capdyn = %.6g, delta = %.6g percentage points\n', ...
    Q.effeff_ablation, Q.effeff_capdyn, Q.effeff_delta_pp);

fprintf('============================================================\n\n');

end

function print_vs_single_row(candidateName, benchmarkLabel, R)

fprintf('  %-8s vs %-32s | Thrp = %10.4f %% | Ew = %10.4f %% | Eff = %10.4f %% | EffEff = %10.4f %%\n', ...
    candidateName, benchmarkLabel, R.throughput_impr_pct, R.Ew_shift_pct, 100*R.eff_c, 100*R.effeff_c);

end

function S = load_single_case(singleFile, singleFormat, taskSet)

singleFile = resolve_existing_file(singleFile);
sng = table2array(readtable(singleFile));

switch lower(singleFormat)
    case 'sleep'
        S.t       = sng(:,1);
        S.en2     = sng(:,3);

        S.inout   = sng(:,5);
        S.vin     = sng(:,6);
        S.pow_in  = S.vin;
        S.vout    = sng(:,7);
        S.stored  = sng(:,8);

        S.t1 = sng(:,9);
        S.t2 = sng(:,10);
        S.t3 = sng(:,11);
        S.t4 = sng(:,12);
        S.t5 = sng(:,13);
        S.t6 = sng(:,14);

        S.iin   = sng(:,15);
        S.iload = sng(:,16);

    case 'nosleep'
        S.t       = sng(:,1);
        S.en2     = sng(:,4);

        S.inout   = sng(:,6);
        S.vin     = sng(:,17);
        S.pow_in  = sng(:,7);
        S.vout    = sng(:,8);
        S.stored  = sng(:,9);

        S.t1 = sng(:,10);
        S.t2 = sng(:,11);
        S.t3 = sng(:,12);
        S.t4 = sng(:,13);
        S.t5 = sng(:,14);
        S.t6 = sng(:,15);

        S.v_bck = sng(:,16);
        S.iin   = sng(:,21);
        S.iload = sng(:,22);

    otherwise
        error('Unknown singleFormat: %s. Use ''sleep'' or ''nosleep''.', singleFormat);
end

switch lower(taskSet)
    case 'exp'
        % Task execution times - single
        S.t1_exec_nom = 0.450+0.473;
        S.t2_exec_nom = 600;
        S.t3_exec_nom = 3*4.565;
        S.t4_exec_nom = 0.222;
        S.t5_exec_nom = 7.23;
        S.t6_exec_nom = 15*4.565;

        % Average task power - single
        S.p1 = (8.426e-3+8.192e-3)/S.t1_exec_nom;
        S.p2 = (2.037543)/S.t2_exec_nom;
        S.p3 = (3*151.97e-3)/S.t3_exec_nom;
        S.p4 = (5.873e-3)/S.t4_exec_nom;
        S.p5 = (37.398e-3)/S.t5_exec_nom;
        S.p6 = (15*151.97e-3)/S.t6_exec_nom;

    case 'lin'
        S.t1_exec_nom = 25.162266882377359    - 2*0.049340;
        S.t2_exec_nom = 537.5124880629907     - 2*0.049340;
        S.t3_exec_nom = 41.321027102210614    - 2*0.049340;
        S.t4_exec_nom = 0.320680000000000     - 2*0.049340;
        S.t5_exec_nom = 169.9287877957878     - 2*0.049340;
        S.t6_exec_nom = 68.573680000000010    - 2*0.049340;

        % Linear version avg powers - single
        S.p1 = (0.462781  - 2*1.086300e-3)/S.t1_exec_nom;
        S.p2 = (1.8269872 - 2*1.086300e-3)/S.t2_exec_nom;
        S.p3 = (1.3722518 - 2*1.086300e-3)/S.t3_exec_nom;
        S.p4 = (0.0080456 - 2*1.086300e-3)/S.t4_exec_nom;
        S.p5 = (0.9175164 - 2*1.086300e-3)/S.t5_exec_nom;
        S.p6 = (2.2817226 - 2*1.086300e-3)/S.t6_exec_nom;

    otherwise
        error('Unknown task set: %s. Use ''exp'' or ''lin''.', taskSet);
end

end

function C = load_cpdn_case(cpdnFile, taskSet)

cpdnFileOriginal = cpdnFile;
cpdnFile = resolve_existing_file(cpdnFile);
cpdn = table2array(readtable(cpdnFile));

tok = regexp(cpdnFileOriginal, 'cpdn_(\d+)stage', 'tokens', 'once');
if isempty(tok)
    tok = regexp(cpdnFile, 'cpdn_(\d+)stage', 'tokens', 'once');
end
if isempty(tok)
    error('Could not infer stage count from filename: %s', cpdnFileOriginal);
end
nStages = str2double(tok{1});

if isnan(nStages) || nStages < 3
    error('Unsupported stage count in filename: %s', cpdnFileOriginal);
end

C.t      = cpdn(:,1);
C.en1    = cpdn(:,3);
C.en2    = cpdn(:,4);
C.inout  = cpdn(:,5);
C.on_stg = cpdn(:,6);
C.vout   = cpdn(:,7);

qStart = 8;
qEnd   = qStart + nStages - 1;

C.q = cpdn(:, qStart:qEnd);
C.nStages = nStages;

if size(C.q,2) >= 1, C.q1 = C.q(:,1); end
if size(C.q,2) >= 2, C.q2 = C.q(:,2); end
if size(C.q,2) >= 3, C.q3 = C.q(:,3); end
if size(C.q,2) >= 4, C.q4 = C.q(:,4); end
if size(C.q,2) >= 5, C.q5 = C.q(:,5); end
if size(C.q,2) >= 6, C.q6 = C.q(:,6); end
if size(C.q,2) >= 7, C.q7 = C.q(:,7); end

postQ = qEnd + 1;

C.stored  = cpdn(:, postQ + 0);

C.t1 = cpdn(:, postQ + 1);
C.t2 = cpdn(:, postQ + 2);
C.t3 = cpdn(:, postQ + 3);
C.t4 = cpdn(:, postQ + 4);
C.t5 = cpdn(:, postQ + 5);
C.t6 = cpdn(:, postQ + 6);

C.v_bck   = cpdn(:, postQ + 7);
C.v_cpdn  = cpdn(:, postQ + 8);
C.vin     = cpdn(:, postQ + 9);
C.vddrsig = cpdn(:, postQ + 10);

C.i_bck   = cpdn(:, postQ + 11);
C.i_d2    = cpdn(:, postQ + 12);
C.i_d3    = cpdn(:, postQ + 13);
C.iin     = cpdn(:, postQ + 14);
C.iload   = cpdn(:, postQ + 15);

switch lower(taskSet)
    case 'exp'
        % Task execution times - capdyn
        C.t1_exec_nom = 0.450+0.473 + 2*0.049340;
        C.t2_exec_nom = 600         + 2*0.049340;
        C.t3_exec_nom = 3*4.565     + 2*0.049340;
        C.t4_exec_nom = 0.222       + 2*0.049340;
        C.t5_exec_nom = 7.23        + 2*0.049340;
        C.t6_exec_nom = 15*4.565    + 2*0.049340;

        % Average task power - capdyn
        C.p1 = (8.426e-3+8.192e-3+2*1.086300e-3)/C.t1_exec_nom;
        C.p2 = (2.037543+2*1.086300e-3)/C.t2_exec_nom;
        C.p3 = (3*151.97e-3+2*1.086300e-3)/C.t3_exec_nom;
        C.p4 = (5.873e-3+2*1.086300e-3)/C.t4_exec_nom;
        C.p5 = (37.398e-3+2*1.086300e-3)/C.t5_exec_nom;
        C.p6 = (15*151.97e-3+2*1.086300e-3)/C.t6_exec_nom;

    case 'lin'
        % Linear version task execution times - capdyn
        C.t1_exec_nom = 25.162266882377359;
        C.t2_exec_nom = 537.5124880629907;
        C.t3_exec_nom = 41.321027102210614;
        C.t4_exec_nom = 0.320680000000000;
        C.t5_exec_nom = 169.9287877957878;
        C.t6_exec_nom = 68.573680000000010;

        % Linear version avg powers - capdyn
        C.p1 = 0.462781/C.t1_exec_nom;
        C.p2 = 1.8269872/C.t2_exec_nom;
        C.p3 = 1.3722518/C.t3_exec_nom;
        C.p4 = 0.0080456/C.t4_exec_nom;
        C.p5 = 0.9175164/C.t5_exec_nom;
        C.p6 = 2.2817226/C.t6_exec_nom;

    otherwise
        error('Unknown task set: %s. Use ''exp'' or ''lin''.', taskSet);
end

end

function [task_bin, ex_dur, m_success, m_fail, exec_start, exec_end, fail_start, fail_end, fail_dur] = ...
    detect_execs(t, en2, task_sig, t_nom, minPeakDist)

task_bin = 1*(en2 > 0.1 & task_sig > 0.7);

if isempty(minPeakDist)
    [~, locs] = findpeaks(abs(diff(task_bin)));
else
    [~, locs] = findpeaks(abs(diff(task_bin)), 'MinPeakDistance', minPeakDist);
end

if numel(locs) < 2
    ex_dur     = [];
    exec_start = [];
    exec_end   = [];
    m_success  = false(0,1);
    m_fail     = false(0,1);
    fail_start = [];
    fail_end   = [];
    fail_dur   = [];
    return;
end

ex_all = diff(t(locs));
ex_dur = ex_all(1:2:end);

exec_start = t(locs(1:2:end));
exec_end   = t(locs(2:2:end));

L = min([numel(exec_start), numel(exec_end), numel(ex_dur)]);
exec_start = exec_start(1:L);
exec_end   = exec_end(1:L);
ex_dur     = ex_dur(1:L);

m_success = (ex_dur > 0.99*t_nom);
m_fail    = ~m_success;

fail_start = exec_start(m_fail);
fail_end   = exec_end(m_fail);
fail_dur   = ex_dur(m_fail);

end

function E = integrate_upto(t, y, t_end)

if isnan(t_end) || isempty(t) || t_end <= t(1)
    E = NaN;
    return;
end

if t_end >= t(end)
    idx = numel(t);
else
    idx = find(t <= t_end, 1, 'last');
end

if isempty(idx) || idx < 2
    E = NaN;
    return;
end

tt = t(1:idx);
yy = y(1:idx);

good = isfinite(tt) & isfinite(yy);
tt = tt(good);
yy = yy(good);

if numel(tt) < 2
    E = NaN;
    return;
end

E = trapz(tt, yy);
end

function plot_diagnostics(S, C, caseName, singlePlotField, singleBins, cpdnBins)

figure('Name',['Voltages - ' caseName],'Position',[0 0 1200 600], 'Visible','on')
tl = tiledlayout('vertical', 'TileSpacing','tight', 'Padding','tight');
title(tl,' ', 'interpreter','latex')

nexttile
plot(C.t, C.v_cpdn, 'DisplayName','$V_{CPDN}$')
box on; grid on; hold on
plot(C.t, C.v_bck, 'DisplayName','$V_{BCK}$')
xlabel('Time [s]')
ylabel('Voltage [V]')
legend

nexttile
hold on; box on; grid on
for i = 1:C.nStages
    plot(C.t, C.q(:,i), 'DisplayName', sprintf('$Q_{%d}$', i))
end
xlabel('Time [s]')
ylabel('Voltage [V]')
legend
ylim([-0.3 3.3])

nexttile
hold on; box on; grid on
for i = 1:6
    plot(C.t, cpdnBins{i}, 'DisplayName', sprintf('$T_{%d}$', i))
end
xlabel('Time [s]')
ylabel('Task binary')
legend
ylim([-0.3 1.3])

nexttile
plot(C.t, C.en1, 'DisplayName','$EN_{1}$')
box on; grid on; hold on
plot(C.t, C.en2, 'DisplayName','$EN_{2}$')
xlabel('Time [s]')
ylabel('Voltage [V]')
legend
ylim([-0.3 3.3])

figure('Name',['Voltages - single vs ' caseName],'Position',[0 0 1200 600], 'Visible','off')
tl = tiledlayout('vertical', 'TileSpacing','tight', 'Padding','tight');
title(tl,' ', 'interpreter','latex')

nexttile
plot(S.t, S.(singlePlotField), 'DisplayName','$V_{SNG}$')
box on; grid on
xlabel('Time [s]')
ylabel('Voltage [V]')
legend

nexttile
hold on; box on; grid on
for i = 1:6
    plot(S.t, singleBins{i}, 'DisplayName', sprintf('$T_{%d}$', i))
end
xlabel('Time [s]')
ylabel('Task binary')
legend
ylim([-0.3 1.3])

nexttile
plot(S.t, S.en2, 'DisplayName','$EN_{2}$')
box on; grid on
xlabel('Time [s]')
ylabel('Voltage [V]')
legend
ylim([-0.3 3.3])

end

function fig = plot_final_four_tiles(caseName, rec, opts)

if nargin < 3
    opts = struct();
end
if ~isfield(opts,'visible'), opts.visible = true; end
if ~isfield(opts,'export'), opts.export = true; end
if ~isfield(opts,'outputDir'), opts.outputDir = pwd; end
if ~isfield(opts,'xMax'), opts.xMax = 18000; end
if ~isfield(opts,'taskSet'), opts.taskSet = 'exp'; end

if opts.visible
    visibleState = 'on';
else
    visibleState = 'off';
end

fig = figure('Name',['Task execution digital view - ' opts.taskSet ' - ' caseName], ...
    'Position',[0 0 1500 1050], 'Visible',visibleState);

tl = tiledlayout(fig, 5, 1, 'TileSpacing','compact', 'Padding','compact');
plotTitle = sprintf('%s task set - %s', upper(opts.taskSet), strrep(caseName,'_','\_'));
title(tl, plotTitle, 'Interpreter','latex')

matlabBlue = hex2rgb('#0072BD');
matlabRed  = hex2rgb('#D95319');
ablationColor = hex2rgb('#7E2F8E');

cfg.colTasks = { ...
    hex2rgb('#0072BD'), ...
    hex2rgb('#D95319'), ...
    hex2rgb('#EDB120'), ...
    hex2rgb('#77AC30'), ...
    hex2rgb('#4DBEEE'), ...
    hex2rgb('#7E2F8E')};

cfg.greenBall = hex2rgb('#2CA02C');
cfg.redBall   = hex2rgb('#A2142F');

cfg.lwV = 1.2;
cfg.lwD = 1.4;
cfg.firstBallSize = 15;
cfg.failBallSize = 15;

cfg.bandLo = 0.05;
cfg.bandHi = 1.70;
cfg.laneH  = (cfg.bandHi-cfg.bandLo)/6;

cfg.y = [ ...
    cfg.bandHi - 0.5*cfg.laneH, ...
    cfg.bandHi - 1.5*cfg.laneH, ...
    cfg.bandHi - 2.5*cfg.laneH, ...
    cfg.bandHi - 3.5*cfg.laneH, ...
    cfg.bandHi - 4.5*cfg.laneH, ...
    cfg.bandHi - 5.5*cfg.laneH];

cfg.digLow  = -0.3*cfg.laneH;
cfg.digHigh = +0.3*cfg.laneH;

cfg.ylimLo = -0.1;
cfg.ylimHi = 3.75;
cfg.xMax = opts.xMax;
cfg.laneBlank = 300;
cfg.gapBefore = @(dur) min(0.05*dur,0.5) + 100;
cfg.gapAfter  = @(dur) min(0.05*dur,0.5) + 100;

ax1 = nexttile(tl);
plot_one_digital_panel(ax1, rec.S0, rec.Rsingle0, rec.singlePlotField0, 80, ...
    [rec.bench0Label ' - Single capacitor'], matlabBlue, cfg);

ax2 = nexttile(tl);
plot_one_digital_panel(ax2, rec.S1, rec.Rsingle1, rec.singlePlotField1, 80, ...
    [rec.bench1Label ' - Single capacitor'], matlabBlue, cfg);

ax3 = nexttile(tl);
plot_one_digital_panel(ax3, rec.S2, rec.Rsingle2, rec.singlePlotField2, 80, ...
    [rec.bench2Label ' - Single capacitor'], matlabBlue, cfg);

ax4 = nexttile(tl);
plot_one_digital_panel(ax4, rec.Cabl, rec.Rabl, 'v_cpdn', 700, ...
    ['Ablation CapDYN - ' rec.ablationCaseName], ablationColor, cfg);

ax5 = nexttile(tl); %#ok<NASGU>
plot_one_digital_panel(ax5, rec.C, rec.Rcpdn, 'v_cpdn', 700, ...
    ['CapDYN - ' rec.caseName], matlabRed, cfg);

hSingle = plot(ax1,NaN,NaN,'-','Color',matlabBlue,'LineWidth',cfg.lwV);
hAbl    = plot(ax1,NaN,NaN,'-','Color',ablationColor,'LineWidth',cfg.lwV);
hDyn    = plot(ax1,NaN,NaN,'-','Color',matlabRed,'LineWidth',cfg.lwV);

hT1 = patch(ax1,NaN,NaN,cfg.colTasks{1});
hT2 = patch(ax1,NaN,NaN,cfg.colTasks{2});
hT3 = patch(ax1,NaN,NaN,cfg.colTasks{3});
hT4 = patch(ax1,NaN,NaN,cfg.colTasks{4});
hT5 = patch(ax1,NaN,NaN,cfg.colTasks{5});
hT6 = patch(ax1,NaN,NaN,cfg.colTasks{6});

hFirst = scatter(ax1,NaN,NaN,cfg.firstBallSize,'o','MarkerFaceColor',cfg.greenBall,'MarkerEdgeColor',cfg.greenBall);
hFail  = scatter(ax1,NaN,NaN,cfg.failBallSize ,'o','MarkerFaceColor',cfg.redBall  ,'MarkerEdgeColor',cfg.redBall);

lg = legend(ax1,[hSingle hAbl hDyn hFirst hFail hT1 hT2 hT3 hT4 hT5 hT6], ...
    {'Single capacitor','Ablation CapDYN','CapDYN','First successful exec','Failed exec', ...
     '$T_1$','$T_2$','$T_3$','$T_4$','$T_5$','$T_6$'}, ...
    'Orientation','horizontal','Location','northoutside');
lg.ItemTokenSize(1)=18;

set(fig, 'Color', 'none');
ax = findall(fig, 'Type', 'axes');
set(ax, 'Color', 'none');
set(fig, 'PaperOrientation', 'landscape');

if opts.export
    outName = sprintf('%s_%s_bench0_bench1_bench2_ablation_capdyn.png', opts.taskSet, caseName);
    outPath = fullfile(opts.outputDir, outName);
    exportgraphics(fig, outPath, 'BackgroundColor', 'none');
    fprintf('Exported final plot: %s\n', outPath);
end

end

function plot_one_digital_panel(ax, X, D, voltageField, filtWindow, panelTitle, voltageColor, cfg)

hold(ax,'on'); box(ax,'on'); grid(ax,'on');

vRaw = X.(voltageField);
if numel(vRaw) >= filtWindow
    vPlot = medfilt1(vRaw, filtWindow);
else
    vPlot = vRaw;
end

hV = plot(ax, X.t, vPlot, 'LineWidth', cfg.lwV, 'Color', voltageColor);

xlim(ax,[0 cfg.xMax]);
ylim(ax,[cfg.ylimLo cfg.ylimHi]);
title(ax, panelTitle, 'Interpreter','none');
xlabel(ax,'Time [s]');
ylabel(ax,'Voltage [V]');

drawBaseline = @(y) plot(ax,[0 cfg.xMax],[y+cfg.digLow y+cfg.digLow], ...
    '-', 'Color',[0.75 0.75 0.75], 'LineWidth',0.5, 'HandleVisibility','off');

drawColoredLane = @(t0,y,col) plot(ax,[t0 cfg.xMax],[y+cfg.digLow y+cfg.digLow], ...
    '-', 'Color',col, 'LineWidth',0.5, 'HandleVisibility','off');

drawRects = @(xs,xe,y,col,t0) local_plot_task_rects(ax,xs,xe,y,cfg.digLow,cfg.digHigh,col,t0,cfg.xMax,cfg.lwD);
drawFirstBall = @(tstart,tend,y) local_draw_first_ball(ax,tstart,tend,y+0.01,cfg.greenBall,cfg.firstBallSize,cfg.xMax,cfg.gapBefore);
drawFailBalls = @(fend,fstart,y) local_draw_fail_balls(ax,fend,fstart,y+0.01,cfg.redBall,cfg.failBallSize,cfg.xMax,cfg.gapAfter);

t0 = zeros(1,6);
for i = 1:6
    drawBaseline(cfg.y(i));
    t0(i) = local_lane_start_from_intersection(X.t, vPlot, cfg.y(i)+cfg.digLow, cfg.laneBlank);
    drawColoredLane(t0(i), cfg.y(i), cfg.colTasks{i});
end

for i = 1:6
    xs = [D.successStart{i}(:); D.failStart{i}(:)];
    xe = [D.successEnd{i}(:);   D.failEnd{i}(:)];
    drawRects(xs, xe, cfg.y(i), cfg.colTasks{i}, t0(i));
    drawFailBalls(D.failEnd{i}, D.failStart{i}, cfg.y(i));

    if ~isempty(D.successStart{i})
        drawFirstBall(D.successStart{i}(1), D.successEnd{i}(1), cfg.y(i));
    end
end

uistack(hV,'top');

end

function local_plot_task_rects(ax,xs,xe,y,digLow,digHigh,col,t0,tmax,lwOutline)
xs = xs(:); xe = xe(:);
n = min(numel(xs),numel(xe));
xs = xs(1:n); xe = xe(1:n);
if n==0, return; end

valid = ~isnan(xs)&~isnan(xe)&(xe>xs);
xs = xs(valid); xe = xe(valid);
if isempty(xs), return; end

[xs,idx] = sort(xs); xe = xe(idx);

xs_m = xs(1); xe_m = xe(1);
for k=2:numel(xs)
    if xs(k)<=xe_m(end)
        xe_m(end)=max(xe_m(end),xe(k));
    else
        xs_m(end+1)=xs(k); %#ok<AGROW>
        xe_m(end+1)=xe(k); %#ok<AGROW>
    end
end

keep = (xe_m>t0)&(xs_m<tmax);
xs_m = xs_m(keep); xe_m = xe_m(keep);
if isempty(xs_m), return; end

xs_c = max(xs_m,t0); xe_c = min(xe_m,tmax);
keep = xe_c>xs_c;
xs_c = xs_c(keep); xe_c = xe_c(keep);
if isempty(xs_c), return; end

for k=1:numel(xs_c)
    x0 = xs_c(k); x1 = xe_c(k);

    X = [x0 x1 x1 x0];
    Y = [y+digLow y+digLow y+digHigh y+digHigh];
    patch(ax,X,Y,col,'EdgeColor','none','HandleVisibility','off','FaceAlpha', 0.85);

    plot(ax,[x0 x0 x1 x1 x0],[y+digLow y+digHigh y+digHigh y+digLow y+digLow], ...
        '-','Color',col,'LineWidth',lwOutline,'HandleVisibility','off');
end
end

function t0 = local_lane_start_from_intersection(t,v,ylane,blank)
t=t(:); v=v(:);
s=v-ylane;
k=find(s(1:end-1).*s(2:end)<=0,1,'first');
if isempty(k), t0=blank; return; end
t1=t(k); t2=t(k+1);
v1=v(k); v2=v(k+1);
if v2==v1
    t_cross=t1;
else
    a=(ylane-v1)/(v2-v1);
    t_cross=t1+a*(t2-t1);
end
t0=max(0,t_cross+blank);
end

function local_draw_first_ball(ax,tstart,tend,y,color,msize,~,gapfun)
if isempty(tstart)||isnan(tstart), return; end
dur=max(tend-tstart,0.1);
x=max(0,tstart-gapfun(dur));
scatter(ax,x,y,msize,'o','MarkerFaceColor',color,'MarkerEdgeColor',color,...
    'LineWidth',0.8,'HandleVisibility','off');
end

function local_draw_fail_balls(ax,fend,fstart,y,color,msize,tmax,gapfun)
fend=fend(:); fstart=fstart(:);
if isempty(fend), return; end
n=numel(fend);
dur=ones(n,1)*0.1;
m=min(n,numel(fstart));
dur(1:m)=max(fend(1:m)-fstart(1:m),0.1);
x=min(tmax,fend+gapfun(dur));
scatter(ax,x,y*ones(n,1),msize,'o','MarkerFaceColor',color,'MarkerEdgeColor',color,...
    'LineWidth',0.8,'HandleVisibility','off');
end

function ablationFile = make_ablation_filename(cpdnFile)

[p,n,e] = fileparts(cpdnFile);

switch n
    case 'cpdn_5stage_dim'
        ablationBase = 'bench_cpdn_5stage_dim_v2';

    case 'cpdn_6stage_dim'
        ablationBase = 'bench_cpdn_6stage_dim_v2';

    case 'cpdn_6stage_dim_D2'
        ablationBase = 'bench_cpdn_6stage_dim_D2_v2';

    case 'cpdn_7stage_dim_lin_D2'
        ablationBase = 'bench_cpdn_7stage_dim_lin_D2_v2';

    otherwise
        ablationBase = ['bench_' n];
end

if isempty(e)
    ablationFile = fullfile(p, ablationBase);
else
    ablationFile = fullfile(p, [ablationBase e]);
end

end
function ok = file_exists_anywhere(fname)

candidates = file_candidates(fname);
ok = false;
for i = 1:numel(candidates)
    if exist(candidates{i}, 'file') == 2
        ok = true;
        return;
    end
end

end

function resolved = resolve_existing_file(fname)

candidates = file_candidates(fname);
for i = 1:numel(candidates)
    if exist(candidates{i}, 'file') == 2
        resolved = candidates{i};
        return;
    end
end

error('File not found: %s', fname);

end

function candidates = file_candidates(fname)

[p,n,e] = fileparts(fname);

base1 = fname;
if isempty(e)
    base2 = [fname '.txt'];
    base3 = fname;
else
    base2 = fname;
    base3 = fullfile(p, n);
end

if isempty(p)
    candidates = { ...
        base1, ...
        base2, ...
        base3, ...
        fullfile('sim_results_raws', base1), ...
        fullfile('sim_results_raws', base2), ...
        fullfile('sim_results_raws', base3)};
else
    candidates = {base1, base2, base3};
end

% Remove duplicates while preserving order.
[~, ia] = unique(candidates, 'stable');
candidates = candidates(sort(ia));

end

function rgb = hex2rgb(hex,range)

assert(nargin>0&nargin<3,'hex2rgb function must have one or two inputs.')
if nargin==2
    assert(isscalar(range)==1,'Range must be a scalar, either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end

if iscell(hex)
    assert(isvector(hex)==1,'Unexpected dimensions of input hex values.')
    if isrow(hex)
        hex = hex';
    end
    hex = cell2mat(hex);
end

if strcmpi(hex(1,1),'#')
    hex(:,1) = [];
end

if nargin == 1
    range = 1;
end

switch range
    case 1
        rgb = reshape(sscanf(hex.','%2x'),3,[]).'/255;
    case {255,256}
        rgb = reshape(sscanf(hex.','%2x'),3,[]).';
    otherwise
        error('Range must be either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end
end
