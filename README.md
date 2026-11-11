# Adaptive energy cost for Q-Learning-based random access in LEO satellite IoT networks with finite batteries

MATLAB simulations for Pedro Henrique Taschetto de Souza's undergraduate thesis (TCC) at UTFPR, advised by Prof. Jamil de Araujo Farhat.

The work builds on the Q-Learning random access scheme of Farhat *et al.*, *Energy-Efficient Replica and Resource Allocation for LEO Satellite IoT using Q-Learning*. It adds finite batteries, a mission of many satellite passes and a **budget rule**. Under this rule, each device adjusts its own energy cost so that its battery lasts until the end of the mission.

## Usage

1. Open `main.m`, set `SIMUL_choice` and run the script. To run it from the command line, use `SIMUL_CHOICE=3 matlab -batch main`.
2. Figures are saved to `plots/` (PNG and PDF), and the data for each figure to `plots/data/` (`.mat`). These folders are not tracked by git.

| `SIMUL_choice` | simulation |
|---|---|
| 1 | fixed energy cost over the mission |
| 2 | network behavior over the mission |
| 3 | budget rule vs. fixed costs |
| 4 | distribution of the energy cost across devices |
| 5 | spread of the initial battery |
| 6 | network load |
| 7 | comparison with Slotted ALOHA |

The scripts in `analysis/` print the per-device statistics quoted in the thesis, e.g. `run analysis/device_spending.m`.

**Requirements:** MATLAB R2021a or later and the Statistics and Machine Learning Toolbox. The Parallel Computing Toolbox is optional and speeds up the simulations.
