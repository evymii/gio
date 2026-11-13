import bcrypt from 'bcryptjs';
import { ACCESS_TOKEN_TTL_SECONDS, REFRESH_TOKEN_TTL_DAYS, hashToken, newRefreshToken, signAccessToken } from '../../lib/tokens.js';
import { ApiError } from '../../utils/ApiError.js';
import { toMeDTO } from '../users/user.dto.js';
import { User, type UserDoc } from '../users/user.model.js';
import { Session } from './session.model.js';

const BCRYPT_ROUNDS = 10;

export const hashPassword = (password: string) => bcrypt.hash(password, BCRYPT_ROUNDS);

async function issueTokens(user: UserDoc, userAgent: string) {
  const refreshToken = newRefreshToken();
  await Session.create({
    user: user._id,
    tokenHash: hashToken(refreshToken),
    userAgent: userAgent.slice(0, 200),
    expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 86_400_000),
  });
  return {
    user: toMeDTO(user),
    accessToken: signAccessToken(String(user._id)),
    refreshToken,
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
  };
}

export const authService = {
  async signup(input: { name: string; email: string; password: string }, userAgent: string) {
    const exists = await User.exists({ email: input.email.toLowerCase() });
    if (exists) throw ApiError.conflict('An account with this email already exists', 'EMAIL_TAKEN');
    const user = await User.create({ name: input.name, email: input.email, passwordHash: await hashPassword(input.password) });
    return issueTokens(user, userAgent);
  },

  async login(input: { email: string; password: string }, userAgent: string) {
    const user = await User.findOne({ email: input.email.toLowerCase() }).select('+passwordHash');
    // Same error for unknown email and wrong password — don't reveal which accounts exist.
    const ok = user ? await bcrypt.compare(input.password, user.passwordHash) : false;
    if (!user || !ok) throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect');
    return issueTokens(user, userAgent);
  },

  /** Rotates the refresh token: the old one stops working immediately. */
  async refresh(refreshToken: string, userAgent: string) {
    const session = await Session.findOneAndDelete({ tokenHash: hashToken(refreshToken), expiresAt: { $gt: new Date() } });
    if (!session) throw new ApiError(401, 'REFRESH_INVALID', 'Please log in again');
    const user = await User.findById(session.user);
    if (!user) throw new ApiError(401, 'REFRESH_INVALID', 'Please log in again');
    return issueTokens(user, userAgent);
  },

  async logout(refreshToken: string) {
    await Session.deleteOne({ tokenHash: hashToken(refreshToken) });
  },
};
