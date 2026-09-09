Name:           ttmux
Version:        1.5.0
Release:        1%{?dist}
Summary:        Wrapper tmux pour attacher, lister ou créer une session avec un profil

License:        MIT
URL:            https://github.com/NCombarieu/ttmux
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       tmux
Requires:       bash
BuildRequires:  tmux
BuildRequires:  bash

%description
ttmux est un wrapper bash autour de tmux qui simplifie l'attache, la
création et le setup d'une session. Il peut charger un fichier de profil
(par défaut ~/.ttmux/base) avec directive include, et appliquer une suite
de splits et de commandes décrits soit dans le profil, soit en ligne de
commande, soit les deux : splits (avec taille en pourcentage), fenêtres
nommées, commandes envoyées à chaque pane et répertoire de travail. Le
mode --dry-run affiche les commandes tmux sans rien exécuter. La
complétion bash et zsh est fournie : sessions tmux existantes, profils de
~/.ttmux, flags et commandes.

%prep
%setup -q

%build
# Rien à compiler — script bash + man page.

%check
bash tests/run.sh

%install
install -D -m 0755 ttmux %{buildroot}%{_bindir}/ttmux
install -D -m 0644 ttmux.1 %{buildroot}%{_mandir}/man1/ttmux.1
install -D -m 0644 completions/ttmux.bash %{buildroot}%{_datadir}/bash-completion/completions/ttmux
install -D -m 0644 completions/_ttmux %{buildroot}%{_datadir}/zsh/site-functions/_ttmux

%files
%{_bindir}/ttmux
%{_mandir}/man1/ttmux.1*
%{_datadir}/bash-completion/completions/ttmux
%{_datadir}/zsh/site-functions/_ttmux

%changelog
* Wed Sep 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.5.0-1
- Nouveaux flags : -V/--version, -d/--detach (créer sans attacher),
  -C/--cd <dir> (répertoire de travail de la session), -w/--window <nom>
  (nouvelle fenêtre), -h<N>/-v<N> (taille de split en pourcentage) et
  --dry-run (affiche les commandes tmux sans rien exécuter).
- « -- » termine désormais l'analyse des options : un nom de session peut
  commencer par un tiret.
- Un « include » introuvable est désormais une erreur au lieu d'être
  silencieusement ignoré, et une ligne de profil mal quotée est signalée.
- Les flags de setup sont validés AVANT la création : plus de session à
  moitié montée quand un profil contient un flag inconnu.
- « ttmux list » sans serveur tmux affiche un message clair au lieu de
  l'erreur brute de tmux ; le routage compte les sessions via
  « tmux list-sessions -F » au lieu d'analyser « tmux ls ».
- Refus explicite des noms de session contenant « : » ou « . ».
- Variable d'environnement TTMUX_PROFILE_DIR pour déplacer ~/.ttmux.
- Suite de tests (tests/run.sh, « make test ») et sources shellcheck-clean.

* Wed Sep 09 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.4.0-1
- Complétion bash et zsh : sessions tmux existantes, profils de ~/.ttmux
  (et chemins), flags courts et longs, commandes pour -c.
- Aide (--help) restructurée avec des exemples pour chaque fonctionnalité.
- Man page : section COMPLETION et exemples supplémentaires.

* Thu May 14 2026 Noel Combarieu <noel.combarieu@gmail.com> - 1.3.0-1
- Ajout du flag -l / --list et de la sous-commande "list" pour afficher
  les sessions tmux existantes (délègue à `tmux ls`).

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
