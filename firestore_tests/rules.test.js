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
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, query, where, getDocs,
} = require('firebase/firestore');

let env;
const BOOK = { title: 'T', author: 'A', category: 'C', url: 'https://x.y', isbn: '' };

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
  driver2: user('busDriver'),
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
    await setDoc(doc(db, 'books', 'b1'), { ...BOOK, status: 'approved', uploadedBy: 'library', uploadedByName: 'L', rejectReason: '' });
    await setDoc(doc(db, 'books', 'bPending'), { ...BOOK, status: 'pending', uploadedBy: 'teacher', uploadedByName: 'T', rejectReason: '' });
    await setDoc(doc(db, 'books', 'bRejected'), { ...BOOK, status: 'rejected', uploadedBy: 'teacher', uploadedByName: 'T', rejectReason: 'bad link' });
    await setDoc(doc(db, 'books', 'bOther'), { ...BOOK, status: 'pending', uploadedBy: 'teacherMBA', uploadedByName: 'T2', rejectReason: '' });
    await setDoc(doc(db, 'books', 'bOld'), { ...BOOK });   // added before approvals existed
    await setDoc(doc(db, 'news', 'n-mca'), { title: 'T', body: 'B', department: 'MCA', authorName: 'a', createdAt: 1 });
    await setDoc(doc(db, 'news', 'n-mba'), { title: 'T', body: 'B', department: 'MBA', authorName: 'a', createdAt: 1 });
    await setDoc(doc(db, 'buses', 'busMCA'), {
      name: 'Bus 1', plate: 'P1', driverUid: 'driver', departments: ['MCA', 'MBA'], active: false,
    });
    await setDoc(doc(db, 'buses', 'busCivil'), {
      name: 'Bus 2', plate: 'P2', driverUid: 'driver2', departments: ['Civil'], active: false,
    });
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

// ---- books ------------------------------------------------------------------
const books = (db) => collection(db, 'books');
const bookDoc = (uid, id) => doc(as(uid), 'books', id);
const newBook = (uploader, status, extra = {}) => ({
  ...BOOK, status, uploadedBy: uploader, uploadedByName: 'N', rejectReason: '', createdAt: 1, ...extra,
});

test('books: everyone except drivers reads approved books', async () => {
  for (const uid of ['student', 'rep', 'teacher', 'library', 'staff', 'admin'])
    await assertSucceeds(getDoc(bookDoc(uid, 'b1')));
  await assertFails(getDoc(bookDoc('driver', 'b1')));
  await assertFails(getDoc(doc(anon(), 'books', 'b1')));
  const q = (uid) => getDocs(query(books(as(uid)), where('status', '==', 'approved')));
  const seen = await assertSucceeds(q('student'));
  if (seen.size !== 1) throw new Error(`student should see 1 approved book, saw ${seen.size}`);
  await assertFails(q('driver'));
});

test('books: unapproved books are private to their teacher and the library team', async () => {
  for (const uid of ['student', 'rep', 'driver', 'teacherMBA'])
    await assertFails(getDoc(bookDoc(uid, 'bPending')));
  for (const uid of ['teacher', 'library', 'staff', 'admin']) {
    await assertSucceeds(getDoc(bookDoc(uid, 'bPending')));
    await assertSucceeds(getDoc(bookDoc(uid, 'bRejected')));
  }
  await assertFails(getDoc(bookDoc('teacher', 'bOther')));   // another teacher's pending book
});

test('books: the queries the app sends for each role', async () => {
  await assertSucceeds(getDocs(query(books(as('teacher')), where('uploadedBy', '==', 'teacher'))));
  await assertFails(getDocs(query(books(as('teacher')), where('uploadedBy', '==', 'teacherMBA'))));
  await assertFails(getDocs(books(as('teacher'))));
  await assertFails(getDocs(books(as('student'))));
  for (const uid of ['library', 'staff', 'admin']) {
    const all = await assertSucceeds(getDocs(books(as(uid))));
    if (all.size !== 5) throw new Error(`${uid} should see 5 books, saw ${all.size}`);
  }
});

test('books: teachers add pending books, staff add approved ones', async () => {
  await assertSucceeds(addDoc(books(as('teacher')), newBook('teacher', 'pending')));
  await assertFails(addDoc(books(as('teacher')), newBook('teacher', 'approved')));   // no self-approval
  await assertFails(addDoc(books(as('teacher')), newBook('teacherMBA', 'pending'))); // not in someone else's name
  for (const uid of ['library', 'staff', 'admin'])
    await assertSucceeds(addDoc(books(as(uid)), newBook(uid, 'approved')));
  await assertFails(addDoc(books(as('library')), newBook('library', 'pending')));
  for (const uid of ['student', 'rep', 'driver'])
    await assertFails(addDoc(books(as(uid)), newBook(uid, 'approved')));
});

test('books: new books must be well formed', async () => {
  const add = (extra) => addDoc(books(as('library')), newBook('library', 'approved', extra));
  await assertSucceeds(add({ isbn: '9781617296147', cover: 'abc' }));
  await assertFails(add({ title: '' }));
  await assertFails(add({ title: 'x'.repeat(201) }));
  await assertFails(add({ url: 'x'.repeat(2001) }));
  await assertFails(add({ cover: 'x'.repeat(700001) }));
  await assertFails(add({ isAdmin: true }));                       // unknown field
  await assertFails(add({ rejectReason: 'pre-rejected' }));
});

test('books: only library staff verify, and only pending books', async () => {
  const verify = (uid, id, data) => updateDoc(bookDoc(uid, id), data);
  // Things that must be refused (the books are still untouched here).
  await assertFails(verify('library', 'bRejected', { status: 'approved', rejectReason: '' }));   // already decided
  await assertFails(verify('library', 'b1', { status: 'rejected', rejectReason: 'x' }));         // already approved
  await assertFails(verify('library', 'bPending', { status: 'rejected', rejectReason: '' }));    // a reason is required
  await assertFails(verify('library', 'bPending', { status: 'rejected', rejectReason: 'x'.repeat(201) }));
  await assertFails(verify('library', 'bPending', { status: 'approved', rejectReason: '', title: 'sneaky' }));
  for (const uid of ['teacher', 'staff', 'admin', 'student', 'driver'])
    await assertFails(verify(uid, 'bPending', { status: 'approved', rejectReason: '' }));
  // What library staff may do.
  await assertSucceeds(verify('library', 'bPending', { status: 'approved', rejectReason: '' }));
  await assertSucceeds(verify('library', 'bOther', { status: 'rejected', rejectReason: 'duplicate' }));
});

test('books: a teacher can fix and resubmit their own unapproved book, nothing else', async () => {
  const mine = (id) => bookDoc('teacher', id);
  // Things that must be refused.
  await assertFails(updateDoc(mine('bRejected'), { status: 'approved', rejectReason: '' }));      // self-approval
  await assertFails(updateDoc(mine('bPending'), { status: 'approved' }));
  await assertFails(updateDoc(mine('bRejected'), { status: 'pending' }));                         // reason must be cleared
  await assertFails(updateDoc(mine('b1'), { title: 'changed after approval' }));                 // approved: library staff only
  await assertFails(updateDoc(bookDoc('teacherMBA', 'bPending'), { title: 'not mine' }));
  await assertFails(updateDoc(mine('bPending'), { uploadedBy: 'someone' }));
  // What a teacher may do.
  await assertSucceeds(updateDoc(mine('bRejected'), { title: 'Fixed', status: 'pending', rejectReason: '' }));
  await assertSucceeds(updateDoc(mine('bPending'), { title: 'Better title' }));
});

test('books: library team edits the content of any book but not its status or owner', async () => {
  for (const uid of ['library', 'staff', 'admin']) {
    await assertSucceeds(updateDoc(bookDoc(uid, 'b1'), { title: `edited by ${uid}`, cover: 'abc' }));
    await assertSucceeds(updateDoc(bookDoc(uid, 'bPending'), { author: 'New Author' }));
  }
  for (const uid of ['staff', 'admin'])
    await assertFails(updateDoc(bookDoc(uid, 'bPending'), { status: 'approved' }));   // only library staff verify
  await assertFails(updateDoc(bookDoc('admin', 'b1'), { uploadedBy: 'admin' }));
  await assertFails(updateDoc(bookDoc('student', 'b1'), { title: 'x' }));
});

test('books: the uploader and the library team delete', async () => {
  await assertSucceeds(deleteDoc(bookDoc('teacher', 'bPending')));
  await assertFails(deleteDoc(bookDoc('teacher', 'bOther')));
  await assertFails(deleteDoc(bookDoc('teacher', 'b1')));
  for (const [uid, id] of [['library', 'b1'], ['staff', 'bOther'], ['admin', 'bRejected']])
    await assertSucceeds(deleteDoc(bookDoc(uid, id)));
  for (const uid of ['student', 'rep', 'driver'])
    await assertFails(deleteDoc(bookDoc(uid, 'bPending')));
});

test('books: books from before approvals can be approved in one go by staff only', async () => {
  for (const uid of ['library', 'staff', 'admin'])
    await assertSucceeds(updateDoc(bookDoc(uid, 'bOld'), { status: 'approved', uploadedBy: '' }));
  await assertFails(updateDoc(bookDoc('teacher', 'bOld'), { status: 'approved', uploadedBy: '' }));
  await assertFails(updateDoc(bookDoc('library', 'b1'), { status: 'approved', uploadedBy: '' })); // already has a status
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

test('news: a poster image is optional, a string and small', async () => {
  const post = (extra) => addDoc(collection(as('rep'), 'news'), {
    title: 'T', body: 'B', department: 'MCA', authorName: 'a', createdAt: 1, ...extra,
  });
  await assertSucceeds(post({}));
  await assertSucceeds(post({ image: 'abcd' }));
  await assertFails(post({ image: 'x'.repeat(700001) }));
  await assertFails(post({ image: 42 }));
  await assertFails(post({ extra: 'field' }));
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
// Who may talk to whom (see ChatPolicy in the app).
const chatId = (a, b) => [a, b].sort().join('_');
const msgs = (db, a, b) => collection(db, 'chats', chatId(a, b), 'messages');
const msg = (sender, text = 'hi') => ({ senderId: sender, text, sentAt: 1, deleted: false, pinned: false });
const canSend = async (from, to) => {
  try {
    await assertSucceeds(addDoc(msgs(as(from), from, to), msg(from)));
    return true;
  } catch (_) {
    await assertFails(addDoc(msgs(as(from), from, to), msg(from)));
    return false;
  }
};

test('chat: students talk to all students and to teachers of their own department', async () => {
  for (const [a, b] of [['student', 'studentMBA'], ['student', 'rep'], ['rep', 'repMBA'], ['student', 'teacher'], ['teacher', 'student'], ['studentMBA', 'teacherMBA']])
    if (!(await canSend(a, b))) throw new Error(`${a} -> ${b} should be allowed`);
});

test('chat: students cannot chat with teachers of other departments or with other staff', async () => {
  for (const [a, b] of [['student', 'teacherMBA'], ['studentMBA', 'teacher'], ['student', 'library'], ['student', 'staff'],
    ['student', 'admin'], ['student', 'driver'], ['rep', 'library'], ['rep', 'driver'],
    ['library', 'student'], ['driver', 'student'], ['admin', 'student'], ['staff', 'rep'], ['teacherMBA', 'student']])
    if (await canSend(a, b)) throw new Error(`${a} -> ${b} should be refused`);
});

test('chat: staff talk to each other', async () => {
  for (const [a, b] of [['teacher', 'teacherMBA'], ['teacher', 'library'], ['library', 'staff'], ['admin', 'driver'], ['driver', 'teacher'], ['staff', 'admin']])
    if (!(await canSend(a, b))) throw new Error(`${a} -> ${b} should be allowed`);
});

test('chat: nobody chats with a disabled person or with themselves, and strangers are refused', async () => {
  if (await canSend('admin', 'disabledAdmin')) throw new Error('disabled account was reachable');
  await assertFails(addDoc(msgs(as('student'), 'student', 'student'), msg('student')));
  await assertFails(addDoc(msgs(anon(), 'student', 'rep'), msg('student')));
});

test('chat: messages must be well formed and sent as yourself', async () => {
  const db = as('student');
  await assertFails(addDoc(msgs(db, 'student', 'rep'), msg('rep')));                       // spoofed sender
  await assertFails(addDoc(msgs(db, 'student', 'rep'), { ...msg('student'), pinned: true }));
  await assertFails(addDoc(msgs(db, 'student', 'rep'), { ...msg('student'), deleted: true }));
  await assertFails(addDoc(msgs(db, 'student', 'rep'), msg('student', '')));               // empty
  await assertFails(addDoc(msgs(db, 'student', 'rep'), msg('student', 'x'.repeat(4001))));
  await assertFails(addDoc(msgs(db, 'student', 'rep'), { ...msg('student'), admin: true })); // extra field
  await assertFails(addDoc(msgs(as('teacher'), 'student', 'rep'), msg('teacher')));        // not a participant
});

test('chat: only the two people read a conversation', async () => {
  await env.withSecurityRulesDisabled(async (ctx) =>
    setDoc(doc(ctx.firestore(), 'chats', chatId('student', 'rep'), 'messages', 'm1'), msg('student')));
  const m = (uid) => doc(as(uid), 'chats', chatId('student', 'rep'), 'messages', 'm1');
  await assertSucceeds(getDoc(m('student')));
  await assertSucceeds(getDoc(m('rep')));
  await assertFails(getDoc(m('teacher')));
  await assertFails(getDoc(m('admin')));
  await assertFails(getDoc(doc(anon(), 'chats', chatId('student', 'rep'), 'messages', 'm1')));
});

const seedMsg = async (a = 'student', b = 'rep', id = 'm1', extra = {}) =>
  env.withSecurityRulesDisabled(async (ctx) =>
    setDoc(doc(ctx.firestore(), 'chats', chatId(a, b), 'messages', id), { ...msg(a), ...extra }));
const m = (uid, a = 'student', b = 'rep', id = 'm1') => doc(as(uid), 'chats', chatId(a, b), 'messages', id);

test('chat: only the sender edits a message, and only its text', async () => {
  await seedMsg();
  await assertSucceeds(updateDoc(m('student'), { text: 'fixed', editedAt: 5 }));
  await assertFails(updateDoc(m('rep'), { text: 'hijack', editedAt: 5 }));      // the other person
  await assertFails(updateDoc(m('teacher'), { text: 'hijack', editedAt: 5 }));  // a stranger
  await assertFails(updateDoc(m('student'), { senderId: 'rep' }));
  await assertFails(updateDoc(m('student'), { text: '', editedAt: 5 }));
  await assertFails(updateDoc(m('student'), { text: 'x', sentAt: 99 }));
});

test('chat: only the sender deletes a message, for everyone, leaving a stub', async () => {
  await seedMsg();
  await assertFails(updateDoc(m('rep'), { deleted: true, text: '', pinned: false }));
  await assertFails(updateDoc(m('student'), { deleted: true }));                 // text must be cleared
  await assertFails(deleteDoc(m('student')));                                    // never hard-deleted
  await assertSucceeds(updateDoc(m('student'), { deleted: true, text: '', pinned: false }));
  // A deleted message cannot be edited or pinned again.
  await assertFails(updateDoc(m('student'), { text: 'back', editedAt: 6 }));
  await assertFails(updateDoc(m('rep'), { pinned: true }));
});

test('chat: either person pins and unpins, nobody else, and nothing else changes', async () => {
  await seedMsg();
  await assertSucceeds(updateDoc(m('rep'), { pinned: true }));
  await assertSucceeds(updateDoc(m('student'), { pinned: false }));
  await assertFails(updateDoc(m('teacher'), { pinned: true }));
  await assertFails(updateDoc(m('rep'), { pinned: true, text: 'changed' }));
  await assertFails(updateDoc(m('rep'), { pinned: 'yes' }));
});

test('chat: summary records only your own latest message for your own two-person chat', async () => {
  const sum = (uid, other, extra = {}) => ({
    participants: [uid, other].sort(), lastText: 'hi', lastMessageAt: 1, lastSenderId: uid, ...extra,
  });
  const c = (uid, other) => doc(as(uid), 'chats', chatId(uid, other));
  await assertSucceeds(setDoc(c('student', 'rep'), sum('student', 'rep')));
  await assertSucceeds(setDoc(c('rep', 'student'), sum('rep', 'student', { lastText: 'reply' })));
  await assertFails(setDoc(c('student', 'rep'), sum('student', 'rep', { lastSenderId: 'rep' })));   // forged sender
  await assertFails(setDoc(c('student', 'rep'), sum('student', 'rep', { participants: ['student', 'teacher'] })));
  await assertFails(setDoc(c('student', 'library'), sum('student', 'library')));                    // not allowed to chat
  await assertFails(setDoc(c('teacher', 'rep'), { ...sum('teacher', 'rep'), extra: 1 }));           // extra field
});

test('chat: the list of conversations is private to its participants', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'chats', chatId('student', 'rep')), { participants: ['rep', 'student'], lastText: 'a', lastMessageAt: 1, lastSenderId: 'student' });
    await setDoc(doc(db, 'chats', chatId('teacher', 'library')), { participants: ['library', 'teacher'], lastText: 'b', lastMessageAt: 2, lastSenderId: 'teacher' });
  });
  const mine = await assertSucceeds(getDocs(query(collection(as('student'), 'chats'), where('participants', 'array-contains', 'student'))));
  if (mine.size !== 1) throw new Error(`student should see 1 chat, saw ${mine.size}`);
  await assertFails(getDocs(query(collection(as('student'), 'chats'), where('participants', 'array-contains', 'teacher'))));
  await assertFails(getDocs(collection(as('student'), 'chats')));
  await assertFails(getDoc(doc(as('admin'), 'chats', chatId('student', 'rep'))));
});

test('chat: read markers are private and shaped correctly', async () => {
  await assertSucceeds(setDoc(doc(as('student'), 'userState', 'student'), { readAt: { a_b: 5 } }, { merge: true }));
  await assertSucceeds(getDoc(doc(as('student'), 'userState', 'student')));
  await assertFails(getDoc(doc(as('rep'), 'userState', 'student')));
  await assertFails(setDoc(doc(as('rep'), 'userState', 'student'), { readAt: {} }));
  await assertFails(setDoc(doc(as('student'), 'userState', 'student'), { readAt: 'x' }));
  await assertFails(setDoc(doc(as('student'), 'userState', 'student'), { readAt: {}, role: 'admin' }));
  await assertFails(setDoc(doc(as('disabledAdmin'), 'userState', 'disabledAdmin'), { readAt: {} }));
});

// ---- buses -----------------------------------------------------------------
const buses = (db) => collection(db, 'buses');
const newBus = (extra = {}) => ({
  name: 'Bus 3', plate: 'P3', driverUid: null, departments: ['MCA'], active: false, ...extra,
});

test('buses: students read only buses of their department', async () => {
  await assertSucceeds(getDoc(doc(as('student'), 'buses', 'busMCA')));
  await assertFails(getDoc(doc(as('student'), 'buses', 'busCivil')));
  await assertSucceeds(getDocs(query(buses(as('student')), where('departments', 'array-contains', 'MCA'))));
  // The query the app really sends for each student.
  const mine = await assertSucceeds(
    getDocs(query(buses(as('studentMBA')), where('departments', 'array-contains', 'MBA'))));
  if (mine.size !== 1) throw new Error(`expected 1 bus for MBA, got ${mine.size}`);
  // Asking for another department's buses, or for everything, is refused.
  await assertFails(getDocs(query(buses(as('student')), where('departments', 'array-contains', 'Civil'))));
  await assertFails(getDocs(buses(as('student'))));
  await assertSucceeds(getDoc(doc(as('rep'), 'buses', 'busMCA')));
  await assertFails(getDoc(doc(as('repMBA'), 'buses', 'busCivil')));
});

test('buses: admin, admin staff, teachers and library staff see every bus', async () => {
  for (const uid of ['admin', 'staff', 'teacher', 'library']) {
    const all = await assertSucceeds(getDocs(buses(as(uid))));
    if (all.size !== 2) throw new Error(`${uid} saw ${all.size} buses`);
  }
});

test('buses: a driver sees only their own bus', async () => {
  await assertSucceeds(getDoc(doc(as('driver'), 'buses', 'busMCA')));
  await assertFails(getDoc(doc(as('driver'), 'buses', 'busCivil')));
  await assertSucceeds(getDocs(query(buses(as('driver')), where('driverUid', '==', 'driver'))));
  await assertFails(getDocs(buses(as('driver'))));
});

test('buses: signed-out and disabled users see nothing', async () => {
  await assertFails(getDoc(doc(anon(), 'buses', 'busMCA')));
  await assertFails(getDocs(buses(as('disabledAdmin'))));
});

test('buses: only admin and admin staff create them, inactive and well formed', async () => {
  for (const uid of ['admin', 'staff'])
    await assertSucceeds(addDoc(buses(as(uid)), newBus()));
  for (const uid of ['teacher', 'library', 'driver', 'student', 'rep'])
    await assertFails(addDoc(buses(as(uid)), newBus()));
  await assertFails(addDoc(buses(as('admin')), newBus({ active: true })));
  await assertFails(addDoc(buses(as('admin')), newBus({ lat: 1, lng: 2 })));
});

test('buses: administration edits configuration but cannot run a trip', async () => {
  for (const uid of ['admin', 'staff']) {
    await assertSucceeds(updateDoc(doc(as(uid), 'buses', 'busMCA'), {
      name: 'Renamed', plate: 'Z', driverUid: 'driver2', departments: ['MCA'],
    }));
    await assertFails(updateDoc(doc(as(uid), 'buses', 'busMCA'), { active: true }));
    await assertFails(updateDoc(doc(as(uid), 'buses', 'busMCA'), { lat: 1, lng: 2, updatedAt: 3 }));
  }
  for (const uid of ['teacher', 'library', 'student', 'rep', 'driver'])
    await assertFails(updateDoc(doc(as(uid), 'buses', 'busMCA'), { name: 'x' }));
});

test('buses: only the assigned driver runs the trip', async () => {
  const bus = (uid) => doc(as(uid), 'buses', 'busMCA');
  await assertSucceeds(updateDoc(bus('driver'), { active: true, lat: 1, lng: 2, updatedAt: 3, tripStartedAt: 3 }));
  await assertSucceeds(updateDoc(bus('driver'), { lat: 1.1, lng: 2.1, updatedAt: 4 }));
  await assertSucceeds(updateDoc(bus('driver'), { active: false }));
  await assertFails(updateDoc(bus('driver2'), { active: true, lat: 1, lng: 2, updatedAt: 3 }));
  for (const uid of ['admin', 'staff', 'teacher', 'student'])
    await assertFails(updateDoc(bus(uid), { active: true, lat: 1, lng: 2, updatedAt: 3 }));
});

test('buses: a driver cannot reassign or reconfigure the bus', async () => {
  const bus = doc(as('driver'), 'buses', 'busMCA');
  await assertFails(updateDoc(bus, { driverUid: 'driver2' }));
  await assertFails(updateDoc(bus, { departments: ['Civil'] }));
  await assertFails(updateDoc(bus, { name: 'Mine' }));
  await assertFails(updateDoc(bus, { active: true, name: 'Mine' }));
});

test('buses: only administration deletes', async () => {
  await assertSucceeds(deleteDoc(doc(as('admin'), 'buses', 'busMCA')));
  await assertSucceeds(deleteDoc(doc(as('staff'), 'buses', 'busCivil')));
  await assertFails(deleteDoc(doc(as('driver'), 'buses', 'busMCA')));
  await assertFails(deleteDoc(doc(as('teacher'), 'buses', 'busMCA')));
});

test('the old single "bus" collection is no longer accessible', async () => {
  await assertFails(getDoc(doc(as('admin'), 'bus', 'current')));
  await assertFails(setDoc(doc(as('driver'), 'bus', 'current'), { lat: 1 }));
});
