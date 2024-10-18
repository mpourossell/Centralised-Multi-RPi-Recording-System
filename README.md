# Automated monitoring of Parental Care in birds using Raspberry Pi and YOLOv8 computer vision

Parental care is a critical focus of study in behavioural ecology due to its influence on offspring fitness and evolutionary outcomes. However, gathering the detailed long-term data required to fully understand these relationships poses significant challenges, especially in wild populations. 

To overcome this, we developed an automated system for continuous non-invasive monitoring of parental care behaviours over extended periods. Using a Raspberry Pi-based system, we recorded video and temperature data in nest boxes throughout the entire reproductive cycle of 14 pairs of wild jackdaws (Corvus monedula) over three consecutive breeding seasons. 

<p align="left">
  <img src="images/outdoor_picture.jpg" alt="Artificial breeding tower" width="603" />
</p>

<p align="left">
  <img src="images/nest_construction.gif" alt="Nest construction in a jackdaw nest box" width="300" />
  <img src="images/incubation.gif" alt="Incubation of a jackdaw female" width="300" />
</p>

Additionally, our approach integrates open-source hardware with deep learning techniques for automated video analysis. Using a custom-trained YOLOv8 computer vision model, which demonstrated high accuracy, we successfully quantified detailed behavioural patterns across all collected data.

<p align="left">
  <img src="images/jackdaw_pose_detection.png" alt="Pose estimation in multiple individuals using YOLOv8" width="603" />
</p>

We provide a low-cost, scalable solution for automated continuous behavioural monitoring. The flexibility of our system allows for broad customization, both in hardware and software, enabling its adaptation for a wide range of behavioural studies. The modular design allows the integration of additional sensors, while the system’s remote connectivity and solar-powered configuration ensure functionality in remote, off-grid locations. 

## Project structure

This project is divided in 3 main parts:
1) Design of an automated recording system based on Raspberry Pi microcomputers, to continuously monitoring nest boxes in the wild for long time periods
1) Application of a custom computer vision model for automated video analysis in Python
1) Data processing and analysis in R to quantify parental behaviour using the long-term and continuous collected data. This approach provides an accessible, cost-effective alternative to existing methods, while offering significant flexibility, enabling customization for a wide range of behavioural quantification applications beyond avian species or parental care. In this paper, we provide a detailed guide for replicating the system, including a materials list, instructions for assembling the electronics, and relevant coding procedures. We tested this system on wild jackdaws in the NE of the Iberian Peninsula to demonstrate its effectiveness in automating both data collection and post-processing for the interpretation of parental care behaviours. 
