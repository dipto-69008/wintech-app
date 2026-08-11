import mongoose, { Schema, Document } from 'mongoose';

export interface IAnnouncement extends Document {
  title: string;
  body: string;
  audience: string;
  priority: 'low' | 'medium' | 'high';
  pinned: boolean;
  author: string;
  date: string;
}

const AnnouncementSchema = new Schema<IAnnouncement>({
  title: { type: String, required: true, trim: true },
  body: { type: String, required: true },
  audience: { type: String, default: 'All Staff' },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  pinned: { type: Boolean, default: false },
  author: { type: String, default: 'Admin' },
  date: { type: String },
}, { timestamps: true });

export default mongoose.models.Announcement || mongoose.model<IAnnouncement>('Announcement', AnnouncementSchema);
