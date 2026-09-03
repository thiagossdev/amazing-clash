# Sources

[← Index](README.md)

## Fetched and cited directly

- [Eslabong, official site](https://eslabong.com/): the developer's own
  pitch, feature list, and "About the Game" copy (the source of the
  human owner's own game brief, word for word in places).
- [Eslabong, Steam store page](https://store.steampowered.com/app/4560660/Eslabong/):
  release date, tags, review score (95% positive of 652, Early Access),
  the developer's own Early Access FAQ (current feature list, planned
  scope, why Early Access, timeline), full "About This Game" text,
  system requirements.
- [Eslabong - New class and demo patch, Steam devlog](https://store.steampowered.com/news/app/4560660/view/668369251018477625):
  developer-authored (Franz, solo developer). Introduces the Ability
  Evolution/Specialization system (first choice at level 20, ~400
  abilities each with two specialization branches at time of writing),
  confirms abilities are randomized per champion instance, BR-PT
  localization added.
- [Eslabong - Async Multiplayer, Steam devlog](https://store.steampowered.com/news/app/4560660/view/668369251018480580):
  developer-authored. Defines the Challenge Tower precisely: submit
  your roster, fight other players' submitted teams **asynchronously**
  via Steam Workshop/Steam Servers data transfer, exhibition-only (no
  rewards, XP, or season-stat effect at time of writing). This is the
  single most load-bearing citation for
  [05. Synthesis](05-synthesis-amazingclash.md): it is the primary
  source establishing that Eslabong has no live PvP.
- [Eslabong - Demo Update - Two new classes, Steam devlog](https://store.steampowered.com/news/app/4560660/view/678504885369438943):
  developer-authored. Hunter (companion/summon class) and Halberdier
  (tanky melee controller) kit descriptions; confirms AI is tuned to
  avoid friendly fire from area abilities like Grenades, i.e.
  friendly-fire-capable area damage already exists in Eslabong's design
  space even though the game has no live PvP to make a toggle
  meaningful yet.
- [Eslabong - Demo update: Roster tab, 40+ new abilities and more!, Steam devlog](https://store.steampowered.com/news/app/4560660/view/706651296750372766):
  developer-authored. Confirms the pace of content iteration (40+
  abilities in one patch) and third-party coverage (SplatterCat, an
  established indie-game YouTuber, covered the demo).
- [Eslabong Strategy Guide, Eslabong Wiki](https://eslabong-game.wiki/en/guide/eslabong-strategy-guide):
  community-authored guide, explicit about its own evidentiary basis
  ("based on observed gameplay coverage and community reports").
  Canonical-tier reference (same tier this project's sibling research
  gave Fandom wikis) for roster roles, formation/tactics, stat/skill
  priorities, and club facilities (Barracks, Academy, Medical Bay, Time
  Chamber, Training Grounds).
- [Eslabong Mercenary Market Guide, Eslabong Wiki](https://eslabong-game.wiki/en/management/eslabong-mercenary-market):
  same tier and caveat as above. Market/recruit decision framework,
  gear/relics, Form/Stamina system, rival-club trades.

## Precedent: Battlerite (Stunlock Studios)

- [Game Design Deep Dive: Turning Bloodline Champions into Battlerite, Game Developer / Gamasutra](https://www.gamedeveloper.com/business/game-design-deep-dive-turning-i-bloodline-champions-i-into-i-battlerite-i-):
  primary source, written by Peter Ilves, Battlerite's Game Director and
  Stunlock Studios co-founder. Design-discipline lessons, netcode and
  server-infrastructure investment, the Bloodline Champions
  free-to-play champion-gating failure.
- [Battlerite Review, MMOs.com](https://mmos.com/review/battlerite):
  critical-analysis source, directly fetched. Primary citation for the
  in-match Rites/card build-customization loop (one of three cards
  picked per round), the melee/ranged/support archetype trinity, the
  skill-only "no items" design stance, and the always-ranked MMR system.

## Precedent: Path of Exile 2's own design self-critique

Cross-referenced from the sibling folder
[docs/research/poe2-build-depth-inspiration/sources.md](../poe2-build-depth-inspiration/sources.md);
not re-listed here to avoid duplication.

## Notes on source quality and fetch limitations

Eslabong is a small, currently-shipping Early Access indie game (single
developer, "Franz," studio name "shirowita"); it has no press coverage
at the depth a AAA or established indie title would, and no developer
interview beyond the Steam devlogs was located. The Eslabong Wiki
(`eslabong-game.wiki`) is an unofficial, SEO-oriented community site;
its guides are treated the same way this project's sibling research
treated Fandom wikis, as a canonical-tier mechanical reference, one
notch below a developer's own words, with the wiki's own disclaimer
("individual values, menus, and mode rules may change between builds")
carried forward here rather than smoothed over. The `redbull.com`
Battlerite interview (Martin Lövgren) failed to fetch on every tier
(local extractor and `r.jina.ai` both returned empty or blocked
content) and is not used; nothing in this folder rests on it. All other
fetches succeeded, most on the local extractor tier; Steam's own news
pages required the `r.jina.ai` proxy tier since Steam's news view is
JS-rendered and the local extractor returns only navigation chrome.
