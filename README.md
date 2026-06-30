# Gestor de Inventario y Pedidos - Comercializadora Aly S.A. 🛠️📦

Una suite multiplataforma premium desarrollada para la gestión en tiempo real de inventarios, pedidos, facturación digital y geolocalización inteligente para **Comercializadora Aly S.A.** (empresa real del sector de construcción y herramientas).

El ecosistema está compuesto por dos plataformas conectadas en tiempo real:
1. **Aplicación Móvil y Web Principal (Flutter / Riverpod / Firebase)**
2. **Portal Logístico y Administrativo Independiente (HTML5 / CSS3 / Vanilla JS / Firestore)**

---

## 🌐 Enlaces Oficiales de Producción

* **Aplicación Móvil / Web (Flutter Web):** [https://gestor-inv-2604190050.web.app](https://gestor-inv-2604190050.web.app)
* **Portal Administrativo y Despacho Logístico (HTML/JS):** [https://gestor-inv-2604190050.web.app/docs/](https://gestor-inv-2604190050.web.app/docs/)

---

## 👥 Integrantes del Proyecto
* **Sosa Porras Jhoan José**
* **Requena Lavi Aldo Alexandre**
* **Bacilio De La Cruz José Anthony**
* **Mendoza Alarcón Maylit**
* **Cristian Celis**

---

## 🚀 Características Clave Implementadas

### 🔑 1. Control de Acceso Basado en Roles (RBAC) y Seguridad en Firestore
Configuración robusta y testeada de reglas de seguridad en [firestore.rules](firestore.rules):
* **Admin**: Control absoluto sobre productos, movimientos de stock, tandas e historial de pedidos.
* **Comprador / Distribuidor**: Solo lectura del catálogo de productos y acceso de lectura/escritura únicamente a sus pedidos individuales (`comprador_id == request.auth.uid`).

### 📝 2. Bitácora de Auditoría en Tiempo Real
Monitoreo automático de cada modificación en el inventario. Las acciones de creación, edición y eliminación de productos escriben automáticamente registros detallados en la colección `/inventario_movimientos`, registrando los valores previos y nuevos de stock, el usuario responsable y la fecha exacta.

### 🗺️ 3. Mapas Inteligentes y Ruteo Dinámico (Mapbox API)
Integración de mapas interactivos con estilo nocturno personalizado:
* **Pin de Despacho Logístico**: El comprador puede colocar un marcador directo en el mapa para marcar el sitio exacto de la obra de construcción.
* **Cálculo de Rutas Reales**: Mapbox Directions API traza la ruta geodésica, calculando la distancia y tiempo estimado de tránsito de Huancayo.
* **Simulador de Delivery Activo**: Un camión animado se desplaza por el mapa siguiendo la ruta trazada y envía notificaciones push locales al llegar al destino.
* **Sincronización de Estado**: Al llegar el camión, la aplicación actualiza automáticamente el estado del pedido en la base de datos de Firestore de `pendiente` a `entregado` de manera inmediata.

### 🤖 4. Asistente IA Experto en Obras (Gemini API)
Chatbot interactivo con el modelo generativo Gemini integrado de forma nativa:
* **Asesor Técnico**: Configurado para realizar cálculos de dosificación de concreto y tarrajeo, torque para pernos y recomendación técnica de herramientas.
* **Persistencia Privada**: El historial de chat de cada cuenta se guarda localmente usando claves indexadas por el UID de Firebase (`gemini_chat_history_${userId}`). Ningún usuario puede visualizar conversaciones de cuentas previas en el mismo dispositivo.

### 📄 5. Facturación Digital con Generador de PDF
* Pasarela de pago interactiva con tarjeta 3D rotativa (giro automático al ingresar código CVV) conectada a Firebase.
* Generación de boleta electrónica en **PDF** detallando la lista completa de productos comprados, precios unitarios, IGV (18%) y total, incluyendo el logotipo corporativo y el **RUC oficial de la empresa: 10432247657**.

### 💻 6. Diseño Responsivo Split-Screen en Login
* Cuando el usuario ingresa a la versión Web (pantallas `>= 900px`), el login adopta un diseño dividido en dos columnas: el lado izquierdo muestra una presentación de la marca con descripción y su RUC, y el lado derecho muestra el formulario de autenticación rápida.

---

## 🛠️ Tecnologías y Librerías Utilizadas
* **Flutter SDK**: Desarrollo multiplataforma optimizado para Web & Mobile.
* **Cloud Firestore**: Base de datos en tiempo real no relacional con persistencia local.
* **Firebase Authentication**: Control de sesiones de usuario seguro y cifrado.
* **Riverpod**: Gestor de estado reactivo y acoplado mediante inyección de dependencias.
* **Flutter Map & Mapbox**: Renderizado de tiles cartográficos vectoriales y navegación.
* **Speech to Text**: Búsqueda por voz dictada en el buscador del catálogo.
* **PDF & Printing**: Maquetación y exportación de comprobantes de pago.

---

## ⚙️ Instrucciones de Configuración y Despliegue

### 1. Iniciar en Modo Desarrollo (Local)
Asegúrate de contar con Flutter SDK en tu sistema y ejecuta:
```bash
flutter run -d chrome
```

### 2. Compilar para Producción (Android APK)
Para generar el archivo instalador optimizado de la aplicación:
```bash
flutter build apk --release
```
El instalador se guardará en `build/app/outputs/flutter-apk/app-release.apk`.

### 3. Despliegue en Firebase Hosting
Para compilar y subir los cambios a la web oficial:
```bash
flutter build web --release
firebase deploy --only hosting --project gestor-inv-2604190050
```

---

## 📋 Historial de Observaciones y Mejoras Aplicadas

Para el cumplimiento del puntaje sobresaliente de la consigna final, se implementaron las siguientes correcciones de software:
1. **Redirección Directa al Catálogo**: El autologin y la autenticación ahora redirigen directamente al usuario comprador al `CatalogoScreen` eliminando pasos innecesarios.
2. **Seguridad y Privacidad de Datos**: Se reforzó `firestore.rules` limitando consultas y aislando carritos de compra y conversaciones con la IA por identificador único de usuario (`userId`).
3. **FocusNode en CVV**: Se corrigió la pérdida de foco en la pasarela de pagos al ingresar datos de la tarjeta.
4. **Decodificador de Rutas Seguro en Web**: Se adaptó el decodificador de polilíneas para soportar listas de coordenadas GeoJSON directamente en Flutter Web en producción, solucionando excepciones de tiempo de ejecución (`charCodeAt` / `RangeError`).
5. **PDF Completos con Logo y RUC**: Se corrigió la boleta del checkout para que desglose el listado real de productos y se incorporó el logo corporativo de Comercializadora Aly en las boletas del historial.
