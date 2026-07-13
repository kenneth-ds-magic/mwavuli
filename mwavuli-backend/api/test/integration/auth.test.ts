import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getApp, uniq, login } from '../helpers';

test('register rejects under-13 (COPPA)', async () => {
  const app = await getApp();
  const u = uniq();
  const res = await app.inject({
    method: 'POST', url: '/v1/auth/register',
    payload: {
      email: `${u}@ex.com`, username: u, password: 'password123',
      displayName: 'Kid', birthYear: new Date().getFullYear() - 10, acceptTos: true,
    },
  });
  assert.equal(res.statusCode, 400);
});

test('register → login → refresh → /me', async () => {
  const app = await getApp();
  const u = uniq();
  const reg = await app.inject({
    method: 'POST', url: '/v1/auth/register',
    payload: {
      email: `${u}@ex.com`, username: u, password: 'password123',
      displayName: 'Adult', birthYear: 1990, acceptTos: true,
    },
  });
  assert.equal(reg.statusCode, 200);
  const { accessToken, refreshToken } = reg.json();
  assert.ok(accessToken && refreshToken);

  const li = await login(app, u);
  assert.equal(li.statusCode, 200);

  const rf = await app.inject({
    method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken },
  });
  assert.equal(rf.statusCode, 200);
  assert.ok(rf.json().accessToken);

  const me = await app.inject({
    method: 'GET', url: '/v1/me', headers: { authorization: `Bearer ${accessToken}` },
  });
  assert.equal(me.statusCode, 200);

  const anon = await app.inject({ method: 'GET', url: '/v1/me' });
  assert.equal(anon.statusCode, 401);

  const patch = await app.inject({
    method: 'PATCH',
    url: '/v1/me',
    headers: { authorization: `Bearer ${accessToken}` },
    payload: {
      displayName: 'Jordan Updated',
      bio: 'Weekend naturalist',
      locationLabel: 'Toronto, ON',
    },
  });
  assert.equal(patch.statusCode, 200);
  const body = patch.json();
  assert.equal(body.profile.displayName, 'Jordan Updated');
  assert.equal(body.profile.bio, 'Weekend naturalist');
});
