![OVE](ove.png)

# What is OVE?
OVE is gathering git repositories and the knowledge how to build and test them. Well sort of, it is up to you to feed this information to OVE. However, OVE provides a well-defined structure for using and sharing this information with others. OVE also provides a number of commands for common tasks, flexible ways of including all sorts of projects as well as expanding OVE on the go! We like to see this particular part of OVE as a shortcut removing not-updated-lately wikis, and let the code speak for itself.

## Justification

### *"To have a localized, yet versioned, top project source view to enable fast modify-build-test loops in parallel development. For developers. For anyone that prefers a see-the-big-picture approach. And for those who just want to take a quick peek."*

OVE is built with the developer in focus. We embrace the fact that while computers (e.g. CI/CD hosts) generally do not get easily frustrated, developers do.

## Tutorial
Eager to get going? We have a tutorial [here](https://github.com/Ericsson/ove-tutorial). Try OVE out with a pre-made tutorial project and get up to speed on OVE in just a few minutes.

## Overview
OVE provides a top project, and on this top level OVE therefore needs to handle four major functionality areas:

* **Versioning**

* **Build chain**

* **System tests**

* **Project specific tasks**

To do this, OVE uses a top git repository (OWEL) containing information related to these tasks. Before we dig into details, let us just elaborate on a few subjects:

Versioning is handled entirely through git. The top repo and whatever sub repos are added are all git repos.

For OVE, a project is something that produces output (e.g. an executable, a library or anything else machine-made). Even though projects are normally contained within a corresponding git repo, OVE treats projects and repos independently. Multiple projects can be configured using code and build systems from the same repo, and one project can use code and build systems from multiple repos.

In order for OVE to build at the top level, independent of any toolchain used by sub-projects, a contract must be set up between OVE and any included project. This is a one-sided contract. Nothing needs to (nor should) go into a sub-project on OVEs account. To set up this contract, some typical build steps (bootstrap, configure, build, install) are specified for added sub projects.

System tests tend to be quite tricky to generalize around, so we simply do not. What is provided is a way of keeping track of entry points and groups of entry points to system tests. However, this creates a template for keeping track of tests as well as a way to pass information that OVE holds down to test suites.

Regardless of how much features goes into tools or frameworks trying to handle software projects, there is never enough. There are always per-project specific needs. OVE is made with a less-is-more approach. Rather than trying to collect as many feature requests as possible, we wanted to provide a solid functional base together with a simple, intuitive way of adding project-specific features. It is therefore possible to to expose customized ove commands from an OWEL, a workspace or from any git that OVE knows about. These commands are called plugins. They are basically just a bunch of executables (most often small bash scripts) that can leverage on the project information held by OVE.

Enough said, let's dig into details! We start with versioning:

### The 'revtab' file
To make it transparent and intuitive for the developer to quickly grasp what revision state a certain workspace or project is in, OVE tries to be as short and clear as possible about it. Therefore, the baseline for a project is defined by a plain, line-by-line, text file in the OWEL. It is called 'revtab' and only contains four fields:

* name: Unique identifier of the git repository. Characters allowed: a-z, A-Z and underscore
* fetch URL: The fetch URL.
* push URL: The pull URL. Not used.
* revision: The git revision. This is passed on to 'git checkout'.

Example:

    $ cat revtab
    # name        fetch URL          push URL           revision
    repoX         ssh://xyz/repoX    ssh://xyz/repoX    master
    deps/repoY    ssh://xyz/repoY    ssh://xyz/repoY    master

Thats it! This is how OVE keeps track of git revisions. Please note that there is no intermediate representation for revisioning in OVE. What you put in the 'revision' collumn travels untouched to git, which means you can safely put anything there that git understands. Now, let's move on to top-view builds:

### The 'projs' file

How does OVE keep track of dependencies? Well, to start with there are (at least) two types: First, there are prerequisites for most projects to build, usually installed using a package manager. Secondly, within a top project handled by ove the sub-projects almost always have dependencies to each other. To specify these two types, you use a YAML file in the OWEL, 'projs', that contains a list of projects with the following syntax:

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

Thats how OVE resolves external and internal dependencies for builds. Please note that the 'version:' keyword creates an environment variable that is passed to all build steps. What are those exactly? We cover that in the next section:

### The 'projects' folder
OVE is agnostic when it comes to build systems. Well, not entirely true. You need to be in an UNIX-like environment. That said, there are still a multitude of ways to build and install software that needs to be taken care of. OVE handles this by providing a way of defining, for each sub project, how that particular project is built. In the OWEL, there is a folder called 'projects'. Within this projects folder, sub directories needs to be present for each sub project containing executables (normally tiny bash scripts) for each build step. The projects structure typically look like this (output from tree):

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

When OVE builds the top project the following happens: First, OVE sorts out the build order as explained in the previous section. Secondly, each projects' build steps are executed (bootstrap, build, configure, install). When done, you should be able to find the final output of the build in the staging area. In most cases, these are then picked up by an OVE plugin that creates deliverable packages of some kind (.rpm, .deb or similar).

Particularly interesting here are the "configure" and "install" steps. In order for OVE to get intermediate build results into the staging area, typically this kind of construct is used from within the 'configure' script:

	./configure --prefix=$OVE_STAGE_DIR/usr

This way, the install step will install any built items into '$OVE_STAGE_DIR/usr'. Of course the way to do this depends on what build system is used, but the same goes for any project you put into an OVE project: You need to be able to get the build results into the staging area.

You now know how to build sub projects together, but what about testing from a system perspective? We cover that in the next section:

### The 'systests' and 'systests-groups' files

We have already covered how OVE keeps track of repos, how sub-project build methods can be included and how they can all form a larger, top view project. We also showed how these parts gets built together using OVE's staging area. On the same note, it also makes sense to provide a way to execute system tests, tests that need more than one sub-project or repo to execute. As stipulated earlier, OVE takes a rather defensive approach here. Quite often, test systems already exist for most functionality you want to develop, at least partly. And you want to re-use them. Luckily, OVE will be able to launch any tests as long as they can execute from prompt. Two files, 'systests' and 'systests-groups' give OVE information about what tests are available and how to execute them:

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

Using the above structure, you would be able to execute either one test (t1, t2 or t3), a series of them (t1 t2) or a test group ("all" or "sanity"). Asking ove what test are avilable in this case would look like this:

    $ ove list-systests
    all
    sanity
    t1
    t2
    t3

Thats it for system tests! Now lets go ahead and look at plugins:

## Plugins
As discussed in the Overview, in most larger projects there is a strong need for flexibility when it comes to what a developer or CI/CD machinery wants to be able to do with it. To accomodate these needs, OVE provides a way of extending the ove command list with customized commands. We call them plugins, and they can be exposed to your OVE project in three ways: From your workspace, from your OWEL (top repo) or from any repo included in the revtab. What are they really then? They are executables, optionally accompanied with a help text and/or a tab completion script. OVE looks for plugins at the following locations:

    $OVE_BASE_DIR/scripts/
    $OVE_PROJECT_DIR/scripts/
    <all repositories>/.ove/scripts/

Any executable found in any of these locations will become an OVE command. And provided that tab completion scripts and help texts exist at the same location, they will also be part of the OVE help and support tab completion for their arguments.

We now covered the four main functionality areas of OVE. Next we will go through how to make life easy for developers or CI/CD machines when it comes to setting up an OVE project:

## Setup
An existing OVE project is typically setup (or downloaded if you will) by the developer or CI/CD machine using the following oneliner:

    $ curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s <name> <OWEL>

* name: Path to the OVE workspace.
* OWEL: URL of the top git repository

The setup script will do two things:

* create the 'name' directory at your current location
* clone the OVE (ove itself) and OWEL (top repo) git repos

The 'setup' script will then urge the developer to enter the OWEL directory and run

    $ source ove

Doing this, OVE will check that you have the required programs installed on your machine and prompt for installation otherwise. This is the current list:

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

After successfully sourcing ove, further instructions are given to enter the OVE workspace and fetch the rest of the repos. When the fetch is completed, everything is ready in order for man or machine to start working with the project! For the sake of clarity, lets look at an example:

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

Done! As simple as that. Lets give a final example of what an OVE project file structure can look like when ready:

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

Up until now we covered everything you need to know to get to the point where developers (or machines) can start working with your OVE project. However, we have mentioned the OVE commands several times already and it is now time to have a closer look at how those work:

## Commands
OVE will enhance your bash shell with commands to manage your OVE based project. We divide them into four categories:

* High level git commands
* Build related commands
* Utility commands
* Plugins (covered by previous sections)

### High level git commands
OVE implements a subset of the standard git commands as "high level" git commands. These commands executes the corresponding git command on all (or selective) **revtab** repositories.

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

### Utility commands
Here's a list (not complete) of a few utility commands:

| Command                  | Description                                              |
|--------------------------|----------------------------------------------------------|
| forall/forall-parallel   | run an arbitrary command for all git repositories        |
| forowel/forowel-parallel | run an arbitrary command in all OVE projects on the host |
| locate                   | list OVE projects/workspaces on this host                |
| news                     | view upstream news for each git repository               |
| switch                   | switch to another OVE project                            |
| unsource                 | clean up all OVE vars/funcs from this shell              |
| vi                       | open all modified files in 'vi'                          |

## Supported Linux distributions

We tell ourselves that we support the following distros at this point:

* Alpine Linux 3.9.0
* Arch Linux
* Centos
* Debian GNU/Linux 9
* Fedora 29
* Gentoo
* Ubuntu 16.04
* Ubuntu 18.04
* Ubuntu 19.10

Want to know more about OVE? Please check out the OVE [tutorial](https://github.com/Ericsson/ove-tutorial) or ask OVE:

	$ ove help
