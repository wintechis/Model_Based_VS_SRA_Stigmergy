# Model_Based_VS_SRA_Stigmergy
Project to compare model-based agents (MBA) and simple reflex agents (SRA) using stigmergy.

The goal is to get an overview of the difference in performance, as well as exploring further usages and models of stigmergy for SRAs. Overall, we want to investigate, if SRA can perform better in a defined transportation task than model-based agents, when they can use stigmergy.
Simulations have a built-in disturbance: every 500 simulated cycles the stations switch their color randomly.

## Contents

models - models that share the same environment behaviour (= dynamic, stochastic transportation requests), but differ in their agents behaviour:
- Model_Based_GlobalKnowledge: a model where MBAs use a common shared knowledge base that all can read and update. They use very simple pathfinding to get to their destination. If this in unknown, the walk randomly around the shop floor until they find it - then the agent updates the global, central knowledge base. If it is at it destination, but does not find the expected station, the entry is deleted.
- Model_Based_Transporter: a model where MBAs are decentralized in their knowledge usage. Each agent has its own base, but may communicate with ONE other agent that it meets during its walk to update each others knowledge. They use very simple pathfinding to get to their destination. If this in unknown, the walk randomly around the shop floor until they find it - then the agent updates its own knowledge base. If it is at it destination, but does not find the expected station, their own entry is deleted. If it meets another agent that has the old, deprecated knowledge, it will adopt this knowledge.
- SRA_Gradient_Transporter_Infinite_Steps: a model with SRAs that walk randomly, use quantitative stigmergy, and follow these marks to get to their destination. They place stigmergy marks on succesful delivery and automatically replicate them if they find any, hence build cooperatively a global gradient (positive feedback). If they find local maxima of their pursued color mark (aka a maximum without a possbility to fulfill their transportation request), they will collaboratively delete these wrong marks (negative feedback).
- SRA_Random_Transporter: SRAs that do NOT use stigmergy but only wander around the shop floor to fulfill their transportation request.

models/experimental_models - models in similar behaviour as above with the additional possibility to place brick walls (= fields that may not be accessed) during simulation by clicking on the shop floor.
- Model_Based_GlobalKnowledge_Disturbance
- Model_Based_Transporter_Disturbances
- SRA_Infinite_Disturbances

doc:
Activity and class diagramm of the simplest SRA approach

cpn:
Colored Petri Net for the the simplest SRA approach (see http://cpntools.org/)

Author: Sebastian Schmid
