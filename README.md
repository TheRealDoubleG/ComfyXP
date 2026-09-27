# ComfyXP

**Version 0.4 – Beta**  
**Target: World of Warcraft: Forever 1.60.1 / Interface 16001**  
Author: **TheRealDoubleG**  
Discord: **the.real.double.g**

XP progress, rested XP and session pace bar for WoW Forever.

A focused leveling bar with rested XP and simple session analytics.

ComfyXP is developed specifically for **WoW: Forever**. Retail/Modern WoW, Midnight and WoW Classic are not compatibility targets.

## 0.4 Beta

- Added configurable XP information line with individual checkboxes for level, current/required XP, percent, rested XP, session XP, XP/hour, ETA and AFK timer.
- Information can be placed above, inside or below the XP bar.
- Added local idle countdown after 5 seconds plus estimated AFK/logout timing.
- Actual WoW AFK state takes priority once UnitIsAFK reports AFK.

## 0.3 Beta

- Fixed XP-bar dragging so periodic refreshes no longer snap the frame back under the mouse.
- Dragging now stores a stable center-relative position.
- Lock state now disables mouse capture when the XP bar is locked.

## 0.1 Beta
- Added movable XP progress bar with rested XP display.
- Added session XP, XP/hour and ETA.
- AFK time is excluded from rate calculations.

## Design notes
OmniXP Bar's Forever-specific fixes show that inactive time must not distort pace estimates.

The referenced third-party addons were used only to study public feature ideas, long-term bug patterns and architecture lessons. ComfyXP uses original Comfy Suite code and Blizzard UI assets.

## Commands
- /comfyxp
- /cxp
