# Customizations

Gitg can read git configuration for customizations

## Main line

`gitg.mainline`: A branch always exposed on Gitg history

## Main remote

`gitg.main-remote`: Default remote for push operation

## Smart commits

Gitg can parse commit messages to indentify git service abbreviations, like issues or merge requets

Capture group will be replaced and turn match into an hyperlink

### Examples
- gitlab issues:

```
[gitg.custom-link "issues"]
regexp="#([0-9]+)"
replacement=https://gitlab.gnome.org/GNOME/gitg/issues/\\1
color = orange
```
- gitlab merge request:
```
[gitg.custom-link "merge.request"]
regexp=!([0-9]+)
replacement=https://gitlab.gnome.org/GNOME/gitg/merge_requests/\\1
color = green
```

## Custom actions

Gitg allows to create actions attached in contextual menus.

There're two entry points:

- `gitg.actions.global`: Added on top right popover menu
- `gitg.actions.reference`: Added on reference contextual menu

For reference actions, some templating is available:

```
name: refs/heads/foo
shortname: foo
remote-name: origin
remote-branch: foo
```

For commands needing a prompt: `input_ref` is available.

parameters:

- name: Name for action
- description: Action description
- group: Add action under a submenu
- command: Command to run
- available: literal true/false or command line evaluating to 1/0. Decides if action is added
- enabled: literal true/false or command line evaluating to 1/0. Decides if action is enabled
- show-output: Shows a dialog with command output. Default false
- show-error: On error show a dialog with command output and err. Default true

### Reference action examples

- Git rebase: Only available if branch has an upstream
```
[gitg.actions.reference "Rebase To Upstream"]
name = To upstream
group = Rebase
description = rebase branch to upstream
command = git rebase
available = git rev-parse --abbrev-ref $shortname@{u}

- Rebase abort: Only enabled if repo is under a rebase
[ "Rebase Abort"]
name = Abort
group = Rebase
description = rebase abort
command = git rebase --abort
available = true
enabled = bash -c 'git_dir=$(git rev-parse --git-dir 2>/dev/null) && ( [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] )'

- Git reset: Provide a mixed reset
[gitg.actions.reference "Reset"]
name = Mixed
group = Reset
description = reset mixed
command = git reset $input_ref
available = true
enabled = true

- Git reset hard: Provide a reset hard
[gitg.actions.reference "Reset Hard"]
name = Hard
group = Reset
description = reset hard
command = git reset --hard $input_ref
available = true
enabled = true

### Global action examples

- Clean all:  clean for unknow files
[gitg.actions.global "Clean all"]
name = Clean all
description = clean all untracked files
command = git clean -dxf
available = true
enabled = true

- Git stash: stash modified files
[gitg.actions.global "Stash"]
group = Stash
name = Stash
description = stash modified tracked files
command = git stash
available = true
enabled = true

- Git stash pop: pop stash
[gitg.actions.global "Stash Pop"]
group = Stash
name = Pop
description = pop first stash
command = git stash pop
available = true
enabled = true

- Git stash list: list existing stash
[gitg.actions.global "Stash List"]
group = Stash
name = List
description = list existing stashes
command = git stash list
available = true
enabled = true
show-output = true

- Git stash drop: drop first stash
[gitg.actions.global "Stash Drop"]
group = Stash
name = Drop
description = Drop first stash
command = git stash drop
available = true
enabled = true
```

