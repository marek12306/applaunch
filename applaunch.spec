Name:           applaunch
Version:        0.3.1
Release:        1
Summary:        Launcher and dock for the Niri compositor

License:        GPL-3.0-or-later
URL:            https://github.com/marek12306/applaunch
# Sources can be obtained by
# git clone https://github.com/marek12306/applaunch
# cd applaunch
# tito build --tgz
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  meson
%if 0%{?suse_version}
BuildRequires:  ninja
%else
BuildRequires:  ninja-build
%endif
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
* Sun Mar 22 2026 deepivin <marek12306@gmail.com> 0.3.1-1
- feat: fix irregular button width in dock (marek12306@gmail.com)
- feat: improve Unicode search (marek12306@gmail.com)

* Sat Mar 21 2026 deepivin <marek12306@gmail.com> 0.3.0-1
- feat: use Event Stream instead of polling windows manually
  (marek12306@gmail.com)
- fix: dock not showing up (marek12306@gmail.com)

* Sat Mar 14 2026 deepivin <marek12306@gmail.com> 0.2.0-1
- refactor: use Gtk.FileLauncher instead of xdg-open (marek12306@gmail.com)
- refactor: use AppInfo.launch instead of calling gio launch
  (marek12306@gmail.com)
- refactor: use niri ipc directly (marek12306@gmail.com)
- fix: language (marek12306@gmail.com)

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.3-1
- fix: race condition in dock reloading and initialization
  (marek12306@gmail.com)

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.2-6
- test 2

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.2-5
- test

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.2-4
- so I was mistaken then

* Fri Mar 13 2026 deepivin <marek12306@gmail.com>
- so I was mistaken then

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.2-3
- require ninja instead of ninja-build for better compatibility between distributions

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.1-2
- fix: yes (marek12306@gmail.com)

* Fri Mar 13 2026 deepivin <marek12306@gmail.com> 0.1.0-1
- Initial package build

