---
title: Electrified bicycles 
---
## Current state.
In the early days of brushless DC motors, I developed a mild need to build an electrified bicycle, since it is convenient in a city to transport kids and smaller goods. My finalised utility is here. The only maintenance it needed for the last 5000 km was occasional rainwash. This thing has all-wheel drive mode and tank turn capabilities.
![Maxxx](https://lh3.googleusercontent.com/d/1-x2v4gs0TvTat1AlLGtMgl8oTqv89C8W)


## Attempt one
Let's step through a complete chain of failures set by the initial goal.
Since my pockets were not very deep, I had to think about how to get things done under a nonexistent budget. 
My first motor was a car generator. I drilled out a regular electromagnet and replaced it with neodymium magnets. Now it can be called a motor. And then I fitted a regular bicycle gear on the shaft.
![motor_and_controller](https://lh3.googleusercontent.com/d/1PikDUnYWtLq9MjYkN747JIE76GcR6W4x)

 This setup has three problems. The magnetic field was weak, heavy, and had no freewheeling (directly connected to the pedals). 
Since BLDC wants switching in electronics, I had to wire hardware and write code to get the motor to spin. Battery technology was not there, and I had to use a second-hand, super-heavy, regular 12V car battery.
To cut BS, this thing was not convenient to use. I accepted losses and paused. Procjet state was recorded [here](https://sourceforge.net/projects/bldc/)

## Attempt two
The second attempt was made when I could buy an el-cheapo BLDC controller and a skateboard motor. The idea was to print out the nylon gravity pusher and the drag front wheel. I wanted to get around 50W of power transfer from it. Unfortunately, it started bouncing on the wheel due to irregularities. Then I pulled it towards the front wheel, got my happy 2 km and blew the controller. Luckily, my self-made battery survived because I did not forget to install a proper fuse.
![dragger](https://lh3.googleusercontent.com/d/10g9JjHB86qkm0I1nxZ5gl7W4OBeL0TvF)

## Attempt three
Since pockets had grown deeper and the world around me had evolved, I managed to buy my first "proper" hub motor and controller. It turned out that starting from a standstill (hall sensors) and using an electronic brake were essential, mainly because speed (weight) increased, and brake pad and rim wear were significant.
![Dahon](https://lh3.googleusercontent.com/d/1Px6WnqZRa2214kOKR6mzoGZ11Q5XzAWk)

I upgraded batterys and got around 120 km range out of it.
![Dahon_range](https://lh3.googleusercontent.com/d/12IZ2eKw6zxC4LFKIXIjZIddFuA6rND2k)

Then, after a significant number of cycles ( around 17 years). Bikeframe started to show its age. Initially, the front fork fell off. Then I discovered small cracks on the seatpost. 
![fork](https://lh3.googleusercontent.com/d/12WWQbUGLDbtIDm7_XGm7qXdXAKcXLhmI)
![HalfOfDahon](https://lh3.googleusercontent.com/d/12h0Q0ORurk5OsY12UHvcQLPYcqSpwdjJ)
![whell](https://lh3.googleusercontent.com/d/10dRWrZySvZS2kiuTYysqSPnTvp8Qo3Vr)

I repaired and replaced everything, but the ageing issues did not go away. And then winter happanes - again.
![Dahon_winter](https://lh3.googleusercontent.com/d/11pJw-tStPbP5CkaoyRZmoN6hmnSZULV4)

## Final attempt
After another reality check, I started to plan my new two-wheeler. 
Requirements were:

1. Maintenance free
2. Robust frame, steel fork
3. Comfort riding position
4. All wheel drive, e-brake
5. Bicycle, by its nature


First, I considered recumbent bikes, but I gave up because of their rarity.

Then no one will sell me a decent quality diamond-framed bicycle with a belt drive. High-end bicycles were built for racing. Regular city bikes were built to compete on price. It took half a year and countless rejections for custom-built bicycle manufacturers until I found 99% what I wanted. The only thing I had to do was lace the motor myself. Build a battery, install a front rack for it ( no bending wires) and hope for the best.

![lace](https://lh3.googleusercontent.com/d/14ODY5M7OlZwa7zdaLuFe5VbATbZv9zFI)
![battery](https://lh3.googleusercontent.com/d/14g3XkMs55Mmnb2pAhugm-oC--uWkXkdo)

I decided to stick with my proven e-bike controller provider. I accidentally purchased a lower-voltage-rated controller during the COVID supply turbulence. I managed to get it to run, but just in case, I contacted the seller since the setup was too hard for a kit. The company owner wrote back to notify me that I have a 50% chance of blowing up MOSFETs — yet another controller swap. Then I discovered that my new battery BMS was weak. This one was luckily fixable in the e-bike software by doing a 0. something seconds softer start. After that, I had to build a [PAS](https://www.thingiverse.com/thing:6533804) sensor inside the gearbox. The initial idea to let the belt drive the PAS looked clumsy. But there was a way to fit everything inside the gearbox's removable cover cap. After numerous failed prints, I got it done.  
Now the final touch was to set up reasonable limits for this beast and hit the road.
![limits](https://lh3.googleusercontent.com/d/14nEu1OKGUNxGlA8nmmijZtdV1kd4KC9S)
![road](https://lh3.googleusercontent.com/d/15-jaml4WMHwOQrApw-wfWDt-LckITELK)
