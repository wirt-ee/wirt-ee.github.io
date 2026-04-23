---
title: Lawn mower 
---
## Electric lawn mower
After I broke my second grass eater and inhaled all its final smoke, I started to roll the idea to electrify this thing. I had time to think since basic economics and scarce availability blessed me with another smoker.
However, during this transition time, this is the final product I came up with:
![new](https://lh3.googleusercontent.com/d/1YQKByA78p9YXiid8hYgcIUFFAcvEfHKc)

## Different aspects 

**Requirements for an electrical lawn mower:**  
1. Safe to my toes  
2. Low noise and vibration  
3. Easy to operate, light  
4. Wide cut area  
5. Slim slides below the bushes  
6. Non-corrosive case (stainless)  
7. Low maintenance  
8. Ability to run 2 hours straight  

**Tradeoffs:**  
1. One cut height  
2. No grass collector  

**What components do I have from various failed projects?**  
1. A brushless motor from an electrified bicycle  
2. A battery from a bicycle to extend its capacity  
3. Bicycle brushless motor controller without throttle  

**Tools I had:**   
1. 3D printer  
2. Generic locksmith belt  

**Materials I did not have:**  
1. stainless steel sheet 1.5 mm  
2. ball bearing steel wheels  
3. material for the handle  
4. cutter blade  

## Process
I decided to use a heavy mower tractor blade. Why did I choose to get more vibration? This decision was made because the motor significantly slowed down when the blade hit something more substantial.  

Since I was sure I could not properly weld stainless steel, I used rivets for case assembly. Straight bending and drilling stainless steel was a long process.  

I used a baseplate to mount the motor on the 3D-printed pillars. The printed structure was angled and spaced for maximum heat transfer and debris removal. It also failed once during the 20-hour print. So, the top and bottom parts are printed separately and glued together with a bronze sleeve armament.  

![failed_print](https://lh3.googleusercontent.com/d/10WX8mpbvdvwjK9YInnD_XUkYY-yApmXq)
![glued_print](https://lh3.googleusercontent.com/d/10X0Sxxb5SKUkRJo0bAZvW8UdJZaJ4ztV)

Blade design puts no significant force on the plastic layers (all layers should be compressed).  

The extended (more elements in parallel) bicycle battery goes into the pencil box. The safety cutoff was the same type of switch as the printer endstop. The trickiest part was to fool the non-throttle controller into thinking that someone is pedalling. I had to create an oscillating PWM controller to simulate the PAS output. Unfortunately, this extra piece of hardware's oscillating frequency was temperature-dependent. So I had to use a mower case as a gigantic grass-cooled radiator. 
![assembly](https://lh3.googleusercontent.com/d/18izNDJLevYP4UzRBnWPFZSTJL3hsBj4Y)

The controller was taken from a 20'' wheeler. Since the blade diameter is close to it, I may assume that the blade tip has travelled over 50 thousand kilometres over many summers. I may have to change motor bearings soon.  
![50k](https://lh3.googleusercontent.com/d/103gw-7N79aLSmOBdLHNQHL-IvMneAuDz)  
So far, a generic war and tear is acceptable. Lots of dents in the blade (smashing a smaller rocks) and one major dent on the case after accidentally jamming a brick between the blade and case on full throttle.
![rollover](https://lh3.googleusercontent.com/d/15eQkdIwygf9bHNW08HCvS5hC9MNiFyng)

