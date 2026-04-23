const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, setDoc } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyBG7vx5LOU5bLZ4gs70-A_47ZNzrEAFgMo",
  authDomain: "sufel-event-app-2026.firebaseapp.com",
  projectId: "sufel-event-app-2026",
  storageBucket: "sufel-event-app-2026.firebasestorage.app",
  messagingSenderId: "624093324864",
  appId: "1:624093324864:web:c9bd38c9b484ca0915e1a5"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const seedAdmin = async () => {
  const email = "kindoanish436@gmail.com";
  const password = "AdminPassword@123";

  let user;
  try {
    console.log("Creating admin user...");
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    user = userCredential.user;
  } catch (error) {
    if (error.code === 'auth/email-already-in-use') {
       console.log("Email already in use, signing in to set admin role...");
       const userCredential = await signInWithEmailAndPassword(auth, email, password);
       user = userCredential.user;
    } else {
       console.error("Error creating/signing in:", error.message);
       process.exit(1);
    }
  }

  try {
    console.log("Setting role to 'admin' in Firestore for UID:", user.uid);
    await setDoc(doc(db, "users", user.uid), {
      email: email,
      role: 'admin',
      fcmToken: ''
    });

    console.log("Admin seeded successfully!");
    console.log("Email: " + email);
    console.log("Password: " + password);
    process.exit(0);
  } catch(error) {
    console.error("Firestore Error:", error);
    process.exit(1);
  }
};

seedAdmin();
