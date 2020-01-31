| Command                  | Arguments                                         | Description                                                                                                           |
|-|-|-|
| !                        |                                                   | view last command in pager (=${OVE_PAGER})                                                                            |
| add                      | [GIT...]                                          | git add -p for all/specified repositories                                                                             |
| ag                       | PATTERN                                           | search OVE workspace using The Silver Searcher [duckduckgo.com/?q=The+Silver+Searcher]                                |
| ahead                    | [GIT...]                                          | list local commits not yet published for all/specified repositories                                                   |
| apply                    | PATCH                                             | apply one OVE patch                                                                                                   |
| authors                  |                                                   | list author summary for all git repositories                                                                          |
| blame                    | PATTERN                                           | git grep-blame-log combo                                                                                              |
| blame-history            | PATTERN                                           | git log -S for all git repositories                                                                                   |
| bootstrap                | [PROJECT...]                                      | run the 'bootstrap' step for all or individual projects                                                               |
| bootstrap-parallel       | [PROJECT...]                                      | run the 'bootstrap' step for all or individual projects (in parallel)                                                 |
| branch                   | [GIT...]                                          | git branch -v for all/specified git repositories                                                                      |
| build                    | [PROJECT...]                                      | run the 'build' step for all or individual projects                                                                   |
| build-order              |                                                   | show build order                                                                                                      |
| build-parallel           | [PROJECT...]                                      | run the 'build' step for all or individual projects (in parallel)                                                     |
| buildme                  | [PROJECT]                                         | build projects from scratch (=bootstrap, configure, build, install)                                                   |
| buildme-parallel         | [PROJECT]                                         | build projects from scratch (=bootstrap, configure, build, install)                                                   |
| cd                       |                                                   | helper for 'cd ${OVE_BASE_DIR}'                                                                                       |
| checkout                 | [rev[ [purge\|autostash]]]                         | git checkout -p for all git repositories OR checkout a new project revision, use 'purge' with care                    |
| clean                    | [PROJECT...]                                      | run the 'clean' step for all or individual projects                                                                   |
| clean-parallel           | [PROJECT...]                                      | run the 'clean' step for all or individual projects (in parallel)                                                     |
| commit                   | [GIT...]                                          | git commit for all/specified git repositories                                                                         |
| config                   | [CONFIG]                                          | show or manipulate .oveconfig                                                                                         |
| configure                | [PROJECT...]                                      | run the 'configure' step for all or individual projects                                                               |
| configure-parallel       | [PROJECT...]                                      | run the 'configure' step for all or individual projects (in parallel)                                                 |
| describe                 | [GIT...]                                          | git describe+log+status combo for all/specified git repositories                                                      |
| diff                     | [GIT...]                                          | git diff for all/specified git repositories                                                                           |
| diff-cached              | [GIT...]                                          | git diff --cached for all/specified repositories                                                                      |
| diff-check               | [OPTIONS]                                         | git diff --check [OPTIONS]                                                                                            |
| diff-project             | <rev> <rev>                                       | git diff the '${OVE_PROJECT_NAME}' project                                                                            |
| digraph                  |                                                   | create a DOT directed graph for all projects                                                                          |
| do                       | DIR COMMAND                                       | run a command within DIR relative to ${OVE_BASE_DIR}                                                                  |
| domains                  |                                                   | list email domain summary for all git repositories                                                                    |
| dry-run                  | [0\|1]                                             | toggle or set OVE_DRY_RUN                                                                                             |
| emacs                    | [PATTERN]                                         | open modified files in emacs                                                                                          |
| env                      | [PATTERN]                                         | show OVE env                                                                                                          |
| export                   | [PROJECT...]                                      | export project(s)                                                                                                     |
| fetch                    | [GIT...]                                          | git fetch --all for all/specified repositories, ends with ove status                                                  |
| forall                   | COMMAND                                           | run 'COMMAND' for all git repositories                                                                                |
| forall-parallel          | COMMAND                                           | run 'COMMAND' in parallel for all git repositories                                                                    |
| forowel                  | COMMAND                                           | run 'COMMAND' for all OVE workspaces on this host                                                                     |
| forowel-parallel         | COMMAND                                           | run 'COMMAND' in parallel for all OVE workspaces on this host                                                         |
| fzf                      | [loop]                                            | OVE fzf [duckduckgo.com/?q=fzf]                                                                                       |
| generate-doc             |                                                   | generate OVE documentation (e.g. ${OVE_DIR}/ove-cmd-list.md)                                                          |
| gitmodules2revtab        |                                                   | import git submodules                                                                                                 |
| grep                     | PATTERN                                           | grep OVE workspace                                                                                                    |
| heads2revtab             | [GIT...]                                          | update '${OVE_PROJECT_DIR}/revtab' with current SHA-1                                                                 |
| help                     | [PATTERN]                                         | OVE help                                                                                                              |
| import                   | [file]                                            | import project(s), see export                                                                                         |
| install                  | [PROJECT...]                                      | run the 'install' step for all or individual projects                                                                 |
| install-parallel         | [PROJECT...]                                      | run the 'install' step for all or individual projects (in parallel)                                                   |
| lastlog                  | [cmin]                                            | list logs created within last 60 min or cmin min                                                                      |
| list-commands            |                                                   | list commands                                                                                                         |
| list-committed-files     | [DAYS]                                            | list committed files within 7 or DAYS day(s)                                                                          |
| list-heads               | [GIT...]                                          | git log for all/specified git repositories                                                                            |
| list-modified-files      |                                                   | list modified files                                                                                                   |
| list-projects            | [long]                                            | list projects                                                                                                         |
| list-repositories        |                                                   | list all git repositories                                                                                             |
| list-scripts             |                                                   | list available scripts                                                                                                |
| list-systests            |                                                   | list available system tests                                                                                           |
| list-systests-aliases    |                                                   | list available system test aliases                                                                                    |
| locate                   |                                                   | print OVE workspaces owned by '${USER}' on this host using either 'locate' or 'find ${OVE_LOCATE_SEARCH_DIR}'         |
| locate-all               |                                                   | print OVE workspaces on this host using either 'locate' or 'find ${OVE_LOCATE_SEARCH_DIR}'                            |
| log                      |                                                   | project '${OVE_PROJECT_NAME}' commit log for branch '${OVE_PROJECT_CI_BRANCH}'                                        |
| log-project              | <rev> <rev>                                       | git log the project '${OVE_PROJECT_NAME}'                                                                             |
| loglevel                 | [LEVEL]                                           | show or change loglevel [0-6]                                                                                         |
| loop                     | \|[TIMEOUT\|?] [INOTIFY\|?] [MAX-COUNT\|?] COMMAND]   | loop one OVE command                                                                                                  |
| ls-files                 | [PATTERN]                                         | git ls-files for all git repositories                                                                                 |
| ls-remote                |                                                   | git ls-remote <URL> HEAD for all git repositories                                                                     |
| make                     | [PROJECT[-nodeps]]                                | build project(s)                                                                                                      |
| mrproper                 | [y\|Y]                                             | remove untracked files AND removes '${OVE_STAGE_DIR}/*' AND removes '${OVE_ARCHIVE_DIR}/*'                            |
| news                     | [GIT...]                                          | list upstream changes for all/specified repositories                                                                  |
| pull                     | [GIT...]                                          | git pull --rebase for all/specified repositories                                                                      |
| readme                   | [GIT...]                                          | display README files for all/specified git repositories                                                               |
| refresh                  |                                                   | refresh projects found by ove-locate                                                                                  |
| remote                   | [GIT...]                                          | git remote -v for all/specified git repositories                                                                      |
| remote-check             |                                                   | sanity check that all remotes are online                                                                              |
| replicate                | HOST                                              | replicate OVE workspace on HOST                                                                                       |
| reset                    | [GIT...]                                          | git reset -p for all/specified repositories                                                                           |
| revtab-diff              | <rev> <rev>                                       | print changes between two '${OVE_PROJECT_NAME}' revisions                                                             |
| run                      | \|TIMEOUT COMMAND                                  | run one OVE command in terminal\|tmux                                                                                  |
| select-configuration     | [PATTERN\|default]                                 | select build configuration for each project                                                                           |
| setup                    |                                                   | print how to set this project up                                                                                      |
| shortlog-project         | <rev> <rev>                                       | git shortlog the project '${OVE_PROJECT_NAME}'                                                                        |
| show                     | [revision...]                                     | ove list-heads or search for 'revision' within all git repositories. If found run 'git show SHA-1\|TAG'                |
| show-configuration       |                                                   | show current build configuration for each project                                                                     |
| stash                    | [drop\|list\|pop\|show]                              | git stash [drop\|list\|pop\|show] for all git repositories                                                               |
| status                   | [GIT...]                                          | git status -zbs -uno for all/specified repositories                                                                   |
| strace-execve-connect    | DIR                                               | run strace connect time analysis on DIR                                                                               |
| strace-execve-time       | DIR                                               | run strace execve time analysis on DIR                                                                                |
| strace-execve-timeline   | DIR                                               | run strace execve timeline analysis on DIR                                                                            |
| strace-graph             | DIR                                               | run strace graph analysis on DIR                                                                                      |
| switch                   | [PATTERN]                                         | switch to another OVE project                                                                                         |
| systest                  | [TEST\|GROUP...]                                   | run one or more system tests/groups described in ${OVE_PROJECT_DIR}/systests-groups and ${OVE_PROJECT_DIR}/systests   |
| tag                      |                                                   | list all project tags                                                                                                 |
| unittest                 | [TEST...]                                         | run all/specific unit tests                                                                                           |
| unsource                 |                                                   | clean up all OVE vars/funcs from this shell                                                                           |
| version                  |                                                   | print OVE version                                                                                                     |
| vi                       | [PATTERN]                                         | open modified files in vi                                                                                             |
| wdiff                    | [GIT...]                                          | git diff (word diff) for all/specified git repositories                                                               |
| what-is                  | DIRECTORY...                                      | classify files using 'file' within a directory                                                                        |
