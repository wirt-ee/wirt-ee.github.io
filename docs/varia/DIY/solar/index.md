---
title: Solar installations 
---
## Off-grid solar
Why not to be a micro producer? Because grid owner charges transmission fees!  
Solar panels got my attention when efficiency started to go over 20%. Since back then, proper panels were expensive, I did my groundwork with individual monocristal cells. Extrapolating the price graph suggested I could do real work within a few years. And here it is. Practically usable thing in 58.5953° N, 25.0136° E for 6 months per year.
![panels](https://lh3.googleusercontent.com/d/1iJM5pDUyzUt0WlHLCtUulVeloxdYd1wa)
Installation consists of four angled solar panels (a canopy) and three vertical panels that catch low evening sunlight. Since the solar panel price dropped below shipping costs, all vertical less efficient (east-west direction) may be more beneficial. Because only panels producing power in winter are vertical, and in the summer, I have issues dumping all that excess energy on peak hours to the electrically heated water boiler (not a steam boiler). Another option is to increase battery size, which is still not so cheap.  


## Electronics
All 41.5 V panels are connected in parallel (with circuit breakers). I used microinverters (MPPT) for every panel to step up the voltage for a 48V system. Unfortunately, those MPPTs all have design flaws. They tend to stay on when the sun is not shining. This means that solar panels consume power. I added rectifier diodes between the battery and the controller to mitigate this nasty issue.
Also, a low-power household thing may want 3.5kW peak power during the transient period. This also means that I had underestimated the inverter size. Minimal inverter size seems to be 5 kW.   
![electronics](https://lh3.googleusercontent.com/d/1ISBdvVlt_CvAM40NK5BQI7kARlO-AnVU)

## Battery
Initially, I tried and failed with a minuscule battery. Home appliances are not doing decent soft starts. When a power-hungry device was turned on, there was a voltage sag, often visible from lightbulb fluctuation. So I had to replace my bicycle's (700 Wh) battery with something bigger. 
Since I had seen too many battery-burning horror stories, I decided to put it in the basement in a separate room with concrete walls. Less than ideal for electronics for high moisture content ( reduced by a dehumidifier). Also, the battery needs a specific temperature range for operating. Enclosing the battery in a box with the Raspberry Pi was sufficient for heating in the winter months. During the summer, I need to remove the box.  
![battery](https://lh3.googleusercontent.com/d/1a1tAjWjReTbtsKbCWe-0twE8ZuB4dk25)


## Operations
Since the system is designed for offline use (grid owner charges transmission fees), I had the option to switch over when battery voltage sags below the recommended level (20%) or to switch over when grid inverter output disappears (ATS). Initially, I tried to switch based on battery voltage. It was a mistake because the inverter still stayed on. If I tried to match the inverter shutdown voltage with the battery switch-off voltage, it ended up in a situation where the inverter prematurely switched off (the house is dark) or consumed more energy than needed in idle. I had to throw this box off using regular ATS (mains/generator failover), monitor external battery voltage, and send a signal to the inverter to switch off (Raspberry PI for this task). 

Then I discovered I want remote access and monitoring. It means that I needed to connect this thing to the house network. Since I did not install any communication cables between the house network and the battery inverter room, I had to use network adapters over the main AC. Luckily, they worked out of the box. 

The next issue was how to use all the excess energy when the battery is full and the house is not consuming. Since I had a central heating water boiler with an electrical heating element, I connected a remotely controllable power regulator to it. The Raspberry Pi monitors the battery logs in the boiler Raspberry Pi and adjusts the power level based on the battery voltage.  
![production](https://lh3.googleusercontent.com/d/1O6cqliNtbBY6UH31A3XlHIoY-krU5jd8)
