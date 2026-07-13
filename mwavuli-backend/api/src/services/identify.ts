import { PutObjectCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';
import { config } from '../config';
import { publicUrl, s3 } from './storage';

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
}

export interface IdentifyImage {
  organ: string;
  data: Buffer;
}

/**
 * Identify a tree from public image URLs using Pl@ntNet.
 */
export async function identify(
  imageUrls: string[],
  organs: string[] = [],
): Promise<IdentifyResult> {
  if (!config.PLANTNET_API_KEY) {
    return { candidates: stub(), source: 'stub' };
  }
  try {
    const url = new URL(config.PLANTNET_ENDPOINT);
    url.searchParams.set('api-key', config.PLANTNET_API_KEY);
    imageUrls.forEach((u) => url.searchParams.append('images', u));
    const organList = organs.length ? organs : imageUrls.map(() => 'auto');
    organList.forEach((o) => url.searchParams.append('organs', o));

    const res = await fetch(url, { method: 'GET' });
    if (!res.ok) throw new Error(`plantnet ${res.status}`);
    const candidates = mapPlantNet((await res.json()) as PlantNetResponse);
    return { candidates, source: 'plantnet' };
  } catch {
    return { candidates: [], source: 'unavailable' };
  }
}

/**
 * Identify from raw JPEG bytes (mobile capture). Posts multipart to Pl@ntNet,
 * or stages to S3 + URL identify when multipart is unavailable.
 */
export async function identifyFromBytes(
  images: IdentifyImage[],
): Promise<IdentifyResult> {
  if (!images.length) {
    return { candidates: [], source: 'unavailable' };
  }
  if (!config.PLANTNET_API_KEY) {
    return { candidates: stub(images.length), source: 'stub' };
  }

  const multipart = await identifyMultipart(images);
  if (multipart) return { candidates: multipart, source: 'plantnet' };

  // Fallback: stage to public bucket and use URL-based identify.
  try {
    const urls: string[] = [];
    const organs: string[] = [];
    for (const img of images) {
      const key = `identify-temp/${randomUUID()}.jpg`;
      const pubKey = `public/${key}`;
      await s3.send(
        new PutObjectCommand({
          Bucket: config.S3_BUCKET_PUBLIC,
          Key: pubKey,
          Body: img.data,
          ContentType: 'image/jpeg',
        }),
      );
      urls.push(publicUrl(pubKey));
      organs.push(img.organ || 'auto');
    }
    return await identify(urls, organs);
  } catch {
    return { candidates: [], source: 'unavailable' };
  }
}

async function identifyMultipart(
  images: IdentifyImage[],
): Promise<Candidate[] | null> {
  try {
    const form = new FormData();
    for (const img of images) {
      const blob = new Blob([new Uint8Array(img.data)], { type: 'image/jpeg' });
      form.append('images', blob, `${img.organ || 'leaf'}.jpg`);
      form.append('organs', img.organ || 'auto');
    }
    const url = new URL(config.PLANTNET_ENDPOINT);
    url.searchParams.set('api-key', config.PLANTNET_API_KEY);
    const res = await fetch(url.toString(), { method: 'POST', body: form });
    if (!res.ok) return null;
    return mapPlantNet((await res.json()) as PlantNetResponse);
  } catch {
    return null;
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
