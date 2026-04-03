# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.1-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | [**日本語**](README.ja.md) | [**简体中文**](README.zh-Hans.md) | **Français**

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

Un terminal déroulant pour macOS qui réside dans votre encoche. Rapide, toujours accessible et qui ne vous gêne pas.

---

## Démo

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## Fonctionnalités

- **Intégration à l'Encoche:** Survolez pour étendre. Fonctionne sur tous les Macs (même ceux sans encoche physique) et sur plusieurs écrans.
- **Accès par la Barre de Menus:** Un élément de la barre de menus est disponible pour un accès rapide aux fonctions principales et aux paramètres.
- **Gestion des Sessions:** La persistance SwiftData restaure automatiquement les positions, tailles et états de vos fenêtres à chaque lancement.
- **Gestion des Fenêtres:** Mode compact, toujours au premier plan, et un système de glisser-déposer prenant en charge les chemins de fichiers.
- **Outils Intégrés:**
  - *Ports Actifs:* Visualisez les ports TCP en écoute et tuez les processus directement.
  - *Analyseur de Stockage:* Analysez et nettoyez rapidement `node_modules`, `DerivedData`, caches et journaux.

### Fonctionnalités Expérimentales
NotchTerminal inclut un onglet de paramètres expérimentaux proposant :
- **Filtre CRT:** Une superposition de terminal CRT rétro utilisant des shaders Metal.
- **Fausse Lueur d'Encoche:** Simule une lumière ambiante émanant de l'encoche (thème Cyberpunk, etc.).
- **Orbe de Démarrage:** Un indicateur visuel lors du lancement de l'application.
- **Glisser pour Ancrer (Drag-to-Dock):** Ajustez la sensibilité magnétique lors du déplacement des fenêtres près de l'encoche.

### Raccourcis Clavier

| Raccourci | Action |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | Copier / Coller / Tout sélectionner |
| `⌘K` | Effacer le buffer |
| `⌘F` | Rechercher |
| `⌘W` | Fermer la session |
| `⌘+` / `⌘-` | Ajuster la taille de la police |

---

## Captures d'écran

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## Prérequis

- macOS 14 ou version ultérieure
- Xcode 16+ (pour compiler depuis les sources)

---

## Installation

### Homebrew

```bash
brew tap idams/notchterminal
brew install --cask notchterminal
```

### Téléchargement Direct

1. Ouvrez la dernière release sur GitHub.
2. Téléchargez `NotchTerminal-<version>.zip`.
3. Décompressez le fichier.
4. Déplacez `NotchTerminal.app` vers `/Applications`.

Releases :

- https://github.com/iDams/NotchTerminal/releases

---

## Compiler depuis les sources

```bash
git clone https://github.com/iDams/NotchTerminal.git
cd NotchTerminal
```
Ouvrez `NotchTerminal.xcodeproj` et exécutez le schéma `NotchTerminal`.

**Signature de Code Locale:**
Le dépôt n'inclut pas de `DEVELOPMENT_TEAM` Apple personnel. Pour compiler localement :
1. Copiez `Config/Signing.local.example.xcconfig` vers `Config/Signing.local.xcconfig`
2. Ajoutez l'ID de votre équipe Apple Developer.
3. Gardez ce fichier local uniquement (il est dans `.gitignore`).

---

## Documentation & Liens

- [Index de la Documentation](docs/README.md)
- [Guide de Test](docs/quality/)
- [Localisation](docs/localization/LOCALIZATION.md)
- [Directives de Contribution](CONTRIBUTING.md)
- [Avis de Tiers](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)

---

## Retours et Bugs

Si vous trouvez un bug, souhaitez demander une fonctionnalité ou rencontrez un problème d'installation :

- Ouvrir une issue : https://github.com/iDams/NotchTerminal/issues

---

## Support

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## Avis Sur Les Marques

Certaines captures d'écran, icônes et références peuvent mentionner des outils ou services tiers tels qu'OpenAI, Claude, Copilot ou d'autres produits similaires afin d'illustrer des flux de travail ou l'interopérabilité.

Ces noms, logos et marques appartiennent à leurs propriétaires respectifs. Ils sont utilisés uniquement à des fins descriptives et d'identification dans l'application, le site web, la documentation ou les visuels promotionnels. NotchTerminal n'est pas affilié, approuvé ni sponsorisé par ces sociétés sauf mention explicite contraire.

---

## Licence

[MIT](LICENSE) © 2026 Marco Astorga González
