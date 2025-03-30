# busy taxi todo

- [x] render road intersections
- [x] render road turns
- [x] large map
- [x] slow down on non-roads
- [x] pedestrians
- [x] customers
- [x] locations
- [x] customer drop off
- [x] arrow to show where the next target is
- [x] score
- [x] time limit
- [x] game over screen
- [x] high score
- [x] adapt to new game engine
- [x] add friction to physics simulation
- [x] have pedestrians move out of the way
- [x] make pedestrians not walk on road
- [x] other cars
  - [x] cars being able to turn with the road and drive around the block
  - [x] cars brake when there is a car blocking in front of the car
- [ ] gameplay fun
  - [x] levels
    - [x] number of customers to deliver
    - [x] go to the next level when all customers are delivered
    - [x] level transition screen
    - [x] game completed screen
    - [x] tweak difficulty and number of levels
  - [ ] polish
    - [x] sound when picking customer
    - [ ] sound when completing level
    - [ ] sound when completing game
    - [ ] sound when crashing
    - [x] music track

## fixes that I will do

- [x] fix render tearing

## fixes

- [ ] fix animation playing too fast after it has been paused for a while
- [ ] dynamic car collision box depending on car orientation
- [ ] three way intersections can still get to a standstill if the cars come in a certain way
  - [ ] add a precedence rectangle to check for a free left turn
  - [ ] disable front check when turning right from the center
- [ ] the four way intersection can still get to a standstill
  - [ ] traffic lights?
- [ ] car right animation does not work sometimes
  - [ ] check the approx equal function in direction
