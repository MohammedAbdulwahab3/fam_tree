importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
    apiKey: "AIzaSyCP1pUXLjbmD63ii3OHWJ7aZWAMBMZe1Pw",
    authDomain: "family-tree-29547.firebaseapp.com",
    projectId: "family-tree-29547",
    storageBucket: "family-tree-29547.firebasestorage.app",
    messagingSenderId: "216305526466",
    appId: "1:216305526466:web:5d33476eed970ff4debd5b",
    measurementId: "G-KTHFRF3ZL2"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
