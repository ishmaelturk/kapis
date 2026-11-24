import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

const here = dirname(fileURLToPath(import.meta.url));
const projectId = 'demo-kapis';
const listingId = 'listing-1';
const handoverToken = 'a'.repeat(43);
const reservationSlotIds = ['slot-1', 'slot-2', 'slot-3'];
let testEnv;

const listingData = (donorId, overrides = {}) => ({
  donorId,
  title: 'Desk',
  description: 'A sturdy desk.',
  pickupArea: 'Kadıköy',
  pickupAreaKey: 'kadikoy',
  category: 'tablesAndDesks',
  condition: 'good',
  tags: ['desk'],
  approximateLatitude: 41,
  approximateLongitude: 29,
  status: 'available',
  createdAt: serverTimestamp(),
  ...overrides,
});

function listingRef(firestore, id = listingId) {
  return doc(firestore, `listings/${id}`);
}

function privateRef(firestore, id, collectionName) {
  return doc(firestore, `listings/${id}/private/${collectionName}`);
}

function reservationSlotRef(firestore, userId, slotId) {
  return doc(
    firestore,
    `users/${userId}/private/reservationSlots/slots/${slotId}`,
  );
}

async function seedListing(id = listingId, donorId = 'donor-1', status = 'available') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `listings/${id}`), {
      ...listingData(donorId, { status, createdAt: Timestamp.now() }),
    });
  });
}

async function seedPickupAndReservation(
  id,
  donorId,
  receiverId,
  {
    expiresAt = Timestamp.fromMillis(Date.now() + 47 * 60 * 60 * 1000),
    slotId = 'slot-1',
  } = {},
) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, `listings/${id}/private/pickup`), {
      latitude: 41.001,
      longitude: 29.001,
    });
    await setDoc(doc(firestore, `listings/${id}/private/reservation`), {
      receiverId,
      createdAt: Timestamp.now(),
      expiresAt,
      slotId,
    });
    await setDoc(reservationSlotRef(firestore, receiverId, slotId), {
      listingId: id,
    });
    await updateDoc(doc(firestore, `listings/${id}`), { status: 'reserved' });
  });
}

async function seedHandover(id, token = handoverToken) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `listings/${id}/private/handover`), {
      token,
      createdAt: Timestamp.now(),
    });
  });
}

async function reserve(id, receiverId, slotId = 'slot-1') {
  const firestore = testEnv.authenticatedContext(receiverId).firestore();
  const batch = writeBatch(firestore);
  batch.update(listingRef(firestore, id), { status: 'reserved' });
  batch.set(privateRef(firestore, id, 'reservation'), {
    receiverId,
    createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 47 * 60 * 60 * 1000),
    slotId,
  });
  batch.set(reservationSlotRef(firestore, receiverId, slotId), {
    listingId: id,
  });
  return batch.commit();
}

async function releaseReservation(id, userId, status = 'available') {
  const firestore = testEnv.authenticatedContext(userId).firestore();
  const snapshot = await getDoc(privateRef(firestore, id, 'reservation'));
  const reservation = snapshot.data();
  const batch = writeBatch(firestore);
  batch.update(listingRef(firestore, id), { status });
  batch.delete(privateRef(firestore, id, 'reservation'));
  if (reservation?.receiverId && reservation.slotId) {
    batch.delete(
      reservationSlotRef(firestore, reservation.receiverId, reservation.slotId),
    );
  }
  return batch.commit();
}

async function confirmHandover(id, userId, token) {
  const firestore = testEnv.authenticatedContext(userId).firestore();
  const batch = writeBatch(firestore);
  batch.update(listingRef(firestore, id), { status: 'handedOver' });
  batch.update(privateRef(firestore, id, 'reservation'), {
    handoverToken: token,
    confirmedAt: serverTimestamp(),
  });
  batch.delete(reservationSlotRef(firestore, userId, 'slot-1'));
  return batch.commit();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(resolve(here, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: await readFile(resolve(here, '../storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv?.cleanup();
});

describe('Firestore listing rules', () => {
  it('accepts a valid listing created by its donor', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(listingRef(firestore), listingData('donor-1')),
    );
  });

  it('requires sign-in to read public listing documents', async () => {
    await seedListing();
    const guest = testEnv.unauthenticatedContext().firestore();
    const signedIn = testEnv.authenticatedContext('receiver-1').firestore();

    await assertFails(getDoc(listingRef(guest)));
    await assertSucceeds(getDoc(listingRef(signedIn)));
  });

  it('accepts one valid image path and rejects malformed image paths', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(
        listingRef(firestore, 'with-image'),
        listingData('donor-1', {
          imagePaths: ['listing-images/with-image/primary'],
        }),
      ),
    );
    await assertSucceeds(
      updateDoc(listingRef(firestore, 'with-image'), {
        imagePaths: ['listing-images/with-image/primary'],
      }),
    );
    await assertFails(
      setDoc(
        listingRef(firestore, 'bad-image'),
        listingData('donor-1', { imagePaths: ['https://example.com/image.jpg'] }),
      ),
    );
    await assertFails(
      setDoc(
        listingRef(firestore, 'many-images'),
        listingData('donor-1', {
          imagePaths: [
            'listing-images/many-images/first',
            'listing-images/many-images/second',
          ],
        }),
      ),
    );
  });

  it('requires normalized keys for new listings but lets legacy listings be withdrawn', async () => {
    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    const withoutKey = listingData('donor-1');
    delete withoutKey.pickupAreaKey;
    await assertFails(
      setDoc(listingRef(donorDb, 'missing-area-key'), withoutKey),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const legacy = listingData('donor-1', {
        createdAt: Timestamp.now(),
      });
      delete legacy.pickupAreaKey;
      await setDoc(
        doc(context.firestore(), 'listings/legacy-listing'),
        legacy,
      );
    });
    await assertSucceeds(
      updateDoc(listingRef(donorDb, 'legacy-listing'), {
        status: 'withdrawn',
      }),
    );
  });

  it('rejects a listing with a different donor id', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertFails(
      setDoc(listingRef(firestore), listingData('another-donor')),
    );
  });

  it('accepts create-only reports from signed-in users and hides reports', async () => {
    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(listingRef(donorDb), listingData('donor-1')),
    );
    const reporterDb = testEnv.authenticatedContext('reporter-1').firestore();
    const report = doc(reporterDb, 'reports/report-1');
    await assertSucceeds(
      setDoc(report, {
        listingId,
        reporterId: 'reporter-1',
        reason: 'spam',
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(getDoc(report));
    await assertFails(updateDoc(report, { reason: 'other' }));
    await assertFails(
      setDoc(doc(reporterDb, 'reports/forged'), {
        listingId,
        reporterId: 'someone-else',
        reason: 'spam',
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(testEnv.unauthenticatedContext().firestore(), 'reports/guest'), {
        listingId,
        reporterId: 'guest',
        reason: 'spam',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('rejects extra fields, client timestamps, and invalid enum values', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertFails(
      setDoc(
        listingRef(firestore, 'extra-field'),
        listingData('donor-1', { internalNote: 'private' }),
      ),
    );
    await assertFails(
      setDoc(
        listingRef(firestore, 'client-time'),
        listingData('donor-1', { createdAt: Timestamp.now() }),
      ),
    );
    await assertFails(
      setDoc(
        listingRef(firestore, 'bad-enum'),
        listingData('donor-1', { category: 'unknown' }),
      ),
    );
  });

  it('rejects whitespace-only text and malformed tags', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    const invalidListings = [
      { title: '   ' },
      { description: '\t\n' },
      { pickupArea: '  ' },
      { pickupAreaKey: '  ' },
      { tags: ['desk', 42] },
      { tags: ['   '] },
      { tags: ['x'.repeat(33)] },
    ];

    for (const [index, overrides] of invalidListings.entries()) {
      await assertFails(
        setDoc(
          listingRef(firestore, `invalid-${index}`),
          listingData('donor-1', overrides),
        ),
      );
    }
  });

  it('allows the donor to edit and withdraw an available listing', async () => {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(listingRef(firestore), listingData('donor-1')),
    );
    await assertSucceeds(
      updateDoc(listingRef(firestore), { title: 'Updated desk' }),
    );
    await assertSucceeds(
      updateDoc(listingRef(firestore), { status: 'withdrawn' }),
    );
  });

  it('rejects a donor edit by another account', async () => {
    await seedListing();
    const firestore = testEnv.authenticatedContext('stranger').firestore();
    await assertFails(updateDoc(listingRef(firestore), { title: 'Changed' }));
  });

  it('rejects reserving your own listing, an already reserved listing, and a second reservation', async () => {
    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(listingRef(donorDb), listingData('donor-1')),
    );
    await assertFails(reserve(listingId, 'donor-1'));

    await seedListing('reserved-listing', 'donor-2', 'reserved');
    await seedPickupAndReservation('reserved-listing', 'donor-2', 'receiver-1');
    await assertFails(reserve('reserved-listing', 'receiver-2'));
  });

  it('caps each receiver at three active reservation slots', async () => {
    const receiverId = 'receiver-1';
    for (const [index, slotId] of reservationSlotIds.entries()) {
      const id = `slot-listing-${index}`;
      await seedListing(id, `donor-${index}`);
      await assertSucceeds(reserve(id, receiverId, slotId));
    }

    await seedListing('fourth-slot-listing', 'donor-4');
    await assertFails(reserve('fourth-slot-listing', receiverId, 'slot-1'));
    await assertFails(reserve('fourth-slot-listing', receiverId, 'slot-4'));
  });

  it('lets the receiver cancel an unconfirmed reservation atomically', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');
    await assertSucceeds(releaseReservation(listingId, 'receiver-1'));

    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    const listing = await getDoc(listingRef(donorDb));
    assert.equal(listing.data()?.status, 'available');
  });

  it('lets the donor release or withdraw an unconfirmed reservation', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');
    await assertSucceeds(
      releaseReservation(listingId, 'donor-1', 'withdrawn'),
    );

    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    const listing = await getDoc(listingRef(donorDb));
    assert.equal(listing.data()?.status, 'withdrawn');
  });

  it('rejects a stranger cancelling an active reservation', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');
    const firestore = testEnv.authenticatedContext('stranger').firestore();
    const batch = writeBatch(firestore);
    batch.update(listingRef(firestore), { status: 'available' });
    batch.delete(privateRef(firestore, listingId, 'reservation'));
    batch.delete(reservationSlotRef(firestore, 'receiver-1', 'slot-1'));
    await assertFails(batch.commit());
  });

  it('allows an account to release an expired reservation and claim the listing', async () => {
    await seedListing();
    await seedPickupAndReservation(
      listingId,
      'donor-1',
      'receiver-1',
      { expiresAt: Timestamp.fromMillis(Date.now() - 1000) },
    );

    const newReceiverDb = testEnv.authenticatedContext('receiver-2').firestore();
    await assertSucceeds(
      getDoc(privateRef(newReceiverDb, listingId, 'reservation')),
    );
    const release = writeBatch(newReceiverDb);
    release.update(listingRef(newReceiverDb), { status: 'available' });
    release.delete(privateRef(newReceiverDb, listingId, 'reservation'));
    release.delete(reservationSlotRef(newReceiverDb, 'receiver-1', 'slot-1'));
    await assertSucceeds(release.commit());
    await assertSucceeds(reserve(listingId, 'receiver-2'));
  });

  it('limits exact pickup reads to the donor and reserving receiver', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');

    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    const receiverDb = testEnv.authenticatedContext('receiver-1').firestore();
    const strangerDb = testEnv.authenticatedContext('stranger').firestore();
    const signedOutDb = testEnv.unauthenticatedContext().firestore();
    const path = (firestore) => privateRef(firestore, listingId, 'pickup');

    await assertSucceeds(getDoc(path(donorDb)));
    await assertSucceeds(getDoc(path(receiverDb)));
    await assertFails(getDoc(path(strangerDb)));
    await assertFails(getDoc(path(signedOutDb)));
  });

  it('stops sharing exact pickup coordinates after reservation expiry', async () => {
    await seedListing();
    await seedPickupAndReservation(
      listingId,
      'donor-1',
      'receiver-1',
      { expiresAt: Timestamp.fromMillis(Date.now() - 1000) },
    );
    const receiverDb = testEnv.authenticatedContext('receiver-1').firestore();
    await assertFails(
      getDoc(privateRef(receiverDb, listingId, 'pickup')),
    );
  });

  it('allows only the donor to issue a handover token while reserved', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');
    const donorDb = testEnv.authenticatedContext('donor-1').firestore();
    const strangerDb = testEnv.authenticatedContext('stranger').firestore();

    await assertSucceeds(
      setDoc(privateRef(donorDb, listingId, 'handover'), {
        token: handoverToken,
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(privateRef(strangerDb, listingId, 'handover'), {
        token: handoverToken,
        createdAt: serverTimestamp(),
      }),
    );

    await seedListing('available-listing', 'donor-2');
    const otherDonorDb = testEnv.authenticatedContext('donor-2').firestore();
    await assertFails(
      setDoc(privateRef(otherDonorDb, 'available-listing', 'handover'), {
        token: handoverToken,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('confirms handover only with the issued token and rejects replay', async () => {
    await seedListing();
    await seedPickupAndReservation(listingId, 'donor-1', 'receiver-1');
    await seedHandover(listingId);

    await assertFails(confirmHandover(listingId, 'receiver-1', 'b'.repeat(43)));
    await assertFails(confirmHandover(listingId, 'receiver-2', handoverToken));
    await assertSucceeds(confirmHandover(listingId, 'receiver-1', handoverToken));
    await assertFails(confirmHandover(listingId, 'receiver-1', handoverToken));

    await seedListing('after-handover', 'donor-2');
    await assertSucceeds(reserve('after-handover', 'receiver-1', 'slot-1'));
  });
});

describe('Storage listing image rules', () => {
  async function seedOwnedListing() {
    const firestore = testEnv.authenticatedContext('donor-1').firestore();
    await assertSucceeds(
      setDoc(listingRef(firestore), listingData('donor-1')),
    );
  }

  it('allows an owner to upload a supported image', async () => {
    await seedOwnedListing();
    const storage = testEnv.authenticatedContext('donor-1').storage();
    await assertSucceeds(
      uploadBytes(
        ref(storage, `listing-images/${listingId}/photo.png`),
        Uint8Array.from([1, 2, 3]),
        { contentType: 'image/png' },
      ),
    );
  });

  it('rejects non-owners, oversized uploads, and unsupported MIME types', async () => {
    await seedOwnedListing();
    const strangerStorage = testEnv.authenticatedContext('stranger').storage();
    const ownerStorage = testEnv.authenticatedContext('donor-1').storage();

    await assertFails(
      uploadBytes(
        ref(strangerStorage, `listing-images/${listingId}/photo.png`),
        Uint8Array.from([1, 2, 3]),
        { contentType: 'image/png' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(ownerStorage, `listing-images/${listingId}/large.png`),
        new Uint8Array(10 * 1024 * 1024 + 1),
        { contentType: 'image/png' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(ownerStorage, `listing-images/${listingId}/text.txt`),
        Uint8Array.from([1, 2, 3]),
        { contentType: 'text/plain' },
      ),
    );
  });
});
