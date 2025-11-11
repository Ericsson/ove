![OVE](ove.png)

<https://user-images.githubusercontent.com/25057211/120758396-1528a300-c512-11eb-82c8-ec479a800102.mp4>

# What is OVE

OVE is gathering git repositories and the knowledge how to build and test them.
Well sort of, it is up to you to feed this information to OVE. However, OVE
provides a well-defined structure for using and sharing this information with
others. OVE also provides a number of commands for common tasks, flexible ways
of including all sorts of projects as well as the ability to expand OVE on the
go! OVE is not a one-entry-point tool, but rather a shell enhancer: All parts
of the OVE workflow can be done manually from prompt. We like to view OVE as a
way of removing not-updated-lately wikis, and instead share ready-to-use
functionality.

## Justification

*To have a localized, yet versioned, top project source view to enable fast
modify-build-test loops in parallel development. For developers, for anyone
that prefers a see-the-big-picture approach and for those who just want to take
a quick peek.*

OVE is built with the developer in focus. We embrace the fact that while
computers (e.g. CI/CD hosts) generally do not get easily frustrated, developers
do.

## Tutorial

Eager to get going? We have a tutorial
[here](https://github.com/Ericsson/ove-tutorial). Try OVE out with a pre-made
tutorial project and get up to speed on OVE in just a few minutes.

## Overview

OVE provides a top project, and on this top level OVE therefore needs to handle
four major functionality areas:

* **Versioning**

* **Build chain**

* **System tests**

* **Project specific tasks**

To do this, OVE uses a top git repository (OWEL) containing information related
to these tasks. Before we dig into details, let us just elaborate on a few
subjects:

Versioning is handled entirely through git. The top repo and whatever sub repos
are added are all git repos.

For OVE, a project is something that produces output (e.g. an executable, a
library or anything else machine-made). Even though projects are normally
contained within a corresponding git repo, OVE treats projects and repos
independently. Multiple projects can be configured using code and build systems
from the same repo, and one project can use code and build systems from
multiple repos.

In order for OVE to build at the top level, independently of any toolchain used
by sub-projects, a contract must be set up between OVE and any included
project. This is a one-sided contract. Nothing needs to (nor should) go into a
sub-project on OVE's account. To set up this contract, some typical build steps
(bootstrap, configure, build, install) are specified for added sub projects.

System tests tend to be quite tricky to generalize, so we simply do not. What
is provided is a way of keeping track of entry points and groups of entry
points to system tests. This creates a template for keeping track of tests and
a way to pass information that OVE holds down to test suites.

Regardless of how much features go into tools or frameworks for software
projects, they are never complete. There are always per-project specific needs.
OVE is made with a less-is-more approach. Rather than trying to implement as
many feature requests as possible, we wanted to provide a solid functional base
together with a simple, intuitive way of adding project-specific features. It
is therefore possible to expose customized OVE commands from an OWEL, a
workspace or from any git that OVE knows about. These commands are called
plugins. They are basically just a bunch of executables (most often small bash
scripts) that can leverage on the project information held by OVE.

Enough said, let us dig into details! We start with versioning:

### The 'revtab' file

To make it transparent and intuitive for the developer to quickly grasp what
revision state a certain workspace or project is in, OVE tries to be as short
and clear as possible about it. Therefore, the baseline for a project is
defined by a plain, line-by-line, text file in the OWEL. It is called 'revtab'
and only contains four fields:

* name: Unique identifier of the git repository.
* fetch URL: The fetch URL.
* push URL: The push URL.
* revision: The git revision. This is passed on to 'git checkout'.

Example:

    $ cat revtab
    # name        fetch URL          push URL           revision
    repoX         ssh://xyz/repoX    ssh://xyz/repoX    main
    deps/repoY    https://xyz/repoY  https://xyz/repoY  stable

That's it! This is how OVE keeps track of git revisions. There is no
intermediate representation for revisioning in OVE. What you put in the
'revision' column travels untouched to git, which means you can safely put
anything there that git understands. Now, let's move on to top-view builds:

### The 'projs' file

How does OVE keep track of dependencies? Well, to start with there are (at
least) two types of dependencies: First, there are prerequisites for most
projects to build, usually installed using a package manager. Secondly, within
a top project handled by OVE the sub-projects almost always have dependencies
to each other. To specify these two types, you use a YAML file in the OWEL,
'projs', that contains a list of projects with the following syntax:

    name:
      deps:
        ...
      needs:
        ...
      path:
        ...
      tags:
        ...
      version:
        ...

#### name

Project name. Characters allowed: a-z, A-Z, 0-9 and underscore. 'common' is
a reserved word.

#### deps

A list of OVE projects that need to be built before this project can be built.

#### needs

A list of OS packages that need to be installed before this project can be
built. Shell command substitution is allowed.

Can be extended with specific distro requirements, syntax:

    needs[_ID][_VER]]

ID is a string and is matched vs. one string within: "${OVE_OS_ID//-/_}
${OVE_OS_ID_LIKE//-/_}". Examples: "ubuntu", "debian", "centos", "rhel",
"fedora", "opensuse_tumbleweed", "suse". VER is a string and is matched vs.
"${OVE_OS_VER//[.-]/_}". Examples: "18_04", "3_12_0", "20200923".

#### path

The path to project work directory. Relative to OVE_BASE_DIR or an absolute
path. Variables are allowed.

#### tags

Mark a project with one or many tags. Tags will allow you to refererence groups
of projects (e.g. for builds).

#### version

Optional. Passed on as a bash variable to all steps for this project.

    $ cat projs
    ---
    projA:
      deps:
        projB
      needs:
        autoconf
        automake
        g++
      path:
        repoX
      tags:
        small
        ui

    projB:
      deps:
        projC
      needs:
        build-essential
        linux-headers-$(uname -r)
      path:
        repoY
      tags:
        backend
        medium

    projC:
      needs:
        build-essential
      needs_ubuntu:
        pkgA
      needs_ubuntu_20_04:
        pkgB
      needs_debian:
        pkgC
      needs_rhel:
        pkgE
      path:
        /tmp/projC
      tags:
        large
        ui
      version:
        2.0.0

That's how OVE resolves external and internal dependencies for builds. As you
just read above, the 'version:' keyword creates an environment variable that is
passed to all build steps. What are those steps exactly? We cover that in the
next section:

### The 'projects' directory

OVE is agnostic when it comes to build systems. Well, not entirely true. You
need to be in a UNIX-like environment. That said, there are still a multitude
of ways to build and install software that need to be taken care of. OVE
handles this by providing a way of defining, for each sub project, how that
particular project is built. In the OWEL, there is a directory called
'projects'. Within this projects directory, sub directories need to be present
for each sub project containing executables (normally tiny shell scripts) for
each build step. The projects structure typically look like this (output from
tree):

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
    │   ├── projC/
    │   │   ├── bootstrap
    │   │   ├── build
    │   │   ├── common
    │   │   ├── configure
    │   │   └── install
    │   └── common/
    │   │   ├── bootstrap
    │   │   ├── bootstrap.post
    │   │   ├── bootstrap.pre
    │   │   └── build.pre

When OVE builds the top project the following happens: First, OVE sorts out the
build order as explained in the previous section. Secondly, each projects'
build steps are executed (bootstrap, build, configure, install). When done, you
should be able to find the final output of the build in the staging area. In
most cases, these are then picked up by an OVE plugin that creates deliverable
packages of some kind (.rpm, .deb or similar).

Particularly interesting here are the "configure" and "install" steps. In order
for OVE to get intermediate build results into the staging area, this kind of
construct is typically used from within the 'configure' script:

    ./configure --prefix=${OVE_STAGE_DIR}${OVE_PREFIX}

This way, the install step will install any built items into
'${OVE_STAGE_DIR}${OVE_PREFIX}'. Of course the way to do this depends on what
build system is used, but the same goes for any project you put into an OVE
project: You need to be able to get the build results into the staging area.

The 'common' directory is special. In the example above, before each individual
project's 'projX/bootstrap' file is executed, the 'common/bootstrap' file is
sourced. This will allow you to put common environment flags, checks etc. into
that 'common/{bootstrap,configure,build,install,...}' shell script. The
pre/post files are sourced before/after the first/last bootstrap command.

Example:

    $ ove bootstrap projA projB
    projects/common/bootstrap.pre
    A: projects/common/bootstrap
    A: projects/projA/bootstrap
    B: projects/common/bootstrap
    B: projects/projB/bootstrap
    projects/common/bootstrap.post

Each OVE project may also have a 'common' file within the project directory.
This 'common' file is sourced before the project command file is executed.

Example:

    $ ove build projC
    projects/common/build.pre
    C: projects/projC/common
    C: projects/projC/build

For convenience, each project command has access to a few OVE_ACTIVE_PROJECT_
variables:

| Environment variable       | Description                                  |
|----------------------------|----------------------------------------------|
| OVE_ACTIVE_PROJECT_COMMAND | Project command. E.g. 'build'                |
| OVE_ACTIVE_PROJECT_NAME    | Project name. E.g. 'projA'                   |
| OVE_ACTIVE_PROJECT_VERSION | Project version (if available). E.g. '1.4.1' |

You now know how to build sub projects together, but what about testing from a
system perspective? We cover that in the next section:

### The 'systests' and 'systests-groups' files

We have already covered how OVE keeps track of repos, how sub-project build
methods can be included and how they can all form a larger, top view project.
We also showed how these parts are built together using OVE's staging area. On
the same note, it also makes sense to provide a way to execute system tests,
tests that need more than one sub-project or repo to execute. As stipulated
earlier, OVE takes a rather defensive approach here. Quite often, test systems
already exist for most functionality you want to develop, at least partly. And
you want to re-use them. OVE is able to launch any tests as long as they can
execute from prompt. Two files, 'systests' and 'systests-groups' give OVE
information about what tests are available and how to execute them:

'systests' is a text file that contains a list of tests. One row is one test:

* name: unique identifier for the test
* timeout: time in seconds when the test should finish. 0 = no timeout.
* type:
   * 0 = 00b = run in fg
   * 1 = 01b = run in fg and abort test suite on errors
   * 2 = 10b = run in bg
   * 3 = 11b = run in bg and abort test suite on errors
* path: where to execute the test (either relative to OVE_BASE_DIR or an absolute path)
* command: command(s) to execute

Example:

    $ cat systests
    # name       timeout (s)   type   path   command
    # ----------------------------------------------
    t1              5          0      repoX  sleep 4
    t2              1          0      .      sleep 2
    t3           3600          0      repoY  ./long-duration-test
    t4              3          0      $HOME  echo hellu $LOGNAME; ls -l; whoami
    t5              3          0      /tmp   pwd

'systests-groups' is a YAML file that contains groups/sets of tests. Example:

    $ cat systests-groups
    all:
      - t1
      - t2
      - t3
    sanity:
      - t1

Using the above structure, you would be able to execute either one test (t1, t2
or t3), a series of them (t1 t2) or a test group ("all" or "sanity"). Asking
ove what test are available in this case would look like this:

    $ ove list-systests
    all
    sanity
    t1
    t2
    t3

That's it for system tests! Now lets go ahead and look at plugins:

## Plugins

As discussed in the Overview, in most larger projects there is a strong need
for flexibility when it comes to what a developer or CI/CD machinery wants to
be able to do with it. To accommodate these needs, OVE provides a way of
extending the OVE command list with customized commands. We call them plugins,
and they can be exposed to your OVE project in three ways: From your workspace,
from your OWEL (top repo) or from any repo included in the revtab. What are
they really then? They are executables, optionally accompanied with a help text
and/or a tab completion script. OVE looks for plugins at the following
locations:

    $OVE_OWEL_DIR/scripts/
    <all repositories>/.ove/scripts/

Any executable found in any of these locations will become an OVE command. And
provided that tab completion scripts and help texts exist at the same location,
they will also be part of the OVE help and support tab completion for their
arguments.

If you are using a plugin that reads from stdin AND you need this plugin within
a pipe, please use this construct:

    echo foo | ove-bar

We now covered the four main functionality areas of OVE. Next we will go
through how to make life easy for developers or CI/CD machines when it comes to
setting up an OVE project:

## Setup: an existing OVE project

An existing OVE project is typically setup (or downloaded if you will) by the
developer or CI/CD machine using the following oneliner:

    curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s <name> <OWEL>

* name: Path to the OVE workspace.
* OWEL: URL of the top git repository

The setup script will do two things:

* create the 'name' directory at your current location
* clone the OVE (ove itself) and OWEL (top repo) git repos

The 'setup' script will then urge the developer to enter the OVE workspace
directory and run

    source ove

Doing this, OVE will check that you have the required programs installed on
your machine and prompt for installation otherwise. This is the current list:

* bash (>=4.3)
* bzip2
* column
* file
* flock
* git (>=1.8.5)
* gzip
* ld
* less
* pgrep
* script
* tar
* tsort

OVE is also dependent on 'sed/grep/tail/awk/...' but they are not checked for
since it is quite uncommon to lack these. To unlock all OVE features you also
need:

* ag
* convert
* dig
* dot
* ffmpeg
* fzf
* graph-easy
* inotifywait
* jp2a
* incus
* locate
* make
* md5deep
* rg
* shellcheck
* sshpass
* strace
* task
* tmux
* tsp
* whois
* yamllint
* xdotool
* xpra

Run 'ove list-externals' or check [this page](doc/ove-externals-list.md) for a
complete list of commands that OVE is dependent on.

After successfully sourcing OVE, further instructions are given to enter the
OVE workspace and fetch the rest of the repos. When the fetch is completed,
everything is ready in order for man or machine to start working with the
project! For the sake of clarity, lets look at an example:

    $ curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s abc ssh://github.com/Ericsson/xyz
    Cloning into '.ove'...
    Cloning into 'xyz'...
    ...
    $ cd abc
    $ source ove
    OVE [SHA-1: ... @ Ubuntu 19.10]
    $ ove fetch
    Cloning into 'repoX'...
    Cloning into 'repoY'...
    ...
    repoX ## main..origin/main
    repoY ## main..origin/stable
    .ove  ## master..origin/master

Done! As simple as that. Lets give a final example of what an OVE project file
structure can look like when ready:

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
        │   ├── projC/
        │   │   ├── bootstrap
        │   │   ├── build
        │   │   ├── configure
        │   │   └── install
        │   └── common/
        │       └── build
        ├── projs
        ├── revtab
        ├── systests
        └── systests-groups

## Setup: track a few repos

Oneliner:

    git clone https://github.com/Ericsson/ove.git .ove && source .ove/ove

In this example you will end up with a complete OVE workspace.

Example:

    # '$HOME/src' has four git repositories
    $ cd $HOME/src
    $ git clone https://github.com/Ericsson/ove.git .ove && source .ove/ove
    ...
    Directory to scan for git repositories? Leave blank to search in '$HOME/src': [ENTER]
    OWEL name? Leave blank to name it 'top': [ENTER]
    Scanning '$HOME/src'. #repos: 5
    Initialized empty Git repository in $HOME/src/top/.git/
    Create example/skeleton files? (y/N) [ENTER]
    ...
    # you now have a OVE workspace in '$HOME/src' that contains six repos: four repos + OVE + OWEL
    # try 'ove status'
    $ ove status
    ...

## Setup: create an OWEL within a git repository

Oneliner:

    source <(curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/ove)

In this example you will create an OWEL within a git repository.

Example:

    $ cd a-git-repo
    $ source <(curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/ove)
    # the commands below will:
    #   - create a git commit of the OWEL specific files
    #   - publish the OWEL commit upstream
    #   - print OVE oneliner
    #   - try the oneliner _after_ the push
    #   - remember to run the oneliner outside of the 'foo' repo
    # create a git commit
    git add projects projs revtab scripts SETUP systests systests-groups && git commit -m "initial commit"
    # publish the commit
    git push
    # OVE oneliner
    curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s foo https://...

## Setup: create an OWEL within a git repository using 'ove init'

Oneliner:

    ove init

Same as above except that OVE is already available on the host.

    # an existing OVE workspace
    $ source ove
    # move to a git repository
    $ cd a-git-repo
    $ ove init
    ...
    # create a git commit
    git add projects projs revtab scripts SETUP systests systests-groups && git commit -m "initial commit"
    # publish the commit
    git push
    # OVE oneliner
    curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s bar https://...

Up until now we covered everything you need to know to get to the point where
developers (or machines) can start working with your OVE project. Going through
these steps, You might have noticed us mention OVE commands several times. It
is time to have a closer look at how they work:

## Commands

OVE will enhance your bash shell with commands to manage your OVE based
project. We divide them into the following categories:

| Category | Description                   | Example             |
|----------|-------------------------------|---------------------|
| BUILD    | Build commands                | buildme, mrproper   |
| CORE     | High level git commands       | status, diff, fetch |
| DEBUG    | Debug commands                | loglevel            |
| INSTANCE | Instance commands             | create-instance     |
| INTERNAL | Internal commands             | unittest            |
| LOG      | Show and manipulate logs      | l, lastlog          |
| PLUGIN   | Plugins/scripts               |                     |
| REMOTE   | Remote commands               | run-remote          |
| SEARCH   | Search repos                  | grep, ag, rg        |
| TEST     | Test commands                 | systest             |
| UTIL     | Utility commands              | vi

### CORE

OVE implements a subset of the standard git commands as "high level" git
commands. These commands executes the corresponding git command on all (or
selective) **revtab** repositories.

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
* stash
* worktree

### BUILD

This is a list of build related commands:

* buildme / buildme-parallel
* make
* mrproper

The above list will be dynamically populated with project commands found under
the "projects/proj/" directories. So, for a "normal" OVE project, these
commands are usually also present:

* bootstrap
* configure
* build
* install

Note: For each project command there is a "command-parallel" version of that
command.

### INSTANCE

The 'ove create-instance" command is a wrapper on top of incus. Features:

* map OVE workspace
* create UID mapped user
* install OpenSSH server
* update ssh-config
* install Desktop Environment
* replicate OVE workspace to incus cluster members

Example:

    # steps:
    #   ove        use the OVE workspace (map it or by running the oneliner) within an instance
    #   running    leave the instance running
    #   ssh        install sshd within the instance and use ssh instead of 'incus exec'
    #   ssh_config update $HOME/.ssh/config with host entries
    #   stopped    leave the instance in stopped state
    #   user       run jobs as user
    #   verbose    debug printouts
    #   worktree   run entry within an OVE worktree
    #   X          Xpra+Xfce
    #
    # run 'ove entry foo' within a Ubuntu 24.04 container, run the job as user, delete the container when done
    export OVE_INSTANCE_STEPS="user ove"
    ove create-instance foo ubuntu/24.04/amd64

    # run a local script "test.sh" within Ubuntu 24.04, enable debug prints, leave the container running
    echo "set -x;date;whoami;hostname;ip addr" > test.sh
    export OVE_INSTANCE_STEPS="running verbose"
    ove create-instance test.sh ubuntu/24.04/amd64

    # in tmux run 'ove entry ag' within three Linux distributions at the same time, run the job as root, leave the containers running
    export OVE_INSTANCE_STEPS="ove running"
    ove create-instance-parallel ag alpine/edge/amd64 fedora/40/amd64 ubuntu/24.04/amd64

    # install Xpra
    bash ${OVE_DIR:?}/hooks/xpra/pre-create-instance

    # attach to a Xfce desktop running within an Alpine container 'alice', enable debug prints, leave the container running
    export OVE_INSTANCE_NAME="alice"
    export OVE_INSTANCE_STEPS="running verbose X"
    export OVE_INSTANCE_XPRA_CLIENT_ARGS="attach"
    ove create-instance true alpine/edge/amd64
    # re-attach
    xpra attach --ssh=ssh ssh://alice

    # add an image remote server
    incus remote add docker https://docker.io --protocol=oci
    # check nginx version
    export OVE_INSTANCE_NAME="nginx"
    export OVE_INSTANCE_STEPS="running"
    ove create-instance 'nginx -v' docker:nginx

### UTIL

Here's a list (not complete) of a few utility commands:

| Command                  | Description                                                |
|--------------------------|------------------------------------------------------------|
| forall/forall-parallel   | run an arbitrary command for all git repositories          |
| forowel/forowel-parallel | run an arbitrary command in all OVE workspaces on the host |
| locate                   | list OVE workspaces on this host                           |
| news                     | view upstream news for each git repository                 |
| cd                       | switch to another OVE workspace                            |
| vi                       | open all modified files in 'vi'                            |

### Command reference

Please find the full command reference [here](doc/ove-cmd-list.md)

### Invocation

Each OVE command can be invoked using four different methods: normal, quick, queue or
remote. The table below tries to explain the differencies on a few aspects.

| method    | performance impact | hooks | log | debug | example                      |
|-----------|--------------------|-------|-----|-------|------------------------------|
| normal    | yes                | yes   | yes | yes   | ove ls-files                 |
| quick     | no                 | no    | no  | no    | ove-ls-files                 |
| queue     | yes                | yes   | yes | no    | OVE_BATCH_IT=1 ove ls-files  |
| remote    | maybe              | maybe | yes | maybe | OVE_REMOTE_IT=1 ove ls-files |

Example:

    # method: normal
    #
    # ls-files command can take a while
    $ time ove ls-files
    ...
    real 0m2,011s
    # the output (and input) of the ls-files command is saved and you can use LOG commands to view or replay the output
    $ ove list-commands LOG
    ...
    # run strace in background and filter on all execve calls
    # ove loglevel 3
    $ ove ls-files
    ...

    # method: quick
    #
    # ls-files using the quick invocation method
    $ time ove-ls-files
    ...
    real 0m0,949s

    # method: queue
    #
    # queue the ls-files command, the command will silently be run in background
    $ time OVE_BATCH_IT=1 ove ls-files
    0
    real 0m0,193 s
    # check task spooler status
    $ ove ts
    ...

    # method: remote
    #
    # run the ls-files command on a few remote hosts (tmux)
    $ time OVE_REMOTE_IT=1 ove ls-files
    real 0m0,949s
    # run the ls-files command on a few remote hosts (no tmux)
    $ time OVE_REMOTE_IT=1 ove ls-files
    real 0m10,858s
    # run the ls-files command on localhost and a few remote hosts (no tmux)
    $ time OVE_REMOTE_IT=2 ove ls-files
    real 0m11,237s

## Configuration

Configurable OVE commands can be found [here](doc/ove-config-list.md)

## Environment variables

A list of OVE environment variables that will remain stable across OVE versions
can be found [here](doc/ove-variables-list.md).

## Supported Linux distributions

OVE has been tested for the following Linux distributions:

| Distribution        | Release(s)   |
|---------------------|--------------|
| AlmaLinux           | 9, 10        |
| Alpine Linux        | 3.15..3.22   |
| Arch Linux          | N/A          |
| Debian              | 10..13       |
| Devuan              | 3..5         |
| Fedora              | 36..43       |
| Kali                | N/A          |
| Linux Mint          | Uma..Wilma   |
| NixOS               | 25.05        |
| openSUSE Tumbleweed | N/A          |
| Ubuntu              | 16.04..24.04 |
| Void Linux          | N/A          |

Want to know more about OVE? Please check out the OVE
[tutorial](https://github.com/Ericsson/ove-tutorial) or ask OVE:

    ove help
