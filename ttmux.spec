Name:           ttmux
Version:        1.0.0
Release:        1%{?dist}
Summary:        Wrapper tmux pour attacher, lister ou créer une session avec un setup

License:        MIT
URL:            https://example.invalid/ttmux
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       tmux
Requires:       bash

%description
ttmux est un wrapper bash autour de tmux qui simplifie les opérations
courantes : attacher à une session existante, en créer une nouvelle, ou
lister les sessions disponibles. Il permet aussi de décrire en ligne de
commande la disposition initiale (splits) et les commandes à envoyer dans
chaque pane d'une nouvelle session.

%prep
%setup -q

%build
# Rien à compiler — script bash + man page.

%install
install -D -m 0755 ttmux %{buildroot}%{_bindir}/ttmux
install -D -m 0644 ttmux.1 %{buildroot}%{_mandir}/man1/ttmux.1

%files
%{_bindir}/ttmux
%{_mandir}/man1/ttmux.1*

%changelog
* Sat May 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.0.0-1
- Première version : commande ttmux + man page.
