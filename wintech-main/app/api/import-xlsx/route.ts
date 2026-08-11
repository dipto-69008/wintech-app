import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db';

export async function POST() {
  try {
    await connectDB();

    // Dynamic import of the CJS script
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { runImport } = require('@/scripts/import-xlsx.js');

    const logs: string[] = [];
    const result = await runImport((msg: string) => {
      logs.push(msg);
      console.log('[import-xlsx]', msg);
    });

    return NextResponse.json({ ok: true, logs, summary: result.summary });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Import failed';
    console.error('[import-xlsx]', msg);
    return NextResponse.json({ ok: false, error: msg }, { status: 500 });
  }
}
