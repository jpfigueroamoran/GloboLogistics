// Firebase Cloud Messaging Service Worker
// Este archivo es requerido por firebase_messaging en Flutter Web.
// Habilita notificaciones push cuando la app está en background o cerrada.

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Configuración del proyecto Firebase (igual que firebase_options.dart → web)
firebase.initializeApp({
  apiKey:            "AIzaSyCyMfRBqAsxJCXhvzsX3bz4ured5PHvSLc",
  authDomain:        "globo-logisti.firebaseapp.com",
  projectId:         "globo-logisti",
  storageBucket:     "globo-logisti.firebasestorage.app",
  messagingSenderId: "78981510555",
  appId:             "1:78981510555:web:53945f5a95fc6729c31d3e",
});

const messaging = firebase.messaging();

// Handler de mensajes en background
messaging.onBackgroundMessage((payload) => {
  const title   = payload.notification?.title ?? "Globo Logistics";
  const body    = payload.notification?.body  ?? "";
  const options = {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data,
    // Para alertas SOS — reemplaza el sonido por defecto
    vibrate: payload.data?.tipo === "sos" ? [200, 100, 200] : [100],
  };
  return self.registration.showNotification(title, options);
});

// Manejar clic en notificación — enfoca la ventana o la abre
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && "focus" in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow("/");
      }
    })
  );
});
