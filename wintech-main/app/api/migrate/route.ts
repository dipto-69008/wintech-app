import { NextRequest, NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';
import { runMigration } from '@/scripts/migrate';

export async function POST(req: NextRequest) {
  try {
    await connectDB();
    const { tables } = await req.json().catch(() => ({ tables: [] }));
    const result = await runMigration(tables);
    return NextResponse.json(result);
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Migration failed' }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({
    info: 'Send POST to /api/migrate to start SQL→MongoDB migration',
    body: { tables: ['all'] },
  });
}
