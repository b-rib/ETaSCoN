# ETaSCoN - **E**nergy-aware **Ta**sk **S**cheduling for quality-of-service assurance in **Co**nstellations of **N**anosatellites
 
**ETaSCoN** is a [Julia](http://www.julialang.org/) package dedicated to energy-aware task scheduling for quality-of-service assurance in constellations of nanosatellites
 
## Dependencies
 
* Julia
* JuMP
* Gurobi
 
## Usage
 
```julia
# Instantiating the Mavrotas
result = mavrotas("input_file")
```
 
### Data file
 
Where **input_file** is a julia lang file (.jl) containing the following definitions:
 
variable | definition
-----------|------------
restringe | 
d | accepted SoC variation within an orbit
M | a large number which would not be part of any optimal solution, used in big-M constraints
LimiteTempo | maximum solving time
LimiteGap | maximum solving gap 
q | nominal battery capacity (in Ah) 
soc_inicial | initial battery SoC
rho | minimum accepted battery SoC
bat_usage | maximum charge/discharge battery current (in Ampères)
ef | battery charge/discharge efficiency
v_bat | battery voltage
subs | number of subsystems
jobs | number of jobs
T | time horizon
constelação | vector indicating, for each task, weather they are individual (0) or collective (1)
sincronous | vector indicating, for each task, weather they are synchronous (1) or not (0)
min_statup_g | vector containing the minimum number of startups for each job globally (i.e., all satellites)
max_statup_g | vector containing the maximum number of startups for each job globally (i.e., all satellites)
min_cpu_time | vector containing the minimum cpu time for each job for each satellite
max_cpu_time | vector containing the maximum cpu time for each job for each satellite
min_periodo_job | vector containing the minimum period for each job for each satellite
max_periodo_job | vector containing the maximum period for each job for each satellite
min_statup | vector containing the minimum number of startups for each job for each satellite
max_statup | vector containing the maximum number of startups for each job for each satellite
priority | vector containing the priority of each job for each satellite
win_min | minimum time window for each job for each satellite
win_max | maximum time window for each job for each satellite
uso_p | vector containing the power usage of each job
recurso_p | vector containing the available resource for each time instant
 
### Output files
 
Three output files are generated, namely:
 
* $(**input_file**)_Bmax_EN.txt
    + **Data format**: sub,t,recurso_tot,recurso_A,recurso_B,solar,soc
* $(**input_file**)_Bmax_SCH.txt
    + **Data format**: sub,job,x[1],..,x[T]
* $(**input_file**)_Amax_EN.txt
    + **Data format**: sub,t,recurso_tot,recurso_A,recurso_B,solar,soc
* $(**input_file**)_Amax_SCH.txt
    + **Data format**:  sub,job,x[1],..,x[T]
* $(**input_file**)_mavrotas.txt
    + **Data format**: A,B
 
## References
Library inspired by Cezar Augusto Rigo`s task scheduling papers.
 
1. Rigo, C. A.; Seman, L. O.; Camponogara, E.; Morsch Filho, E.; Bezerra; E. A . .  Task scheduling for optimal power management and quality-of-service assurance in CubeSats. ACTA Astronautica, v. 179, p. 550-560, 2021. 
 
2. Rigo, C. A. ; Seman, L. O. ; Camponogara, E. ; Morsch Filho, E. ; Bezerra, E. A. . A nanosatellite task scheduling framework to improve mission value using fuzzy constraints. EXPERT SYSTEMS WITH APPLICATIONS, v. 175, p. 114784, 2021.
 
3. Rigo, C. A. ; Seman, L. O. ; Camponogara, E. ; Morsch Filho, E. ; Bezerra, E. A. ; Munari Junior, P. A. . A branch-and-price algorithm for nanosatellite task scheduling to improve mission quality-of-service. EUROPEAN JOURNAL OF OPERATIONAL RESEARCH, 2022.
