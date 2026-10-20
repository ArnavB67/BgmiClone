# BGMI 3D - Battle Royale Prototype

**Task ID:** BGMIClone

**Submission for:** Web Enthusiasts' Club (GDG NITK x Iris) Recruitments 2026  

**Playable Build / Deployment:** https://prismop.itch.io/bgmiclone

Please Download The game from itch and try running it rather than playing the web build, Web build will give poor performance and lag.

Video Demonstration : https://drive.google.com/file/d/1L-Q0CeJyzosedOUCPTIjGpblPfnu9skB/view?usp=sharing (High Quality)

A 3D battle royale mini-game built from scratch in **Godot 4.7**, You drop from a plane onto an arena with AI bots, loot weapons and gear, stay inside the shrinking blue zone, and fight to be the last one standing.


* **Plane Drop & Parachuting:** You start in a flying plane and can jump out whenever you want (or get auto-ejected at the end of the flight path), skydive, and pull your parachute manually or let it auto-open near the ground.
* **3D Character Controller:** Created 3D models for Character(Rigged and animated) and guns from scratch in Blender, Full third-person movement with sprinting, crouching, jumping.
* **Weapons & Shooting:** Includes an **AK-47**, **Glock**, and **Melee (Fists)**. Raycast shooting with distance-based damage falloff, camera recoil, muzzle flashes, bullet tracers.
* **FSM Enemy Bots:** AI bots use NavigationAgent3D and a state machine (Patrol, Loot, Chase, Attack). They drop from the plane, spawn with fists, actively search the map for guns before picking fights, shoot at both you and other bots, and drop loot when they die.
* **Shrinking Blue Zone:** The safe zone shrinks from a 160m radius down to 25m over 2 minutes and deals tick damage per second to anyone(player or bot) In zone.
* **Loot, Inventory & HUD:** Map manager spawns 45 random loot drops (guns, rifle/pistol ammo, medkits, and armour).Includes a kill/alive counter, match timer, inventory menu, and a main menu where you can tweak the bot count.


## Controls

| Key / Input | Action |
| :--- | :--- |
| **W, A, S, D** | Move |
| **Shift** | Sprint |
| **Space** | Jump / Open Parachute (while skydiving) |
| **C** | Toggle Crouch |
| **Left Click** | Shoot / Melee Attack |
| **Right Click** | Aim Down Sights (ADS) |
| **1 / 2 / 3** | Equip Primary (AK-47) / Secondary (Glock) / Melee (Fists) |
| **4** | Use Medkit (+50 HP) |
| **R** | Reload |
| **F** | Jump from Plane / Pick Up Nearby Loot |
| **G** | Drop Equipped Gun |
| **Tab** | Toggle Inventory UI |

## How to Run Locally

1. Clone this repository.
2. Open **Godot Engine 4.7** and import the project.godot file.
3. Press **F5** (or hit the Play button) to run the game.
