import mongoose, { Schema, Document } from 'mongoose';

export interface INotification extends Document {
  type: string;
  title: string;
  message: string;
  link?: string;
  read: boolean;
  createdBy?: mongoose.Types.ObjectId;
  meta?: Record<string, unknown>;
}

const NotificationSchema = new Schema<INotification>({
  type:      { type: String, default: 'info' },
  title:     { type: String, required: true },
  message:   { type: String, default: '' },
  link:      String,
  read:      { type: Boolean, default: false },
  createdBy: { type: Schema.Types.ObjectId, ref: 'Employee' },
  meta:      { type: Schema.Types.Mixed },
}, { timestamps: true });

NotificationSchema.index({ read: 1, createdAt: -1 });

export default mongoose.models.Notification
  || mongoose.model<INotification>('Notification', NotificationSchema);
