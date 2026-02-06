# 🎨 Logo de Markdebrand - Instrucciones

## 📁 Ubicación del Logo

Coloca el archivo del logo en:
```
mvp_odoo/assets/image/logo.png
```

## 📝 Especificaciones del Archivo

- **Nombre**: `logo.png` (exactamente este nombre)
- **Formato**: PNG (preferible con fondo transparente)
- **Tamaño recomendado**: 512x512 px o mayor
- **Aspecto**: Cuadrado o rectangular

## ✅ Configuración Actual

- ✅ `pubspec.yaml` - Ya configurado para incluir `assets/image/`
- ✅ `login_screen.dart` - Ya actualizado para mostrar el logo
- ✅ **Fallback**: Si el logo no existe, mostrará un ícono de cohete temporalmente

## 🎯 Dónde se Usa el Logo

### Pantalla de Login
El logo aparece en la parte superior de la pantalla de login:
- Tamaño: 120x120 px
- Bordes redondeados
- Sombra suave

## 🚀 Próximos Pasos

1. **Coloca el archivo del logo** en `assets/image/logo.png`
2. **Ejecuta**: `flutter pub get` (opcional, solo si es la primera vez)
3. **Hot Reload**: Presiona `r` en la terminal donde corre `flutter run`

## 💡 Formatos Alternativos

Si tienes el logo en otro formato, puedes usar:
- `logo.jpg` - Cambia la referencia en `login_screen.dart` línea 151
- `logo.svg` - Requiere el paquete `flutter_svg` (no instalado actualmente)
- `logo.webp` - Formato moderno, soportado nativamente

## ⚠️ Importante

- El archivo debe llamarse exactamente `logo.png` (minúsculas)
- Si cambias el nombre, actualiza la línea 151 en `login_screen.dart`
- La aplicación funcionará sin el logo (mostrará el ícono de cohete)

## 🎨 Recomendaciones de Diseño

Para mejor visualización:
- Usa fondo transparente (PNG)
- Asegúrate de que el logo sea visible en fondo blanco
- Mantén proporciones cuadradas o cercanas a cuadrado
- Resolución mínima: 256x256 px
