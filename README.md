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
- [Complétion](#complétion)
- [Profils](#profils)
- [Développement](#développement)
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

Prérequis : `tmux` >= 3.1 (résolu automatiquement par le RPM) et une distribution
RPM-based (Fedora, RHEL, AlmaLinux, Rocky…).

### Via le dépôt DNF (recommandé — permet `dnf update`)

```sh
sudo curl -o /etc/yum.repos.d/ttmux.repo \
  https://ncombarieu.github.io/ttmux/ttmux.repo
sudo dnf install ttmux
```

Les mises à jour sont ensuite disponibles via `dnf update ttmux`.

### Depuis le RPM publié sur GitHub Releases

Récupérer le `.rpm` depuis [Releases](https://github.com/NCombarieu/ttmux/releases/latest)
puis :

```sh
sudo dnf install ./ttmux-*.noarch.rpm
```

Installe `/usr/bin/ttmux` (disponible pour tous les utilisateurs), la page
de manuel `/usr/share/man/man1/ttmux.1.gz` et la
[complétion](#complétion) bash et zsh.

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
sudo dnf remove ttmux               # si installé via RPM ou dépôt
# si installé via make install :
sudo rm /usr/bin/ttmux /usr/share/man/man1/ttmux.1* \
        /usr/share/bash-completion/completions/ttmux \
        /usr/share/zsh/site-functions/_ttmux
# Supprimer aussi le dépôt si ajouté :
sudo rm /etc/yum.repos.d/ttmux.repo
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

### Lister les sessions

```sh
ttmux list      # ou : ttmux -l, ttmux --list
```

Délègue à `tmux ls` et termine. Utile pour forcer l'affichage de la
liste même quand 0 ou 1 session existe (cas où un `ttmux` nu attacherait
ou créerait à la place).

### Avec un nom

```sh
ttmux work       # attache 'work' si elle existe, sinon la crée
                 # le profil ~/.ttmux/base est appliqué uniquement à la création
```

### Setup initial en CLI

Les flags sont appliqués **dans l'ordre** sur le pane courant. Un split
rend le nouveau pane actif pour les flags suivants.

Flags de **layout** (appliqués dans l'ordre, sur le pane courant) :

| Flag                  | Effet                                                    |
|-----------------------|----------------------------------------------------------|
| `-c <cmd>`            | envoie `<cmd>` + Entrée dans le pane courant             |
| `-h`, `-h<N>`         | split horizontal (pane à droite, devient actif) ; `<N>` = % de largeur |
| `-v`, `-v<N>`         | split vertical (pane en bas, devient actif) ; `<N>` = % de hauteur |
| `-w`, `--window <nom>`| nouvelle fenêtre nommée (devient courante)               |

Autres flags :

| Flag                  | Effet                                                    |
|-----------------------|----------------------------------------------------------|
| `-p`, `--profile <nom\|chemin>` | charge un profil au lieu de `base`            |
| `-N`, `--no-config`   | désactive le chargement du profil par défaut             |
| `-C`, `--cd <dir>`    | répertoire de travail de la session créée                |
| `-d`, `--detach`      | crée et configure la session sans l'attacher             |
| `--dry-run`           | affiche les commandes tmux au lieu de les exécuter       |
| `-l`, `--list`        | liste les sessions tmux (équivalent : `ttmux list`)      |
| `--`                  | fin des options : l'argument suivant est le nom de session |
| `-V`, `--version`     | affiche la version                                       |

Exemple — éditeur à gauche, SSH en haut à droite, `htop` en bas à droite :

```sh
ttmux dev -N -c 'cd ~/proj && nvim' -h -c 'ssh prod-host' -v -c 'htop'
```

L'ordre d'application est toujours **profil d'abord, CLI ensuite**.

Quelques variantes :

```sh
ttmux dev -N -c nvim -h25 -c 'watch make test'   # sidebar de 25 %
ttmux dev -N -c nvim -w logs -c 'journalctl -f'  # deux fenêtres nommées
ttmux api -C ~/proj/api -d -c 'make run'         # préparée, non attachée
ttmux -- -scratch                                # nom commençant par un tiret
```

### Vérifier sans rien lancer

`--dry-run` affiche les commandes `tmux` qui seraient exécutées, sans
créer quoi que ce soit — pratique pour déboguer un profil et son ordre
d'application :

```console
$ ttmux dev -p cnetcv --dry-run
tmux new-session -d -s dev -c /home/noel/proj
tmux send-keys -t '<pane0>' nvim C-m
tmux split-window -h -l 30% -t '<pane0>'
tmux send-keys -t '<pane1>' 'ssh prod-host' C-m
tmux attach-session -t =dev
```

`<paneN>` est la cible symbolique du pane courant : `N` s'incrémente à
chaque split et à chaque nouvelle fenêtre.

### Aide

```sh
ttmux --help     # aide en ligne, avec un exemple par fonctionnalité
man ttmux        # page de manuel complète (après install RPM)
```

## Complétion

Le paquet installe la complétion **bash** et **zsh**. Elle est active dans
tout nouveau shell ; pour l'activer immédiatement dans le shell bash
courant :

```sh
source /usr/share/bash-completion/completions/ttmux
```

Ce qui est complété :

| Contexte                 | Candidats proposés                                    |
|--------------------------|-------------------------------------------------------|
| `ttmux <TAB>`            | sessions tmux existantes + sous-commande `list`       |
| `ttmux -<TAB>`           | flags courts et longs                                 |
| `ttmux dev -p <TAB>`     | fichiers de `~/.ttmux/`                               |
| `ttmux dev -p ./<TAB>`   | complétion de chemin (dès un `/` ou un `~`)           |
| `ttmux dev -c <TAB>`     | commandes disponibles dans le `PATH`                  |
| `ttmux dev -C <TAB>`     | répertoires                                           |

Les modes exclusifs (`list`, `-l`, `--list`, `--help`, `-V`, `--version`)
ne proposent plus
rien après eux, et le nom de session n'est proposé qu'une fois, puisqu'un
seul argument positionnel est accepté.

```sh
ttmux <TAB>              # → list  main  work
ttmux work -p <TAB>      # → base  cnetcv  common
ttmux work -c ngi<TAB>   # → nginx
```

Fichiers installés :

```
/usr/share/bash-completion/completions/ttmux
/usr/share/zsh/site-functions/_ttmux
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
parcouru au plus une fois par invocation). En revanche une inclusion
**introuvable**, un flag inconnu ou une ligne mal quotée sont des
erreurs : `ttmux` s'arrête *avant* de créer la session, qui n'est donc
jamais laissée à moitié montée.

Les flags acceptés dans un profil sont les flags de layout (`-c`, `-h`,
`-v`, `-w`) et `-C`. Un `-C` passé en ligne de commande l'emporte sur
celui du profil.

### Choix d'un profil alternatif

```sh
ttmux dev -p cnetcv          # charge ~/.ttmux/cnetcv
ttmux dev -p ./foo.conf      # charge un chemin
ttmux dev -N                 # ne charge AUCUN profil
```

La variable d'environnement `TTMUX_PROFILE_DIR` remplace `~/.ttmux` si
l'on veut ranger ses profils ailleurs.

## Développement

```sh
make test        # suite de tests (bash + tmux, aucune autre dépendance)
make test T=profile   # ne joue que les tests dont le nom contient "profile"
make lint        # shellcheck sur ttmux, les tests et la complétion bash
```

Les tests tournent contre un serveur tmux jetable (`TMUX_TMPDIR` dédié) et
un répertoire de profils temporaire : ni les sessions ni la configuration
de l'utilisateur ne sont touchées. Ils sont aussi joués en `%check` lors du
`rpmbuild`.

## Construction du RPM

```sh
make rpm         # tarball + rpmbuild -bb (utilise ~/rpmbuild)
make clean       # nettoie le tarball
make distclean   # nettoie aussi le BUILD/ et les RPM produits
```

Pour bumper la version : éditer `VERSION` dans `Makefile`, `Version` dans
`ttmux.spec`, `VERSION` dans `ttmux` et l'en-tête `.TH` de `ttmux.1`,
ajouter une entrée `%changelog`, puis `make rpm`. Un test vérifie que le
script, le `Makefile` et le `.spec` annoncent bien la même version.

## Licence

[MIT](LICENSE)
