# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)]()

[**English**](README.md) | **Español** | [**日本語**](README.ja.md) | [**简体中文**](README.zh-Hans.md) | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

**NotchTerminal** es una aplicación de terminal para macOS construida alrededor del "notch". Mantén el acceso a la terminal rápido, visible y cerca de lo que estás haciendo, sin llenar tu escritorio con ventanas adicionales.

---


## Demostración

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023


https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## Tabla de Contenidos

- [Capturas de pantalla](#capturas-de-pantalla)
- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Construir desde el código fuente](#construir-desde-el-código-fuente)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Ajustes](#ajustes)
- [Documentación](#documentación)
- [Contribución](#contribución)
- [Créditos](#créditos)
- [Soporte](#soporte)
- [Licencia](#licencia)

---

## Capturas de pantalla

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## Características

### Superposición del Notch
- Se expande al pasar el cursor
- Funciona en múltiples pantallas
- Compatible con Macs con y sin notch físico
- Muestra los terminales minimizados
- Acciones rápidas: `Nuevo`, `Reorganizar`, `En masa`, `Ajustes`

### Ventanas de Terminal
- Abrir/cerrar/minimizar/maximizar
- Modo compacto
- Opción de "Siempre visible" (Always on Top)
- Se acopla al notch al arrastrar cerca de él
- Arrastrar y soltar archivos/carpetas (inserta rutas escapadas)

### Sesiones
- Persistencia a través de SwiftData
- Restauración automática al iniciar: posición, tamaño, estado acoplado, modo compacto, siempre visible, estado maximizado

### Utilidades para Desarrolladores
- **Puertos Activos**: lista de puertos TCP en escucha, filtrar, matar procesos por PID
- **Análisis de Almacenamiento**: escaneo de `node_modules`, `DerivedData`, `Pods`, cachés, registros, Papelera, y más

### Efectos Visuales
- Fondo estilo Aurora
- Filtro CRT
- Brillo simulado del Notch

### Barra de Menú
- Acceso rápido: Nuevo Terminal, Mostrar Todas las Ventanas, Ajustes, Ocultar, Salir

### Atajos de Teclado
| Atajo | Acción |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | Copiar / Pegar / Seleccionar Todo |
| `⌘K` | Limpiar buffer |
| `⌘F` | Buscar |
| `⌘W` | Cerrar sesión |
| `⌘+` / `⌘-` | Ajustar tamaño de fuente |

---

## Requisitos

- macOS 14 o superior
- Xcode 16+ (solo para desarrollo)

> La shell por defecto es `/bin/zsh`, disponible en cualquier instalación limpia de macOS.

---

## Instalación

> Próximamente

---

## Construir desde el código fuente

1. Clona el repositorio:
   ```bash
   git clone https://github.com/marcoastorj/NotchTerminal.git
   cd NotchTerminal
   ```

2. Abre `NotchTerminal.xcodeproj`

3. Selecciona el esquema `NotchTerminal`

4. Compila y ejecuta

### Firma de Código Local para Contribuidores

El repositorio no incluye un `DEVELOPMENT_TEAM` personal de Apple:

1. Copia `Config/Signing.local.example.xcconfig` a `Config/Signing.local.xcconfig`
2. Reemplaza `YOURTEAMID` con tu propio ID de equipo de Apple Developer
3. Mantén `Config/Signing.local.xcconfig` solo a nivel local (en `.gitignore`)

### Flujo de Trabajo de Depuración

Las compilaciones de depuración se instalan automáticamente en `/Applications/NotchTerminal.app` para probar fuera de Xcode.

---

## Estructura del Proyecto

```
NotchTerminal/
├── App/                    # Ciclo de vida de la aplicación
├── Features/
│   ├── Notch/              # Interfaz superpuesta, interacciones
│   ├── Storage/            # Análisis de almacenamiento
│   ├── Windows/            # Gestor de ventanas, terminal
│   └── Persistence/        # Modelos de SwiftData
├── Rendering/Metal/        # Shaders y renderizadores
├── Settings/               # Pantallas de ajustes
├── Services/               # Ayudantes y servicios
└── Assets.xcassets/        # Iconos e imágenes
```

---

## Ajustes

| Sección | Opciones Principales |
|---------|--------------|
| **General** | Idioma, háptica, icono en el Dock, icono en barra de menú, comportamiento al pasar el cursor |
| **Notch** | Habilitar/deshabilitar por pantalla, desplazamientos X/Y, ancho, Aurora personalizada |
| **Apariencia** | Relleno, cerrar al pasar el cursor, vista previa al pasar, tema Aurora |
| **Acerca de** | Mostrar pestaña Experimental |
| **Experimental** | Sensibilidad de arrastre al notch, Orbe de Inicio, Brillo de Notch falso, Filtro CRT |

Idiomas soportados: English, Español, Français, 日本語, 简体中文

---

## Documentación

- Índice de documentación: [`docs/README.md`](docs/README.md)
- Pruebas: [`docs/quality/`](docs/quality/)
- Localización: [`docs/localization/LOCALIZATION.md`](docs/localization/LOCALIZATION.md)

---

## Contribución

Ver [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Créditos

Ver [`NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md).

Atribuciones principales:
- **SwiftTerm** – emulación de terminal (MIT)
- **Port-Killer** – inspiración para el flujo de puertos (MIT)

Las marcas/logotipos utilizados en la interfaz de usuario pertenecen a sus respectivos dueños.

---

## Soporte

Si deseas apoyar el desarrollo:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## Licencia

[MIT](LICENSE) © 2026 Marco Astorga González

---

<p align="center">
  Hecho con ❤️ por Marco Astorga González
</p>