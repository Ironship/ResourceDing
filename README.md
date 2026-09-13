# ResourceDing

<img width="1024" height="1024" alt="icon_resourceding" src="https://github.com/user-attachments/assets/89aeb4d8-0cd7-4983-b622-79d4f91efd47" />


A small World of Warcraft addon that plays one sound when your class finisher resource reaches maximum.

It is useful when you are watching the fight instead of the resource bar: build five Combo Points, hear the cue, use a finisher. It only fires on the transition to full, so it does not repeat until you spend some resource and fill it again.

## Supported resources

- Rogue and Feral Druid — Combo Points
- Monk — Chi *(Retail)*
- Paladin — Holy Power *(Retail)*
- Warlock — Soul Shards *(Retail)*
- Arcane Mage — Arcane Charges *(Retail)*
- Evoker — Essence *(Retail)*

Unsupported specs remain silent automatically.

On Classic Era only combo points exist. Chi, Holy Power, Arcane Charges and the
Soul Shard bar all arrived with later expansions, and Monk and Evoker are not in
that game at all, so `Core.lua` drops every entry but Rogue and Druid when it
loads there — the settings never offer a resource the client cannot have.

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

Retail 12.1 (`Interface 120100`) and Classic Era 1.15.9 (`11509`) — one manifest
each. All rights reserved.
