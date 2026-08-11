import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import Notification from '@/models/Notification';

export async function GET(req: NextRequest) {
  try {
    await connectDB();
    const limit = parseInt(new URL(req.url).searchParams.get('limit') || '20');
    const items = await Notification.find()
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();
    const unreadCount = await Notification.countDocuments({ read: false });
    return NextResponse.json({ items, unreadCount });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const body = await req.json();
    const n = await Notification.create(body);
    return NextResponse.json(n, { status: 201 });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}

// PATCH /api/notifications  → mark all read
export async function PATCH() {
  try {
    await connectDB();
    await Notification.updateMany({ read: false }, { read: true });
    return NextResponse.json({ ok: true });
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Server error' }, { status: 500 });
  }
}
