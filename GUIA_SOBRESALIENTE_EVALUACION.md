# 🏆 GUÍA PASO A PASO: ESTRATEGIA PARA OBTENER EL PUNTAJE SOBRESALIENTE (20/20)
**Asignatura:** Desarrollo de Aplicaciones Móviles (DAM)  
**Proyecto:** Aplicación Móvil Comercializadora Aly S.A.  

Esta guía contiene la estrategia detallada y sustentada técnicamente para que el grupo logre los **4 puntos (Sobresaliente)** en cada uno de los 5 criterios de la rúbrica de evaluación final.

---

## 1. PRESENTACIÓN COMERCIAL (PITCH DE VENTA) — [4 Puntos]
*Criterio: Presentación clara, convincente y profesional; comunica el problema, la solución y los beneficios de la app.*

### 🎯 Estructura de Pitch Sugerida (Fórmula del Gancho Comercial):
1. **El Problema (El dolor del cliente):** 
   *"El sector ferretero y de construcción en la región central del país sufre de retrasos y falta de visibilidad en el suministro de insumos críticos. Los compradores tradicionales pierden tiempo llamando, cotizando por separado o esperando camiones de reparto sin saber exactamente dónde se encuentran o cuándo llegarán, paralizando las obras."*
2. **La Solución (Nuestra propuesta):**
   *"Presentamos Aly Móvil, la primera plataforma logística y de adquisición inteligente integrada con Inteligencia Artificial y geolocalización en tiempo real para Comercializadora Aly. Diseñada específicamente para optimizar la cadena de suministro de obras de construcción."*
3. **Beneficios Clave:**
   * **Inmediatez y Control:** Compra en 3 pasos con cálculo automático de ruta, distancia y tiempo estimado mediante GPS y mapa interactivo.
   * **Asistente Experto IA 24/7:** Un bot conversacional inteligente integrado con Gemini que resuelve dudas técnicas sobre dosificación de cemento, torque de pernos o fichas técnicas en segundos.
   * **Transparencia Absoluta:** Emisión automática de boletas electrónicas en PDF con RUC y detalle de productos directo a tu bandeja.

---

## 2. DEMOSTRACIÓN DEL APK (EXPOSICIÓN EN VIVO) — [4 Puntos]
*Criterio: Demostración fluida; la app funciona correctamente en todas las pantallas mostradas.*

### 🛠️ Protocolo de Demostración Segura en la Defensa:
Para evitar cualquier fallo en vivo, sigan esta ruta exacta durante la exposición:
1. **Inicio de Sesión y Perfiles:** 
   * Muestren el **diseño responsivo split-screen** de la versión Web (`isWide` layout) ingresando con la cuenta `comp_maria` (comprador).
   * Muestren que en móviles el diseño se ajusta automáticamente.
2. **Uso del Asistente IA (Gemini):**
   * Abran el chat interactivo y escriban consultas como: `"Calcular torque para perno de 1/2"` o `"¿Cómo calibro mi nivelador digital?"` para demostrar la velocidad de respuesta del modelo integrado.
   * Muestren que al cerrar sesión y loguearse con otro usuario, el chat del usuario anterior es inaccesible y privado.
3. **Flujo de Compra y Mapa de Delivery:**
   * Agreguen productos al carrito y procedan a la pasarela de pagos.
   * Seleccionen la opción de **Ubicar Delivery por Pin**. Toquen el mapa en vivo en una coordenada real de Huancayo y demuestren cómo la API de Mapbox Directions calcula la ruta, distancia (en km) y tiempo de llegada.
   * Presionen **Confirmar y Pagar** y muestren la boleta detallada del pago exitoso con el logo, el RUC `10432247657` y la lista de productos.
4. **Seguimiento del Delivery en Vivo (Simulación Hilo Activo):**
   * Presionen el botón de seguimiento en vivo. Muestren cómo el ícono del camión avanza sobre la línea trazada en el mapa en vivo actualizando la distancia restante y enviando notificaciones locales al llegar a su destino.
   * Demuestren cómo al llegar a su destino el estado en la colección `pedidos` de Firestore se actualiza automáticamente de `pendiente` a `entregado` en tiempo real.

---

## 3. EXPLICACIÓN DE FUNCIONALIDADES IMPLEMENTADAS — [4 Puntos]
*Criterio: Explica todas las funciones implementadas con orden y sustento técnico.*

Preparen diapositivas o material visual centrado en los siguientes módulos desarrollados:
* **Módulo de Autenticación y Privacidad:** Inicio de sesión estructurado por roles (Admin/Comprador) sincronizado con Firebase Auth y Firestore, con almacenamiento local encriptado y segregación completa de datos de usuario.
* **Módulo de Catálogo y Carrito:** Carga dinámica de productos segmentados por categorías industriales con cálculo en tiempo real de subtotales, totales e inventario disponible.
* **Módulo de Geolocalización (Mapbox API):** Trazado dinámico de rutas geodésicas en mapas utilizando el servicio Directions de Mapbox, calculando variables de transporte (km, min) de origen a destino.
* **Módulo de Seguimiento Logístico (Simulado sobre GPS):** Hilo periódico en segundo plano que simula el movimiento del vehículo de reparto actualizando la ubicación geográfica y disparando notificaciones Push/Locales mediante el Gestor de Notificaciones.
* **Módulo de Facturación y Comprobantes (PDF):** Generador de documentos PDF en el dispositivo móvil con inserción de assets binarios (Logos), tablas dinámicas con firmas y RUC empresarial oficial.
* **Módulo de Asistente Experto (IA Integrada):** Chat inteligente con memoria contextual persistente conectado al modelo generativo Gemini mediante peticiones HTTP asíncronas seguras.

---

## 4. JUSTIFICACIÓN TÉCNICA (ARQUITECTURA Y DECISIONES) — [4 Puntos]
*Criterio: Justifica tecnologías, estructura, manejo de datos, permisos y navegación.*

El docente evaluará el sustento tecnológico. Utilicen este marco argumentativo:
* **Framework y Lenguaje (Flutter / Dart):**
     * *Justificación:* Permite un desarrollo multiplataforma (iOS, Android y Web) con un único código base. Su motor gráfico Impeller/Skia garantiza 60 FPS estables ideales para el renderizado del mapa dinámico en vivo.
* **Arquitectura de Software (Clean Architecture + Riverpod):**
     * *Justificación:* Separación estricta de capas en **Data** (servicios de red, repositorios de base de datos), **Domain** (modelos de negocio) y **Presentation** (UI, pantallas, estados). El uso de Riverpod asegura un flujo de datos unidireccional, simplifica las pruebas unitarias y evita estados mutados huérfanos.
* **Base de Datos y Sesiones (Cloud Firestore + SharedPreferences):**
     * *Justificación:* Firestore proporciona persistencia en la nube y sincronización de datos en tiempo real (Offline-First) mediante listeners reactivos. SharedPreferences almacena de forma segura datos de sesión y preferencias del dispositivo local sin latencia.
* **Integración del Mapa (Flutter Map + Mapbox Directions):**
     * *Justificación:* Flutter Map utiliza tiles vectoriales abiertos optimizando el rendimiento y consumo de memoria RAM. Mapbox provee la ruta óptima mediante grafos de calles reales de Huancayo en formato de coordenadas GeoJSON.

---

## 5. ORIGINALIDAD, MEJORAS Y VALOR AGREGADO — [4 Puntos]
*Criterio: Presenta mejoras claras, ideas innovadoras y valor agregado notable para la empresa real.*

Durante la sustentación, destaquen estas **3 ideas disruptivas** implementadas en su app como el factor diferenciador:
1. **Asistente Técnico con IA de Obra (Gemini):**
   * *Valor agregado:* No es un chatbot genérico de preguntas y respuestas; está configurado como un asistente especializado en ingeniería y construcción. Puede calcular la cantidad de cemento y arena fina necesarios para tarrajear una pared de determinado tamaño en segundos. Esto fideliza al cliente y reduce la tasa de abreviatura de compra.
2. **Pasarela de Despacho con Pin GPS Personalizado:**
   * *Valor agregado:* Resuelve el problema de las direcciones imprecisas en Perú y zonas periféricas sin nomenclatura de calles. El usuario simplemente arrastra y suelta el pin en el mapa y la aplicación genera las coordenadas GPS exactas para que el conductor de reparto llegue directamente.
3. **Simulador de Delivery Activo y Notificaciones:**
   * *Valor agregado:* Informa activamente al cliente sobre el estado de su pedido, estimando el tiempo de llegada real basándose en la distancia geográfica calculada por Mapbox.

---

## 💡 Recomendaciones para la Exposición del Grupo
* **Duración:** Planifiquen la defensa para durar exactamente **12 minutos** (8 minutos para el pitch y sustentación de arquitectura, 4 minutos para la demostración del APK en vivo).
* **Demostración:** Compartan la pantalla del emulador o dispositivo real usando software de duplicado (ej. Scrcpy o Vysor) para que se observe el APK funcionando con fluidez.
* **Roles:** Dividan la exposición. Un integrante puede liderar el Pitch de Ventas (Punto 1 y 5), otro explicar el APK en vivo (Punto 2 y 3) y otro detallar la Arquitectura y Decisiones Técnicas (Punto 4).
