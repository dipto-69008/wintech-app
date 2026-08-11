import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Product from '@/models/Product';

function escapeRegex(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const status = searchParams.get('status') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = Math.min(parseInt(searchParams.get('limit') || '50'), 200);

    const branch = searchParams.get('branch') || '';

    const query: Record<string, unknown> = {};
    if (search) {
      const safe = escapeRegex(search);
      query.$or = [
        { name: { $regex: safe, $options: 'i' } },
        { code: { $regex: safe, $options: 'i' } },
      ];
    }
    if (status) query.status = status;
    const category = searchParams.get('category') || '';
    if (category) query.categoryName = { $regex: `^${escapeRegex(category)}$`, $options: 'i' };
    if (branch === 'cumilla')    query.stockCumilla    = { $gt: 0 };
    if (branch === 'mymensingh') query.stockMymensingh = { $gt: 0 };
    if (branch === 'bogra')      query.stockBogra      = { $gt: 0 };
    if (branch === 'jessore')    query.stockJessore    = { $gt: 0 };
    if (branch === 'feni')       query.stockFeni       = { $gt: 0 };

    const [data, total] = await Promise.all([
      Product.find(query).sort({ name: 1 }).skip((page - 1) * limit).limit(limit).lean(),
      Product.countDocuments(query),
    ]);

    return NextResponse.json({ data, total, page, limit });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const product = await Product.create(body);
    return NextResponse.json(product, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
