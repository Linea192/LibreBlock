# Filter list attribution

LibreBlock ships its own conservative built-in rules (MIT, see LICENSE) and
lets users download community-maintained filter lists at runtime. Those lists
are fetched directly from their maintainers' official URLs and cached on the
user's device; they are **not** redistributed inside this repository or the
app binary.

## Downloaded on demand

| List | URL | License |
| --- | --- | --- |
| EasyList | https://easylist.to/easylist/easylist.txt | GPLv3 (rights granted via https://easylist.to/) |
| EasyPrivacy | https://easylist.to/easylist/easyprivacy.txt | GPLv3 |
| Fanboy's Annoyances | https://secure.fanboy.co.nz/fanboy-annoyance.txt | CC-BY-3.0 / MIT variant |
| Adblock Warning Removal List | https://easylist-downloads.adblockplus.org/antiadblockfilters.txt | GPLv3 |
| Phishing Army blocklist | https://phishing.army/download/phishing_army_blocklist_extended.txt | MIT |
| AdAway hosts | https://adaway.org/hosts.txt | CC-BY-3.0 |
| NoCoin adblock list | https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/nocoin.txt | MIT |
| EasyList Germany | https://easylist.to/easylistgermany/easylistgermany.txt | GPLv3 |
| Liste FR | https://easylist-downloads.adblockplus.org/liste_fr.txt | CC-BY-3.0 |
| EasyList China / Italy / Spanish / Dutch / Portuguese | easylist-downloads.adblockplus.org | GPLv3 / CC-BY |
| RU AdList | https://easylist-downloads.adblockplus.org/advblock.txt | CC-BY-3.0 (after 2023) |
| KoreanList, IndianList, Liste AR | easylist-downloads.adblockplus.org | per-list (GPLv3 / CC-BY) |
| EasyList Hebrew | https://github.com/easylist/EasyListHebrew | MIT |
| EasyList Czech and Slovak | https://github.com/tomasko126/easylistczechandslovak | MIT |
| Dandelion Sprout's Nordic Filters | https://github.com/DandelionSprout/adfilt | CC-BY-4.0 / multiple |
| ABPindo | https://github.com/heradhis/indonesianadblockrules | CC-BY-3.0 |
| ABPVN | https://abpvn.com/filter/abpvn-IPl6HE.txt | GPLv3 |
| Latvian List | https://github.com/Latvian-List/adblock-latvian | CC-BY-4.0 |
| EasyList Lithuania | https://github.com/EasyList-Lithuania/easylist_lithuania | CC-BY-4.0 |
| ROList | https://www.zoso.ro/pages/rolist.txt | CC-BY-3.0 |

Licenses summarized from each project's official page at the time of writing;
check the linked sites for the authoritative text. If you redistribute
LibreBlock with any of these lists bundled, you must comply with their
respective licenses — the default build only downloads them, which each
license permits.

## Bundled in the app (original work)

- `Resources/filters/mobile-ads.txt`
- `Resources/filters/popups.txt`
- `Resources/filters/mobile-trackers.txt`
- `Resources/filters/social-widgets.txt`
- `Resources/filters/social-embeds.txt`
- `Resources/filters/nocoin.txt`
- `Resources/filters/cookies.txt`
- `Resources/filters/webfonts.txt`

All authored for this project (MIT).

## This project

LibreBlock is an independent, clean-room implementation. It is not affiliated
with, endorsed by, or derived from any other ad blocker's source code or
binary. Feature parity with commercial blockers is achieved through Safari's
public content blocker APIs and public filter subscriptions.
