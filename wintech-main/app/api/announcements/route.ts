import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Announcement from '@/models/Announcement';

export async function GET() {
  try {
    await connectDB();
    const data = await Announcement.find().sort({ pinned: -1, createdAt: -1 }).lean();
    return NextResponse.json({ data });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    if (!body.date) body.date = new Date().toISOString().split('T')[0];
    const doc = await Announcement.create(body);
    return NextResponse.json(doc, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
