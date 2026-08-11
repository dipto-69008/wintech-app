import mongoose from 'mongoose';

declare global {
  var _mongoConn: { conn: typeof mongoose | null; promise: Promise<typeof mongoose> | null };
}

if (!global._mongoConn) {
  global._mongoConn = { conn: null, promise: null };
}

export async function connectDB(): Promise<typeof mongoose> {
  if (global._mongoConn.conn) return global._mongoConn.conn;

  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI environment variable is not set. Please add it in the Secrets tab.');

  if (!global._mongoConn.promise) {
    global._mongoConn.promise = mongoose.connect(uri);
  }

  try {
    global._mongoConn.conn = await global._mongoConn.promise;
  } catch (err) {
    // reset so next call retries
    global._mongoConn.promise = null;
    throw err;
  }

  return global._mongoConn.conn;
}
