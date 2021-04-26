# Performance comparison of Simple Reflex Agents Using Stigmergy with Model-Based Agents in Self-Organizing Transportation
Project to compare the performances of naive simple reflex agents (SRA), SRAs using stigmergy, model-based agents (MBA) and a monolithic approach in a disturbed transportation setting that simulates a dynamic, real-world industrial shop floor.   

The goal is to get an overview of the differences in performance, as well as exploring further usages and models of stigmergy for SRAs. Overall, we want to investigate, if SRAs with stigmergy can perform better in a defined transportation task than MBAs, when they can use stigmergy.

We simulate a shop floor that contains four major components: a fixed number of stations and transporters, a varying amount of colored items, and a discrete grid of floor tiles which can be read and manipulated by transporters (only used if agents use stigmergy, see below). 
Distinct colored items are randomly produced by stations and have to be transported to another designated station of matching color. Transporters shall fulfill this transportation task. Stations are not related, that means there is no order or specification for the transporters to visit them. 
Each station can hold at most one item, then it has to wait until a transporter picks up the item before another one is produced. Transporters can carry only one item at a time. 

The simulations have a built-in disturbance in their environment: every 500 simulated cycles the stations switch their color randomly, such that the destinations of the items is dynamic.

## Contents

models - models that share the same environment behaviour (= dynamic, stochastic transportation requests), but differ in their agents behaviour:
- 1_SRA_Naive_Transporter: SRAs that do NOT use stigmergy but only wander around the shop floor to fulfill their transportation request.
- 2_SRA_Stigmergy_Transporter: a model with SRAs that walk randomly, but use quantitative stigmergy, and follow these marks to get to their destination. They place stigmergy marks on succesful delivery and automatically replicate them if they find any, hence build cooperatively a global gradient (positive feedback). If they find local maxima of their pursued color mark (aka a maximum without a possbility to fulfill their transportation request), they will collaboratively delete these wrong marks (negative feedback).
- 3_MBA_Transporter: a model where MBAs are decentralized in their knowledge usage. Each agent has its own internal states, but may communicate with another agent that it meets during its walk to update each others knowledge. They use simple, greedy pathfinding to get to their destination. If this in unknown, the walk randomly around the shop floor until they find it, then the agent updates its own knowledge base. If it is at it destination, but does not find the expected station, their own entry is deleted. If it meets another agent that has the old, deprecated knowledge, it will adopt this wrong knowledge.
- 4_Blackboard_Transporter: a model where agents use a common shared knowledge base that all can read and update. They use very simple pathfinding to get to their destination. If this in unknown, the walk randomly around the shop floor until they find it - then the agent updates the global, central knowledge base. If it is at it destination, but does not find the expected station, the entry is deleted.

result - contains our measured data for this setup with 10k simulated cycles and 40 repetitions per model:
-  \*.csv : results per model, names as above
-  Model_vs_StigInf_vs_Global.ods: a consolidated table of all measured values, including charts

## Setup of the artifact for [GAMA](https://gama-platform.github.io/) _without_ a VM

- Install GAMA according to these [steps](https://gama-platform.github.io/wiki/Installation)
  -  [System Requirements](https://gama-platform.github.io/wiki/Installation#system-requirements)
- [Import the project into your workspace](https://gama-platform.github.io/wiki/ImportingModels)
- Select the model you are interested in
- Run the included experiments in /models/:
  - "\*_Transporter": run a simulation with a GUI, an animated shop floor and charts
  - "No_Charts": same as above, but without charts, but added shop floor names
  - "\*_Transporter_batch": run a batch of simulations, pre-set to 10k cycles and 40 repetitions. Results are saved under the above given names in /models/result/
- Note that the simulation results are saved in separate files and have to be put externally together, e.g. to be displayed in a chart

## Setup of the artifact [GAMA](https://gama-platform.github.io/) _with_ a VM

- tbd
