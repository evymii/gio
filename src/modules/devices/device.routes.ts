import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { Device, LOCATION_PERMISSIONS, PLATFORMS } from './device.model.js';

const upsertSchema = z.object({
  deviceId: z.string().trim().min(8).max(100),
  platform: z.enum(PLATFORMS),
  pushToken: z.string().trim().max(500).nullish(),
  locationPermission: z.enum(LOCATION_PERMISSIONS).optional(),
  appVersion: z.string().trim().max(20).optional(),
});

/** /api/v1/devices — the app registers itself (push token, location permission) on launch. */
export const devicesRouter = Router();
devicesRouter.use(requireAuth);

devicesRouter.put('/', validate(upsertSchema), async (req, res) => {
  const { deviceId, ...rest } = res.locals.body as z.infer<typeof upsertSchema>;
  const d = await Device.findOneAndUpdate(
    { user: req.userId, deviceId },
    { $set: { ...rest, lastSeenAt: new Date() } },
    { upsert: true, new: true, runValidators: true },
  );
  res.json({
    data: {
      id: String(d._id),
      deviceId: d.deviceId,
      platform: d.platform,
      pushToken: d.pushToken,
      locationPermission: d.locationPermission,
      lastSeenAt: d.lastSeenAt.toISOString(),
    },
  });
});
