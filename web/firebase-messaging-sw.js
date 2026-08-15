// Firebase Messaging Service Worker
// This file is required for Firebase Cloud Messaging to work on web.
// It handles background notifications when the app is not in the foreground.

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Initialize Firebase with your web app configuration
firebase.initializeApp({
    apiKey: 'AIzaSyAsoGcqMT_-mFR1J-5nUCC-HZFIstwzaFo',
    appId: '1:479561947288:web:2259765408badf820898ed',
    messagingSenderId: '479561947288',
    projectId: 'marivio-inventory-sales-a10db',
    authDomain: 'marivio-inventory-sales-a10db.firebaseapp.com',
    storageBucket: 'marivio-inventory-sales-a10db.firebasestorage.app',
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('Received background message: ', payload);

    const notificationTitle = payload.notification?.title || 'Marivio ERP';
    const notificationOptions = {
        body: payload.notification?.body || '',
        icon: '/favicon.png',
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});