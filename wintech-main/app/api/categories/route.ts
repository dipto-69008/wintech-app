import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Category from '@/models/Category';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const query: Record<string, unknown> = {};
    if (search) query.name = { $regex: search, $options: 'i' };
    const data = await Category.find(query).sort({ name: 1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const doc = await Category.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
