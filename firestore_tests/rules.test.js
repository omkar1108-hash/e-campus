// Run with:  cd firestore_tests && npm install && npm test
// Needs Java (for the Firestore emulator) and Node 18+.
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection } =
  require('firebase/firestore');

let env;

const user = (role, extra = {}) => ({
  email: `${role}@x.y`, name: role, department: 'MCA', role, active: true, ...extra,
});

const USERS = {
  admin: user('admin'),
  admin2: user('admin'),
  staff: user('adminStaff'),
  staff2: user('adminStaff'),
  teacher: user('teacher'),
  teacherMBA: user('teacher', { department: 'MBA' }),
  library: user('libraryStaff'),
  driver: user('busDriver'),
  student: user('student', { gender: 'female' }),
  studentMBA: user('student', { department: 'MBA', gender: 'male' }),
  rep: user('classRep'),
  repMBA: user('classRep', { department: 'MBA' }),
  disabledAdmin: user('admin', { active: false }),
  // Profile written before the "active" field existed.
  legacyAdmin: { email: 'old@x.y', name: 'Old', department: 'MCA', role: 'admin' },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ecampus',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8089,
    },
  });
});
after(async () => env && env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [id, data] of Object.entries(USERS)) await setDoc(doc(db, 'users', id), data);
    await setDoc(doc(db, 'books', 'b1'), { title: 'T', author: 'A', category: 'C', url: 'https://x.y' });
    await setDoc(doc(db, 'news', 'n-mca'), { title: 'T', body: 'B', department: 'MCA', authorName: 'a', createdAt: 1 });
    await setDoc(doc(db, 'news', 'n-mba'), { title: 'T', body: 'B', department: 'MBA', authorName: 'a', createdAt: 1 });
    await setDoc(doc(db, 'bus', 'current'), { lat: 1, lng: 2, updatedAt: 3 });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const newUser = (role, extra = {}) => user(role, { email: 'new@x.y', ...extra });

// ---- users: reading --------------------------------------------------------
test('signed-in active users can read profiles, others cannot', async () => {
  for (const uid of ['student', 'driver', 'legacyAdmin', 'library'])
    await assertSucceeds(getDoc(doc(as(uid), 'users', 'teacher')));
  await assertFails(getDoc(doc(anon(), 'users', 'teacher')));
  await assertFails(getDoc(doc(as('disabledAdmin'), 'users', 'teacher')));
  await assertFails(getDoc(doc(as('stranger-without-profile'), 'users', 'teacher')));
});

// ---- users: creating (admin-created accounts only) ---------------------------
test('admin creates every role except class rep', async () => {
  for (const role of ['admin', 'adminStaff', 'libraryStaff', 'teacher', 'student', 'busDriver'])
    await assertSucceeds(setDoc(doc(as('admin'), 'users', `n-${role}`), newUser(role)));
  await assertFails(setDoc(doc(as('admin'), 'users', 'n-rep'), newUser('classRep')));
});

test('admin staff creates only library staff, teachers, students and drivers', async () => {
  for (const role of ['libraryStaff', 'teacher', 'student', 'busDriver'])
    await assertSucceeds(setDoc(doc(as('staff'), 'users', `n-${role}`), newUser(role)));
  for (const role of ['admin', 'adminStaff', 'classRep'])
    await assertFails(setDoc(doc(as('staff'), 'users', `n-${role}`), newUser(role)));
});

test('nobody else creates profiles, and nobody self-registers', async () => {
  for (const uid of ['teacher', 'library', 'student', 'rep', 'driver'])
    await assertFails(setDoc(doc(as(uid), 'users', 'n-x'), newUser('student')));
  // A brand-new login writing its own profile as a student is refused too.
  await assertFails(setDoc(doc(as('fresh-uid'), 'users', 'fresh-uid'), newUser('student')));
  await assertFails(setDoc(doc(anon(), 'users', 'n-x'), newUser('student')));
});

test('created profiles must be well formed', async () => {
  await assertFails(setDoc(doc(as('admin'), 'users', 'n1'), newUser('student', { active: false })));
  await assertFails(setDoc(doc(as('admin'), 'users', 'n2'), newUser('student', { isSuper: true })));
  const { email, ...noEmail } = newUser('student');
  await assertFails(setDoc(doc(as('admin'), 'users', 'n3'), noEmail));
});

// ---- users: updating -------------------------------------------------------
test('admin edits and disables others but not themselves', async () => {
  await assertSucceeds(updateDoc(doc(as('admin'), 'users', 'teacher'), { active: false }));
  await assertSucceeds(updateDoc(doc(as('admin'), 'users', 'student'), { role: 'libraryStaff', name: 'N' }));
  await assertSucceeds(updateDoc(doc(as('admin'), 'users', 'admin2'), { active: false }));
  await assertFails(updateDoc(doc(as('admin'), 'users', 'admin'), { role: 'student' }));
  await assertFails(updateDoc(doc(as('admin'), 'users', 'admin'), { active: false }));
});

test('nobody changes an email or uid-bound field', async () => {
  await assertFails(updateDoc(doc(as('admin'), 'users', 'student'), { email: 'evil@x.y' }));
  await assertFails(updateDoc(doc(as('staff'), 'users', 'student'), { email: 'evil@x.y' }));
});

test('admin staff manage everyone except administrators', async () => {
  await assertSucceeds(updateDoc(doc(as('staff'), 'users', 'teacher'), { active: false }));
  await assertSucceeds(updateDoc(doc(as('staff'), 'users', 'student'), { department: 'MBA' }));
  await assertSucceeds(updateDoc(doc(as('staff'), 'users', 'staff2'), { active: false }));
  await assertFails(updateDoc(doc(as('staff'), 'users', 'admin'), { active: false }));
  await assertFails(updateDoc(doc(as('staff'), 'users', 'admin'), { name: 'x' }));
  await assertFails(updateDoc(doc(as('staff'), 'users', 'staff'), { name: 'x' }));
});

test('admin staff cannot grant administrator or admin-staff roles', async () => {
  await assertFails(updateDoc(doc(as('staff'), 'users', 'student'), { role: 'admin' }));
  await assertFails(updateDoc(doc(as('staff'), 'users', 'teacher'), { role: 'adminStaff' }));
  await assertSucceeds(updateDoc(doc(as('staff'), 'users', 'student'), { role: 'teacher' }));
});

test('teachers toggle class reps in their own department only', async () => {
  await assertSucceeds(updateDoc(doc(as('teacher'), 'users', 'student'), { role: 'classRep' }));
  await assertSucceeds(updateDoc(doc(as('teacher'), 'users', 'rep'), { role: 'student' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'studentMBA'), { role: 'classRep' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'repMBA'), { role: 'student' }));
});

test('teachers cannot do anything else to profiles', async () => {
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'student'), { role: 'teacher' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'student'), { role: 'admin' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'student'), { name: 'x' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'student'), { active: false }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'teacher'), { role: 'admin' }));
  await assertFails(updateDoc(doc(as('teacher'), 'users', 'library'), { role: 'student' }));
});

test('other roles cannot edit profiles, including their own', async () => {
  for (const uid of ['student', 'rep', 'library', 'driver']) {
    await assertFails(updateDoc(doc(as(uid), 'users', uid), { role: 'admin' }));
    await assertFails(updateDoc(doc(as(uid), 'users', uid), { name: 'x' }));
  }
});

test('profiles are never deleted', async () => {
  await assertFails(deleteDoc(doc(as('admin'), 'users', 'student')));
  await assertFails(deleteDoc(doc(as('staff'), 'users', 'student')));
});

// ---- disabled and legacy accounts -----------------------------------------------
test('a disabled administrator is locked out of everything', async () => {
  const db = as('disabledAdmin');
  await assertFails(getDoc(doc(db, 'books', 'b1')));
  await assertFails(updateDoc(doc(db, 'users', 'student'), { active: false }));
  await assertFails(setDoc(doc(db, 'users', 'n1'), newUser('student')));
  await assertFails(getDoc(doc(db, 'bus', 'current')));
});

test('profiles written before "active" existed still work', async () => {
  const db = as('legacyAdmin');
  await assertSucceeds(getDoc(doc(db, 'books', 'b1')));
  await assertSucceeds(updateDoc(doc(db, 'users', 'student'), { active: false }));
});

// ---- books -----------------------------------------------------------------
test('books: everyone but drivers read; staff roles write', async () => {
  for (const uid of ['student', 'rep', 'teacher', 'library', 'staff', 'admin'])
    await assertSucceeds(getDoc(doc(as(uid), 'books', 'b1')));
  await assertFails(getDoc(doc(as('driver'), 'books', 'b1')));
  await assertFails(getDoc(doc(anon(), 'books', 'b1')));
  const book = { title: 'N', author: 'A', category: 'C', url: 'https://x.y' };
  for (const uid of ['teacher', 'library', 'staff', 'admin'])
    await assertSucceeds(addDoc(collection(as(uid), 'books'), book));
  for (const uid of ['student', 'rep', 'driver'])
    await assertFails(addDoc(collection(as(uid), 'books'), book));
  await assertFails(deleteDoc(doc(as('student'), 'books', 'b1')));
  await assertSucceeds(deleteDoc(doc(as('library'), 'books', 'b1')));
});

// ---- news ------------------------------------------------------------------
test('news: drivers cannot read, everyone else can', async () => {
  await assertFails(getDoc(doc(as('driver'), 'news', 'n-mca')));
  for (const uid of ['student', 'rep', 'teacher', 'library', 'staff', 'admin'])
    await assertSucceeds(getDoc(doc(as(uid), 'news', 'n-mca')));
});

test('news: who may post', async () => {
  const mine = { title: 'T', body: 'B', department: 'MCA', authorName: 'a', createdAt: 1 };
  const other = { ...mine, department: 'MBA' };
  for (const uid of ['rep', 'teacher', 'staff', 'admin'])
    await assertSucceeds(addDoc(collection(as(uid), 'news'), mine));
  for (const uid of ['student', 'library', 'driver'])
    await assertFails(addDoc(collection(as(uid), 'news'), mine));
  await assertFails(addDoc(collection(as('rep'), 'news'), other));
  await assertFails(addDoc(collection(as('staff'), 'news'), other));
  await assertSucceeds(addDoc(collection(as('admin'), 'news'), other));
});

test('news: who may delete', async () => {
  await assertSucceeds(deleteDoc(doc(as('rep'), 'news', 'n-mca')));
  await assertFails(deleteDoc(doc(as('rep'), 'news', 'n-mba')));
  await assertFails(deleteDoc(doc(as('teacher'), 'news', 'n-mba')));
  await assertSucceeds(deleteDoc(doc(as('staff'), 'news', 'n-mba')));
  await assertSucceeds(deleteDoc(doc(as('admin'), 'news', 'n-mca')));
  await assertFails(deleteDoc(doc(as('student'), 'news', 'n-mca')));
  await assertFails(deleteDoc(doc(as('library'), 'news', 'n-mca')));
});

// ---- chat ------------------------------------------------------------------
test('chat: only the two participants, and no spoofed senders', async () => {
  const chat = 'driver_student';
  const msgs = (db) => collection(db, 'chats', chat, 'messages');
  await assertSucceeds(addDoc(msgs(as('driver')), { senderId: 'driver', text: 'hi', sentAt: 1 }));
  await assertSucceeds(addDoc(msgs(as('student')), { senderId: 'student', text: 'hi', sentAt: 2 }));
  await assertFails(addDoc(msgs(as('student')), { senderId: 'driver', text: 'spoof', sentAt: 3 }));
  await assertFails(addDoc(msgs(as('teacher')), { senderId: 'teacher', text: 'x', sentAt: 4 }));
  await assertSucceeds(getDoc(doc(as('student'), 'chats', chat, 'messages', 'any')));
  await assertFails(getDoc(doc(as('teacher'), 'chats', chat, 'messages', 'any')));
  await assertFails(getDoc(doc(anon(), 'chats', chat, 'messages', 'any')));
});

// ---- bus -------------------------------------------------------------------
test('bus: everyone reads, only drivers write', async () => {
  for (const uid of ['student', 'driver', 'admin', 'teacher'])
    await assertSucceeds(getDoc(doc(as(uid), 'bus', 'current')));
  await assertFails(getDoc(doc(anon(), 'bus', 'current')));
  await assertSucceeds(setDoc(doc(as('driver'), 'bus', 'current'), { lat: 5, lng: 6, updatedAt: 7 }));
  for (const uid of ['admin', 'staff', 'student', 'teacher'])
    await assertFails(setDoc(doc(as(uid), 'bus', 'current'), { lat: 5, lng: 6, updatedAt: 7 }));
});
