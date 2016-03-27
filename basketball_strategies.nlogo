; UVA/VU - Multi-Agent Systems
; Koen Keune & Marysia Winkels
;
; Running the code will result in a print of the current settings with the score for
; each team after the specified number of possessions

__includes["setup.nls" "general_functions.nls"]

; --- Setup ---
to setup
  clear-all
  setup-court
  setup-game
  setup-parameters
  setup-ticks
end

; --- Main processing cycle ---
to go
  if time = 0 [jump-ball 15]
  if shot-made != "false" [
    inbound shot-made
    set shot-made "false"
    ]
  if shot-missed != "false" [
    bounce-off-rim shot-missed 15
    set shot-missed "false"
  ]

  update-beliefs ; desires need up-to-date beliefs
  update-desires
  update-intentions
  execute-actions
  send-messages

  update-possessions
  set time time + 1

  ; print when done
  if possessions-lakers >= number-of-possesions and possessions-celtics >= number-of-possesions [
    print "time passed:"
    print time
    print "lakers: "
    print "teamplayer:"
    print teamplayers-lakers?
    print "zone-defense:"
    print zone-defense-lakers?
    print "points: "
    print points-lakers

    print "celtics"
    print "teamplayer:"
    print teamplayers-celtics?
    print "zone-defense:"
    print zone-defense-celtics?
    print "points: "
    print points-celtics

    stop
  ]

  tick
end

; --- Update desires ---
to update-desires
  ask players [
    ifelse loose-ball? [ set desire "get ball" ]
    [
      ifelse team-has-ball? [ set desire "score" ]
      [ set desire "defend" ]
    ]
  ]
end

; --- Update beliefs ---
; first if: player has ball
; second if: team has ball
; else: team doesnt has the ball
to update-beliefs
  ask ball 11 [
    set closest-to-ball min-one-of players [distance myself]
  ]

  ask players [
    ifelse (closest-to-ball = self) and (distance ball-position < distance-for-possession) [ ; this player has the ball
      set loose-ball? false
      set player-has-ball? true
      ask ball 11 [
        set prev-owner owner
        set owner myself
      ]

      let distance-to-basket 0
      ask basket-to-score [
        set distance-to-basket distance myself
      ]

      ; ******** beginning of open teammate stuff ********
      let players-own-team other (players in-cone vision-distance 160) with [team = [team] of myself] ; all players of own team in vision cone
      let players-other-team other (players in-cone vision-distance 160) with [team != [team] of myself] ; all player of other team in vision cone
      let players-open-temp []

      ask players-own-team [
        let open true
        let dist-ball-teammate distance myself ; distance of player with ball to player-own-team

        ask players-other-team [
          let dist-ball-opponent 0
          let dist-teammate-opponent distance myself ; distance of teammate to opponent

          ask players with [player-has-ball? = true] [
            set dist-ball-opponent distance myself
          ]
          if not (dist-ball-teammate < dist-teammate-opponent or dist-ball-teammate < dist-ball-opponent) [ ; third option could be added if it doesnt work
            set open false
          ]
        ]
        if open [
          set players-open-temp lput self players-open-temp
        ]
      ]
      let counter 0
      repeat length received-messages [
        if not member? item counter received-messages players-open-temp [
          set players-open-temp lput item counter received-messages players-open-temp
        ]
        set counter counter + 1
      ]
      set received-messages []

      set players-open players-open-temp ; temp is used because it is in a different turtle scope

      if not empty? players-open-temp [ ; determine the best option by looking at the closest teammate to the basket
        let best-option-temp1 item 0 players-open-temp
        ask basket-to-score [
          if length players-open-temp > 1 [

            let distance-to-score1 distance item 0 players-open-temp ; should probably use ask turtles
            let counter2 1 ; skip the first one
            repeat length players-open-temp - 1 [
              ask item counter2 players-open-temp [
                let best-option-temp2 self
                let distance-to-score2 distance myself
                if distance-to-score2 < distance-to-score1 [
                  set best-option-temp1 best-option-temp2
                  set distance-to-score1 distance-to-score2
                ]
              ]
              set counter2 counter2 + 1
            ]
          ]
        ]
        set best-option best-option-temp1
      ]
      ; ******** end of open teammate stuff ********

      ifelse distance-to-basket < shooting-range [ set in-shooting-range? true ][
        set in-shooting-range? false
      ]

    ][
      set player-has-ball? false
    ]

    ifelse ([team] of ([owner] of ball 11) = [team] of self) [
      set team-has-ball? true
      set getting-to-defensive-spot? false
      set got-back? false
      set ball-is-defended? false
      set defends-ball? false

      let defender-is-close-temp? false
      let dist distance ball-position
      let players-close other players with [team-has-ball? = false] in-radius 7 ; distance of 7 for a defender close

      let off-basket-dist 0
      if any? players-close [
        ask basket-to-score [
          set off-basket-dist distance myself
          ask players-close [
            if distance myself < off-basket-dist [ ; the defender is closer to the basket
              set defender-is-close-temp? true
            ]
          ]
        ]
      ]
      set defender-is-close? defender-is-close-temp?

      let basket basket-to-score
      let dist-temp1 5 ; maximal distance
      ask players-close [
        let dist-temp2 distance myself
        ask basket [
          if distance myself < off-basket-dist and dist-temp2 < dist-temp1 [
            set dist-temp1 dist-temp2
          ]
        ]
      ]
      set dist-closest-defender dist-temp1

      if spot != 0 [ ; if initialized
        if pxcor = item 0 spot and pycor = item 1 spot and getting-to-offensive-spot? [
          set getting-to-offensive-spot? false
        ]
      ]
    ][ ; defense stuff
      set team-has-ball? false
      set getting-to-offensive-spot? false
      set closest-player min-one-of players with [team != [team] of myself] [distance myself]

      let zone-to-defend-temp zone-to-defend
      let otherPlayers players with [team != [team] of myself]; and member? patch-here zone-to-defend]
      let players-in-zone []
      let closest-player-in-zone-temp 0
      let dist-temp 100
      ask otherPlayers [
        if member? patch-here zone-to-defend-temp [
            set players-in-zone lput self players-in-zone
            let dist-temp2 distance myself

            if distance myself < dist-temp [
              set dist-temp distance myself
              set closest-player-in-zone-temp self
            ]
          ]
      ]
      set closest-player-in-zone closest-player-in-zone-temp

      if spot != 0 [ ; if initialized
        if pxcor = item 0 spot and pycor = item 1 spot and not got-back? [
          set got-back? true
        ]
        if pxcor = item 0 spot and pycor = item 1 spot and getting-to-defensive-spot? [
          set getting-to-defensive-spot? false
        ]
      ]
      if got-back? and not ball-is-defended? [
        set defends-ball? true
        set ball-is-defended? true ; send-message makes the other players know it
      ]

    ]
  ]
end

; --- Update intentions ---
to update-intentions
  ask players [
    ifelse desire = "get ball" [
      ifelse closest-to-ball = self [
        set intention "go to ball"
      ][
        set intention "no intention"]
    ][
    ifelse desire = "score" [
      ifelse player-has-ball? and in-shooting-range? [
        set intention "shoot"
      ][
      ifelse player-has-ball? and not empty? players-open and teamplayer? and random-float 1 < 1 - pass-percentage [
        set intention "pass"
      ][
      ifelse player-has-ball? and not empty? players-open and defender-is-close? [
        set intention "pass"
      ][
      ifelse player-has-ball? [
        set intention "walk with ball"
      ][
      set intention "get open"
      ]]]]
    ][
    if desire = "defend" [
      ifelse not got-back? [
        set intention "get back"
      ][
      ifelse zone-defense? and closest-player-in-zone != 0 [
        set intention "defend player in zone"
      ][
      ifelse zone-defense? [
        set intention "go to zone"
      ][
      ifelse defends-ball? [
        set intention "defend ball"
      ][
        set intention "defend man"
      ]]]]]
    ]]
  ]
end

; --- Execute actions ---
to execute-actions
  ask players [
    if intention = "walk with ball" [
      face one-of basket-to-score
      fd speed-with-ball
      ask ball 11 [
        set heading ([heading] of owner) ; make it go the same direction
        setxy ([xcor] of myself) ([ycor] of myself)
        fd 1
      ]
    ]
    if intention = "shoot" [
      let xBasket 0
      let yBasket 0
      let distance-to-basket 0
      let range shooting-range
      let teamTemp team
      let dist-defender dist-closest-defender

      ask basket-to-score [
        set xBasket pxcor
        set yBasket pycor
        set distance-to-basket distance myself
      ]

      ask ball 11 [
        setxy xBasket yBasket

        ifelse random-float 1 < probability-score range distance-to-basket dist-defender 5 [
          set shot-made teamTemp
          ; no 3-pointers yet
          ifelse teamTemp = "lakers" [
            set points-lakers points-lakers + 2
          ][
            set points-celtics points-celtics + 2
          ]
        ][
          set shot-missed teamTemp
          set loose-ball? true
        ]
      ]
    ]
    if intention = "no intention"[
      left random 360
      fd 1
    ]
    if intention = "go to ball" [
      face ball 11
      fd 1
    ]
    if intention = "pass" [
      set target best-option
      face target
      let xTarget 0
      let yTarget 0
      ask target [
        set xTarget pxcor
        set yTarget pycor
      ]
      pass-position xTarget yTarget 5
    ]
    if intention = "get open" [
      if not getting-to-offensive-spot? [ ; keep moving if it has arrived at the random spot
        set spot offense-spot team
        set getting-to-offensive-spot? true
      ]
      facexy item 0 spot item 1 spot
      fd 1
    ]
    if intention = "get back" [
      set spot paint-spot team
      set getting-to-defensive-spot? true
      facexy item 0 spot item 1 spot
      fd 1
    ]
    if intention = "defend ball" [
      face ball-position
      fd 1
    ]
    if intention = "defend man" [
      face closest-player
      fd 1
    ]
    if intention = "defend player in zone" [
      face closest-player-in-zone
      fd 1
    ]
    if intention = "go to zone" [
      face min-one-of zone-to-defend [distance myself]
      fd 1
    ]
  ]
end

to send-messages
  ask players [
    if not team-has-ball? and defends-ball? [ ; communicate to others if you are defending the ball
      let send-to other players with [team = [team] of myself]
      ask send-to [
        set ball-is-defended? true ; communicate when the ball is defended (reverse is common knowledge)
      ]
    ] ; communicate when in offense to the one with the ball that you are open when you have seen that you are open
    if team-has-ball? and not defender-is-close? and not player-has-ball? [
      let player-open-message self
      let send-to players with [player-has-ball?]
      ask send-to [
        set received-messages lput player-open-message received-messages
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
409
13
1310
539
49
27
9.0
1
10
1
1
1
0
0
0
1
-49
49
-27
27
0
0
1
ticks
30.0

BUTTON
68
20
131
53
NIL
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
20
65
83
98
NIL
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
137
70
200
103
NIL
go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
13
118
99
163
Points Lakers
points-lakers
17
1
11

MONITOR
129
123
215
168
Points Celtics
points-celtics
17
1
11

MONITOR
20
252
131
297
Desire of player 1
[desire] of player 1
17
1
11

MONITOR
174
253
285
298
Desire of player 6
[desire] of player 6
17
1
11

MONITOR
12
310
139
355
Intention of player 1
[intention] of player 1
17
1
11

MONITOR
167
310
294
355
Intention of player 6
[intention] of player 6
17
1
11

MONITOR
13
183
312
228
Beliefs of the player with the ball about who is open
[players-open] of players with [player-has-ball?]
17
1
11

SWITCH
208
371
374
404
teamplayers-lakers?
teamplayers-lakers?
0
1
-1000

SWITCH
21
370
188
403
teamplayers-celtics?
teamplayers-celtics?
0
1
-1000

SLIDER
17
466
189
499
pass-percentage
pass-percentage
0
1
0.9
.05
1
NIL
HORIZONTAL

SWITCH
18
416
192
449
zone-defense-lakers?
zone-defense-lakers?
1
1
-1000

SWITCH
215
420
390
453
zone-defense-celtics?
zone-defense-celtics?
1
1
-1000

INPUTBOX
231
25
386
85
number-of-possesions
1000
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This model is about a football game but can also be used for different teamsports with a ball and passing and shooting behaviour.

The model is trying to show how the composition of different types of soccer players influence the result of a match.

## HOW IT WORKS

there are 4 types of players.

- selfish defender
- selfish attacker
- attacking teamplayer
- defensive teamplayer

they all behave in their own way. The teamplayers tend to pass faster, the selfish players are better with tricks and will shoot at greater distances. The attackers tend to move forward while their team has the ball and the defenders will move backwards when their team does not have the ball.

At the setup and after each goal the players are randomly placed on their side of the field leading to a different behaviour for every model run.

## HOW TO USE IT

In this model you can change the composition of the team with sliders. You can create traditional teams with 10 players or even vary with the amount of players. there is a max of 10 players of the same type for each team.

With the fixed seed option turned on you can watch the same goal over and over again. You can rewatch the previous goal by entering the previous seed number in the current seed number and turn the fixed seed option on.

## THINGS TO NOTICE

Check the different behaviour of the team when a certain mix of players are in the field.

## THINGS TO TRY

Try different composition of teams to beat a team.

## CREDITS AND REFERENCES

Designed by: Willemijn Bikker & Sander van Egmond
Written by: Sander van Egmond
For the course Agent Based Modelling at Wageningen University
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

ball basketball
false
0
Circle -7500403 true true 26 26 247
Polygon -16777216 false false 30 150 30 165 45 195 75 225 120 240 180 240 225 225 255 195 270 165 270 150 270 135 255 105 225 75 180 60 120 60 75 75 45 105 30 135
Line -16777216 false 30 150 270 150
Circle -16777216 false false 26 26 247

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

football
true
0
Circle -1 true false 65 65 170
Line -16777216 false 60 150 90 150
Line -16777216 false 90 150 105 135
Line -16777216 false 105 135 105 120
Line -16777216 false 105 120 105 105
Line -16777216 false 105 105 90 90
Polygon -16777216 true false 225 150 210 150 195 165 195 195 210 210 225 195 240 150
Polygon -16777216 true false 60 150 90 150 105 135 105 105 90 90 75 105 60 135
Polygon -16777216 true false 135 150 150 165 165 165 180 150 180 135 165 120 150 120 135 135
Polygon -16777216 true false 105 210 90 225 135 240 150 240 150 210 135 195 120 195 105 210
Polygon -16777216 true false 165 60 195 75 210 90 210 105 195 105 180 105 165 90 165 75

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

keeper
true
0
Circle -6459832 true false 174 99 42
Circle -6459832 true false 84 99 42
Circle -7500403 true true 180 120 60
Rectangle -7500403 true true 90 120 210 180
Circle -7500403 true true 60 120 60
Circle -955883 true false 103 88 95
Polygon -7500403 true true 255 120 240 105 210 135 240 150 255 120
Polygon -7500403 true true 45 120 60 105 90 135 60 150 45 120
Circle -6459832 true false 240 90 30
Circle -6459832 true false 30 90 30

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

player
true
0
Circle -6459832 true false 174 99 42
Circle -6459832 true false 84 99 42
Circle -7500403 true true 180 120 60
Rectangle -7500403 true true 90 120 210 180
Circle -7500403 true true 60 120 60
Circle -955883 true false 103 88 95

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="blind (red) willems (blue) selfish shot sens" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print sensitivity
print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="blind (red) willems (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print sensitivity
print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="blind (red) kuyt (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print sensitivity
print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="blind (red) huntelaar (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print sensitivity
print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kuyt  (red) huntelaar (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="willems  (red) huntelaar (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="willems  (red) kuyt (blue) selfish shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-selfish sensitivity</setup>
    <go>go

print shoot-distance-selfish</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="12.5"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="willems  (red) kuyt (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="willems (red) blind (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="willems (red) huntelaar (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kuyt (red) huntelaar (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="blind (red) huntelaar (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="blind (red) kuyt (blue) teamplayer shot sens" repetitions="50" runMetricsEveryStep="false">
    <setup>setup
set shoot-distance-teamplayer sensitivity</setup>
    <go>go

print shoot-distance-teamplayer</go>
    <exitCondition>score-red = 10 or score-blue = 10</exitCondition>
    <metric>score-red</metric>
    <metric>score-blue</metric>
    <enumeratedValueSet variable="defense-team-red">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-red">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-team-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defense-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-team-blue">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attack-selfish-blue">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensitivity">
      <value value="2.5"/>
      <value value="5"/>
      <value value="7.5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
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
