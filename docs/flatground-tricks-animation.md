# Flatground tricks — animation reference

Source: flatground tricks reference video (100 tricks montage with on-screen names).

## Rules from the video
- Standard game-of-skate flatground only (no no-complys, grabs, boneless).
- Real-time, static camera; each trick numbered + named on screen.
- Airborne phase typically ~0.4–0.6s; crouch/wind-up is longer than the flip.

## Priority clip set for v1 (ship these first)
1. ollie
2. fakie ollie
3. nollie
4. switch ollie
5. frontside 180 / backside 180
6. kickflip / heelflip (regular)
7. backside shuv / frontside shuv
8. 360 flip (tre)
9. land_recover + sketchy_land (under-rotate / pivot)

## Full ordered list (1–100)
### Ollies & 180s
1. ollie
2. fakie ollie
3. nollie
4. switch ollie
5. frontside 180
6. backside 180
7. fakie backside 180
8. fakie frontside 180
9. nollie frontside 180
10. nollie backside 180
11. switch backside 180
12. switch frontside 180

### Basic flips
13. kickflip
14. fakie kickflip
15. switch kickflip
16. nollie kickflip
17. heelflip
18. fakie heelflip
19. switch heelflip
20. nollie heelflip

### 180 flips
21. frontside flip
22. backside flip
23. fakie backside flip
24. fakie backside heelflip
25. fakie frontside flip
26. backside heelflip
27. frontside heelflip
28. fakie frontside heelflip
29. nollie backside flip
30. switch frontside flip
31. nollie frontside flip
32. nollie frontside heelflip
33. switch backside heelflip
34. switch backside flip
35. nollie backside heelflip
36. switch frontside heelflip

### 360 flips & varials
37. 360 flip
38. switch 360 flip
39. fakie 360 flip
40. nollie 360 flip
41. varial flip
42. fakie varial flip
43. switch varial flip
44. nollie varial flip

### Shuvits
45. backside shuv
46. fakie backside shuv
47. nollie frontside shuv
48. switch frontside shuv
49. frontside shuv
50. fakie frontside shuv
51. nollie backside shuv
52. switch backside shuv

### Bigspins
53. backside bigspin flip
54. fakie bigspin flip
55. nollie frontside bigspin flip
56. switch backside bigspin flip
57. backside bigspin
58. fakie backside bigspin
59. nollie frontside bigspin
60. switch backside bigspin
61. frontside bigspin
62. fakie frontside bigspin
63. nollie backside bigspin
64. switch frontside bigspin

### Advanced flips
65. varial heelflip
66. fakie varial heelflip
67. nollie varial heelflip
68. switch varial heelflip
69. inward heelflip
70. fakie inward heelflip
71. nollie inward heelflip
72. switch inward heelflip
73. hardflip
74. nollie hardflip
75. fakie hardflip
76. switch hardflip

### 360 shuvs & 360 spins
77. 360 backside shuv
78. fakie 360 backside shuv
79. nollie 360 frontside shuv
80. switch 360 backside shuv
81. 360 frontside shuv
82. fakie 360 frontside shuv
83. nollie 360 backside shuv
84. switch 360 frontside shuv
85. frontside 360
86. backside 360
87. fakie frontside 360
88. fakie backside 360
89. switch frontside 360
90. nollie backside 360
91. nollie frontside 360
92. switch backside 360

### Elite
93. frontside bigspin heelflip
94. fakie bigspin heelflip
95. nollie bigspin heelflip
96. switch bigspin heelflip
97. lazer flip
98. fakie lazer flip
99. nollie lazer flip
100. switch lazer flip

## Godot animation architecture (recommended)
- Skateboard = separate skeletal entity; feet use IK to board, do not bake board into character root.
- Phase clips: Crouch_Start_Loop → Pop_Trigger → Airborne_Board_Flip → Catch_Impact → Land_Recover
- Animate ~25 base tricks in Regular stance; mirror X for Switch; reuse for Fakie/Nollie via root direction / board attachment.
- Soft secondary motion (realistic but stylish) is post-skinned-rig; damp on Catch_Impact / Land_Recover.
