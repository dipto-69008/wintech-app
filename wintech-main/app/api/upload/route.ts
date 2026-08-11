import { NextRequest, NextResponse } from 'next/server';
import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const MAX_BYTES = 10 * 1024 * 1024; // 10 MB
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']);

export async function POST(req: NextRequest) {
  try {
    const form = await req.formData();
    const file = form.get('file') as File | null;
    if (!file) return NextResponse.json({ error: 'No file provided' }, { status: 400 });

    if (!ALLOWED_MIME.has(file.type))
      return NextResponse.json({ error: 'Only JPEG, PNG, WEBP, GIF, AVIF images are allowed' }, { status: 400 });

    if (file.size > MAX_BYTES)
      return NextResponse.json({ error: 'File too large — maximum 10 MB' }, { status: 400 });

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    const base64 = `data:${file.type};base64,${buffer.toString('base64')}`;

    const result = await cloudinary.uploader.upload(base64, {
      folder: 'wintech/products',
      resource_type: 'image',
      transformation: [{ width: 800, height: 800, crop: 'limit', quality: 'auto', fetch_format: 'auto' }],
    });

    return NextResponse.json({ url: result.secure_url, publicId: result.public_id });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Upload failed' }, { status: 500 });
  }
}
