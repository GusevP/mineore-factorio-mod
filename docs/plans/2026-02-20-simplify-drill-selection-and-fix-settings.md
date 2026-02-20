# Simplify Drill Selection and Fix Settings

## Overview
Simplify drill selection logic to exclude only burner drills, fix productivity mode default not applying correctly, fix underground belt visual appearance, and prepare repository for GitHub publication.

## Context
- Files involved:
  - scripts/resource_scanner.lua - drill filtering logic
  - scripts/gui.lua - default mode selection
  - scripts/belt_placer.lua - underground belt placement
  - info.json - metadata for mod portal
  - .gitignore - git exclusions
  - CLAUDE.md - will be removed from repository
  - docs/ - will be removed from repository
- Related patterns: Technology-Based Entity Filtering, Burner Drill Exclusion Pattern, Underground Belt Direction Pattern
- Dependencies: None

## Development Approach
- Testing approach: Regular (code first, then manual tests)
- Complete each task fully before moving to the next
- Run manual acceptance tests in Factorio after code changes
- **CRITICAL: every task MUST include new/updated test documentation**
- **CRITICAL: validate changes in-game before moving to next task**

## Implementation Steps

### Task 1: Simplify drill selection logic

**Files:**
- Modify: `scripts/resource_scanner.lua`

- [x] Remove complex category-based drill filtering logic from find_compatible_drills()
- [x] Replace with simple filter: include all mining drills except burner-mining-drill
- [x] Remove the selected_categories parameter from find_compatible_drills()
- [x] Update scan() function to call find_compatible_drills() without category parameter
- [x] Remove category compatibility checks (lines 67-75)
- [x] Update documentation in CLAUDE.md Burner Drill Exclusion Pattern section
- [x] Create/update docs/tests/drill-selection-simplified-tests.md with test cases
- [x] Test in-game: verify all electric drills appear regardless of ore type

### Task 2: Fix productivity mode default

**Files:**
- Modify: `scripts/gui.lua`

- [ ] Add debug logging before line 49 to check what mod_settings returns
- [ ] Verify the setting key name matches exactly: "mineore-default-mode"
- [ ] Check if gui_draft is overriding the default mode on first use
- [ ] Test logic flow: ensure settings.placement_mode gets set when nil
- [ ] Add guard to prevent gui_draft.placement_mode from being nil on first open
- [ ] Update docs/tests/productive-mode-default-tests.md with fix validation
- [ ] Test in-game: open GUI on fresh player, verify productivity is selected

### Task 3: Fix underground belt visual appearance

**Files:**
- Modify: `scripts/belt_placer.lua`

- [ ] Research: Review Factorio API docs for proper underground belt direction usage
- [ ] Identify root cause: why both UBO and UBI appear as input visually
- [ ] Fix direction assignment: ensure UBO (output/exit) and UBI (input/entrance) display correctly
- [ ] Update belt_to_ground_type parameter usage if needed
- [ ] Test different belt flow directions (north, south, east, west)
- [ ] Update CLAUDE.md Underground Belt Direction Pattern with corrected understanding
- [ ] Update docs/tests/underground-belt-direction-tests.md with visual validation steps
- [ ] Test in-game: verify UBO and UBI have distinct visual appearances

### Task 4: Prepare repository for GitHub publication

**Files:**
- Modify: `.gitignore`
- Modify: `info.json`
- Remove: `CLAUDE.md` (from repository, keep local)
- Remove: `docs/` (entire directory from repository)

- [ ] Add CLAUDE.md to .gitignore
- [ ] Add docs/ to .gitignore
- [ ] Remove CLAUDE.md from git tracking: git rm --cached CLAUDE.md
- [ ] Remove docs/ from git tracking: git rm -r --cached docs/
- [ ] Update info.json: add "homepage": "https://github.com/CrazyFeSS/factorio-miner-mod"
- [ ] Update info.json: verify other fields are publication-ready
- [ ] Create README.md if it doesn't exist with basic mod description
- [ ] Verify .gitignore has all necessary exclusions (*.zip, mineore_*/, etc.)
- [ ] Test: run git status to ensure docs/ and CLAUDE.md are not tracked
- [ ] Manual verification: check that local CLAUDE.md and docs/ still exist

### Task 5: Verify acceptance criteria

- [ ] Manual test: drill selection shows all drills except burner
- [ ] Manual test: fresh player opens GUI and sees productivity mode selected
- [ ] Manual test: underground belts show visually distinct UBO (exit) and UBI (entrance)
- [ ] Manual test: git status shows docs/ and CLAUDE.md as untracked
- [ ] Verify info.json has GitHub URL
- [ ] Run package.sh to ensure mod packages correctly
- [ ] Review changes don't break existing functionality

### Task 6: Update documentation

- [ ] Update CLAUDE.md with corrected patterns (if not being removed from repo)
- [ ] Verify test documentation is complete for all changes
- [ ] Move this plan to docs/plans/completed/ (keep local, won't be in repo)
