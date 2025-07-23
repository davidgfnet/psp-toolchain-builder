
pspdev toolchain builder
========================

This is an attempt at rebooting a new build system for pspdev's toolchains.

Goals
-----

The main goal is to provide a build system that is hermetic and reproducible.
For this, we must guarantee that builds require no internet connection and that
a self-contained _source_ tarball exists, so that it can be built at any time
(ie. for regression testing purposes, homebrew maintenability, etc).

It is quite common that changes in the pspdev toolchain (usually the PSPSDK
or some ports/packages) breaks some homebrew, which can be quite frustrating.
This build system allows homebrews to remain at a specific toolchain version
and have a much reasonable upgrade path.

How does this work
------------------

This repo is a bunch of pkgbuild-like files that contain build recipes for the
different toolchain and ports components. The idea behind it is to be able to
reuse the packages db already existing in the ecosystem (pspdev/psp-packages).

To build on this I've created a bunch of packages for the toolchain components
(ie. binutils, gcc, newlib, etc.) and added the right sequencing and
dependencies to them.

There's a driver script (builder.sh) that orchestrates the whole thing, as well
as a Makefile for ease of use.

The build system consists of two parts/processes:

  - Source build: fetches all the dependencies, sources and requires sources
    (tarballs or git repos) and packages them. This generates a source tarball
    that can be build completely offline. This package is platform independent.

  - Binary build: Uses the package description (pkgbuild files), source
    tarballs and a couple of scripts to build all the components and generate
    a binary release (also a tarball).

Maintenance
-----------

The script `tools/packages-import.py` can import PSPBUILD files from the
pspdev/psp-packages repo. It does some processing such as changing some
dependencies and copying them into a slightly different directory structure.
In general we just have a single file for each package, unless it has some
local files (ie. patches), for which we create a subdir.

Supported builds
----------------

Added support for Fedora (.spec) and Ubuntu (debian/) packaging.
For now I maintain these builds:

 - Fedora (copr): https://copr.fedorainfracloud.org/coprs/davidgf/pspdev/
   `#> dnf copr enable davidgf/pspdev`
 - Ubuntu (launchpad): https://launchpad.net/~david-davidgf/+archive/ubuntu/pspdev
   `#> add-apt-repository ppa:david-davidgf/pspdev`

