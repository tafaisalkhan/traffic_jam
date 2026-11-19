# City Rescue Puzzle

An original Godot 4 traffic-escape puzzle for Android. No reference-game code, artwork, layouts, or UI assets are reused.

## Current milestone: Phases 0–10 complete

The runnable main scene opens a branded splash screen with a loading bar, then stays on the main menu until Play is pressed. Play starts the timed ambulance rescue stages. The project uses the Mobile renderer and a 720×1280 portrait viewport.

Phase 1 adds a modular world kit. Roads are generated as reusable tiles with connectivity metadata, road markings, curbs, entry/exit gates, blocked sections, one-way markings, bridge rails, and tunnel portals. The preview board displays the complete kit alongside original trees, shrubs, flower beds, lamps, cones, barriers, signs, benches, buildings, and a fountain.

Phase 2 adds a procedural vehicle catalog: compact sedan, hatchback, SUV, taxi, sports car, minivan, delivery van, school bus, delivery truck, ambulance, police car, and fire truck. Every vehicle has a distinct footprint and roof silhouette, wheels, lights, mirrors, windows, type-specific details, and a roof-mounted direction arrow designed for the portrait camera. The showcase scene places all twelve models on the board for visual review.

Phase 3 is a playable vertical slice. Level data defines a road graph and intended routes; tap or correctly-directed swipe input validates complete road connectivity and logical occupancy before a move. Routes are reserved during animation, preventing overlapping commands. Vehicles animate through turns and exits, while restart, undo, move counting, blocked feedback, and level completion are functional. `tests/test_puzzle_logic.gd` validates connectivity, blocking, route reservation, and the intended solution order.

Phase 4 adds the mobile interface flow: main menu, level select, settings, gameplay HUD, pause overlay, restart/undo controls, hint placeholder, and level-complete reward panel. UI controls are programmatic, responsive to the portrait viewport, and share the same original navy/blue/gold visual system. `tests/test_ui_flow.gd` constructs each screen to validate the UI flow without manual interaction.

Phase 5 adds ten hand-authored tutorial puzzles, each with its own vehicle arrangement, move target, star thresholds, and tutorial instruction. A lightweight progression manager awards stars and coins and unlocks the next level. The level solver validates all ten configurations before delivery, preventing unsolvable tutorial data from entering the game.

Phase 6 completes the production asset pass: the twelve original vehicle silhouettes and the full modular environment catalog are active in gameplay, with lightweight selection rings, blocked pulses, and vehicle-exit sparkles. Effects use simple low-poly meshes and short tweens rather than costly full-screen or physics effects, keeping the mobile performance target in scope.

Phase 7 adds versioned local progress data in `user://traffic_mash_save.json`. The save layer validates and repairs malformed values, preserves stars, best moves, coins, settings, power-up inventory, and the selected cosmetic, and falls back safely to defaults if storage is unavailable. The UI now provides settings toggles and a vehicle collection where players can choose original Classic, Ocean, or Sunset tints.

Phase 8 adds a deterministic procedural level pipeline. A seed produces a connected road network, exit-aware routes, themed vehicle selection, reproducible metadata, and a difficulty estimate. The generator accepts a level only after the solver verifies a complete vehicle escape sequence. `tests/test_level_generator.gd` validates 90 seed/difficulty combinations.

Phase 9 expands the campaign catalog to 300 levels. Levels 1–10 remain hand-authored tutorials; levels 11–300 use reproducible solver-gated seeds, theme metadata, and eight staged difficulty bands. The level selector now pages through the campaign. `tests/test_campaign.gd` performs a complete 300-level solver audit.

Phase 10 adds delivery configuration: portrait Android export preset, Mobile renderer, ARMv7/ARM64 targets, immersive mode, configurable 30 FPS Battery and 60 FPS Mobile profiles, and runtime FPS sampling. `AudioManager` generates an original quiet music loop and short sound effects at runtime. The Music and SFX settings stop their respective players immediately.

## Ads and Remove Ads

Settings includes Remove Ads at $4.99, Restore Purchase, Music and SFX switches, and an optional rewarded ad for 50 coins. An Android AdMob banner appears on the main menu and Settings, and is hidden during gameplay. The game requests an interstitial only when the player chooses Next Level after every third completed level. Coins are granted only after the native earned-reward callback. A verified `remove_ads` purchase disables forced banner and interstitial ads while leaving optional rewarded ads available.

The Android AdMob v4.2 native libraries from Poing Studios are bundled under `addons/traffic_mash_ads/android/libs` (MIT license). The export plugin packages them with Google Mobile Ads SDK `24.9.0`. The project uses Google's **test** app and ad unit IDs for banner, interstitial, and rewarded ads. Replace these in `addons/traffic_mash_ads/export_plugin.gd` and `scripts/systems/monetization_manager.gd` before release. Android export requires the Godot 4.7.2 Android build template, Gradle build, and an Android SDK with network access to resolve the Google SDK dependency.

Every playable level now shows its time limit before the countdown starts. Rescue stages keep their authored 50–95 second limits; campaign puzzles receive a limit based on their vehicle count. The timer pauses while the player chooses extra time. A 25-coin purchase adds 15 seconds. If coins are short, a completed rewarded ad grants 50 coins and adds 15 seconds to the current level. Closing the ad without earning the reward grants neither. Expiry opens the same recovery choices plus Retry.

**The $4.99 checkout still requires a Google Play Billing plugin and Play Console product.** Until configured, the purchase control reports that checkout is unavailable and cannot grant ad removal. Set the `remove_ads` one-time product price to USD 4.99 in Play Console, then use the store's localized price in the UI for public release.

The future billing singleton is `TrafficMashMonetization`. It should provide `purchase_remove_ads("remove_ads")` and `restore_purchases()`, plus `purchase_verified(product_id)` and `purchase_failed(message)` signals. It must verify and acknowledge the non-consumable Google Play purchase before emitting `purchase_verified`.

The startup scene is `scenes/gameplay/ambulance_rescue_level.tscn`.

## Setup

1. Open `project.godot` in Godot 4.3 or newer (verified with Godot 4.7.2).
2. Run the project. The splash screen advances to the main menu; press Play to load the rescue stage.
3. Use the editor's Mobile renderer for normal development; Compatibility will be tested as a dedicated lower-end profile later.

## Foundation architecture

- `scripts/core/design_tokens.gd`: shared visual colors, UI spacing, and shape rules.
- `scripts/core/app_boot.gd`: splash transition.
- `scripts/core/art_direction_board.gd`: procedural visual QA board for environment and camera direction.
- `scripts/world/road_tile_factory.gd`: modular road pieces and connection metadata.
- `scripts/world/environment_factory.gd`: non-blocking miniature-city decorations.
- `scripts/world/world_materials.gd`: cached shared world materials.
- `scripts/gameplay/vehicle_factory.gd`: reusable twelve-type vehicle meshes, dimensions, and roof arrows.
- `scripts/gameplay/path_validator.gd`: whole-route road connectivity validation.
- `scripts/gameplay/occupancy_manager.gd`: deterministic occupancy and movement reservations.
- `scripts/core/game.gd`: playable puzzle board, input, UI, restart, and undo.
- `scripts/ui/ui_manager.gd`: menu, HUD, pause, settings, selection, and completion UI flow.
- `scripts/core/level_manager.gd`: tutorial progression, stars, coins, and unlock state.
- `scripts/generation/level_solver.gd`: deterministic solvability verification for structured levels.
- `scripts/world/effects_manager.gd`: lightweight exit and blocked-action visual effects.
- `scripts/systems/save_manager.gd`: versioned, validated local save data.
- `scripts/generation/level_generator.gd`: seeded, solver-gated generated level data.
- `scripts/generation/campaign_catalog.gd`: authored-plus-generated 300-level catalog.
- `scripts/systems/quality_manager.gd`: 30/60 FPS Android quality profiles.
- `scripts/systems/audio_manager.gd`: generated music and sound effects with independent controls.
- `scripts/ui/ui_manager.gd`: splash, loading bar, main menu, settings, and gameplay interface.
- `assets/ui/traffic_mash_icon.png`: generated game icon used by the splash, menu, and Godot project.

## Android export

Install Godot's Android SDK/JDK export dependencies, then use **Project → Export → Android**. Export presets and device performance tuning arrive in the Android delivery phase.
