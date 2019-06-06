![OVE](ove.png)

# What is OVE?
OVE is gathering git repositories and the knowledge how to build and test them. Well sort of. It is up to you to feed this information to OVE since it is highly depending on included projects. However, OVE provides a well-defined structure for using and sharing this information. OVE also provides a number of commands for common tasks, flexible ways of including all sorts of projects as well as expanding OVE on the go! We like to see this particular part of OVE as a shortcut removing not-updated-lately wikis, and let the code speak for itself.

## Justification

### *"To have a localized, yet versioned, top project source view to enable fast modify-build-test loops in parallel devlopment. For developers. For anyone that prefers a see-the-big-picture approach. And for those who just want to take quick peek."*

OVE is built with the developer in focus. We embrace the fact that while computers (e.g. CI/CD hosts) generally do not get easily frustrated, developers do.

## Tutorial
Eager to get going? We have a tutorial [here](https://github.com/Ericsson/ove-tutorial). Try OVE out with a pre-made tutorial project and get up to speed on OVE in a just a few minutes.

## Overview
OVE provides a top project, and therefore need to handle four major functionality areas:

* **Versioning**

* **Build chain**

* **System tests**

* **Project specific tasks**

To do this, OVE uses a top git repository (OWEL) containing information related to these tasks. Before we dig into details, let us just elaborate on a few things:

Versioning is handled entirely through git. The top repo and whatever sub repos are added are all git repos.

For OVE, a project is something that produces output (e.g. an executable, a library or anything else machine-made). Even though projects are normally contained within a corresponding git repo, OVE treats projects and repos independently. Multiple projects can be configured using code and build systems from the same repo, and one project can use code and build systems from multiple repos.

In order for OVE to build at the top level, independent of any toolchain used by sub-projects, a contract must be set up between OVE and any included project. This is a one-sided contract. Nothing needs to (nor should) go into a sub-project on OVEs account. To set up this contract, some typical build steps (bootstrap, configure, build, install) are specified for added sub projects.

System tests tend to be quite tricky to generalize around, so we simply do not. What is provided is a way of keeping track of entry points and groups of entry points to system tests. However, this creates a template for keeping track of tests as well as a way to pass information that OVE tracks down to test suites.

Enough said, let's dig into details! We start with versioning:

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

Thats it! This is how OVE keeps track of git revisions. Please note that there is no intermediate representation for git revisioning in OVE. What you put in the 'revision' collumn travels untouched to git, which means you can safely put anything there that git understands. Let's move on to top-view builds:

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
