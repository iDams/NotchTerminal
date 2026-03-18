# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | [**日本語**](README.ja.md) | [**简体中文**](README.zh-Hans.md) | **Français**

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

**NotchTerminal** est une application terminal macOS construite autour de l'encoche (notch). Gardez l'accès au terminal rapide, visible et proche de ce que vous faites, sans encombrer votre bureau de fenêtres supplémentaires.

---


## Démo

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023


https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## Table des Matières

- [Captures d'écran](#captures-décran)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Compiler depuis les sources](#compiler-depuis-les-sources)
- [Structure du Projet](#structure-du-projet)
- [Paramètres](#paramètres)
- [Documentation](#documentation)
- [Contribution](#contribution)
- [Crédits](#crédits)
- [Support](#support)
- [Licence](#licence)

---

## Captures d'écran

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## Fonctionnalités

### Superposition d'Encoche (Notch Overlay)
- S'étend au survol
- Fonctionne sur plusieurs écrans
- Compatible avec les Macs avec et sans encoche physique
- Affiche les terminaux minimisés (puces)
- Actions rapides : `Nouveau`, `Réorganiser`, `En vrac`, `Paramètres`

### Fenêtres de Terminal
- Ouvrir/fermer/minimiser/maximiser
- Mode compact
- Bouton pour "Toujours au premier plan"
- S'ancre à l'encoche en glissant près de celle-ci
- Glisser-déposer de fichiers/dossiers (insère des chemins échappés)

### Sessions
- Persistance via SwiftData
- Restauration automatique au lancement : position, taille, état d'ancrage, mode compact, toujours au premier plan, état maximisé

### Utilitaires pour Développeurs
- **Ports Actifs** : liste les ports TCP en écoute, filtrer, tuer les processus par PID
- **Analyse du Stockage** : analyser `node_modules`, `DerivedData`, `Pods`, caches, journaux, Corbeille, et plus

### Effets Visuels
- Arrière-plan de style Aurore
- Filtre CRT
- Fausse lueur de l'encoche

### Barre de Menu
- Accès rapide : Nouveau Terminal, Afficher Toutes les Fenêtres, Paramètres, Masquer, Quitter

### Raccourcis Clavier
| Raccourci | Action |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | Copier / Coller / Tout sélectionner |
| `⌘K` | Effacer le buffer |
| `⌘F` | Rechercher |
| `⌘W` | Fermer la session |
| `⌘+` / `⌘-` | Ajuster la taille de la police |

---

## Prérequis

- macOS 14 ou version ultérieure
- Xcode 16+ (pour le développement uniquement)

> Le shell par défaut est `/bin/zsh`, disponible sur toute installation macOS standard.

---

## Installation

> À venir

---

## Compiler depuis les sources

1. Clonez le dépôt :
   ```bash
   git clone https://github.com/marcoastorj/NotchTerminal.git
   cd NotchTerminal
   ```

2. Ouvrez `NotchTerminal.xcodeproj`

3. Sélectionnez le schéma `NotchTerminal`

4. Compilez et exécutez

### Signature de Code Locale pour les Contributeurs

Le dépôt n'inclut pas de `DEVELOPMENT_TEAM` Apple personnel :

1. Copiez `Config/Signing.local.example.xcconfig` vers `Config/Signing.local.xcconfig`
2. Remplacez `YOURTEAMID` par l'ID de votre équipe Apple Developer
3. Gardez `Config/Signing.local.xcconfig` local uniquement (dans `.gitignore`)

### Flux de Travail de Débogage

Les compilations de débogage s'installent automatiquement dans `/Applications/NotchTerminal.app` pour tester en dehors de Xcode.

---

## Structure du Projet

```
NotchTerminal/
├── App/                    # Cycle de vie de l'application
├── Features/
│   ├── Notch/              # Interface superposée, interactions
│   ├── Storage/            # Analyse du stockage
│   ├── Windows/            # Gestionnaire de fenêtres, terminal
│   └── Persistence/        # Modèles SwiftData
├── Rendering/Metal/        # Shaders et rendus
├── Settings/               # Écrans de paramètres
├── Services/               # Aides et services
└── Assets.xcassets/        # Icônes et images
```

---

## Paramètres

| Section | Options Principales |
|---------|--------------|
| **Général** | Langue, retour haptique, icône du Dock, icône de la barre de menus, comportement au survol |
| **Notch (Encoche)** | Activer/désactiver par écran, décalages X/Y, largeur, Aurore personnalisée |
| **Apparence** | Espacement (padding), fermeture de puce au survol, aperçu au survol, thème Aurore |
| **À propos** | Afficher l'onglet Expérimental |
| **Expérimental** | Sensibilité de glissement vers l'encoche, Orbe de démarrage, Fausse lueur d'encoche, Filtre CRT |

Langues prises en charge : English, Español, Français, 日本語, 简体中文

---

## Documentation

- Index de la documentation : [`docs/README.md`](docs/README.md)
- Tests : [`docs/quality/`](docs/quality/)
- Localisation : [`docs/localization/LOCALIZATION.md`](docs/localization/LOCALIZATION.md)

---

## Contribution

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Crédits

Voir [`NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md).

Attributions principales :
- **SwiftTerm** – émulation de terminal (MIT)
- **Port-Killer** – inspiration pour le flux de ports (MIT)

Les marques/logos utilisés dans l'interface utilisateur appartiennent à leurs propriétaires respectifs.

---

## Support

Si vous souhaitez soutenir le développement :

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## Licence

[MIT](LICENSE) © 2026 Marco Astorga González

---

<p align="center">
  Fait avec ❤️ par Marco Astorga González
</p>
