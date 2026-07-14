import { randomUUID } from 'crypto';
import { config } from '../config';

export interface Candidate {
  commonName: string;
  scientificName: string;
  confidence: number; // 0–100
}

/** Where the candidates came from — clients use this to avoid silent demos. */
export type IdentifySource = 'plantnet' | 'stub' | 'unavailable';

export interface IdentifyResult {
  candidates: Candidate[];
  source: IdentifySource;
  /** Short reason when source is unavailable (safe for clients / logs). */
  detail?: string;
}

export interface IdentifyImage {
  organ: string;
  data: Buffer;
}

/** Pl@ntNet organs — our UI "whole" maps to habit/auto. */
function plantNetOrgan(organ: string): string {
  switch (organ) {
    case 'leaf':
    case 'flower':
    case 'fruit':
    case 'bark':
      return organ;
    case 'whole':
      return 'habit';
    default:
      return 'auto';
  }
}

function hasPlantNetKey(): boolean {
  return Boolean(config.PLANTNET_API_KEY?.trim());
}

/**
 * Identify a tree from public image URLs using Pl@ntNet (GET).
 * Only useful when those URLs are reachable from the public internet.
 */
export async function identify(
  imageUrls: string[],
  organs: string[] = [],
): Promise<IdentifyResult> {
  if (!hasPlantNetKey()) {
    return { candidates: stub(), source: 'stub' };
  }
  try {
    const url = new URL(config.PLANTNET_ENDPOINT);
    url.searchParams.set('api-key', config.PLANTNET_API_KEY);
    imageUrls.forEach((u) => url.searchParams.append('images', u));
    const organList =
      organs.length > 0 ? organs.map(plantNetOrgan) : imageUrls.map(() => 'auto');
    organList.forEach((o) => url.searchParams.append('organs', o));

    const res = await fetch(url, { method: 'GET' });
    const text = await res.text();
    if (!res.ok) {
      console.error(`[identify] PlantNet GET ${res.status}: ${text.slice(0, 300)}`);
      return {
        candidates: [],
        source: 'unavailable',
        detail: `plantnet_http_${res.status}`,
      };
    }
    const candidates = mapPlantNet(JSON.parse(text) as PlantNetResponse);
    return { candidates, source: 'plantnet' };
  } catch (err) {
    console.error('[identify] PlantNet GET failed', err);
    return { candidates: [], source: 'unavailable', detail: 'plantnet_error' };
  }
}

/**
 * Identify from raw JPEG bytes (mobile capture). Posts multipart to Pl@ntNet.
 */
export async function identifyFromBytes(
  images: IdentifyImage[],
): Promise<IdentifyResult> {
  if (!images.length) {
    return { candidates: [], source: 'unavailable', detail: 'no_images' };
  }
  if (!hasPlantNetKey()) {
    console.warn(
      '[identify] PLANTNET_API_KEY is empty — returning demo stub candidates',
    );
    return { candidates: stub(images.length), source: 'stub' };
  }

  return identifyMultipart(images);
}

async function identifyMultipart(
  images: IdentifyImage[],
): Promise<IdentifyResult> {
  try {
    const form = new FormData();
    for (const img of images) {
      const name = `${plantNetOrgan(img.organ)}-${randomUUID().slice(0, 8)}.jpg`;
      // Node 20+: File is the reliable way to attach filename + type.
      const file = new File([new Uint8Array(img.data)], name, {
        type: 'image/jpeg',
      });
      form.append('images', file);
      form.append('organs', plantNetOrgan(img.organ));
    }

    const url = new URL(config.PLANTNET_ENDPOINT);
    url.searchParams.set('api-key', config.PLANTNET_API_KEY.trim());

    console.info(
      `[identify] PlantNet POST ${url.origin}${url.pathname} ` +
        `(${images.length} image(s), key …${config.PLANTNET_API_KEY.trim().slice(-4)})`,
    );

    const res = await fetch(url.toString(), { method: 'POST', body: form });
    const text = await res.text();
    if (!res.ok) {
      console.error(`[identify] PlantNet POST ${res.status}: ${text.slice(0, 400)}`);
      return {
        candidates: [],
        source: 'unavailable',
        detail: `plantnet_http_${res.status}`,
      };
    }

    const candidates = mapPlantNet(JSON.parse(text) as PlantNetResponse);
    console.info(`[identify] PlantNet OK — ${candidates.length} candidate(s)`);
    return { candidates, source: 'plantnet' };
  } catch (err) {
    console.error('[identify] PlantNet POST failed', err);
    return {
      candidates: [],
      source: 'unavailable',
      detail: 'plantnet_error',
    };
  }
}

interface PlantNetResponse {
  results?: Array<{
    score?: number;
    species?: {
      scientificNameWithoutAuthor?: string;
      commonNames?: string[];
    };
  }>;
}

function mapPlantNet(data: PlantNetResponse): Candidate[] {
  return (data.results ?? []).slice(0, 5).map((r) => ({
    commonName:
      r.species?.commonNames?.[0] ??
      r.species?.scientificNameWithoutAuthor ??
      'Unknown',
    scientificName: r.species?.scientificNameWithoutAuthor ?? '',
    confidence: Math.round((r.score ?? 0) * 100),
  }));
}

function stub(photoCount = 1): Candidate[] {
  void photoCount;
  return [
    { commonName: 'English Oak', scientificName: 'Quercus robur', confidence: 97 },
    { commonName: 'Sessile Oak', scientificName: 'Quercus petraea', confidence: 71 },
    { commonName: 'Hungarian Oak', scientificName: 'Quercus frainetto', confidence: 44 },
  ];
}
