---
title: Wood boiler 
---
## House central heating
My first wood boiler was initially designed to burn coal and had a manual setpoint for air intake. Every ignition setpoint was different, and burning was considered suboptimal at best. The main idea was to add a Raspberry Pi controllable draft ventilator, an air intake regulator and a chimney temperature sensor. Here is a graph showing how the PID algorithm manages the burning process:  
![pid](https://lh3.googleusercontent.com/d/1lfPUdjONq7Gml7F7YvabmdC6UJkTfNUk)

## Draft fan
Because the chimney draft was weak at temperatures above 0 degrees Celsius, or powerful at temperatures below -15 degrees Celsius. I had to moderate suction on the chimney side. I managed to buy a draft fan and an impeller, but no adapter to fit it. So I had to design and weld it myself. It was a sort of success story because if the burning temperature was too low, then massive chemical loss clogged up everything, and I got an early indication about the rising issue. But when the temperature was too high, I lost energy or, in extreme cases, started a fire within the chimney. Since the decent setpoints were within a narrow range, I messed up a lot and cleaned this impeller more than needed.  
![fan](https://lh3.googleusercontent.com/d/11A7yrpBE_DwK-qvGem_oq006fyi9XUVw)

## Air intake
Another lever I had for the burning process control was the air intake. This one was easier to automate. I just had to replace manual setpoint screw with stepper motor.  
![door](https://lh3.googleusercontent.com/d/1pxHXM_2PBq6bVCpDXwE91_Mc31dwdRJs)

## Controller
Controller hardware consists of an ADC for thermocoupler temperature sensing, a solid-state 220V relay for the fan and a servo driver for the door intake adjustment.
![controller](https://lh3.googleusercontent.com/d/13y1NvRPw-mHmRpfzR6mzqnVR5CIFKA-m)

## Wood gas boiler 
Then, after years of service, the old boiler efficiency levels were no longer satisfactory by my standards. The new system had semi-mechanical automation capabilities, like switching the fan off when it is out of fuel. So I had to revive old hardware in a new launchbox.  
![atmos_setup](https://lh3.googleusercontent.com/d/12mcIet4nDiw1vfstWEyf4kvMPjcg_WLa)  

Since the boiler is relatively airtight, I only needed a fan on/off switching capability based on chimney temperature.  
![atmos_temperature](https://lh3.googleusercontent.com/d/1jYkU-sIrzz3BWurmfu4RLuY_O1beHGWi)
