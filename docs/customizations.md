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

There're several entry points:

- `gitg.actions.global`: Added on top right popover menu
- `gitg.actions.reference`: Added on reference contextual menu
- `gitg.actions.commits`: Added on commit contextual menu

### Templating:

Some command might need related info from object selected. With `${}` or `$` templating is available:

#### Vars:

- for references:
```
name: refs/heads/foo
shortname: foo
remote-name: origin
remote-branch: foo
```

- for commits:
```
sha: 123ed34
``

#### Input prompt:

For commands needing a prompt:

- `$input`: Provide input from a dialog.
- `$question`: Confirm. This allows command to continue or stop.

parameters:

- name: Name for action
- description: Action description
- group: Add action under a submenu
- command: Command to run
- available: literal true/false or command line evaluating to 1/0. Decides if action is added
- enabled: literal true/false or command line evaluating to 1/0. Decides if action is enabled
- show-output: Shows a dialog with command output. Default false
- show-error: On error show a dialog with command output and err. Default true
- dialog-title: Title for output dialog. Default "Output"
- dialog-label: label text for output dialog. Default "Results:"
- input-title: Title for input dialog. Default "Input"
- input-label: label text for input dialog. Default "Value:"
- input-yes: Text for input yes response. Default "Ok"
- input-no: Text for input no response. Default "Cancel"
- input-text: Initial text for input value. Default ""
- input-placeholder: Placeholder text. Default ""
- input-force-show-placeholder: Disable focus on input entry to see placeholder.
- question-title: Title for question dialog. Default "Question"
- question-message: Text for question dialog. Default "Are you sure?"
- question-yes: Text for question yes response. Default "Yes"
- question-no: Text for question no response. Default "No"
- question-level: Level of question (info/warning/question/error). Default "question"

### Reference action examples

- Git rebase: Only available if branch has an upstream
```
[gitg.actions.reference "Rebase To Upstream"]
name = To upstream
group = Rebase
description = rebase branch to upstream
command = git rebase
available = git rev-parse --abbrev-ref $shortname@{u}
```

- Rebase continue: Only enabled if repo is under a rebase
```
[gitg.actions.reference "Rebase Continue"]
name = Abort
group = Rebase
description = rebase abort
command = git rebase --abort
available = true
enabled = bash -c 'git_dir=$(git rev-parse --git-dir 2>/dev/null) && ( [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] )'
```

- Rebase abort: Only enabled if repo is under a rebase
```
[gitg.actions.reference "Rebase Abort"]
name = Abort
group = Rebase
description = rebase abort
command = git rebase --abort
available = true
enabled = bash -c 'git_dir=$(git rev-parse --git-dir 2>/dev/null) && ( [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] )'
```

- Git reset: Provide a mixed reset
```
[gitg.actions.reference "Reset"]
name = Mixed
group = Reset
description = reset mixed
command = git reset $input_ref
available = true
enabled = true
```

- Git reset hard: Provide a reset hard
```
[gitg.actions.reference "Reset Hard"]
name = Hard
group = Reset
description = reset hard
command = git reset --hard $input_ref
available = true
enabled = true
```

### Commit action examples

- Git cherry pick: Bring commits into current head
```
[gitg.actions.commits "Cherry pick"]
group = Cherry Pick
name = Pick
description = Cherry picking commits
command = git cherry-pick $sha
available = true
enabled = true
```

- Git cherry pick continue. During a cherry pick, after manually commit, allow to continue
```
[gitg.actions.commits "Cherry pick continue"]
group = Cherry Pick
name = Continue
description = Cherry pick continue
command = git cherry-pick --continue
available = true
enabled = bash -c 'git_dir=$(git rev-parse --git-dir 2>/dev/null) && [ -f "$git_dir/CHERRY_PICK_HEAD" ]'
```

- Git cherry pick abort. During a cherry pick, allow to abort
```
[gitg.actions.commits "Cherry pick abort"]
group = Cherry Pick
name = Abort
description = Cherry pick abort
command = git cherry-pick --abort
available = true
enabled = bash -c 'git_dir=$(git rev-parse --git-dir 2>/dev/null) && [ -f "$git_dir/CHERRY_PICK_HEAD" ]'
```

### Global action examples

- Clean all:  clean for unknow files
```
[gitg.actions.global "Clean all"]
name = Clean all
description = clean all untracked files
command = git clean -dxf
available = true
enabled = true
```

- Git stash: stash modified files
```
[gitg.actions.global "Stash"]
group = Stash
name = Stash
description = stash modified tracked files
command = git stash
available = true
enabled = true
```

- Git stash pop: pop stash
```
[gitg.actions.global "Stash Pop"]
group = Stash
name = Pop
description = pop first stash
command = git stash pop
available = true
enabled = true
```

- Git stash list: list existing stash
```
[gitg.actions.global "Stash List"]
group = Stash
name = List
description = list existing stashes
command = git stash list
available = true
enabled = true
show-output = true
```

- Git stash drop: drop first stash
```
[gitg.actions.global "Stash Drop"]
group = Stash
name = Drop
description = Drop first stash
command = git stash drop
available = true
enabled = true
```
