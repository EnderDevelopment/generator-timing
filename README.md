# Roblox Generator Repair Script

This Roblox script implements a generator repair system with a timing challenge, colored timing zones, server validated progress, ProximityPrompt interaction, keyboard and button input, and failure penalties for Roblox survival and multiplayer games.

## Install

1. Open your Roblox Studio place.
2. Create a normal `Script` in `ServerScriptService` and copy in `GeneratorRepairServer.server.lua`.
3. Create a `LocalScript` in `StarterPlayer > StarterPlayerScripts` and copy in `GeneratorRepairClient.client.lua`.
4. Add generator Models or BaseParts to `Workspace > Generators`, or tag them with the `Generator` CollectionService tag.
5. If a generator is a Model, give it a `PrimaryPart` or include at least one BasePart inside it.
6. Press Play to test the system.

The server script automatically creates `ReplicatedStorage > GeneratorRepairRemote`. You do not need to create this RemoteEvent manually.

## Use

1. Walk near a generator.
2. Activate its RepairPrompt.
3. Watch the marker move across the timing bar.
4. Press Space or click the on-screen HIT button when the marker reaches a colored zone.
5. Perfect timing adds 15% progress.
6. Good timing adds 10% progress.
7. Bad timing adds 6% progress.
8. Worst timing cancels the attempt and removes 15% progress, without reducing progress below 0%.
9. Repeat successful attempts until the generator reaches 100%.
10. A generator at 100% can no longer be repaired.

Only one player can repair a generator at a time. The server checks the player’s distance, attempt ID, timing, and attempt duration before changing progress.

You can adjust `FAILURE_PENALTY`, `BAR_PERIOD`, `ATTEMPT_TIMEOUT`, and `REPAIR_DISTANCE` near the top of `GeneratorRepairServer.server.lua`. If you change the timing zones, update both the client zone table and the server classification ranges so they stay synchronized.

---

More Roblox script projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/19684629-aa75-4d13-b95d-bbc6e23675d2?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=19684629-aa75-4d13-b95d-bbc6e23675d2
