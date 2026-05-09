# ttmux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-1f425f.svg)](ttmux)
[![Platform: Fedora](https://img.shields.io/badge/platform-Fedora-294172.svg)](#installation)

Wrapper [tmux](https://github.com/tmux/tmux) pour attacher, lister ou créer
une session avec un setup (splits + commandes) en une seule ligne de
commande.

```sh
ttmux dev -c 'cd ~/proj && nvim' -h -c 'ssh prod-host' -v -c 'htop'
```

## Sommaire

- [Pourquoi](#pourquoi)
- [Installation](#installation)
- [Usage](#usage)
- [Construction du RPM](#construction-du-rpm)
- [Licence](#licence)

## Pourquoi

`tmux` est puissant mais verbeux pour les opérations courantes :

- attacher la session existante quand il n'y en a qu'une
- créer une session nommée si elle n'existe pas, l'attacher sinon
- décrire d'un coup une layout (splits) et la commande à lancer dans
  chaque pane

`ttmux` enveloppe ces trois cas dans une seule commande, sans
remplacer `tmux` (auquel il délègue tout).

## Installation

### Depuis le RPM (Fedora / RHEL)

```sh
sudo dnf install ./ttmux-1.0.0-1.fc44.noarch.rpm
```

Installe `/usr/bin/ttmux` et `/usr/share/man/man1/ttmux.1.gz`. La
dépendance `tmux` est résolue automatiquement.

### Depuis les sources

```sh
git clone git@github.com:NCombarieu/ttmux.git
cd ttmux
make rpm                 # produit le RPM dans ~/rpmbuild/RPMS/noarch/
sudo dnf install ~/rpmbuild/RPMS/noarch/ttmux-*.noarch.rpm
```

### Sans RPM (autres distributions)

```sh
sudo make install        # installe dans /usr/bin et /usr/share/man/man1
```

## Usage

### Sans argument

| État de tmux | Comportement                              |
|--------------|-------------------------------------------|
| 0 session    | crée la session `main` et l'attache       |
| 1 session    | l'attache directement                     |
| 2+ sessions  | affiche la liste (équivalent `tmux ls`)   |

### Avec un nom

```sh
ttmux work       # attache 'work' si elle existe, sinon la crée vide
```

### Avec un setup initial

Les flags sont appliqués **dans l'ordre** sur le pane courant. Un split
rend le nouveau pane actif pour les flags suivants.

| Flag        | Effet                                                    |
|-------------|----------------------------------------------------------|
| `-c <cmd>`  | envoie `<cmd>` + Entrée dans le pane courant             |
| `-h`        | split horizontal (nouveau pane à droite, devient actif)  |
| `-v`        | split vertical (nouveau pane en bas, devient actif)      |

Exemple — éditeur à gauche, SSH en haut à droite, `htop` en bas à droite :

```sh
ttmux dev -c 'cd ~/proj && nvim' -h -c 'ssh prod-host' -v -c 'htop'
```

Si la session `dev` existe déjà, les flags sont ignorés (avec un
avertissement) et la session est simplement attachée.

### Aide

```sh
ttmux --help     # aide en ligne
man ttmux        # page de manuel complète (après install RPM)
```

## Construction du RPM

```sh
make rpm         # tarball + rpmbuild -bb (utilise ~/rpmbuild)
make clean       # nettoie le tarball
make distclean   # nettoie aussi le BUILD/ et les RPM produits
```

Pour bumper la version : éditer `VERSION` dans `Makefile` et `Version`
dans `ttmux.spec`, ajouter une entrée `%changelog`, puis `make rpm`.

## Licence

[MIT](LICENSE)
