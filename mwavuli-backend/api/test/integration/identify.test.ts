import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getApp, registerUser, auth } from '../helpers';

// Minimal 1×1 JPEG (valid base64 payload for identify route).
const TINY_JPEG_B64 =
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA//2Q==';

test('identify accepts base64 organ images and returns candidates', async () => {
  const app = await getApp();
  const user = await registerUser(app);

  const res = await app.inject({
    method: 'POST',
    url: '/v1/identify',
    headers: auth(user.accessToken),
    payload: {
      images: [
        { organ: 'whole', data: TINY_JPEG_B64, contentType: 'image/jpeg' },
        { organ: 'leaf', data: TINY_JPEG_B64, contentType: 'image/jpeg' },
      ],
    },
  });
  assert.equal(res.statusCode, 200);
  const body = res.json();
  const { candidates, source } = body;
  assert.ok(Array.isArray(candidates));
  assert.ok(['plantnet', 'stub', 'unavailable'].includes(source));
  // Without PLANTNET_API_KEY in test env we expect the explicit stub.
  if (source === 'stub') {
    assert.ok(candidates.length >= 1);
    assert.ok(candidates[0].commonName);
    assert.ok(candidates[0].scientificName);
    assert.ok(typeof candidates[0].confidence === 'number');
  }
});

test('identify requires auth', async () => {
  const app = await getApp();
  const res = await app.inject({
    method: 'POST',
    url: '/v1/identify',
    payload: {
      images: [{ organ: 'whole', data: TINY_JPEG_B64 }],
    },
  });
  assert.equal(res.statusCode, 401);
});
