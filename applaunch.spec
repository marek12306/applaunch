Name:           applaunch
Version:        0.1.2
Release:        3
Summary:        Launcher and dock for the Niri compositor

License:        GPL-3.0-or-later
URL:            https://github.com/marek12306/applaunch
# Sources can be obtained by
# git clone https://github.com/marek12306/applaunch
# cd applaunch
# tito build --tgz
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  meson
BuildRequires:  ninja
BuildRequires:  vala 
BuildRequires:  gcc
BuildRequires:  pkgconfig(glib-2.0) 
BuildRequires:  pkgconfig(gobject-2.0) 
BuildRequires:  pkgconfig(gtk4) 
BuildRequires:  pkgconfig(libadwaita-1) 
BuildRequires:  pkgconfig(gtk4-layer-shell-0) 
BuildRequires:  pkgconfig(gio-unix-2.0) 
BuildRequires:  pkgconfig(gio-2.0) 
BuildRequires:  pkgconfig(appstream) 
BuildRequires:  pkgconfig(json-glib-1.0) 
BuildRequires:  pkgconfig(gee-0.8) 

Requires:       niri
Requires:       qalculate
Requires:       plocate

%description
Applaunch is an opinionated application launcher and dock designed specifically 
for the Niri compositor.

%prep
%autosetup

%build
%meson
%meson_build

%install
%meson_install

%files
%license LICENSE
%doc README.md
%{_bindir}/%{name}

%changelog
* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.2-3
- require ninja instead of ninja-build for better compatibility between distributions

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.1-2
- fix: yes (marek12306@gmail.com)

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.0-1
- Initial package build

