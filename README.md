# Colonization Redone

A Godot adaptation of the 1994 strategy game. This first repository snapshot contains v020 Art Workbench, the current campaign source, original remake artwork, design notes and the two latest AI test batches. The local version archive remains available for historical playtesting.

## Run locally

1. Install Godot 4.7.2.
2. From PowerShell in this checkout, run:

   ```powershell
   .\Install-LocalAssets.ps1 -Source 'C:\[GPT stuff]\game-versions\v020-art-workbench'
   ```

   The source is the existing local v020 build, which contains the required extracted classic sprites and historical map. This copies those dependencies into ignored paths. The public repository requires these local files before Godot can launch it.
3. Open `game/project.godot` in Godot and press F5.
4. In Campaign, select All art or mix the visual settings individually.

[Production handoff](docs/colonization-production-handoff.md) · [Latest AI audit](docs/game-test-slots/current/summary.md)
