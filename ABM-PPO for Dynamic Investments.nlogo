globals
[
   years-simulated
   ;num-investors
   num-investor-failures
   ;patch-mean-profit
   patch-min-risk
   patch-max-risk
   ;decision-time-horizon
]

patches-own
[
   profit
   annual-risk
   p-num-years-occupied
   p-num-failures
]

turtles-own
[
   wealth
   current-utility
   old-policy-prob
   new-policy-prob
]

to setup
  clear-all
  reset-ticks
  ; global simulation parameters below
  set years-simulated 50
  ;set num-investors 25
  ;set patch-mean-profit 6000
  set patch-min-risk 0.01
  set patch-max-risk 0.08
  ;set decision-time-horizon 5
  set num-investor-failures 0

  ; initialize investment environment (patches)

  ask patches [
    ; profit follows an exp distribution with a 10% premium
    set profit random-exponential patch-mean-profit * 1.1
    set annual-risk patch-min-risk + random-float (patch-max-risk - patch-min-risk)
    set pcolor scale-color green profit 0 (4 * patch-mean-profit)
    set plabel precision annual-risk 2
    set p-num-years-occupied 0
    set p-num-failures 0
  ]
  ; initialize investors
  create-turtles num-investors [
    move-to one-of patches with [not any? turtles-here]
    set wealth 2000.0
    set old-policy-prob 0.5
    set new-policy-prob 0.5
  ]

  output
end

to go
  tick
  if ticks > years-simulated [ stop ]

  ask patches [ fluctuate-profit-risk ]

  ask turtles [
    ppo-reposition
    do-accounting
  ]

  output
end

to fluctuate-profit-risk
  ; apply a random economic shock to profits
  let economic-shock random-normal 0.03 0.08
  set profit profit * (1 + economic-shock)
  set profit max list 100 profit
  ; adjust risk based on patch history + a little random noise
  let risk-adjustment (0.007 * p-num-failures) - (0.004 * p-num-years-occupied)
  set annual-risk annual-risk + risk-adjustment + random-normal 0 0.008
  set annual-risk min list patch-max-risk (max list patch-min-risk annual-risk)

  set pcolor scale-color green profit 0 (4 * patch-mean-profit)
end


; PPO Decision Rule

to ppo-reposition
  ; Step 1: State observation
  let state-wealth wealth
  let state-profit [profit] of patch-here
  let state-risk [annual-risk] of patch-here

  ; Step 2: Compute old and new policy probabilities
  set old-policy-prob new-policy-prob
  set new-policy-prob 1 / (1 + exp(- (state-profit - state-risk * 100)))

  ; Step 3: Probability ratio
  let ratio new-policy-prob / (old-policy-prob + 0.0001)

  ; Step 4: Advantage (utility difference)
  let advantage (utility-for self - current-utility)

  ; Step 5: Clipped loss
  let clip-low max list 0.8 (min list 1.2 ratio)
  let clipped-loss min list (ratio * advantage) (clip-low * advantage)

  ; Step 6: Action selection
  ifelse (clipped-loss > 0) [
    ; Exploit best patch
    let best-patch max-one-of patches [profit - annual-risk * 100]
    if best-patch != nobody [ move-to best-patch ]
  ] [
    ; Explore random patch
    let random-patch one-of patches
    if random-patch != nobody [ move-to random-patch ]
  ]
end

to do-accounting
  set wealth wealth + (profit * 0.8) ; add net profit to wealth
  ; check if a risk event occurs this year
  if random-float 1.0 < annual-risk [
    set wealth wealth * 0.7
  ]

  if wealth = 0.0 [
    set num-investor-failures num-investor-failures + 1
    ask patch-here [ set p-num-failures p-num-failures + 1 ]   ; log failures if wealth is completely wiped out
  ]
  ; update patch history and recalculate investor utility
  ask patch-here [ set p-num-years-occupied p-num-years-occupied + 1 ]
  set current-utility utility-for self
end

to-report utility-for [a-turtle]
  let turtles-wealth [wealth] of a-turtle
  let patch-profit [profit] of patch-here
  ; calculate projected baseline wealth over the decision horizon
  let utility turtles-wealth + (patch-profit * decision-time-horizon * 0.8)
  let estimated-risk [annual-risk] of patch-here   ; discount the projected utility based on the patch's risk profile over time
  set utility utility * ((1 - (estimated-risk / 3)) ^ decision-time-horizon)

  report utility
end

to output  ; update utility distribution and dynamically scale the x-axis to fit the data
  let utility-values [current-utility] of turtles
  if not empty? utility-values [
    set-current-plot "UtilityHistogram"
    histogram utility-values
  ]

  let max-utility max utility-values
  if max-utility <= 0 [ set max-utility 1 ]
  set-plot-x-range 0 (max-utility * 1.1)

  set-current-plot "Mean Wealth"
  if count turtles > 0 [
    plot mean [wealth] of turtles    ; track average system performance over time
  ]

  set-current-plot "Mean Profit"
  plot mean [profit] of patches

  set-current-plot "Mean Risk"
  plot mean [annual-risk] of patches

  set-current-plot "Wealth Std. Dev."    ; measure wealth inequality/dispersion among the investors
  let wealth-values [wealth] of turtles
  if not empty? wealth-values [
    plot standard-deviation wealth-values
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
694
89
1082
478
-1
-1
20.0
1
8
1
1
1
0
0
0
1
-9
9
-9
9
1
1
1
ticks
30.0

BUTTON
164
284
247
351
SETUP
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
164
350
247
410
GO
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
164
410
246
479
STEP
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
469
89
694
286
UtilityHistogram
Utility
No. (Investors)
0.0
3000000.0
0.0
10.0
false
false
"" ""
PENS
"default" 100000.0 1 -16777216 true "" ""

PLOT
246
286
469
479
Mean Profit
Year
Profit
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
469
286
694
478
Mean Risk
Year
Risk
0.0
10.0
0.0
0.1
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
23
89
246
287
Mean Wealth
Year
Wealth
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
246
89
469
287
Wealth Std. Dev.
Year
Wealth SD
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
192
10
364
43
num-investors
num-investors
0
25
25.0
1
1
NIL
HORIZONTAL

SLIDER
396
10
568
43
patch-mean-profit
patch-mean-profit
0
10000
6000.0
500
1
NIL
HORIZONTAL

SLIDER
395
48
567
81
decision-time-horizon
decision-time-horizon
0
15
5.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
# Integrating the Proximal Poicy Optimation (PPO) in the Dynamic Business Investment Model

In this model, the agents are made intelligent in their dynamic investment decisions by embedding the Reinforcement Learning (RL) algorithm named Proximal Poicy Optimation (PPO) in the model. The original model has been proposed by Railsback and Grimm (2019) in the Chapter 12 of their book titled _Agent-based and Individual-based Modeling, 2nd edition_,. 


## 1. Purpose and patterns

Think about a business world that changes quickly and where investors are always trying to find a balance between making money and not going bankrupt. The goal of this model is to see how autonomous agents deal with this tradeoff over time. The investors in this model can learn instead of having to follow a strict set of hard-coded if-then rules. The model lets agents constantly check to see if their current investment strategy is working by using a simplified Proximal Policy Optimization (PPO) reinforcement learning algorithm. If an investor is doing well, they use what they know to find the best opportunities in their area. If they are failing, they explore new, quiet places.

The patterns we want to find are: We want to see how a group of learning agents naturally spreads out over a landscape with different risks and rewards. We anticipate the emergence of behaviors such as market correction (agents maintaining profitable yet saturated sectors) and an increasing degree of wealth inequality over time.



## 2. State variables and scales

The model operates over a simulated timeframe where 1 tick equals 1 year. A standard run lasts for 50 years. 
There are two main entities: the Environment (Patches) and the Investors (Turtles).

**The Investor (turtle agents):**
 These variables represent the agent's wallet, memory, and learning brain.

*wealth:* It is the investor's bank account balance. If this hits 0, they go bankrupt. Initial state is 2000.

*current-utility:* It is theinvestor's satisfaction score, combining wealth, expected profit, and risk tolerance.
	
*old-policy-prob:* It is the mathematical confidence the investor had in their previous strategy. Initial value is 0.5.

*new-policy-prob.* It is the mathematical confidence the investor has in their current strategy. Initial value is set at 0.5.

**The Business Market/Environemnt (patch agents):** These variables represent the economic conditions of the markets.

*profit:* It is the baseline annual payout of the sector. It initially follows the	Random Exponential pattern.

*annual-risk:* It is the percentage chance (0.01 to 0.08) that a business here will suffer a catastrophic failure this year.  It initially follows the Random Exponential pattern.

*p-num-years-occupied:* The number of years a patch representing a market, has been successfully held/captures by an investor?

*p-num-failures*: It is the number of times an investor has gone bankrupt.




## 3. Process overview and scheduling

The model includes the following actions that are executed in this order each time step.

**The Market Shifts:** The environment changes before anyone does anything. Profits go up and down because of economic shocks, and the risk of a market goes up or down based on how many times it has gone bankrupt in the past.

**The Agents Think and Move (PPO Learning):** Investors look around them. They figure out their PPO advantage (Am I doing better or worse than I thought I would?). They change their strategy based on this and either move to a new sector or stay where they are.

**Accounting:** At the end of the cycle, agents collect their local profits and add them to their capital. The system then does a probabilistic risk assessment. Agents who trigger their sector's annual-risk penalty lose a lot of money or go bankrupt. Lastly, the agents who are still alive recalculate their baseline utility and adjust their PPO advantage for the next learning cycle.

Output: The View, plots and utility histograms are updated.
 

## 4. Design concepts

**Basic principles:** This model is built on the intersection of microeconomics (utility theory) and machine learning (reinforcement learning). It assumes that humans (or agents) don't just chase raw cash; they chase a balance of cash, future stability, and risk avoidance.

**Emergence:** The following are the model's main outputs: Mean investor value and standard deviation of wealth for various time periods. Secondary outputs refer to the mean profit, mean risk, utility distribution and number of investor failures. These outputs arise from the way that investors balance exploration and exploitation using the PPO clipped surrogate objective that is greatly determined by the spatial crowding. 

**Adaptive behavior:** The adaptive behavior of the investor agents is repositioning. Investors adjust through PPO, conservatively revising policy probabilities seen in terms of the advantages (utility difference) experienced. They actively adapt to the behavior of other agents by assigning mathematical penalties to crowded patches. 

**Objective:** There are two different measures that investors are seeking to maximize. For step-by-step learning, they want to maximise PPO clipped surrogate objective function. For overall evaluation, their rating of their position is based on a modified utility measure of the expected future wealth at the end of a time horizon (T):

U = (W + P × T × 0.8) × (1 - F/3)<sup>T</sup>

**Prediction**: Prediction is implicit in advantage function. The advantage (A), as computed during the repositioning step, represents an agent's prediction of whether or not a new action has a higher expected utility for the agent than before.

**Sensing:** The investor agents perfectly sense their own wealth, and the current, post-fluctuation profit and risk at their own patch. Crucially, they also have a sense for the very number of other investors that are currently in potential destination patches (count turtles - here).

**Interaction:** The investors interact directly with each other through spatial competition. Unlike simple models where a patch has been strictly exclusive, agents in this case can be on the same patch but incur severe mathematical penalties to the perceived profit/risk ratio if the agents decide on crowded locations.

**Stochasticity:** Initial states of P and F are specified randomly. Stochasticity is the driver of dynamics in the environment; the normal distributions inject unpredictable economic shocks (upward trend) both in the profits and risks as step by step. Stochasticity is also a factor in determining business failures and in random patch selection for the PPO exploration phase.

**Observation:** The View displays the location of the agents colored to indicate patch profit. Graphs are maintained for mean risk, mean profit, mean wealth, wealth standard deviation, and utility distributions as a function of time.

**Learning:** Proximal Policy Optimization (PPO) is used by agents. To make the learning stable, PPO limits the change of the policy in each step by calculating a probability ratio and clipping the ratio. This prevents the agent from making destructively large updates in the face of one anomalous economic shock.
 

## 5. Initialization

When the model is set up (t = 0):
•A global population of investors (default 25) is created.
•The grid is generated. To mimic the real world where most businesses make modest money and only a few make millions, profits are drawn from an exponential distribution based on the patch-mean-profit slider.
•Risks are assigned randomly between 1% and 8%.
•Investors are dropped onto random, unoccupied patches with 2000.0 starting wealth
 

## 6. Input data

No time-series inputs are used.

## 7. Submodels

**Economic Fluctuations**: Every tick, patches adjust their profit (P) subject to a normally distributed economic shock (mean 0.03, standard deviation 0.08), ensuring profit never drops below 100:

*P*<sub>t+1</sub> = max(100, *P*<sub>t</sub> × (1 + *N*(0.03, 0.08)))

**Risk (F)** dynamically updates based on local historical failures and occupancy, plus a normal distribution shock N(0, 0.08). It is strictly clamped between the global bounds of 0.01 and 0.08:

*F*<sub>adj</sub> = (0.007 × *N*<sub>failures</sub>) - (0.004 × *N*<sub>years occupied</sub>)

*F*<sub>t+1</sub> = clamp(*F*<sub>t</sub> + *F*<sub>adj</sub> + *N*(0, 0.008), 0.01, 0.08)

**PPO Repositioning**: To make a decision, an agent first evaluates its state and updates its policy probabilities using a sigmoid function:

π<sub>new</sub> = 1 / (1 + e<sup>-(*P*<sub>t</sub> - *F*<sub>t</sub> × 100)</sup>)

**The ratio between the new and old policy** is calculated (adding a small epsilon to prevent division by zero), followed by the Advantage (A), which is the difference between potential utility and current utility:

*r*(θ) = π<sub>new</sub> / (π<sub>old</sub> + 0.001)
,
*A* = *U*<sub>potential</sub> - *U*<sub>current</sub>

**The agent calculates the Clipped Loss objective** to determine the action phase:

*L*<sub>CLIP</sub> = min(*r*(θ) × *A*, clip(*r*(θ), 0.8, 1.2) × *A*)

**Action selection**:

if *L*<sub>t</sub> > 0:
  - choose argmax(*P* - (*F* × 100)), if empty business exists
  - choose argmax(*P* - (*F* × 100)) / (*n* + 1), otherwise

if *L*<sub>t</sub> ≤ 0:
  - choose a random business such that *n* ≤ 1, if such patches exist
  - choose a random patch from all patches, otherwise


**Accounting**: Wealth updates linearly based on 80% of the patch's profit (*W*<sub>t+1</sub> =*W*<sub>t</sub> + P × 0.8) If the stochastic risk check fails, the agent does not lose everything; rather, it suffers a 30% reduction in accumulated wealth:

*W*<sub>t+1</sub> = *W*<sub>t</sub> × 0.7

Following this, the agent evaluates its new current-utility using the equation detailed in the Objective section.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="RSM 1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>mean [wealth] of turtles</metric>
    <metric>sum [wealth] of turtles</metric>
    <metric>count turtles with [wealth &lt; 100000]</metric>
    <metric>mean [current-utility] of turtles</metric>
    <metric>mean [profit] of patches</metric>
    <metric>mean [annual-risk] of patches</metric>
    <metric>count patches with [profit &lt; 500]</metric>
    <metric>count patches with [profit &gt; 15000]</metric>
    <enumeratedValueSet variable="num-investors">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-mean-profit">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="decision-time-horizon">
      <value value="7"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
