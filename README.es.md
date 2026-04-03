# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.1-green.svg)]()

[**English**](README.md) | **Español** | [**日本語**](README.ja.md) | [**简体中文**](README.zh-Hans.md) | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

Una terminal desplegable para macOS que vive en tu notch. Rápida, siempre accesible y no estorba.

---

## Demostración

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## Características

- **Integración con el Notch:** Se expande al pasar el cursor. Funciona en todos los Macs (incluso aquellos sin notch físico) y en múltiples pantallas.
- **Acceso en la Barra de Menú:** Un ícono en la barra de menú está disponible para acceso rápido a las funciones principales y ajustes.
- **Gestión de Sesiones:** La persistencia con SwiftData restaura automáticamente las posiciones, tamaños y estados de tus ventanas al iniciar.
- **Gestión de Ventanas:** Modo compacto, siempre visible (always-on-top) y un sistema de arrastrar y soltar que soporta rutas.
- **Herramientas Integradas:**
  - *Puertos Activos:* Ve los puertos TCP en escucha y mata procesos directamente.
  - *Analizador de Almacenamiento:* Escanea y limpia rápidamente `node_modules`, `DerivedData`, cachés y registros.

### Funciones Experimentales
NotchTerminal incluye una pestaña de ajustes experimentales que ofrece:
- **Filtro CRT:** Una superposición de terminal CRT retro usando shaders de Metal.
- **Brillo Simulado del Notch:** Simula una luz ambiental que proviene del notch (tema Cyberpunk, etc.).
- **Orbe de Inicio:** Un indicador visual durante el lanzamiento de la aplicación.
- **Arrastrar para Acoplar (Drag-to-Dock):** Ajusta la sensibilidad magnética al arrastrar ventanas de terminal cerca del notch.

### Atajos de Teclado

| Atajo | Acción |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | Copiar / Pegar / Seleccionar Todo |
| `⌘K` | Limpiar buffer |
| `⌘F` | Buscar |
| `⌘W` | Cerrar sesión |
| `⌘+` / `⌘-` | Ajustar tamaño de fuente |

---

## Capturas de pantalla

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## Requisitos

- macOS 14 o superior
- Xcode 16+ (solo para compilar desde el código fuente)

---

## Instalación

### Homebrew

```bash
brew tap idams/notchterminal
brew install --cask notchterminal
```

### Descarga Directa

1. Abre la última release en GitHub.
2. Descarga `NotchTerminal-<version>.zip`.
3. Descomprime el archivo.
4. Mueve `NotchTerminal.app` a `/Applications`.

Releases:

- https://github.com/iDams/NotchTerminal/releases

---

## Construir desde el código fuente

```bash
git clone https://github.com/iDams/NotchTerminal.git
cd NotchTerminal
```
Abre `NotchTerminal.xcodeproj` y ejecuta el esquema `NotchTerminal`.

**Firma de Código Local:**
El repositorio no incluye un `DEVELOPMENT_TEAM` personal de Apple. Para compilar localmente:
1. Copia `Config/Signing.local.example.xcconfig` a `Config/Signing.local.xcconfig`
2. Añade tu propio ID de equipo de Apple Developer.
3. Mantén este archivo solo de forma local (está en `.gitignore`).

---

## Documentación y Enlaces

- [Índice de Documentación](docs/README.md)
- [Guía de Pruebas](docs/quality/)
- [Localización](docs/localization/LOCALIZATION.md)
- [Guía de Contribución](CONTRIBUTING.md)
- [Avisos de Terceros](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)

---

## Soporte

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## Aviso Sobre Marcas

Algunas capturas, iconos y referencias pueden mencionar herramientas o servicios de terceros como OpenAI, Claude, Copilot u otros productos similares para mostrar flujos de trabajo o interoperabilidad.

Esos nombres, logotipos y marcas pertenecen a sus respectivos propietarios. Se usan únicamente con fines descriptivos e identificativos dentro de la app, el sitio web, la documentación o el material visual. NotchTerminal no está afiliado, respaldado ni patrocinado por esas compañías salvo que se indique explícitamente.

---

## Licencia

[MIT](LICENSE) © 2026 Marco Astorga González
