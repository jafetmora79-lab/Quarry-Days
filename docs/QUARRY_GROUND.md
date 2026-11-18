# Quarry ground: one system

- **One ground.** The heightfield terrain (`scripts/terrain/quarry_terrain.gd`, 0.5 m vertices) is the only ground. The old 22 x 10 square soil field is gone as a thing of its own:
  `scripts/soil.gd` is now a *view* of loose topsoil lying on the terrain. A cell's units are read from the ground (`loose topsoil over its 16 vertices / 0.3 m3`), so contracts
  (`soil_removed`, `soil_hauled`), saves (`soil_units`, plus the terrain snapshot), machines, the crew and the blade keep working with the same numbers, and the soil
  slumps, heaps, walks and collides like any other ground. An older save (cells only) is laid onto the ground at load.
- **Geology.** Under the loose layers (thickness varies from place to place) lies limestone bedrock holding ore BODIES: a broad coal seam, iron pockets, a narrow tilted copper vein, rare deep gold
  pockets (`QuarryGeology.BODIES`). A seeded hash decides where, so it is the same every game. The formations of the progression (the contract zones) still decide where their resources are.
- **Digging rules.** Free inside the survey stakes. A hand tool cannot take a vertex more than `MAX_DROP` (0.55 m) under its highest neighbour, so no narrow vertical shaft: the hole has to be widened
  as it goes down. The quarry is dug in benches: `LiveTerrain.bench_floor` is the lowest the ground may go at a place (level 1 floor everywhere; each reached level lowers the floor inside its own
  nested pit rectangle, whose haul-road strip is the ramp). When digging cannot continue the strike returns `limit = "step" | "floor"` and the player is told what to do.
- **Bag and buckets** are untouched: the bag (`state.inventory`) and the placed/carried buckets are separate, as before.
