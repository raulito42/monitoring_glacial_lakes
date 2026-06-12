# Waterdetection

This folder contains the main radar-based water detection pipeline for the `monitoring_glacial_lakes` project. The pipeline is organized into a sequence of MATLAB scripts that prepare radar data (from agbaumann/MIMO-SAR GitHub repository), extract stable land masks, detect shoreline change, and evaluate water area dynamics.

## Structure

- `main.m` — Batch driver for multiple datasets. Configures project paths, sets environment-specific thresholds, and executes pipeline steps.
- `P00_condition_data.m` — Signal conditioning and feature extraction from complex SAR data. Produces temporal coherence, amplitude, and phase variance features for both nominal and detrended streams.
- `P01_cluster.m` — Morphological clustering and stable land mask extraction. Uses k-means clustering and post-processing filters to separate stable land from water / shift regions.
- `P02_water_tracking_unified.m` — Unified shoreline tracking. Builds a narrow ribbon around the shoreline and applies dual-stream detection using both nominal and detrended features.
- `P03_water_area_dynamics.m` — Water surface area dynamics and trend analysis. Computes absolute area, percentage change, and directional shoreline transitions over time.
- `P04_sensitivity_analysis.m` — Sensitivity sweeps and validation. Runs parametric threshold and window variations to quantify robustness of water detection.
- `utils/` — Shared helper functions used across the pipeline.

## Pipeline Overview

1. **Configure and initialize**
   - `main.m` sets `project_root`, selects dataset names, and loads per-site hyperparameters.
   - The configuration includes temporal window sizes, morphological radii, and environment-specific thresholds.

2. **Signal conditioning** (`P00_condition_data.m`)
   - Loads complex SLC radar data from `D00_sample_data/.../03_PSI_Interfero/01_SLC_Filt.mat`.
   - Applies spatial cropping, constructs an interpolation grid, and computes feature streams:
     - coherence
     - amplitude
     - phase variance
   - Builds both nominal and detrended feature representations.

3. **Stable land and shoreline extraction** (`P01_cluster.m`)
   - Loads preprocessed tuned features from `tuned_features.mat`.
   - Computes robust pixel-level feature baselines and weights coherence, amplitude, and phase variance.
   - Runs weighted k-means clustering to separate land-like and water-like pixels.
   - Uses morphological closing/opening and area filtering to create a refined continuous land mask.
   - Saves the final `land_mask.mat` for downstream tracking.

4. **Unified shoreline tracking** (`P02_water_tracking_unified.m`)
   - Loads the land mask and tuned features.
   - Uses interactive ROI selection to focus the tracking region.
   - Builds a shoreline ribbon from the land mask and limits detection to the narrow tracking zone.
   - Executes two parallel detection streams:
     - Nominal stream: raw coherence/amplitude/phase metrics
     - Detrended stream: range-normalized metrics
   - Produces fixed-threshold and adaptive threshold masks for each frame.
   - Saves tracking outputs for area and transition analysis.

5. **Water area dynamics** (`P03_water_area_dynamics.m`)
   - Loads tracking results from `tracking_results.mat`.
   - Computes area time series for nominal/detrended and fixed/adaptive streams.
   - Calculates percentage changes relative to the first frame.
   - Computes expansion, retreat, and net transition velocities.
   - Exports a CSV file containing area and transition metrics.

6. **Sensitivity analysis** (`P04_sensitivity_analysis.m`)
   - Loads features and land mask data.
   - Defines evaluation masks from the narrow tracking ribbon.
   - Runs parameter sweeps across threshold levels and temporal smoothing windows.
   - Measures area trajectories, rejection rates, and net water transition behavior.
   - Saves sensitivity outputs under `sensitivity_analysis_report`.

## How to run

Open MATLAB and set the current folder to this directory.

Example:

```matlab
run_batch_pipeline();
```

Or call the pipeline directly from `main.m`:

```matlab
main;
```

If you only want to run a single step, call the corresponding function with a configuration struct derived from `main.m`.

## Notes

- `main.m` includes core steps `P00` through `P04` but currently comments out `P00_condition_data`, `P01_cluster`, `P02_water_tracking_unified`, and `P03_water_area_dynamics` for selective execution. Update as needed.
- The pipeline expects data under `Source/D00_sample_data/real/<dataset>/export_xxx` and the original SLC files in `03_PSI_Interfero/01_SLC_Filt.mat`.
- This README does not cover `plots_report/`.

## Requirements

- MATLAB
- Image Processing Toolbox (for `strel`, `imclose`, `imopen`, `bwareaopen`, `imerode`)
- Statistics Toolbox and Machine Learning Toolbox (for `kmeans`, `zscore`, `statset`)
