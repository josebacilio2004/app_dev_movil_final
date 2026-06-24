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
Para generar el instalador de producción/release:
```bash
flutter build apk --release
```
El archivo resultante se encuentra en `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📋 Ejercicio 1 — Levantamiento de Observaciones y Correcciones Aplicadas

Para dar cumplimiento a la rúbrica de la entrega final, a continuación se detallan las observaciones recibidas y las correcciones de software implementadas:

### 1. Observación: El Ruteo Inicial no ingresaba directamente al Catálogo
* **Detalle:** Al iniciar la aplicación con sesión activa (Autologin) o al realizar un Login manual/biométrico, se redirigía a una pantalla de inicio neutral (`HomeScreen`) en lugar del catálogo.
* **Corrección:** Modificamos la navegación en [main.dart](lib/main.dart), [login_screen.dart](lib/presentation/screens/login_screen.dart) y [splash_screen.dart](lib/presentation/screens/splash_screen.dart). Ahora el flujo redirecciona directamente al usuario comprador a `CatalogoScreen` con su rol dinámico.

### 2. Observación: Error en Registro de Usuarios y falta de Seguridad en Pedidos
* **Detalle:** El registro de cuentas nuevas (`signUp`) generaba una excepción de seguridad de Firebase Firestore al evaluar recursivamente la regla `getUserRole()` antes de que el perfil de usuario existiera. Además, cualquier usuario logueado podía leer y escribir pedidos ajenos.
* **Corrección:** 
  * Modificamos [firestore.rules](firestore.rules) agregando comprobaciones `exists()` en `getUserRole()` y dividiendo la regla `/users` en permisos específicos de `create` y `update`.
  * Reforzamos la seguridad de `/pedidos` restringiendo la lectura y escritura para que los compradores solo puedan acceder a los registros donde `comprador_id == request.auth.uid`.
  * Modificamos `getPedidos` en [firestore_service.dart](lib/data/services/firestore_service.dart) para filtrar los pedidos de forma nativa por UID del comprador y realizar el ordenamiento cronológico en memoria, evitando requerir índices complejos de Firebase.

### 3. Observación: El Carrito de compras se mezclaba entre cuentas
* **Detalle:** Si un usuario agregaba productos al carrito, cerraba sesión e ingresaba con otra cuenta en el mismo dispositivo, los ítems agregados anteriormente persistían.
* **Corrección:** Adaptamos los modelos de datos de productos y carrito para admitir serialización JSON. En [cart_provider.dart](lib/presentation/providers/cart_provider.dart) rediseñamos el gestor de estado para que `cartProvider` escuche a `authStateProvider` y cargue/guarde el carrito individualmente desde `SharedPreferences` usando una clave única (`cart_${userId}`). Al desloguearse, el carrito se limpia en memoria instantáneamente.

### 4. Observación: Glitch de Foco en pasarela de pagos (CVV)
* **Detalle:** El teclado de la tarjeta en la pasarela de pagos perdía el foco tras digitar cada número del CVV, interrumpiendo la usabilidad.
* **Corrección:** Corregimos la inicialización de `FocusNode` en [payment_gateway_screen.dart](lib/presentation/screens/payment_gateway_screen.dart), moviendo la variable a nivel de clase de estado persistente (`_cvvFocusNode`) y liberándola en `dispose()`.

