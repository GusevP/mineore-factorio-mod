# Mod Packaging Script and Portal Description

## Overview
Create a shell script to package the mod into a properly formatted .zip file for the Factorio Mod Portal, and write a mod portal description (long description) for publishing.

## Context
- Files involved: info.json (version source), all mod files at repo root
- Factorio mod portal expects zips named modname_version.zip containing a top-level folder modname_version/
- The mod internal name is "mineore", current version is 0.5.0
- There is already a stale mineore/ folder and mineore.zip in the repo (manually created, version 0.4.0 inside) - these should be cleaned up
- .gitignore already ignores mineore/ and mineore.zip

## Development Approach
- Single straightforward task, no tests needed (shell script + text file)
- Validate the script works by running it once

## Implementation Steps

### Task 1: Clean up stale packaging artifacts

**Files:**
- Delete: `mineore/` directory
- Delete: `mineore.zip`

- [x] Remove the stale `mineore/` directory and `mineore.zip` from the working tree (already gitignored, so no git impact)

### Task 2: Create the packaging script

**Files:**
- Create: `package.sh`

- [ ] Create `package.sh` that:
  - Reads version from info.json using grep/sed (no external deps)
  - Creates a temp directory `mineore_$VERSION/`
  - Copies mod files into it: info.json, control.lua, data.lua, settings.lua, changelog.txt, thumbnail.png, scripts/, prototypes/, locale/, graphics/
  - Excludes: .git, docs/, .gitignore, .vscode/, README.md, .ralphex/, package.sh, mineore/, *.zip, .DS_Store
  - Zips it as `mineore_$VERSION.zip`
  - Cleans up the temp directory
  - Prints the output filename and size
- [ ] Make the script executable
- [ ] Add `mineore_*.zip` to .gitignore (replacing the current mineore.zip entry)
- [ ] Run the script to verify it produces a valid zip

### Task 3: Write mod portal description

**Files:**
- Create: `docs/mod-portal-description.md`

- [ ] Write a polished mod portal long description covering:
  - What the mod does (one-paragraph summary)
  - Feature list with clear formatting
  - How to use it (quick-start steps)
  - Mod settings overview
  - Requirements and compatibility notes
  - Credit/inspiration (P.U.M.P. mod)
- [ ] Use Factorio mod portal markdown formatting (it supports a subset of markdown)

### Task 4: Update info.json homepage field

**Files:**
- Modify: `info.json`

- [ ] Set homepage to the GitHub repo URL (if the user provides one) or leave a placeholder comment in the plan

### Task 5: Verify

- [ ] Run `package.sh` and confirm the zip is created with correct structure
- [ ] Verify zip contents contain `modname_version/` top-level folder with all expected files
