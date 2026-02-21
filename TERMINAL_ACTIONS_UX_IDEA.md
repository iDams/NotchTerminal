# NotchTerminal - Terminal Actions UX (Distribucion Recomendada)

## Objetivo
Gestionar multiples terminales desde el notch sin sobrecargar la UI principal ni romper el flujo rapido.

## Alcance
Esta propuesta define solo UX e interacciones de acciones de terminal.
No cambia el diseno base del notch ni su motor de render.

## Distribucion Recomendada (sin recargar el notch)

### 1) Notch expandido (barra superior: acciones globales)
- `New`
- `Reorg`
- `Bulk` (boton nuevo con menu)
- `Settings`

### 2) Menu Bulk (dropdown/popover desde boton Bulk)
- `Restore All`
- `Minimize All`
- `Close All`
- `Close All on This Display`
- `Clear Workspace` (dejar para mas adelante, opcional)

### 3) Chips de terminal (acciones por ventana)
- `Click`: Restore
- `Right click`: menu contextual:
  - `Restore`
  - `Minimize`
  - `Close`
  - `Always on Top` (toggle opcional)

### 4) Accion rapida en hover (opcional)
- Mostrar mini boton `x` solo en hover sobre chip.
- Cierre rapido de una terminal sin abrir menu.

## Proteccion de cierre (safety layer)

### Confirmacion obligatoria (al menos)
- `Close All`
- `Clear Workspace`

### Texto sugerido modal
- `Close 7 terminals?`

### Opcion en modal
- `Don't ask again`

## Settings > General (comportamiento)
- `Show close button on chip hover`
- `Confirm before Close All`
- `Close action mode`:
  - `Close window only`
  - `Terminate process and close`

## Atajos (power users)
- `Option + click` en chip -> `Close` directo
- `Cmd + Option + K` -> `Close All`
- `Cmd + Option + M` -> `Minimize All`
- `Cmd + Option + R` -> `Restore All`

## Reglas UX (importantes)
- Acciones destructivas siempre visibles en Bulk, no escondidas en submenus profundos.
- `Close All on This Display` debe operar solo sobre el display activo del notch actual.
- El menu contextual del chip debe reflejar estado real:
  - Si ya esta minimizada, deshabilitar `Minimize`.
  - Si no esta minimizada, deshabilitar `Restore`.
- `Always on Top` debe mostrarse con checkmark cuando este activo.
- Mantener feedback inmediato:
  - Animacion corta al cerrar/minimizar/restaurar.
  - Estado de chips actualizado sin delay perceptible.

## Checklist de Implementacion (tecnico)

### Fase 1 (MVP recomendado)
- Agregar boton `Bulk` en notch expandido.
- Implementar menu `Bulk` con:
  - `Restore All`
  - `Minimize All`
  - `Close All`
- Agregar confirmacion para `Close All`.
- Agregar setting `Confirm before Close All`.

### Fase 2
- Agregar `Close All on This Display`.
- Agregar menu contextual por chip (`Restore`, `Minimize`, `Close`).
- Agregar `Option + click` para cierre directo.
- Agregar atajos `Cmd+Option+K/M/R`.

### Fase 3
- Agregar toggle `Show close button on chip hover`.
- Agregar mini `x` en hover.
- Agregar `Close action mode` con:
  - `Close window only`
  - `Terminate process and close`

### Fase 4 (opcional)
- Agregar `Clear Workspace` con confirmacion fuerte.
- Guardar preferencia `Don't ask again` por accion destructiva.

## Criterios de Aceptacion
- El usuario puede cerrar/restaurar/minimizar multiples terminales sin abrir cada ventana.
- `Close All` no ejecuta sin confirmacion si la opcion esta activa.
- Los atajos funcionan aunque el foco este en terminal.
- Las acciones por display no afectan otros displays.
- El notch se mantiene limpio: maximo 4 acciones visibles en barra superior.
