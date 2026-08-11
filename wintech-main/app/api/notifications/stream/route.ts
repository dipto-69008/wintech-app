import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/db';
import Notification from '@/models/Notification';

export const dynamic = 'force-dynamic';

export async function GET(_req: NextRequest) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      try {
        await connectDB();
        const items = await Notification.find()
          .sort({ createdAt: -1 })
          .limit(20)
          .lean();
        const unreadCount = await Notification.countDocuments({ read: false });
        const payload = JSON.stringify({ items, unreadCount });
        controller.enqueue(encoder.encode(`event: notification\ndata: ${payload}\n\n`));
      } catch {
        // ignore
      }
      // Keep-alive ping every 30s
      const ping = setInterval(() => {
        try { controller.enqueue(encoder.encode(': ping\n\n')); } catch { clearInterval(ping); }
      }, 30000);
      // Close after 55s to avoid timeout; client auto-reconnects
      setTimeout(() => { clearInterval(ping); try { controller.close(); } catch {} }, 55000);
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  });
}
