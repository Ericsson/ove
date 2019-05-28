![OVE](ove.png)

# OVE
OVE is gathering git repositories and the knowledge how to build and test them.

The OVE environment justification: To have a localized yet versioned top
source view to enable fast modify-build-test loops for developers or anyone
that prefers a see-the-big-picture approach or simply want to take quick peek.

## Tutorial
We have a tutorial [here](https://github.com/Ericsson/ove-tutorial). Go there and get up to speed on OVE in a few minutes.

## Terminology
OVE is dependent on one top git repository (OWEL). This top repository keep track of three things:

* Git repositories and revisions. Specified in a text file '**revtab**'.

* Projects. A project is typically something that creates a library or executable. Projects has their own build system - OVE does not care which one. It's up to you to decide how to define the project structure. OVE keep track of project dependencies and know in what order to build individual projects. Projects are defined in a YAML file '**projs**'. Individual build steps (bootstrap, configure, build, install) is defined in separate executable files at this location: '**projects/<name/**'.

* System tests. Tests are defined in a text file **systests** and groups of tests (test suites) are defined in **systest-groups**.

The next section will explain the above in more detail.

### revtab
A text file that contains four fields:

* name: Unique identifier of the git repository. Characters allowed: a-z, A-Z and underscore
* fetch URL: The fetch URL.
* push URL: The pull URL. Not used.
* revision: The git revision. This is passed on to 'git checkout'.

Example:

    $ cat revtab
    # name        fetch URL          push URL           revision
    repoX         ssh://xyz/repoX    ssh://xyz/repoX    master
    deps/repoY    ssh://xyz/repoY    ssh://xyz/repoY    master

### projs
A YAML file that contains a list of projects with the following syntax:

    name:
      deps:    list of projects that need to be built before myself
      needs:   list of packages that need to be installed before I can be built
      path:    path to the source code of myself
      version: Optional. Passed on to all build stages for this project.

Example:

    $ cat projs
    ---
    projA:
      deps:  projB
      needs: autoconf automake g++
      path:  repoX

    projB:
      deps:  projC
      needs: build-essential
      path:  repoY

    projC:
      needs: build-essential
      path:  repoY

### systests and systests-groups
'systests' is a text file that contains a list of tests. One row is one test:

* name: Unique identifier for the test
* timeout: time in seconds when the test should finish
* type: 0 = normal. 1 = will break execution on failures if this test is part of a test suite.
* path: where to execute the test
* command: command to execute

Example:

    $ cat systests
    # name       timeout (s)   type   path   command
    # ----------------------------------------------
    t1              5          0      repoX  "sleep 4"
    t2              1          0      repoX  "echo Hello"
    t3           3600          0      repoY  "./long-duration-test

'systests-groups' is a YAML file that contains groups/sets of tests. Example:

    $ cat systests-groups
    all:
      - t1
      - t2
      - t3
    sanity:
      - t1

## Setup
One OVE project is typically setup using the following oneliner:

    $ curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s <name> <OWEL>

* name: Path to the OVE workspace.
* OWEL: URL of the top git repository

The setup script will basically do two things:

* create the **name** directory
* clone the OVE and OWEL git repositories

The '**setup**' script will now tell you to run the '**source ove**' command. Here, OVE will do a check that you have the required programs installed on your machine. This is the current list:

* column
* file
* envsubst
* git
* hostname
* pgrep
* script
* tree
* tsort

OVE is also dependent on 'sed/grep/tail/awk/...' but they are not (yet) checked for.

### Setup example

    $ curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s abc ssh://github.com/Ericsson/ove-tutorial
    Cloning into '.ove'...
    Cloning into 'xyz'...
    ...
    $ cd abc
    $ source ove
    OVE [SHA-1: ... @ Ubuntu 19.10]
    This script will do a few things:

    * add 75 bash functions:
    ...

    * add 39 bash variables:
    ...

    * enable tab completion for ove

    Now what? Run 'ove fetch' to sync with the outside world or 'ove help' for more information

    $ ove fetch
    Cloning into 'repoX'...
    Cloning into 'repoY'...
    ...
    repoX ## master..origin/master
    repoY ## master..origin/master
    .ove  ## master..origin/master

    $ tree
    ├── ove -> .ove/ove
    ├── .ove/
    │   ├── .git/
    │   ├── LICENSE
    │   ├── ove
    │   ├── ove.png
    │   ├── README.md
    │   ├── scripts/
    │   ├── setup
    │   ├── tests/
    │   └── yex
    ├── .owel -> xyz/
    ├── repoX/
    │   ├── .git/
    │   └── README
    ├── repoY/
    │   ├── .git/
    │   └── README
    └── xyz/
        ├── .git/
        ├── projects/
        │   ├── projA/
        │   │   ├── bootstrap
        │   │   ├── build
        │   │   ├── configure
        │   │   └── install
        │   ├── projB/
        │   │   ├── bootstrap
        │   │   ├── build
        │   │   ├── configure
        │   │   └── install
        │   └── projC/
        │       ├── bootstrap
        │       ├── build
        │       ├── configure
        │       └── install
        ├── projs
        ├── revtab
        ├── systests
        └── systests-groups

## Commands
OVE will enhance (or mess up?) your bash shell with some new commands. We divide them into three categories:

* High level git commands
* Build related commands
* Misc commands

### High level git commands
OVE implements a subset of the "high level" git commands. The OVE version of these commands executes these git commands on all (or selective) **revtab** repositories. Here's a list of implemented git commands:

* add
* apply
* blame
* branch
* checkout
* commit
* describe
* diff
* fetch
* grep
* pull
* show
* status
* tag

### Build related commands
This is a list of build related commands:

* buildme / buildme-parallel
* make
* mrproper

The above list will be dynamically populated with project commands found under the "projects/<proj>/" directories. So, for a "normal" OVE project, these commands are usually also present:

* bootstrap
* configure
* build
* install

Note: For each project command there is a "<command>-parallel" version of that command.

### Misc commands
Here's a list (not complete) of a few Misc commands:

| Command                  | Description                                              |
|--------------------------|----------------------------------------------------------|
| forall/forall-parallel   | run an arbitrary command for all git repositories        |
| forowel/forowel-parallel | run an arbitrary command in all OVE projects on the host |
| locate                   | list OVE projects/workspaces on this host                |
| news                     | view upstream news for each git repository               |
| switch                   | switch to another OVE project                            |
| unsource                 | clean up all OVE vars/funcs from this shell              |
| vi                       | open all modified files in 'vi'                          |

## Tested Linux distributions
* Alpine Linux 3.9.0
* Arch Linux
* Centos
* Debian GNU/Linux 9
* Fedora 29
* Gentoo
* Ubuntu 16.04
* Ubuntu 18.04
* Ubuntu 19.10

## Need more help?
Try 'ove help'.
