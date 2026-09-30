# Arcade Vehicle Framework (Godot 4+)

A rock-solid, name-independent 4-wheel arcade vehicle physics system built using RayCast3D suspension. Designed to give a responsive, heavy, satisfying driving feel right out of the box—perfect for open-world games, arcade racers, or city prototypes!

## Features

- 🏎️ **Name Independent:** Fully modular. Assign your RayCasts and Wheel Meshes directly via the Inspector panel. No hardcoded node path locks!
- ⌨️ **Input Filter Smoothing:** Erases instant keyboard wheel snapping. Transitions steering angles smoothly over time for a polished gameplay look.
- 🔊 **Dynamic RPM Audio Glide:** Features an engine rev audio modulator that scales pitch based on forward speed with natural weight interpolation.
- ⚖️ **Anti-Roll Stabilizers:** Built-in anti-roll physics prevent the vehicle from flipping over wildly during aggressive, high-speed drifting maneuvers.
- 🎮 **Assignable Control Mapping:** Customize your actions (Forward, Reverse, Steer) directly inside the Inspector slots to easily support WASD, Arrow keys, or multi-player controls using the same script.

---

## Installation & Setup

1. Copy the `addons/arcade_vehicle` folder into your Godot 4 project directory.
2. Go to **Project -> Project Settings -> Plugins** and check the **Enable** box next to **Arcade Vehicle Framework**.
3. Create or open your vehicle scene.
4. Add a `RigidBody3D` node to your scene.
5. In the Inspector, change the `Script` slot at the bottom to use `universal_arcade_vehicle.gd` (or simply add a new **`ArcadeVehicle3D`** node via the Add Node window).
6. Set the `Center of Mass Mode` to **Auto** in the RigidBody3D properties.

---

## Assigning Your Nodes

With your vehicle node selected, look at the **Universal Vehicle Assigning** category in your Inspector panel and drag your nodes directly into their corresponding slots:

| Slot Field | Description |
| :--- | :--- |
| **Front Left / Right Ray** | The `RayCast3D` nodes pointing downwards representing your front steering suspension track. |
| **Rear Left / Right Ray** | The `RayCast3D` nodes pointing downwards representing your rear drive track. |
| **Wheel Meshes** | The actual `MeshInstance3D` visual wheel models. These will rotate and steer dynamically based on physics calculations. |
| **Engine Sound** | An `AudioStreamPlayer3D` node loaded with an engine loop sound effect. |

---

## Customizing Controls

Under the **Custom Control Layout** category in the Inspector, type the string names of your actions exactly as they appear in your **Project Settings -> Input Map**:

- **Forward Action:** (Default: `ui_up`)
- **Backward Action:** (Default: `ui_down`)
- **Left Action:** (Default: `ui_left`)
- **Right Action:** (Default: `ui_right`)

## License

This project is open-source and free to use under the MIT License. Feel free to use it in your personal or commercial games!
