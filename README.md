# AutoTrack

A hunter addon for **Improved Tracking**, the talent that adds damage against whatever creature type you're tracking. Instead of keeping six tracking spells on your bars, you get one key that always casts the right one for your target.

## How it works

- Target an attackable mob out of combat and AutoTrack loads the matching tracking spell (Beasts, Humanoids, Undead, Demons, Elementals, Giants, Dragonkin) onto its button.
- The button only appears when your tracking is wrong for the target:
  - **Flashing gold:** press your AutoTrack key to switch.
  - **Flashing red:** you're in combat on a different mob type. Hold the modifier shown under the button and press your key.
- It stays hidden when your tracking already matches, or when there's nothing to track (dead, friendly, critters, mechanicals).
- Only tracking spells you've learned are used.

### Modifiers in combat

Blizzard locks addon buttons during combat, so AutoTrack can't change the spell mid-fight. Instead, every learned tracking spell is assigned to a modifier before the pull:

| Modifier + key | Tracking |
|---|---|
| none | whatever matched your target before combat |
| Shift | Humanoids |
| Ctrl | Beasts |
| Alt | Undead |
| Ctrl+Shift | Demons |
| Alt+Shift | Elementals |
| Alt+Ctrl | Dragonkin |
| Alt+Ctrl+Shift | Giants |

Hover the button to see the list. If one of these combinations is already bound to something else on your AutoTrack key, the game uses that other binding instead.

## Setup

1. Install the addon and log in on a hunter.
2. Bind a key: **Esc → Options → Keybindings → AddOns → Cast matching tracking**.
3. Type `/autotrack unlock`, drag the button where you want it, then `/autotrack lock`.

## Commands

| Command | Effect |
|---|---|
| `/autotrack lock` / `unlock` | Lock the button, or unlock it to drag (it stays visible while unlocked) |
| `/autotrack autohide` | Toggle hiding the button when your tracking already matches |
| `/autotrack hide` | Toggle hiding the button when there's nothing to track |
| `/autotrack reset` | Move the button back to the default position |

## Rules

AutoTrack never casts on its own. Every tracking change happens because you pressed a key or clicked, which is what Blizzard's addon API requires.

## License

MIT
