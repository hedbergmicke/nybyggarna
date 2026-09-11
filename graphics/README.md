# Graphics pass

Real-time Godot Forward+ rendering; no generated background image.

- 4x MSAA, 4096 directional shadow atlas and soft sun shadows.
- ACES, ambient occlusion, screen-space indirect light/reflections, restrained glow and volumetric fog.
- Deterministic cached tree meshes and instanced wind-animated ground cover, streamed in nearby chunks.
- Procedural forest-floor, foliage, timber and animated water shaders.
- Detailed cottage siding, roof strips, window frames, dock nails and character accessories.

Final rendered previews: `harbor-world.png`, `meadow-world.png` (3D viewport), `harbor-ultra.png`, `meadow-ultra.png` (full UI).

Validation: gameplay regression test in `test_world.gd` passed. D3D12 render tested on NVIDIA RTX 2060. A short static meadow test averaged approximately 136 FPS over 60 frames with GPU readback at 1196 x 501 viewport resolution. This is an isolated smoke measurement, not a guarantee of traversal performance or higher-resolution performance.

Gameplay, discovery and purchase rules remain unchanged. Further visual gains depend chiefly on authored models, textures and animations; this pass does not represent Godot's absolute graphics limit.
