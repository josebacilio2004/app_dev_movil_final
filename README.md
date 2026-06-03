# Gestor de Inventario y Pedidos - Comercializadora Aly 🛠️📦

Una aplicación móvil y web multiplataforma desarrollada en **Flutter** para la gestión en tiempo real de inventarios, pedidos, facturación y geolocalización para **Comercializadora Aly**. La aplicación cuenta con un diseño premium con estética industrial, glassmorphism, modo oscuro e interacciones fluidas.

---

## 👥 Integrantes del Proyecto
* **Sosa Porras Jhoan José**
* **Requena Lavi Aldo Alexandre**
* **Bacilio De La Cruz José Anthony**
* **Mendoza Alarcón Maylit**
* **Cristian Celis**

---

## 🚀 Características Clave Implementadas

### 🔑 1. Reglas de Seguridad de Firestore (Role-Based Access Control)
Configuración robusta en [firestore.rules](firestore.rules) para proteger las colecciones según el rol del usuario autenticado:
* **Admin**: Acceso completo de lectura y escritura a todo el sistema.
* **Operador**: Acceso completo a inventarios, pedidos y clientes; lectura de estadísticas operativas.
* **Inversionista**: Acceso de lectura a estadísticas financieras de alto nivel (Dashboards).
* **Comprador / Distribuidor**: Solo lectura de catálogo y creación de pedidos propios.

### 📝 2. Bitácora de Auditoría en Tiempo Real
Cada creación, modificación o eliminación de productos en el catálogo registra automáticamente una traza detallada en la colección `/inventario_movimientos` incluyendo:
* ID del producto y nombre.
* Acción realizada (Creación, Edición, Eliminación).
* Valores anteriores y nuevos para control de stock.
* Usuario responsable del cambio y fecha/hora exacta.

### 🗺️ 3. Mapas Premium con Mapbox, Rutas 3D y Geocercas Simuladas
Integración completa de geolocalización en tiempo real utilizando la API y estilo oscuro de **Mapbox**:
* **Ruta de Tránsito**: Trazado inteligente de calles desde la ubicación del usuario a la Tienda de Comercializadora Aly (evitando CORS).
* **Geocerca de Arribo (500m / 200m)**: Simulación interactiva de entrada al perímetro de la tienda mediante un botón satelital cyan, disparando una notificación local push y alerta visual para preparar las herramientas.
* **Alineación 3D y Controles de Cámara**: Permite cambiar la perspectiva del mapa y recentrar con facilidad.

### 📄 4. Facturación Digital con Generación Real de PDF
Pasarela de pagos con tarjeta de crédito interactiva 3D (giro automático al ingresar CVV) conectada a Firebase.
* Genera una boleta electrónica real en formato **PDF** con el desglose de productos, cantidades, precios unitarios, IGV (18%) y monto total.
* Integración con la librería `printing` para guardar localmente el documento o enviarlo a imprimir directamente desde la aplicación.

### 🎙️ 5. Búsqueda por Voz y Modo Offline
* **Búsqueda Asistida por Voz**: Micrófono interactivo en el catálogo de productos utilizando `speech_to_text` para dictar los nombres de herramientas o categorías.
* **Banner de Conectividad**: Detección dinámica del estado de red con alertas en tiempo real en la parte superior cuando la aplicación entra en modo sin conexión.

### 📊 6. Dashboards Premium con Glassmorphism
Gráficos interactivos de ventas, ganancias e inversiones para administradores e inversionistas, diseñados con contenedores estilo vidrio esmerilado translúcido e íconos premium.

---

## 🛠️ Tecnologías y Librerías Utilizadas
* **Flutter SDK**: Multiplataforma (Web & Mobile).
* **Firebase Suite**: Authentication, Firestore, Cloud Messaging (FCM).
* **Riverpod**: Gestión de estado reactiva y desacoplada.
* **Flutter Map & Mapbox Tiles**: Visualización interactiva y geocodificación.
* **Speech to Text**: Procesamiento de voz a texto.
* **PDF & Printing**: Maquetación y exportación de boletas electrónicas.
* **Google Fonts**: Tipografías modernas (*Outfit*, *Share Tech Mono*, etc.).

---

## ⚙️ Instrucciones de Configuración y Despliegue

### 1. Requisitos Previos
* Flutter SDK (versión `>= 3.11.4`).
* Android SDK y Gradle configurados.
* Node.js y Firebase CLI instalados para la gestión de reglas.

### 2. Configurar Token de Mapbox
El token oficial de Mapbox se encuentra configurado en la clase `MapaRutaScreen`:
`pk.eyJ1Ijoiam9zZWJhYyIsImEiOiJjbW9pYTU0MW8wMGM4MnNvZ3NhOHo1NWM4In0.5Gw3E-h62DwI4ks5Y70cDw`

### 3. Ejecutar en Web (Chrome)
Para iniciar la aplicación en modo desarrollo web:
```bash
flutter run -d chrome
```

### 4. Compilar APK (Android)
Para generar el instalador de depuración:
```bash
flutter build apk --debug
```
El archivo resultante se encuentra en `build/app/outputs/flutter-apk/app-debug.apk`.
