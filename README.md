vault-bridge
===

macos native swiftui app for traversing obsidian vault via internal links. brutalist, dense interface.

goal
---
click through documents and their internal links in obsidian knowledge base.

status
---
exploration phase. initial vault scan and note display working.

stack
---
- swiftui
- macos 14.0+
- xcode 15+

run locally
---
open vault-bridge.xcodeproj
select VaultBridge scheme
cmd+r

features
---
- vault path configuration
- markdown file scanning
- note list view
- note detail view
- search filter
- brutalist design (mono font, high contrast, dense)

to do
---
- implement internal link detection ([[links]])
- implement bidirectional link visualization
- add link traversal navigation
- improve density (smaller fonts, tighter spacing)
- keyboard shortcuts
- menubar integration

vault path
---
configured in app: /Users/enw/Documents/Areas/vault

license
---
unlicense
