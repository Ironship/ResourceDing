# ResourceDing

A small World of Warcraft addon that plays one sound when your class finisher resource reaches maximum.

It is useful when you are watching the fight instead of the resource bar: build five Combo Points, hear the cue, use a finisher. It only fires on the transition to full, so it does not repeat until you spend some resource and fill it again.

## Supported resources

- Rogue and Feral Druid — Combo Points
- Monk — Chi
- Paladin — Holy Power
- Warlock — Soul Shards
- Arcane Mage — Arcane Charges
- Evoker — Essence

Unsupported specs remain silent automatically.

## Settings

Open **Esc → Options → AddOns → ResourceDing** or type `/rding`.

- Enable/disable
- Combat-only mode (enabled by default)
- Auction House, Ready Check, Quest Complete, Level Up, Bell, Coins, and Raid Warning sounds
- Test sound button

The panel follows the game: it shows the resource your current spec actually
uses and updates when you change spec or form. **Defaults** restores the saved
settings.

`/rding test`, `/rding on`, `/rding off` are also available.

Retail 12.1 (`Interface 120100`). All rights reserved.
