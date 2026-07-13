import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getApp, registerUser, auth, createOakTree } from '../helpers';

test('create → feed exposes fuzzy only; exact-location is owner-gated', async () => {
  const app = await getApp();
  const owner = await registerUser(app);

  const create = await createOakTree(app, owner.accessToken);
  assert.equal(create.statusCode, 200);
  const { tree, rewards } = create.json();
  assert.ok(tree.id);
  assert.equal(tree.isFuzzy, true);
  assert.ok(tree.fuzzyLocation, 'has a public fuzzy point');
  assert.equal(tree.exactLocation, undefined, 'no exact point in public payload');
  assert.equal(rewards.pointsEarned, 10);
  assert.ok(rewards.totalPoints >= 10);
  assert.ok(rewards.level >= 1);
  assert.ok(rewards.levelName);

  const feed = await app.inject({ method: 'GET', url: '/v1/feed?limit=50' });
  assert.equal(feed.statusCode, 200);
  const found = feed.json().items.find((t: { id: string }) => t.id === tree.id);
  assert.ok(found, 'tree appears in the public feed');
  assert.equal(found.exactLocation, undefined);

  const exOwner = await app.inject({
    method: 'GET', url: `/v1/trees/${tree.id}/exact-location`,
    headers: auth(owner.accessToken),
  });
  assert.equal(exOwner.statusCode, 200);
  assert.ok(Math.abs(exOwner.json().lat - 43.6489) < 1e-4, 'owner reads exact point');

  const other = await registerUser(app);
  const exOther = await app.inject({
    method: 'GET', url: `/v1/trees/${tree.id}/exact-location`,
    headers: auth(other.accessToken),
  });
  assert.equal(exOther.statusCode, 403, 'RLS blocks non-owner exact read');
});

test('private trees are hidden from the public feed', async () => {
  const app = await getApp();
  const owner = await registerUser(app);
  const create = await createOakTree(app, owner.accessToken, { visibility: 'private' });
  const { tree } = create.json();

  const feed = await app.inject({ method: 'GET', url: '/v1/feed?limit=50' });
  const found = feed.json().items.find((t: { id: string }) => t.id === tree.id);
  assert.equal(found, undefined, 'private tree not in public feed');
});

test('save and unsave bookmark a tree in the user collection', async () => {
  const app = await getApp();
  const owner = await registerUser(app);
  const other = await registerUser(app);

  const create = await createOakTree(app, owner.accessToken);
  const { tree } = create.json();

  const before = await app.inject({
    method: 'GET',
    url: `/v1/trees/${tree.id}`,
    headers: auth(other.accessToken),
  });
  assert.equal(before.json().saved, false);

  const save = await app.inject({
    method: 'POST',
    url: `/v1/trees/${tree.id}/save`,
    headers: auth(other.accessToken),
  });
  assert.equal(save.statusCode, 200);
  assert.equal(save.json().saved, true);

  const after = await app.inject({
    method: 'GET',
    url: `/v1/trees/${tree.id}`,
    headers: auth(other.accessToken),
  });
  assert.equal(after.json().saved, true);

  const savedList = await app.inject({
    method: 'GET',
    url: '/v1/me/saved',
    headers: auth(other.accessToken),
  });
  assert.equal(savedList.statusCode, 200);
  assert.ok(savedList.json().items.some((t: { id: string }) => t.id === tree.id));

  const unsave = await app.inject({
    method: 'DELETE',
    url: `/v1/trees/${tree.id}/save`,
    headers: auth(other.accessToken),
  });
  assert.equal(unsave.statusCode, 200);
  assert.equal(unsave.json().saved, false);
});

test('explore returns tree count and trending species', async () => {
  const app = await getApp();
  const owner = await registerUser(app);
  await createOakTree(app, owner.accessToken);

  const res = await app.inject({ method: 'GET', url: '/v1/explore' });
  assert.equal(res.statusCode, 200);
  const body = res.json();
  assert.ok(body.treeCount >= 1);
  assert.ok(Array.isArray(body.trendingSpecies));
  assert.ok(body.trendingSpecies.length >= 1);
  assert.equal(body.trendingSpecies[0].commonName, 'English Oak');
  assert.ok(Array.isArray(body.recentActivity));
  assert.ok(Array.isArray(body.feed));
});

test('feed supports search and oak filter', async () => {
  const app = await getApp();
  const owner = await registerUser(app);
  const create = await createOakTree(app, owner.accessToken);
  const { tree } = create.json();

  const oak = await app.inject({
    method: 'GET',
    url: '/v1/feed?filter=oak&limit=50',
  });
  assert.equal(oak.statusCode, 200);
  assert.ok(oak.json().items.some((t: { id: string }) => t.id === tree.id));

  const miss = await app.inject({
    method: 'GET',
    url: '/v1/feed?search=zzznomatch&limit=50',
  });
  assert.equal(miss.statusCode, 200);
  assert.equal(miss.json().items.length, 0);
});
