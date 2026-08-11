import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Party from '@/models/Party';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const status = searchParams.get('status') || '';
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '50');

    const query: Record<string, unknown> = {};
    if (search) query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { mobile: { $regex: search, $options: 'i' } },
      { code: { $regex: search, $options: 'i' } },
    ];
    if (status) query.status = status;

    const [data, total] = await Promise.all([
      Party.find(query).sort({ code: 1 }).skip((page - 1) * limit).limit(limit).lean(),
      Party.countDocuments(query),
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
    const doc = await Party.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
