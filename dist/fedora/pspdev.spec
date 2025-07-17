%global pspdev_version 1.0.0-0b069ec

Name:           pspdev
Epoch:          1
Version:        1.0.0
Release:        1%{?dist}
Summary:        pspdev toolchain and SDK for PSP

License:        GPLv2+ and GPLv3+ and LGPLv2+ and BSD and MIT and AFL
URL:            https://github.com/pspdev

Source0:        pspdev-%{pspdev_version}-source.tgz

BuildRequires:	autoconf automake pkgconf openssl-devel texinfo bison flex libarchive-devel
BuildRequires:	make ncurses-devel wget bc gmp-devel mpfr-devel libmpc-devel
BuildRequires:  gcc gcc-c++ git gpgme-devel python3 python3-pip fakeroot bsdtar
BuildRequires:  zlib-devel make cmake libtool gettext gettext-devel doxygen tcl readline-devel
BuildRequires:  zlib bzip2 xz libzstd-devel
Requires:       glibc libgcc mpfr gmp libmpc libzstd zlib ncurses
AutoReqProv: no

BuildRequires: libusb-compat-0.1-devel

%undefine _missing_build_ids_terminate_build
%global debug_package %{nil}
%global __strip /bin/true
%global _build_id_links alldebug

%description
pspdev toolchain for PSP. Includes toolchain (binutils, gcc, newlib), SDK (pspsdk)
and several library ports, including PSP-specific libraries.

%prep
%setup -q -c

%build
%undefine _auto_set_build_flags
export PSPDEV=%{buildroot}/opt/pspdev
export PATH=$PATH:$PSPDEV/bin
mkdir -p %{buildroot}/opt/pspdev
make build-all
rm -f %{buildroot}/opt/pspdev/psp/bin/{sq_static,sq}

%files
/opt/pspdev/*

%changelog
* Mon Jul 07 2025 David Guillen Fandos <david@davidgf.net> - v1
- First attempt


