// ==========================================================================
// Aly Industrial - Premium Web Application Logic
// ==========================================================================

// --- App State ---
let cart = [];
let orders = [];
let activeFilters = {
  search: '',
  category: null,
  maxPrice: 1000
};

// Coordenadas simuladas para el cálculo de distancia
const tiendaCoords = { x: 45, y: 40 }; // Centro en el mapa (porcentaje)
let userCoords = { x: 60, y: 60 };

// Catálogo de Productos Oficiales
const products = [
  { id: 'PROD-001', nombre: 'Electrodo de Soldadura 6011 3/32" (1kg)', categoria: 'Abrasivos y Consumibles', subcategoria: 'Soldadura', precioUnitario: 13.00, unidad: 'kg', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop' },
  { id: 'PROD-002', nombre: 'Rotomartillo Aly Industrial 800W', categoria: 'Herramientas Eléctricas', subcategoria: 'Perforación', precioUnitario: 249.00, unidad: 'un.', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop' },
  { id: 'PROD-003', nombre: 'Nivelador Digital de Burbuja Aly Pro', categoria: 'Instrumentos de Medición', subcategoria: 'Nivelación', precioUnitario: 85.00, unidad: 'un.', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop' },
  { id: 'PROD-004', nombre: 'Cemento Industrial Extra Forte Aly (42.5kg)', categoria: 'Materiales de Construcción', subcategoria: 'Bolsas', precioUnitario: 28.50, unidad: 'bolsa', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=500&auto=format&fit=crop' },
  { id: 'PROD-005', nombre: 'Amoladora Angular Aly 4-1/2" Pro', categoria: 'Herramientas Eléctricas', subcategoria: 'Corte', precioUnitario: 125.00, unidad: 'un.', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=500&auto=format&fit=crop' },
  { id: 'PROD-006', nombre: 'Silicona Aly Ultra Selladora 300ml', categoria: 'Abrasivos y Consumibles', subcategoria: 'Adhesivos', precioUnitario: 15.00, unidad: 'tubo', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop' },
  { id: 'PROD-007', nombre: 'Casco de Seguridad Aly con Suspensión', categoria: 'Equipos de Protección', subcategoria: 'Seguridad', precioUnitario: 22.00, unidad: 'un.', disponible: true, imagenUrl: 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=500&auto=format&fit=crop' },
  { id: 'PROD-008', nombre: 'Cinta Métrica Industrial Aly (5m)', categoria: 'Instrumentos de Medición', subcategoria: 'Medición', precioUnitario: 12.50, unidad: 'un.', disponible: false, imagenUrl: 'https://images.unsplash.com/photo-1534224039826-c7a0dea0e66a?w=500&auto=format&fit=crop' }
];

// Conversaciones simuladas del chatbot
const chatResponses = {
  default: "¡Hola! Soy el asistente Aly IA. Pregúntame sobre torque de pernos, calibración de niveles o insumos de obra.",
  torque: "Para pernos de grado industrial: un perno de 1/2\" UNC Grado 5 requiere aproximadamente 75 lb-pie (101 Nm) con lubricación estándar, o 110 lb-pie (149 Nm) seco. ¿Deseas calcular otro perno?",
  nivelador: "Para calibrar tu Nivelador Digital Aly:\n1. Colócalo en una superficie horizontal plana.\n2. Presiona y mantén el botón CAL durante 3 segundos hasta que parpadee.\n3. Gira el nivelador 180° sobre sí mismo y presiona CAL de nuevo. La pantalla mostrará 0.0° y se emitirá un pitido de confirmación.",
  insumos: "Para cubrir 50m² de tarrajeo grueso (1.5cm espesor), necesitarás aproximadamente:\n- 12.5 bolsas de Cemento Aly Extra Forte (42.5kg)\n- 1.15m³ de arena fina.\n- 180 litros de agua.\n\n¿Quieres que añada las bolsas de cemento al carrito?",
  cemento: "El cemento Aly Extra Forte está formulado con aditivos plastificantes que evitan fisuras y mejoran la trabajabilidad. Cuesta S/ 28.50 la bolsa."
};

// --- DOM elements ---
document.addEventListener('DOMContentLoaded', () => {
  initApp();
  registerEvents();
});

function initApp() {
  // Load mock database from localStorage
  const savedOrders = localStorage.getItem('aly_orders');
  if (savedOrders) {
    orders = JSON.parse(savedOrders);
  } else {
    // Populate default history
    orders = [
      { id: 'BOL-B001-382903', fecha: '28/06/2026 10:15', producto: 'Electrodo de Soldadura 6011 3/32" (1kg)', total: 26.00, estado: 'entregado', delivery: '12 min', items: [{ nombre: 'Electrodo de Soldadura 6011 3/32" (1kg)', cantidad: 2, precio: 13.00 }] },
      { id: 'BOL-B001-390293', fecha: '29/06/2026 15:44', producto: 'Rotomartillo Aly Industrial 800W y 1 más', total: 277.50, estado: 'entregado', delivery: '9 min', items: [{ nombre: 'Rotomartillo Aly Industrial 800W', cantidad: 1, precio: 249.00 }, { nombre: 'Cemento Industrial Extra Forte Aly (42.5kg)', cantidad: 1, precio: 28.50 }] }
    ];
    localStorage.setItem('aly_orders', JSON.stringify(orders));
  }

  // Initial UI Render
  renderDashboard();
  renderCatalog();
  renderOrdersTable();
  renderInvoicesTable();
  initCharts();
  renderChatbot();
}

function registerEvents() {
  // Tab Switch logic
  document.querySelectorAll('.menu-item').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const tabId = btn.getAttribute('data-tab');
      switchTab(tabId);
    });
  });

  // Theme Toggler
  document.getElementById('btn-toggle-theme').addEventListener('click', () => {
    document.body.classList.toggle('light-theme');
    const icon = document.querySelector('#btn-toggle-theme i');
    if (document.body.classList.contains('light-theme')) {
      icon.className = 'fa-solid fa-sun';
    } else {
      icon.className = 'fa-solid fa-moon';
    }
  });

  // Open / Close Cart Drawer
  document.getElementById('btn-open-cart').addEventListener('click', () => {
    document.getElementById('cart-modal').style.display = 'block';
    setTimeout(() => {
      document.getElementById('cart-modal').classList.add('active');
    }, 10);
  });

  document.getElementById('btn-close-cart').addEventListener('click', () => {
    document.getElementById('cart-modal').classList.remove('active');
    setTimeout(() => {
      document.getElementById('cart-modal').style.display = 'none';
    }, 300);
  });

  // Open / Close Checkout
  document.getElementById('btn-go-checkout').addEventListener('click', () => {
    document.getElementById('cart-modal').classList.remove('active');
    setTimeout(() => {
      document.getElementById('cart-modal').style.display = 'none';
      openCheckoutModal();
    }, 300);
  });

  document.getElementById('btn-close-checkout').addEventListener('click', () => {
    document.getElementById('checkout-modal').style.display = 'none';
  });

  // Radio delivery toggles
  document.querySelectorAll('input[name="delivery-type"]').forEach(radio => {
    radio.addEventListener('change', (e) => {
      const isManual = e.target.value === 'manual';
      document.getElementById('manual-address-group').style.display = isManual ? 'block' : 'none';
      if (!isManual) {
        // Reset pin position on GPS select
        moveMapPin({ x: 60, y: 60 });
      }
    });
  });

  // Tapping map selector
  document.getElementById('map-interaction-area').addEventListener('click', (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;
    
    // Only map tapping works if manual address option is checked
    const manualRadio = document.querySelector('input[name="delivery-type"][value="manual"]');
    if (manualRadio.checked) {
      moveMapPin({ x, y });
    }
  });

  // Confirm payment form submit
  document.getElementById('checkout-form').addEventListener('submit', (e) => {
    e.preventDefault();
    processCheckout();
  });

  // Finish checkout modals
  document.getElementById('btn-finish-checkout').addEventListener('click', () => {
    document.getElementById('receipt-modal').style.display = 'none';
    switchTab('orders');
  });

  document.getElementById('btn-print-receipt').addEventListener('click', () => {
    alert('Imprimiendo recibo correlativo en la impresora conectada...');
  });

  // Close invoice details modal
  document.getElementById('btn-close-invoice-details').addEventListener('click', () => {
    document.getElementById('invoice-details-modal').style.display = 'none';
  });

  document.getElementById('btn-download-pdf-real').addEventListener('click', () => {
    alert('Descargando comprobante oficial en formato PDF...');
  });

  document.getElementById('btn-print-pdf-real').addEventListener('click', () => {
    window.print();
  });

  // Catalog Filters query
  document.getElementById('catalog-search').addEventListener('input', (e) => {
    activeFilters.search = e.target.value;
    filterProducts();
  });

  document.getElementById('price-max-slider').addEventListener('input', (e) => {
    const val = e.target.value;
    activeFilters.maxPrice = parseFloat(val);
    document.getElementById('price-max-lbl').innerText = `S/ ${val}`;
    filterProducts();
  });

  document.getElementById('btn-clear-filters').addEventListener('click', () => {
    activeFilters.search = '';
    activeFilters.category = null;
    activeFilters.maxPrice = 1000;
    document.getElementById('catalog-search').value = '';
    document.getElementById('price-max-slider').value = 1000;
    document.getElementById('price-max-lbl').innerText = 'S/ 1000';
    
    document.querySelectorAll('.category-item').forEach(item => item.classList.remove('active'));
    document.querySelector('.category-item[data-cat="all"]').classList.add('active');
    
    filterProducts();
  });

  // Chatbot send message
  document.getElementById('btn-send-chat').addEventListener('click', sendChatMessage);
  document.getElementById('chat-input').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendChatMessage();
  });

  document.getElementById('btn-clear-chat').addEventListener('click', () => {
    if (confirm('¿Vaciar todo el historial de chat con la IA?')) {
      localStorage.removeItem('gemini_chat_history');
      renderChatbot();
    }
  });

  // Go to tab helpers
  document.querySelectorAll('.btn-go-to-tab').forEach(btn => {
    btn.addEventListener('click', () => {
      switchTab(btn.getAttribute('data-tab'));
    });
  });
}

// --- SPA Navigation ---
function switchTab(tabId) {
  // Update sidebar active buttons
  document.querySelectorAll('.menu-item').forEach(btn => {
    btn.classList.remove('active');
    if (btn.getAttribute('data-tab') === tabId) {
      btn.classList.add('active');
    }
  });

  // Show selected pane
  document.querySelectorAll('.tab-pane').forEach(pane => {
    pane.classList.remove('active');
  });
  const activePane = document.getElementById(`tab-${tabId}`);
  if (activePane) activePane.classList.add('active');
}

// --- UI rendering: Dashboard ---
function renderDashboard() {
  // Stats numbers
  const totalInvoiced = orders.reduce((sum, o) => sum + o.total, 0);
  const totalItemsCount = orders.reduce((sum, o) => {
    return sum + o.items.reduce((iSum, i) => iSum + i.cantidad, 0);
  }, 0);

  document.getElementById('stat-total-orders').innerText = orders.length;
  document.getElementById('stat-active-products').innerText = totalItemsCount;
  document.getElementById('stat-total-revenue').innerText = `S/ ${totalInvoiced.toFixed(2)}`;

  // Populate recent orders list
  const recentList = document.getElementById('recent-orders-list');
  recentList.innerHTML = '';
  
  // Show up to 4 recent orders
  const recentOrders = orders.slice().reverse().slice(0, 4);
  recentOrders.forEach(o => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><strong>${o.id}</strong></td>
      <td>${o.fecha}</td>
      <td>${o.producto}</td>
      <td><strong>S/ ${o.total.toFixed(2)}</strong></td>
      <td><span class="status-pill ${o.estado}">${o.estado === 'pendiente' ? 'pendiente' : 'entregado'}</span></td>
    `;
    recentList.appendChild(tr);
  });
}

// --- UI rendering: Catalog ---
function renderCatalog() {
  // Render Categories List in sidebar filter
  const catList = document.getElementById('category-filter-list');
  catList.innerHTML = '';

  const categories = ['all', 'Manuales', 'Eléctricas', 'Construcción', 'EPP', 'Abrasivos', 'Medición'];
  const catLabels = {
    all: 'Todas',
    Manuales: 'H. Manuales',
    Eléctricas: 'H. Eléctricas',
    Construcción: 'M. Construcción',
    EPP: 'Seguridad / EPP',
    Abrasivos: 'Consumibles',
    Medición: 'Medición'
  };
  const catIcons = {
    all: 'fa-cubes',
    Manuales: 'fa-screwdriver-wrench',
    Eléctricas: 'fa-bolt',
    Construcción: 'fa-trowel-bricks',
    EPP: 'fa-helmet-safety',
    Abrasivos: 'fa-spray-can-sparkles',
    Medición: 'fa-compass-drafting'
  };

  categories.forEach(cat => {
    const div = document.createElement('div');
    div.className = `category-item ${activeFilters.category === cat || (cat === 'all' && activeFilters.category === null) ? 'active' : ''}`;
    div.setAttribute('data-cat', cat);
    div.innerHTML = `
      <div>
        <i class="fa-solid ${catIcons[cat]}"></i>
        <span>${catLabels[cat]}</span>
      </div>
      <i class="fa-solid fa-angle-right text-gray arrow-chevron"></i>
    `;
    div.addEventListener('click', () => {
      document.querySelectorAll('.category-item').forEach(item => item.classList.remove('active'));
      div.classList.add('active');
      activeFilters.category = cat === 'all' ? null : cat;
      filterProducts();
    });
    catList.appendChild(div);
  });

  filterProducts();
}

function filterProducts() {
  const filtered = products.filter(p => {
    // Search query match
    const searchMatch = p.nombre.toLowerCase().includes(activeFilters.search.toLowerCase());
    
    // Category match
    let catMatch = true;
    if (activeFilters.category) {
      catMatch = p.categoria.toLowerCase().includes(activeFilters.category.toLowerCase());
    }

    // Price match
    const priceMatch = p.precioUnitario <= activeFilters.maxPrice;

    return searchMatch && catMatch && priceMatch;
  });

  // Render Grid
  const grid = document.getElementById('products-grid');
  grid.innerHTML = '';

  document.getElementById('catalog-results-count').innerText = `Mostrando ${filtered.length} productos`;

  if (filtered.length === 0) {
    grid.innerHTML = `
      <div class="cart-empty-msg" style="grid-column: 1/-1; height: 250px;">
        <i class="fa-solid fa-magnifying-glass"></i>
        <span>No se encontraron productos con los filtros aplicados.</span>
      </div>
    `;
    return;
  }

  filtered.forEach((p, index) => {
    const card = document.createElement('div');
    card.className = 'product-card';
    card.style.animationDelay = `${index * 0.05}s`;

    let badgeClass = 'manual';
    if (p.categoria.includes('Eléctricas')) badgeClass = 'electrica';
    else if (p.categoria.includes('Construcción')) badgeClass = 'construccion';
    else if (p.categoria.includes('EPP')) badgeClass = 'epp';
    else if (p.categoria.includes('Abrasivos')) badgeClass = 'abrasivos';
    else if (p.categoria.includes('Medición')) badgeClass = 'medicion';

    card.innerHTML = `
      <div class="product-img-box">
        <img src="${p.imagenUrl}" alt="${p.nombre}" class="product-img">
        <span class="product-badge ${badgeClass}">${p.categoria}</span>
      </div>
      <div class="product-details">
        <h4 class="product-title" title="${p.nombre}">${p.nombre}</h4>
        <div class="product-footer">
          <div class="product-price">S/ ${p.precioUnitario.toFixed(2)} <span>x ${p.unidad}</span></div>
          <button class="btn-add-cart-card" ${p.disponible ? '' : 'disabled style="background-color: var(--border-white); cursor: not-allowed;"'} title="Añadir al carrito">
            <i class="fa-solid ${p.disponible ? 'fa-cart-plus' : 'fa-ban'}"></i>
          </button>
        </div>
      </div>
    `;

    // Add item to cart click event
    if (p.disponible) {
      card.querySelector('.btn-add-cart-card').addEventListener('click', (e) => {
        e.stopPropagation();
        addToCart(p);
      });
    }

    grid.appendChild(card);
  });
}

// --- Cart CRUD ---
function addToCart(product) {
  const existing = cart.find(item => item.product.id === product.id);
  if (existing) {
    existing.quantity += 1;
  } else {
    cart.push({ product, quantity: 1 });
  }
  updateCartUI();
}

function updateCartUI() {
  const count = cart.reduce((sum, item) => sum + item.quantity, 0);
  document.getElementById('cart-badge-count').innerText = count;

  const cartList = document.getElementById('cart-items-list');
  cartList.innerHTML = '';

  if (cart.length === 0) {
    cartList.innerHTML = `
      <div class="cart-empty-msg">
        <i class="fa-solid fa-cart-flatbed-suitcase"></i>
        <span>Tu carrito está vacío. ¡Agrega herramientas de catálogo!</span>
      </div>
    `;
    document.getElementById('btn-go-checkout').disabled = true;
    updateCartTotals(0);
    return;
  }

  document.getElementById('btn-go-checkout').disabled = false;
  let subtotal = 0;

  cart.forEach(item => {
    const itemTotal = item.product.precioUnitario * item.quantity;
    subtotal += itemTotal;

    const div = document.createElement('div');
    div.className = 'cart-item';
    div.innerHTML = `
      <img src="${item.product.imagenUrl}" alt="${item.product.nombre}" class="cart-item-img">
      <div class="cart-item-info">
        <span class="cart-item-title">${item.product.nombre}</span>
        <span class="cart-item-price">S/ ${itemTotal.toFixed(2)}</span>
      </div>
      <div class="cart-item-controls">
        <button class="cart-qty-btn btn-qty-minus">-</button>
        <span class="cart-item-qty">${item.quantity}</span>
        <button class="cart-qty-btn btn-qty-plus">+</button>
      </div>
      <button class="cart-remove-btn"><i class="fa-solid fa-trash-can"></i></button>
    `;

    div.querySelector('.btn-qty-minus').addEventListener('click', () => {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        cart = cart.filter(i => i.product.id !== item.product.id);
      }
      updateCartUI();
    });

    div.querySelector('.btn-qty-plus').addEventListener('click', () => {
      item.quantity++;
      updateCartUI();
    });

    div.querySelector('.cart-remove-btn').addEventListener('click', () => {
      cart = cart.filter(i => i.product.id !== item.product.id);
      updateCartUI();
    });

    cartList.appendChild(div);
  });

  updateCartTotals(subtotal);
}

function updateCartTotals(subtotal) {
  const igv = subtotal - (subtotal / 1.18);
  const base = subtotal / 1.18;

  document.getElementById('cart-subtotal').innerText = `S/ ${base.toFixed(2)}`;
  document.getElementById('cart-igv').innerText = `S/ ${igv.toFixed(2)}`;
  document.getElementById('cart-total').innerText = `S/ ${subtotal.toFixed(2)}`;
}

// --- Checkout Modal ---
function openCheckoutModal() {
  const total = cart.reduce((sum, item) => sum + (item.product.precioUnitario * item.quantity), 0);
  document.getElementById('pay-total-value').innerText = `S/ ${total.toFixed(2)}`;
  
  // Set default checkout route calculation values
  calculateRouteDuration(userCoords);

  document.getElementById('checkout-modal').style.display = 'block';
}

function moveMapPin(point) {
  userCoords = point;
  
  // Update marker absolute position
  const pin = document.getElementById('map-pin');
  pin.style.left = `${point.x}%`;
  pin.style.top = `${point.y}%`;

  // Draw line between tienda (45, 40) and user pin (x, y)
  const line = document.getElementById('svg-line');
  line.setAttribute('x2', `${point.x}%`);
  line.setAttribute('y2', `${point.y}%`);

  // Calculate route duration and distance dynamically
  calculateRouteDuration(point);
}

function calculateRouteDuration(point) {
  // Math mapping: calculate euclidean distance between coords (percentage)
  const dx = point.x - tiendaCoords.x;
  const dy = point.y - tiendaCoords.y;
  const rawDist = Math.sqrt(dx * dx + dy * dy); // Percentage distance
  
  // Convert percentage distance to simulated km (1% approx 0.15 km in Huancayo)
  const km = rawDist * 0.15;
  const distanceStr = `${km.toFixed(1)} km`;

  // Standard speed 25 km/h + 2 min prep
  const minutes = Math.round((km / 25) * 60) + 2;
  const durationStr = `${minutes} min`;

  document.getElementById('calc-distance').innerText = distanceStr;
  document.getElementById('calc-duration').innerText = durationStr;
}

function processCheckout() {
  document.getElementById('btn-pay-action').disabled = true;
  document.getElementById('btn-pay-action').innerText = 'PROCESANDO...';

  // Get total
  const total = cart.reduce((sum, item) => sum + (item.product.precioUnitario * item.quantity), 0);
  const distance = document.getElementById('calc-distance').innerText;
  const duration = document.getElementById('calc-duration').innerText;

  setTimeout(() => {
    // Generate new random real correlation boleta code
    const boletaCode = `BOL-B001-${Math.floor(Math.random() * 899999 + 100000)}`;
    const formattedDate = new Date().toLocaleDateString('es-PE') + ' ' + new Date().toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });

    // Prepare order details
    const productStr = cart.length === 1 
        ? cart[0].product.nombre 
        : `${cart[0].product.nombre} y ${cart.length - 1} más`;

    const newOrder = {
      id: boletaCode,
      fecha: formattedDate,
      producto: productStr,
      total: total,
      estado: 'pendiente',
      delivery: duration,
      items: cart.map(i => ({ nombre: i.product.nombre, cantidad: i.quantity, precio: i.product.precioUnitario }))
    };

    // Save to orders db
    orders.push(newOrder);
    localStorage.setItem('aly_orders', JSON.stringify(orders));

    // Clear cart
    cart = [];
    updateCartUI();

    // Re-render UI
    renderDashboard();
    renderOrdersTable();
    renderInvoicesTable();
    updateChartsData();

    // Show Success Modal
    document.getElementById('checkout-modal').style.display = 'none';
    document.getElementById('btn-pay-action').disabled = false;
    document.getElementById('btn-pay-action').innerText = 'CONFIRMAR Y PAGAR';

    // Populate receipt details
    document.getElementById('receipt-code').innerText = boletaCode;
    document.getElementById('receipt-date').innerText = formattedDate;
    document.getElementById('receipt-total').innerText = `S/ ${total.toFixed(2)}`;
    document.getElementById('receipt-delivery').innerText = duration;
    
    document.getElementById('receipt-modal').style.display = 'block';

  }, 1500);
}

// --- Orders History Table ---
function renderOrdersTable() {
  const tbody = document.getElementById('orders-full-list');
  tbody.innerHTML = '';

  if (orders.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay pedidos registrados.</td></tr>';
    return;
  }

  // Reverse list to show newest first
  orders.slice().reverse().forEach(o => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><strong>${o.id}</strong></td>
      <td>${o.fecha}</td>
      <td>${o.producto}</td>
      <td><strong>S/ ${o.total.toFixed(2)}</strong></td>
      <td><span class="status-pill ${o.estado}">${o.estado}</span></td>
      <td><i class="fa-solid fa-truck-ramp-box text-orange"></i> ${o.delivery}</td>
    `;
    tbody.appendChild(tr);
  });
}

// --- Invoices Table ---
function renderInvoicesTable() {
  const tbody = document.getElementById('invoices-full-list');
  tbody.innerHTML = '';

  if (orders.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay boletas generadas.</td></tr>';
    return;
  }

  orders.slice().reverse().forEach(o => {
    const itemsCount = o.items.reduce((sum, item) => sum + item.cantidad, 0);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><strong>${o.id}</strong></td>
      <td>${o.fecha}</td>
      <td>María López</td>
      <td>${itemsCount} un.</td>
      <td><strong>S/ ${o.total.toFixed(2)}</strong></td>
      <td>
        <button class="btn-receipt-action secondary btn-open-invoice-details" style="padding: 6px 12px; margin: 0; font-size: 10px;">
          <i class="fa-solid fa-file-pdf"></i> Ver PDF
        </button>
      </td>
    `;
    
    tr.querySelector('.btn-open-invoice-details').addEventListener('click', () => {
      openInvoiceDetailsModal(o);
    });

    tbody.appendChild(tr);
  });
}

function openInvoiceDetailsModal(order) {
  // Populate PDF Preview Document
  document.getElementById('pdf-receipt-id').innerText = order.id;
  document.getElementById('pdf-client-date').innerText = order.fecha;
  document.getElementById('pdf-total').innerText = `S/ ${order.total.toFixed(2)}`;
  
  // Calculate base & tax
  const subtotalVal = order.total / 1.18;
  const igvVal = order.total - subtotalVal;
  document.getElementById('pdf-subtotal').innerText = `S/ ${subtotalVal.toFixed(2)}`;
  document.getElementById('pdf-igv').innerText = `S/ ${igvVal.toFixed(2)}`;

  // Populate list of items
  const itemsBody = document.getElementById('pdf-items-body');
  itemsBody.innerHTML = '';

  order.items.forEach(i => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${i.nombre}</td>
      <td class="text-center">${i.cantidad}</td>
      <td class="text-right">S/ ${i.precio.toFixed(2)}</td>
      <td class="text-right">S/ ${(i.precio * i.cantidad).toFixed(2)}</td>
    `;
    itemsBody.appendChild(tr);
  });

  document.getElementById('invoice-details-modal').style.display = 'block';
}

// --- Chatbot Section ---
function renderChatbot() {
  const messagesContainer = document.getElementById('chat-messages');
  messagesContainer.innerHTML = '';

  let chatHistory = [];
  const savedChat = localStorage.getItem('gemini_chat_history');
  if (savedChat) {
    chatHistory = JSON.parse(savedChat);
  } else {
    chatHistory = [
      { role: 'model', text: chatResponses.default }
    ];
    localStorage.setItem('gemini_chat_history', JSON.stringify(chatHistory));
  }

  chatHistory.forEach(msg => {
    const div = document.createElement('div');
    div.className = `chat-bubble ${msg.role}`;
    div.innerText = msg.text;
    messagesContainer.appendChild(div);
  });

  // Example prompts hooks
  document.querySelectorAll('.chat-prompt-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const text = btn.innerText.substring(2); // Skip icon prefix
      document.getElementById('chat-input').value = text;
      sendChatMessage();
    });
  });

  messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

function sendChatMessage() {
  const input = document.getElementById('chat-input');
  const text = input.value.trim();
  if (!text) return;

  const messagesContainer = document.getElementById('chat-messages');

  // Add User bubble
  const userDiv = document.createElement('div');
  userDiv.className = 'chat-bubble user';
  userDiv.innerText = text;
  messagesContainer.appendChild(userDiv);
  messagesContainer.scrollTop = messagesContainer.scrollHeight;

  // Save chat to state & local
  let chatHistory = JSON.parse(localStorage.getItem('gemini_chat_history') || '[]');
  chatHistory.push({ role: 'user', text: text });
  localStorage.setItem('gemini_chat_history', JSON.stringify(chatHistory));

  input.value = '';

  // Add simulated Loading bubble
  const loadDiv = document.createElement('div');
  loadDiv.className = 'chat-bubble model loading';
  loadDiv.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i><span>Gemini está pensando...</span>';
  messagesContainer.appendChild(loadDiv);
  messagesContainer.scrollTop = messagesContainer.scrollHeight;

  // Process response delay
  setTimeout(() => {
    // Remove loading
    loadDiv.remove();

    // Check custom responses keys
    let responseText = "Entendido. Como asistente IA de Aly Industrial, puedo informarte que contamos con stock completo de cemento Extra Forte, silicona ultra selladora y electrodos de soldadura. Escríbeme cualquier consulta técnica sobre estos materiales.";
    const query = text.toLowerCase();
    
    if (query.includes('torque') || query.includes('perno')) {
      responseText = chatResponses.torque;
    } else if (query.includes('calibr') || query.includes('nivelador')) {
      responseText = chatResponses.nivelador;
    } else if (query.includes('insumo') || query.includes('50m') || query.includes('obra')) {
      responseText = chatResponses.insumos;
    } else if (query.includes('cemento') || query.includes('bolsa')) {
      responseText = chatResponses.cemento;
    }

    const modelDiv = document.createElement('div');
    modelDiv.className = 'chat-bubble model';
    modelDiv.innerText = responseText;
    messagesContainer.appendChild(modelDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;

    // Save model response to history
    chatHistory.push({ role: 'model', text: responseText });
    localStorage.setItem('gemini_chat_history', JSON.stringify(chatHistory));

  }, 1000);
}

// --- Charts Setup ---
let chartSales, chartCategories;

function initCharts() {
  // Sales History Line Chart
  const ctxSales = document.getElementById('chart-sales').getContext('2d');
  chartSales = new Chart(ctxSales, {
    type: 'line',
    data: {
      labels: ['Semana 1', 'Semana 2', 'Semana 3', 'Semana 4'],
      datasets: [{
        label: 'Inversión en Insumos',
        data: [120, 190, 85, 482],
        borderColor: '#e67e22',
        backgroundColor: 'rgba(230, 126, 34, 0.1)',
        tension: 0.4,
        fill: true
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false }
      },
      scales: {
        y: { grid: { color: 'rgba(255,255,255,0.03)' }, ticks: { color: '#8b92b6' } },
        x: { grid: { display: false }, ticks: { color: '#8b92b6' } }
      }
    }
  });

  // Category Pie Chart
  const ctxCat = document.getElementById('chart-categories').getContext('2d');
  chartCategories = new Chart(ctxCat, {
    type: 'doughnut',
    data: {
      labels: ['Soldadura', 'H. Eléctricas', 'H. Manuales', 'Materiales'],
      datasets: [{
        data: [2, 1, 3, 2],
        backgroundColor: ['#e67e22', '#3498db', '#9b59b6', '#2ecc71'],
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'bottom', labels: { color: '#8b92b6', boxWidth: 12 } }
      }
    }
  });
}

function updateChartsData() {
  if (!chartSales || !chartCategories) return;

  // Compute category frequencies from orders
  const cats = { Soldadura: 0, Eléctricas: 0, Manuales: 0, Materiales: 0 };
  let weeklyInvoiced = [0, 0, 0, 0];

  orders.forEach((o, index) => {
    // Distribute total revenue over the weeks
    const weekIndex = index % 4;
    weeklyInvoiced[weekIndex] += o.total;

    // Distribute items categories
    o.items.forEach(i => {
      if (i.nombre.includes('Soldadura') || i.nombre.includes('Electrodo')) cats.Soldadura += i.cantidad;
      else if (i.nombre.includes('Rotomartillo') || i.nombre.includes('Amoladora')) cats.Eléctricas += i.cantidad;
      else if (i.nombre.includes('Nivel') || i.nombre.includes('Métrica')) cats.Manuales += i.cantidad;
      else if (i.nombre.includes('Cemento') || i.nombre.includes('Silicona')) cats.Materiales += i.cantidad;
    });
  });

  chartSales.data.datasets[0].data = weeklyInvoiced;
  chartSales.update();

  chartCategories.data.datasets[0].data = [cats.Soldadura, cats.Eléctricas, cats.Manuales, cats.Materiales];
  chartCategories.update();
}
