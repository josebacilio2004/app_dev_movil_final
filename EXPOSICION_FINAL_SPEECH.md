# 🎤 SPEECH COMPLETO DE EXPOSICIÓN: ECOINTEGRACIÓN DE ALY S.A.
**Ecosistema:** Aplicación Móvil (Flutter) & Portal de Gestión (HTML/JS)  
**Tiempo estimado total:** 15 minutos  

---

## INTRODUCCIÓN GENERAL (1.5 minutos)
**[Presenter 1]**  
> *"Estimado docente y compañeros de clase, buenos días. Hoy tenemos el agrado de presentarles nuestro proyecto final titulado **Ecosistema Digital Aly S.A.**.  
>  
> Comercializadora Aly S.A. es una empresa peruana real dedicada a la venta y distribución de herramientas industriales y materiales de construcción en la región centro del país. Identificamos que el sector ferretero sufre de tres grandes problemas: la imprecisión en las rutas de reparto, el retraso en las obras por falta de asesoría técnica inmediata y la desconexión entre la administración web y la aplicación del comprador.  
>  
> Para solucionar esto, hemos construido una solución de ingeniería de software integrada por dos grandes plataformas: una aplicación móvil interactiva desarrollada en **Flutter** para el cliente comprador, y una plataforma web administrativa independiente en **HTML/CSS/JS** conectada en tiempo real mediante **Cloud Firestore**. Este ecosistema incorpora Inteligencia Artificial generativa de Gemini, Geolocalización con Mapbox, Realidad Aumentada y lectura de sensores físicos de hardware."*

---

## 1. REGISTRO DE USUARIO E INICIO DE SESIÓN (1.5 minutos)
**[Presenter 1]**  
> *"Comencemos con el flujo de acceso de seguridad. La aplicación cuenta con una pantalla de Login premium adaptada a la identidad visual de la empresa.  
>  
> * **Registro de Usuario (Sign Up):** Permite a nuevos usuarios registrarse especificando su DNI, correo electrónico y credenciales. Al registrarse, el sistema crea de forma atómica el perfil de usuario en la colección `/users` de Firestore asignándole por defecto el rol de `comprador`.  
> * **Inicio de Sesión Inteligente (Sign In):** El login verifica las credenciales contra Firebase Auth y extrae dinámicamente el rol del usuario desde Firestore. Si el dispositivo cuenta con lector de huellas o reconocimiento facial, implementamos **autenticación biométrica mediante la librería Local Auth**, la cual encripta localmente las credenciales en `SharedPreferences` y las asocia con una clave única (`bio_enabled`), permitiendo accesos ultra rápidos y 100% seguros sin volver a escribir la contraseña."*

---

## 2. CATÁLOGO INTELIGENTE Y CARRITO DE COMPRA (1.5 minutos)
**[Presenter 2]**  
> *"Una vez autenticado, el usuario es redirigido directamente al **Catálogo de Productos**.  
>  
> * **Catálogo Dinámico:** Los productos se cargan directamente desde Firestore organizados por categorías (Herramientas manuales, eléctricas, materiales, tornillería, etc.). Incorporamos un **Buscador Asistido por Voz** mediante la API `speech_to_text`, ideal para que el obrero o carpintero dicte la herramienta que busca con las manos ocupadas.  
> * **Carrito de Compra Privado:** Aislamos completamente la sesión en memoria. Mediante Riverpod, el `cartProvider` observa el `authStateProvider`. Esto garantiza que los productos agregados al carrito se almacenen de forma privada en el almacenamiento local bajo una clave única indexada por el UID del usuario (`cart_${userId}`). Al cerrar sesión o cambiar de cuenta, el carrito se limpia de inmediato para proteger los datos de compra entre distintos dispositivos compartidos."*

---

## 3. PASARELA DE PAGO Y FACTURACIÓN PDF (1.5 minutos)
**[Presenter 2]**  
> *"Cuando el usuario decide proceder al checkout, es guiado a nuestra **Pasarela de Pagos**:  
>  
> * **Pasarela Interactiva:** Cuenta con un formulario de tarjeta de crédito interactiva en 3D que gira automáticamente sobre su propio eje al posicionar el foco sobre el campo de CVV, dando un efecto visual sumamente pulido.  
> * **Facturación Digital:** Al confirmarse la transacción simulada de la tarjeta con Firebase, la aplicación genera dinámicamente un comprobante de pago oficial en formato **PDF** en tiempo real. Esta boleta incluye el logo oficial de la empresa, el desglose exacto de cada producto comprado, su subtotal, el cálculo automático de impuestos (18% IGV) y el RUC oficial empresarial: **10432247657**, lista para descargarse en el dispositivo o enviarse a imprimir mediante la API nativa de impresión."*

---

## 4. CÓMO LLEGAR A LA TIENDA Y GEOLOCALIZACIÓN (1.5 minutos)
**[Presenter 3]**  
> *"Para los clientes que prefieren recoger sus materiales directamente, hemos implementado el módulo de **Geolocalización** integrado con **Mapbox**:  
>  
> * **Ruta en Tiempo Real:** El mapa carga la ubicación en tiempo real del GPS del dispositivo y traza una ruta geodésica óptima hacia la tienda física de Comercializadora Aly.  
> * **Geocerca de Arribo Inteligente:** Simulamos un perímetro o geocerca de seguridad de 500 y 200 metros alrededor de la tienda. Cuando el GPS detecta que el vehículo cruza este radio, la app dispara una **Notificación Local Push** informando al personal de almacén para que comience a despachar y preparar los materiales comprados, reduciendo los tiempos de espera del cliente a cero."*

---

## 5. HERRAMIENTAS ADICIONALES: NIVELADOR DIGITAL Y MEDIDOR LÁSER AR (2 minutos)
**[Presenter 3]**  
> *"Añadimos valor disruptivo a la app con herramientas de campo interactivas:  
>  
> * **Nivelador Digital Industrial:** Utiliza el sensor de acelerómetro de hardware para calcular los ángulos de inclinación (roll y pitch) del dispositivo en tiempo real. La interfaz simula un nivelador esmerilado con una burbuja que flota sobre la cuadrícula. Al lograr una alineación perfecta (0.0° con un margen de 0.8°), la app emite una **vibración háptica de confirmación** y brilla en verde.  
> * **Visualizador AR y Medidor Láser:** Permite tomar una fotografía del muro o espacio de trabajo de la obra. Sobre esta foto, el usuario puede proyectar las herramientas del catálogo en 3D, rotándolas, escalándolas y ajustando su inclinación física mediante el acelerómetro para comprobar visualmente si caben o si la alineación del montaje es la correcta antes de comprarlas."*

---

## 6. ASISTENTE CHATBOT EXPERTO IA (GEMINI) (1.5 minutos)
**[Presenter 1]**  
> *"En el núcleo de la asistencia técnica, incorporamos a **Gemini de Google**.  
>  
> * **Chatbot Técnico:** Este bot no es un canal genérico de ayuda. Cuenta con instrucciones contextuales de ingeniería para actuar como un asesor técnico de obra. Puede calcular dosificaciones exactas de cemento y arena fina, recomendar herramientas según la resistencia del material o explicar fichas técnicas industriales.  
> * **Memoria Persistente y Privada:** El historial de la conversación se almacena localmente utilizando claves personalizadas por usuario (`gemini_chat_history_${userId}`). Si otro usuario inicia sesión en el mismo dispositivo, sus conversaciones previas son inaccesibles y privadas."*

---

## 7. SEGUIMIENTO DE DELIVERY EN VIVO (1.5 minutos)
**[Presenter 2]**  
> *"Para compras a domicilio, implementamos el **Seguimiento Logístico**:  
>  
> * **Tracking Activo:** En el mapa interactivo se traza la ruta desde la tienda al pin GPS que el cliente marcó en la pasarela. Se inicializa un hilo simulador en segundo plano que avanza geográficamente simulando el camión de despacho en tiempo real.  
> * **Sincronización a Firestore:** El camión actualiza periódicamente sus coordenadas GPS en la colección `geolocalizacion_rutas`. Cuando el simulador detecta que el camión llega a las coordenadas exactas de la obra, actualiza de forma atómica el estado del pedido en la base de datos de `pendiente` a `entregado` en tiempo real, disparando notificaciones automáticas en el panel."*

---

## 8. CONFIGURACIÓN, COMENTARIOS Y SEGURIDAD (1.5 minutos)
**[Presenter 2]**  
> *"Por el lado de usabilidad y políticas generales:  
>  
> * **Bandeja de Notificaciones:** Cuenta con un historial completo de notificaciones guardado de forma persistente para que el usuario nunca pierda un aviso de facturación o entrega.  
> * **Configuraciones y Modo Offline:** Permite al usuario activar/desactivar notificaciones y alternar entre tema oscuro e industrial. La app detecta pérdidas de conexión a Internet y despliega un banner superior de alerta offline.  
> * **Reseñas de Productos:** Los usuarios pueden emitir calificaciones y comentarios sobre los productos del catálogo directamente a Firestore.  
> * **Seguridad Integral:** El backend implementa **Firestore Rules** protegiendo los datos confidenciales e impidiendo lecturas no autorizadas. Además, cada movimiento en el stock de inventario se registra en una colección de auditoría llamada `/inventario_movimientos` indicando el responsable y los valores anteriores y nuevos de stock."*

---

## 9. PLATAFORMA WEB INDEPENDIENTE DE GESTIÓN (1.5 minutos)
**[Presenter 3]**  
> *"Para cerrar el círculo de administración, desarrollamos el **Portal Web Administrativo** (HTML/CSS/JS) conectado en tiempo real a la misma base de datos.  
>  
> * **Modificador de Catálogo & Gestión de Inventario:** Permite a los operadores agregar productos, editar imágenes base64 o ajustar stocks en tiempo real. Cualquier cambio se ve reflejado instantáneamente en la aplicación móvil de los clientes.  
> * **Gestión de Pedidos en Vivo:** Un panel dinámico que lista los pedidos ingresados por los compradores móviles, permitiendo a los operadores ver las coordenadas geográficas exactas marcadas en el mapa y cambiar el estado del delivery en tiempo real.  
> * **Dashboards con Estética Industrial:** Visualización financiera premium mediante gráficos interactivos de ventas, ganancias e historial de adquisición para inversores y administradores, diseñados con estética de vidrio esmerilado translúcido (Glassmorphism)."*

---

## CIERRE Y CONCLUSIÓN (0.5 minutos)
**[Presenter 1]**  
> *"Como hemos visto, el **Ecosistema Digital Aly S.A.** no es una aplicación aislada, sino una plataforma empresarial integral que conecta logística, compras, realidad aumentada, inteligencia artificial y administración financiera en tiempo real, aportando valor de negocio real a la empresa y garantizando una experiencia de usuario sobresaliente. Muchas gracias por su atención. Quedamos atentos a sus preguntas."*
