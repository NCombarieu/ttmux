# ttmux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-1f425f.svg)](ttmux)
[![Platform: Fedora](https://img.shields.io/badge/platform-Fedora-294172.svg)](#installation)

Wrapper [tmux](https://github.com/tmux/tmux) pour attacher, lister ou créer
une session avec un setup (splits + commandes), en CLI ou via un fichier
de profil.

```sh
ttmux dev -c 'cd ~/proj && nvim' -h -c 'ssh prod-host' -v -c 'htop'
```

## Sommaire

- [Pourquoi](#pourquoi)
- [Installation](#installation)
- [Usage](#usage)
- [Profils](#profils)
- [Construction du RPM](#construction-du-rpm)
- [Licence](#licence)

## Pourquoi

`tmux` est puissant mais verbeux pour les opérations courantes :

- attacher la session existante quand il n'y en a qu'une
- créer une session nommée si elle n'existe pas, l'attacher sinon
- décrire d'un coup une layout (splits) et la commande à lancer dans
  chaque pane
- factoriser des layouts récurrents dans des profils réutilisables

`ttmux` enveloppe ces cas dans une seule commande, sans remplacer `tmux`
(auquel il délègue tout).

## Installation

Prérequis : `tmux` (résolu automatiquement par le RPM) et une distribution
RPM-based (Fedora, RHEL, AlmaLinux, Rocky…).

### Depuis le RPM publié sur GitHub Releases

Récupérer le `.rpm` depuis [Releases](https://github.com/NCombarieu/ttmux/releases/latest)
puis :

```sh
sudo dnf install ./ttmux-*.noarch.rpm
```

Installe `/usr/bin/ttmux` (disponible pour tous les utilisateurs) et
`/usr/share/man/man1/ttmux.1.gz`.

### Depuis les sources

```sh
git clone git@github.com:NCombarieu/ttmux.git
cd ttmux
make rpm                 # produit le RPM dans ~/rpmbuild/RPMS/noarch/
sudo dnf install ~/rpmbuild/RPMS/noarch/ttmux-*.noarch.rpm
```

Prérequis pour build : `rpm-build` et `rpmdevtools`
(`sudo dnf install rpm-build rpmdevtools`).

### Sans RPM (autres distributions)

```sh
sudo make install        # installe dans /usr/bin et /usr/share/man/man1
```

### Désinstallation

```sh
sudo dnf remove ttmux               # si installé via RPM
sudo rm /usr/bin/ttmux /usr/share/man/man1/ttmux.1*  # si installé via make install
```

## Usage

> Profil et flags de setup sont appliqués **uniquement à la création**
> d'une session. Sur une session existante, `ttmux` attache simplement
> (et émet un warning si des flags ou un `-p` explicite étaient passés).

### Sans nom de session

| État de tmux | Comportement                                              |
|--------------|-----------------------------------------------------------|
| 0 session    | crée `main` (profil appliqué si présent) puis attache     |
| 1 session    | l'attache (warning si flags ignorés)                      |
| 2+ sessions  | affiche la liste (`tmux ls`)                              |

### Avec un nom

```sh
ttmux work       # attache 'work' si elle existe, sinon la crée
                 # le profil ~/.ttmux/base est appliqué uniquement à la création
```

### Setup initial en CLI

Les flags sont appliqués **dans l'ordre** sur le pane courant. Un split
rend le nouveau pane actif pour les flags suivants.

| Flag             | Effet                                                    |
|------------------|----------------------------------------------------------|
| `-c <cmd>`       | envoie `<cmd>` + Entrée dans le pane courant             |
| `-h`             | split horizontal (nouveau pane à droite, devient actif)  |
| `-v`             | split vertical (nouveau pane en bas, devient actif)      |
| `-p <nom\|chemin>` | charge un profil au lieu de `base`                     |
| `-N`             | désactive le chargement du profil par défaut             |

Exemple — éditeur à gauche, SSH en haut à droite, `htop` en bas à droite :

```sh
ttmux dev -N -c 'cd ~/proj && nvim' -h -c 'ssh prod-host' -v -c 'htop'
```

L'ordre d'application est toujours **profil d'abord, CLI ensuite**.

### Aide

```sh
ttmux --help     # aide en ligne
man ttmux        # page de manuel complète (après install RPM)
```

## Profils

Les profils vivent dans `~/.ttmux/`. Un fichier de profil contient les
mêmes flags que la CLI, un ou plusieurs par ligne. Les lignes vides et
celles commençant par `#` sont ignorées.

`~/.ttmux/base` est chargé automatiquement à chaque appel (sauf `-N`).
N'importe quel autre nom est chargé via `-p <nom>` (ou `-p <chemin>`
pour pointer ailleurs que dans `~/.ttmux/`).

### Exemple

`~/.ttmux/common` :

```
-c 'cd ~/proj'
```

`~/.ttmux/base` :

```
include common
-c 'nvim'
-h -c 'ssh prod-host'
-v -c 'htop'
```

### Directive `include`

`include <nom|chemin>` inclut récursivement un autre profil :

| Forme                | Résolution                                          |
|----------------------|-----------------------------------------------------|
| `/abs/path`          | utilisé tel quel                                    |
| `./foo`, `../foo`, `dir/foo` | relatif au fichier courant                |
| `nom` (sans `/`)     | `~/.ttmux/<nom>` si présent, sinon relatif au fichier courant |

Les inclusions cycliques sont détectées et ignorées (chaque fichier est
parcouru au plus une fois par invocation).

### Choix d'un profil alternatif

```sh
ttmux dev -p cnetcv          # charge ~/.ttmux/cnetcv
ttmux dev -p ./foo.conf      # charge un chemin
ttmux dev -N                 # ne charge AUCUN profil
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
