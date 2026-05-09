Name:           ttmux
Version:        1.2.0
Release:        1%{?dist}
Summary:        Wrapper tmux pour attacher, lister ou créer une session avec un profil

License:        MIT
URL:            https://github.com/NCombarieu/ttmux
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       tmux
Requires:       bash

%description
ttmux est un wrapper bash autour de tmux qui simplifie l'attache, la
création et le setup d'une session. Il peut charger un fichier de profil
(par défaut ~/.ttmux/base) avec directive include, et appliquer une suite
de splits et de commandes décrits soit dans le profil, soit en ligne de
commande, soit les deux.

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
* Sat May 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.2.0-1
- Profil et flags de setup appliqués UNIQUEMENT à la création d'une
  session. Sur une session existante, simple attache ; warning si des
  flags ou un -p explicite étaient passés.
- README : mention des Releases GitHub et section désinstallation.

* Sat May 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.1.0-1
- Support des profils ~/.ttmux/<nom> (par défaut "base").
- Flag -p pour choisir un profil (nom ou chemin).
- Flag -N pour désactiver le chargement du profil.
- Directive "include" pour composer plusieurs profils (cycles ignorés).

* Sat May 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.0.0-1
- Première version : commande ttmux + man page.
